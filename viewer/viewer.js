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

// seamlessphoto512: GSI seamless aerial photography, re-tiled to 512px,
// served from the user's own Martin tileserver (stars.optgeo.org) — not a
// Cesium ion asset, so no API key/token is needed.
//
// Originally this used a different tileset on the same server,
// `kitaphoto` (minzoom 2, maxzoom 12). Found 2026-08-27 after the user
// reported the imagery looked noticeably blurry and suspected a
// zoom-level mismatch tied to the 512px tile size: `kitaphoto`'s own
// catalog description (`curl https://stars.optgeo.org/catalog`) says
// explicitly that it's a *downsampled* derivative — "z13 GSI
// seamlessphoto512 ... downsampled to z2-12 via 2x2 box averaging ...
// z13+ intentionally not included here — served from the original
// seamlessphoto512.pmtiles instead". So `kitaphoto`'s maxzoom-12 cap
// wasn't just "no higher zoom exists" — it was capping us at a
// deliberately blurred derivative even at levels 2-12, and had no path
// past z12 at all (Cesium over-zooms its most-detailed available tile
// rather than failing, which is what produced the blur).
//
// `seamlessphoto512` (same server, same 512px JPEG format, so the
// tileWidth/tileHeight reasoning below is unchanged) is the real
// source: "GSI seamlessphoto re-tiled to 512px tiles, zoom 1-17 (from
// 256px z2-z18)" — genuine per-level detail, not a synthetic downsample,
// confirmed reachable with real (non-blank) content at Hokkaido
// coordinates: sampled z14/16/17 tiles at both Sarabetsu and Muroran's
// coordinates directly (`curl` + Pillow pixel stats), all real aerial
// photos (mean brightness 105-139, stdev 27-36 — not blank/black).
// `kitaphoto`'s own low-zoom (2-12) also had extra gap-filling (a
// satellite-mosaic fallback for missing photo coverage) that
// `seamlessphoto512` doesn't add — a low-zoom-only resilience feature
// not expected to matter for this viewer, which only ever shows two
// specific, well-covered Hokkaido municipalities, not arbitrary global
// low-zoom views.
//
// Tiles are 512x512, not Cesium's 256x256 default — tileWidth/tileHeight
// must be set explicitly or the zoom-level-to-URL mapping is wrong (a
// 512px tile at level z covers what a standard 256px tiling scheme calls
// level z+1) — confirmed correct for this specific tileset by checking
// its own description ("from 256px z2-z18"), not just assumed.
viewer.imageryLayers.addImageryProvider(
  new Cesium.UrlTemplateImageryProvider({
    url: 'https://stars.optgeo.org/seamlessphoto512/{z}/{x}/{y}',
    credit: '国土地理院 シームレス空中写真 (GSI seamlessphoto), CC BY 4.0',
    tileWidth: 512,
    tileHeight: 512,
    minimumLevel: 1,
    maximumLevel: 17,
  })
);

// Real elevation via Re:Earth Terrain (https://terrain.reearth.land),
// a public, no-API-key quantized-mesh-1.0 service that blends Mapterhorn's
// global open DEM with the EGM2008 geoid so heights land on the WGS84
// ellipsoid CesiumJS actually draws (not just mean-sea-level heights,
// which would sit tens of meters off). Confirmed reachable and valid
// 2026-08-26 via `curl https://terrain.reearth.land/cesium-mesh/ellipsoid/layer.json`
// (quantized-mesh-1.0, global bounds, minzoom 0/maxzoom 14). Not a Cesium
// ion asset — `Cesium.Ion.defaultAccessToken` above stays empty. `fromUrl`
// is async, so this replaces the placeholder EllipsoidTerrainProvider set
// in the constructor above once it resolves, rather than blocking Viewer
// construction on a network round trip.
//
// Caveat not yet investigated: Mago's building placement uses ellipsoid
// height by default (no terrain-clamping option was passed at build time),
// so in sloped areas (Muroran especially — a port city, not flat, per
// docs/test-plan.md's Phase 5 "slope and coastal conditions" note) a
// building's base may not sit flush with the now-real terrain surface
// underneath it. Not confirmed either way by live rendering this session.
Cesium.CesiumTerrainProvider.fromUrl('https://terrain.reearth.land/cesium-mesh/ellipsoid', {
  requestVertexNormals: true,
  requestWaterMask: true,
}).then((terrain) => {
  viewer.terrainProvider = terrain;
}).catch((err) => {
  console.error('Failed to load Re:Earth Terrain, staying on flat ellipsoid:', err);
});

viewer.scene.fog.enabled = false;
viewer.scene.globe.depthTestAgainstTerrain = true;

// Mitigate the roof/wall shimmer the user reported (2026-08-27) on real
// PLATEAU buildings. Investigated two candidate causes before touching
// anything: (1) duplicate/overlapping LOD1 geometry from Mago or the
// source CityGML — decoded a real built GLB (sarabetsu/explicit/full's
// RC021.glb, 21,794 triangles) and searched for triangles sharing the
// same 3 vertices to within 1mm: found only 2 (0.01%), ruling out
// duplicate geometry as the primary cause. (2) CesiumJS's logarithmic
// depth buffer — used by default so one scene can span planet-to-building
// scale, but Cesium's own engineering blog
// (https://cesium.com/blog/2018/05/24/logarithmic-depth/) states plainly
// that precision loss from this is "particularly problematic with flat
// surfaces like roofs," exactly the reported symptom. `Scene`'s own docs
// for the near-plane analogue property state "if a primitive or model
// close to the surface shows z-fighting, decreasing this will eliminate
// the artifact, but decrease performance." This viewer only ever shows
// two small municipalities, never a true planet-scale view, so trading a
// little of that unused range for real precision here is a good deal.
// Lowered from the 1e9 default to 1e5. Not independently confirmed by
// live rendering this session (same `document.visibilityState: "hidden"`
// limitation as every other viewer check) — worth the user's own look.
viewer.scene.logarithmicDepthFarToNearRatio = 1e5;

// Start already looking at Hokkaido, not the default whole-Earth view —
// this viewer is only ever about Sarabetsu/Muroran, so a global starting
// view is irrelevant to what it's for, and it also means the initial
// low-zoom tile requests land inside seamlessphoto512's actual coverage
// instead of at levels/areas it doesn't serve (its bounds are Japan-only,
// [122.9-154.0°E, 20.4-45.5°N]; the whole-Earth default view logs
// harmless but noisy "failed to obtain image tile" console errors for
// out-of-coverage areas).
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

    // Mago 3DTiler assigns its own placeholder material per building —
    // decoded directly from a real GLB (2026-08-27): a warm orange roof
    // (baseColorFactor [1.0, 0.5, 0.25]) and a light-gray wall
    // ([0.9, 0.9, 0.9]), fully rough/non-metal. Against a real aerial
    // photo basemap this reads as noticeably dark/"sunken" (the user's
    // word: 沈みすぎている) rather than the pale, often-white cladding
    // typical of real Hokkaido buildings. Overriding to a flat, warm
    // off-white is a viewer-only style choice — it doesn't touch the
    // GLB data itself, so it doesn't affect Explicit/Implicit comparison
    // or any determinism/validation finding.
    tileset.style = new Cesium.Cesium3DTileStyle({
      color: "color('#F2EFE6')",
    });

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
      setStatus('');
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
  currentDatasetKey = key;
  currentCustomUrl = null;

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
  currentDatasetKey = null;
  currentCustomUrl = url;
  loadTileset(url, url);
});

// URL hash view-state, like MapLibre GL JS's `hash` option — lets a
// specific dataset + camera view be bookmarked or shared via the URL.
// Format: #dataset=<key>&lon=<deg>&lat=<deg>&h=<meters>&heading=<deg>&pitch=<deg>&roll=<deg>
// (or #url=<encoded tileset.json URL>&... in place of `dataset` for a
// custom, non-predefined tileset loaded via the URL field). Cesium has no
// built-in equivalent, so this is hand-rolled, deliberately kept to the
// same small parameter set MapLibre's own hash uses (position +
// orientation) rather than trying to serialize full viewer state.
let currentDatasetKey = null;
let currentCustomUrl = null;
let hashRestoring = false;

function updateHash() {
  if (hashRestoring || !currentTileset) return;
  const params = new URLSearchParams();
  if (currentDatasetKey) {
    params.set('dataset', currentDatasetKey);
  } else if (currentCustomUrl) {
    params.set('url', currentCustomUrl);
  } else {
    return;
  }
  const carto = viewer.camera.positionCartographic;
  params.set('lon', Cesium.Math.toDegrees(carto.longitude).toFixed(6));
  params.set('lat', Cesium.Math.toDegrees(carto.latitude).toFixed(6));
  params.set('h', Math.round(carto.height));
  params.set('heading', Cesium.Math.toDegrees(viewer.camera.heading).toFixed(1));
  params.set('pitch', Cesium.Math.toDegrees(viewer.camera.pitch).toFixed(1));
  params.set('roll', Cesium.Math.toDegrees(viewer.camera.roll).toFixed(1));
  history.replaceState(null, '', '#' + params.toString());
}
viewer.camera.moveEnd.addEventListener(updateHash);

function cameraFromHashParams(params) {
  if (!params.has('lon') || !params.has('lat') || !params.has('h')) return null;
  return {
    destination: Cesium.Cartesian3.fromDegrees(
      parseFloat(params.get('lon')),
      parseFloat(params.get('lat')),
      parseFloat(params.get('h'))
    ),
    orientation: {
      heading: Cesium.Math.toRadians(parseFloat(params.get('heading') || '0')),
      pitch: Cesium.Math.toRadians(parseFloat(params.get('pitch') || '-90')),
      roll: Cesium.Math.toRadians(parseFloat(params.get('roll') || '0')),
    },
  };
}

// Restore view from the URL hash at startup, if present. Runs after the
// listeners above so loadTileset()'s own state changes don't race it.
(function restoreFromHash() {
  const raw = location.hash.replace(/^#/, '');
  if (!raw) return;
  const params = new URLSearchParams(raw);
  const datasetKey = params.get('dataset');
  const customUrl = params.get('url');
  const cam = cameraFromHashParams(params);

  hashRestoring = true;
  if (datasetKey && VIEWPOINTS[datasetKey]) {
    const vp = VIEWPOINTS[datasetKey];
    document.getElementById('datasetSelect').value = datasetKey;
    document.getElementById('customUrl').value = vp.tilesetUrl;
    currentDatasetKey = datasetKey;
    loadTileset(vp.tilesetUrl, vp.label).then(() => {
      viewer.camera.setView(cam || { destination: vp.destination, orientation: vp.orientation });
      hashRestoring = false;
    });
  } else if (customUrl) {
    document.getElementById('customUrl').value = customUrl;
    currentCustomUrl = customUrl;
    loadTileset(customUrl, customUrl).then(() => {
      if (cam) viewer.camera.setView(cam);
      hashRestoring = false;
    });
  } else {
    hashRestoring = false;
  }
})();

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
