/**
 * viewer.js — Minimal CesiumJS viewer for plateau-mago-implicit
 *
 * Loads configurable tileset.json. Supports:
 * - Switching between Sarabetsu Village and Muroran City datasets
 * - Switching between Explicit and Implicit outputs
 * - Predefined viewpoints
 * - Geographic jumps
 * - Diagnostics panel
 * - Attribution display
 */

// Predefined viewpoints.
//
// All entries point at real published builds on tunnel.optgeo.org
// (scripts/publish.sh / make publish), so they resolve from the GitHub Pages
// viewer with no local server needed — verified reachable via `curl -I`
// 2026-08-26 (see HANDOVER.md "Real public hosting"). Only full-profile
// (whole-municipality) entries are offered — the small_file (single
// building) entries served Phase 1-3/5's determinism/comparison
// experiments, which are done; both the dropdown entries and the
// underlying published data were removed together (2026-08-26, at the
// user's request) rather than leaving a stale menu item pointing at
// deleted data.
//
// destination/orientation use each build's own root tileset.json
// bounding region (computed 2026-08-26) to center on the whole
// municipality's building extent, not a guess — Sarabetsu spans roughly
// 16km x 22km, Muroran roughly 11.5km x 15.5km. Both explicit_full and
// implicit_full for a dataset intentionally use the *Explicit* build's
// region, not the Implicit one's: Implicit's root region is padded out to
// the quadtree grid's boundary (needed for valid subdivision), not
// tightly fit to actual building content the way Explicit's is —
// confirmed by comparing the two directly (Implicit's north edge sits
// ~3-6km further out than Explicit's for both municipalities), which
// shifted the computed center north of where the buildings actually are.
//
// Altitude is deliberately much lower than "fit the whole extent in one
// shot" would need (e.g. Sarabetsu's 22km-wide extent would want ~22km+
// altitude) — at that altitude the root tile's own geometricError already
// satisfies CesiumJS's default maximumScreenSpaceError (16px) before ever
// reaching a tile with actual content, so the view looks sparse/empty
// rather than "whole municipality, zoomed out" (verified by computing the
// SSE-vs-distance refinement threshold directly: root geometricError 512
// stops refining beyond ~22km at threshold 16, which is almost exactly
// where the old 22km viewpoint sat). Lower altitude trades "shows the
// literal full extent" for "actually shows buildings" — a deliberate
// choice per user feedback that a sparse full-extent view reads worse
// than a denser partial one.
const VIEWPOINTS = {
  sarabetsu_explicit_full: {
    label: '更別村 — Explicit（全建物 6,795棟）',
    tilesetUrl: 'https://tunnel.optgeo.org/plateau-mago-implicit/sarabetsu/explicit/full/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(143.2044, 42.6462, 6000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-90),
      roll: 0,
    },
  },
  sarabetsu_implicit_full: {
    label: '更別村 — Implicit（全建物 6,795棟）',
    tilesetUrl: 'https://tunnel.optgeo.org/plateau-mago-implicit/sarabetsu/implicit/full/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(143.2044, 42.6462, 6000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-90),
      roll: 0,
    },
  },
  muroran_explicit_full: {
    label: '室蘭市 — Explicit（全建物 55,906棟）',
    tilesetUrl: 'https://tunnel.optgeo.org/plateau-mago-implicit/muroran/explicit/full/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(140.9786, 42.3613, 5000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-90),
      roll: 0,
    },
  },
  muroran_implicit_full: {
    label: '室蘭市 — Implicit（全建物 55,906棟）',
    tilesetUrl: 'https://tunnel.optgeo.org/plateau-mago-implicit/muroran/implicit/full/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(140.9786, 42.3613, 5000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-90),
      roll: 0,
    },
  },
};

// Diagnostics state
let firstVisibleTime = null;
let usefulViewTime = null;
let loadStartTime = null;
let currentTileset = null;

// Initialise Cesium viewer without ion token requirement
Cesium.Ion.defaultAccessToken = '';

const viewer = new Cesium.Viewer('cesiumContainer', {
  baseLayerPicker: false,
  // Without this, Cesium constructs its own default ion-based base layer
  // (Bing Aerial) even though we clear the ion token above — it just fails
  // to load instead of not existing. Explicitly skip it; kitaphoto is
  // added as the only imagery layer right after construction, below.
  baseLayer: false,
  geocoder: false,
  homeButton: true,
  sceneModePicker: false,
  navigationHelpButton: false,
  animation: false,
  timeline: false,
  fullscreenButton: false,
  // Cesium's default click-to-inspect popup shows raw feature properties
  // (id, BatchId, NodeName, FileName) — exactly the technical detail this
  // viewer's own UI deliberately hides by default. Off for consistency;
  // selectionIndicator (the highlight bracket) stays on for basic feedback.
  infoBox: false,
  // `imageryProvider` (used here previously, for OSM) was deprecated in
  // CesiumJS 1.104 and fully REMOVED in 1.107 — silently ignored by 1.144
  // with no error/warning, so the globe's imagery was never actually
  // loading regardless of which provider was named. Found 2026-08-26 while
  // debugging why kitaphoto (below) wasn't appearing: `viewer.imageryLayers.length`
  // was 0 even after construction. Fixed by using the current API
  // (`baseLayer`) instead — see the assignment after construction below.
  terrainProvider: new Cesium.EllipsoidTerrainProvider(),
  creditContainer: document.createElement('div'),
});

// kitaphoto: GSI seamless aerial photography, re-tiled and gap-filled,
// served from the user's own Martin tileserver (stars.optgeo.org) — not a
// Cesium ion asset, so no API key/token is needed. TileJSON confirmed
// 2026-08-26 via `curl https://stars.optgeo.org/kitaphoto` (minzoom 2,
// maxzoom 12; z13+ intentionally not covered by this tileset, per its own
// description — CesiumJS will upsample beyond z12 rather than fail).
// Tiles are 512x512 (confirmed by downloading and inspecting one), not
// Cesium's 256x256 default — tileWidth/tileHeight must be set explicitly
// or the zoom-level-to-URL mapping is wrong (a 512px tile at level z
// covers what a standard 256px tiling scheme calls level z+1).
viewer.imageryLayers.addImageryProvider(
  new Cesium.UrlTemplateImageryProvider({
    url: 'https://stars.optgeo.org/kitaphoto/{z}/{x}/{y}',
    credit: '国土地理院 シームレス空中写真 (GSI seamlessphoto), CC BY 4.0',
    tileWidth: 512,
    tileHeight: 512,
    minimumLevel: 2,
    maximumLevel: 12,
  })
);

viewer.scene.fog.enabled = false;
viewer.scene.globe.depthTestAgainstTerrain = true;

// Start already looking at Hokkaido, not the default whole-Earth view —
// this viewer is only ever about Sarabetsu/Muroran, so a global starting
// view is irrelevant to what it's for, and it also means the initial
// low-zoom tile requests land inside kitaphoto's actual coverage instead
// of at levels/areas it doesn't serve (kitaphoto is Japan-focused; the
// whole-Earth default view logs harmless but noisy "failed to obtain
// image tile" console errors for level 0/1 and out-of-coverage areas).
viewer.camera.setView({
  destination: Cesium.Cartesian3.fromDegrees(142.3, 42.5, 400000),
});

// Helpers
function setStatus(msg) {
  document.getElementById('status').textContent = msg;
}

function updateDiagnostic(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

function formatMs(ms) {
  if (ms < 1000) return ms + ' ms';
  return (ms / 1000).toFixed(1) + ' s';
}

// Load a tileset from URL
async function loadTileset(url, label) {
  if (currentTileset) {
    viewer.scene.primitives.remove(currentTileset);
    currentTileset = null;
  }

  firstVisibleTime = null;
  usefulViewTime = null;
  loadStartTime = performance.now();

  setStatus(`読み込み中: ${label || url}`);
  updateDiagnostic('d-dataset', label || url);
  updateDiagnostic('d-url', url);
  updateDiagnostic('d-first-visible', '—');
  updateDiagnostic('d-useful-view', '—');

  try {
    const tileset = await Cesium.Cesium3DTileset.fromUrl(url, {
      maximumScreenSpaceError: 16,
      maximumMemoryUsage: 512,
    });

    viewer.scene.primitives.add(tileset);
    currentTileset = tileset;

    tileset.tileLoad.addEventListener(() => {
      if (firstVisibleTime === null) {
        firstVisibleTime = performance.now() - loadStartTime;
        updateDiagnostic('d-first-visible', formatMs(firstVisibleTime));
      }
    });

    setStatus(`読み込み完了。視点へ移動しています…`);
  } catch (err) {
    setStatus(`エラー: ${err.message || err}`);
    console.error('Tileset load error:', err);
  }
}

// Fly to predefined viewpoint
function flyTo(destination, orientation) {
  viewer.camera.flyTo({
    destination,
    orientation,
    duration: 2.0,
    complete: () => {
      if (usefulViewTime === null && currentTileset) {
        usefulViewTime = performance.now() - loadStartTime;
        updateDiagnostic('d-useful-view', formatMs(usefulViewTime));
      }
      setStatus('表示準備完了。マウス・タッチで操作できます。');
    },
  });
}

// Dataset selector
document.getElementById('datasetSelect').addEventListener('change', function () {
  const key = this.value;
  if (!key) return;
  const vp = VIEWPOINTS[key];
  if (!vp) return;

  const url = vp.tilesetUrl;
  document.getElementById('customUrl').value = url;

  loadTileset(url, vp.label).then(() => {
    if (vp.destination && vp.orientation) {
      flyTo(vp.destination, vp.orientation);
    }
  });
});

// Load button
document.getElementById('loadBtn').addEventListener('click', () => {
  const url = document.getElementById('customUrl').value.trim();
  if (!url) {
    setStatus('tileset.json のURLを入力してください。');
    return;
  }
  loadTileset(url, url);
});

// Diagnostics update loop
viewer.clock.onTick.addEventListener(() => {
  if (!currentTileset) return;

  updateDiagnostic('d-tiles-loaded',
    currentTileset.statistics ? String(currentTileset.statistics.numberOfTilesWithContentReady) : '—'
  );
  updateDiagnostic('d-tiles-pending',
    currentTileset.statistics ? String(currentTileset.statistics.numberOfPendingRequests) : '—'
  );
});

// FPS and heap update
let lastFpsTime = performance.now();
let frameCount = 0;
viewer.scene.postRender.addEventListener(() => {
  frameCount++;
  const now = performance.now();
  if (now - lastFpsTime >= 1000) {
    const fps = (frameCount / ((now - lastFpsTime) / 1000)).toFixed(0);
    updateDiagnostic('d-fps', fps);
    frameCount = 0;
    lastFpsTime = now;

    if (performance.memory) {
      updateDiagnostic('d-heap',
        `${formatBytes(performance.memory.usedJSHeapSize)} / ${formatBytes(performance.memory.jsHeapSizeLimit)}`
      );
    }
  }
});

// Collapsible panel — state persisted so a reload doesn't re-expand it.
const uiPanel = document.getElementById('ui');
const uiToggle = document.getElementById('uiToggle');
function setUiCollapsed(collapsed) {
  uiPanel.classList.toggle('collapsed', collapsed);
  uiToggle.textContent = collapsed ? '+' : '–';
  try {
    localStorage.setItem('plateau-mago-implicit:uiCollapsed', collapsed ? '1' : '0');
  } catch (e) {
    // localStorage unavailable (e.g. private browsing) — not persisted, still works this session.
  }
}
document.getElementById('uiHeader').addEventListener('click', () => {
  setUiCollapsed(!uiPanel.classList.contains('collapsed'));
});
let startCollapsed = false;
try {
  startCollapsed = localStorage.getItem('plateau-mago-implicit:uiCollapsed') === '1';
} catch (e) {
  // ignore
}
setUiCollapsed(startCollapsed);

// Technical details section (FPS, heap, raw URL, custom tileset input) —
// collapsed by default; this is developer-facing information, not
// something a general visitor needs to see up front.
document.getElementById('detailsToggle').addEventListener('click', () => {
  document.getElementById('details').classList.toggle('open');
});

// Initial message
setStatus('表示するデータを選んでください。');
