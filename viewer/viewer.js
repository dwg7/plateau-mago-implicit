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
  // Sapporo City (札幌市) — third municipality, added 2026-08-28 to
  // demonstrate Implicit's practical-consumption advantage at real
  // metropolitan scale (646,474 buildings, ~11.6x Muroran's count).
  // destination/orientation computed the same way as the other entries
  // above: real full-profile Explicit build's own tileset.json bounding
  // region (fit to actual building extent, ~31km x 32km — much larger
  // than Sarabetsu/Muroran), center at lon 141.312568 / lat 43.040184.
  // Altitude kept at 6000m, matching Sarabetsu's exact value and well
  // below the ~19.8km distance at which this dataset's root
  // geometricError (460.05) would stop refining at the default 16px SSE
  // threshold — same reasoning as the comment block above.
  sapporo_explicit_full: {
    label: '札幌市 — Explicit（全建物 646,474棟）',
    tilesetUrl: 'https://tunnel.optgeo.org/plateau-mago-implicit/sapporo/explicit/full/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(141.312568, 43.040184, 6000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-90),
      roll: 0,
    },
  },
  sapporo_implicit_full: {
    label: '札幌市 — Implicit（全建物 646,474棟）',
    tilesetUrl: 'https://tunnel.optgeo.org/plateau-mago-implicit/sapporo/implicit/full/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(141.312568, 43.040184, 6000),
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

// Newly-loaded-tile flash: briefly recolors a tile's content pale yellow
// when it finishes loading, fading back to the normal off-white — lets a
// viewer tell "just loaded" apart from "always been here" apart from
// "not loaded yet" (which stays empty/transparent, Cesium draws nothing
// for it — there's no supported way to show a placeholder for a tile
// that hasn't loaded yet: Cesium3DTilesetBaseTraversal only calls
// selectTile — which is what raises tileVisible — for tiles where
// tile.contentAvailable is already true, confirmed against the actual
// pinned Cesium 1.144 source; the only way around that is private,
// unstable internals, not worth relying on). User request, 2026-08-29.
const BUILDING_BASE_COLOR = Cesium.Color.fromCssColorString('#FAFAFA');
const TILE_FLASH_COLOR = Cesium.Color.fromCssColorString('#FFF59D');
const TILE_FLASH_DURATION_MS = 600;
let flashingTiles = [];

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

// kitaphoto17: GSI seamless aerial photography, re-tiled to 512px,
// served from the user's own Martin tileserver (stars.optgeo.org) — not a
// Cesium ion asset, so no API key/token is needed.
//
// History: this went kitaphoto (a downsampled, z12-capped derivative,
// blurry) -> seamlessphoto512 (real per-level detail to z17, but its own
// low zoom shows GSI's raw multi-survey photo patchwork — visible seams/
// color shifts, inconsistent when zoomed out) -> kitaphoto17, a merged
// PMTiles file combining kitaphoto's smoothed z2-12 with
// seamlessphoto512's real z13-17, built 2026-08-27 because Cesium has no
// built-in way to swap imagery sources by zoom and a two-layer
// `show`-toggle approach was judged too complex. Spatially cropped to
// Hokkaido + the Northern Territories (bbox 137.8125,40.979898,151.875,
// 47.040182 — z7-tile-aligned, so the crop is exact/clean at
// every zoom level, not just an arbitrary lat/lon box) since the
// unscoped merge would have needed ~715GB, far past the server's free
// disk; this viewer never shows anywhere else. Verified byte-for-byte
// identical to both source archives across 14 spot-check tiles (both
// municipalities, z2 through z17) before deploying.
//
// Tiles are 512x512, not Cesium's 256x256 default — tileWidth/tileHeight
// must be set explicitly or the zoom-level-to-URL mapping is wrong (a
// 512px tile at level z covers what a standard 256px tiling scheme calls
// level z+1).
viewer.imageryLayers.addImageryProvider(
  new Cesium.UrlTemplateImageryProvider({
    url: 'https://stars.optgeo.org/kitaphoto17/{z}/{x}/{y}',
    credit: '国土地理院 シームレス空中写真 (GSI seamlessphoto), CC BY 4.0',
    tileWidth: 512,
    tileHeight: 512,
    minimumLevel: 2,
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

// Flatten building shading, and stop it changing with the real clock.
// CesiumJS's default scene.light is a SunLight (Scene.js's own default,
// `this.light = new SunLight()`) whose direction is computed from the
// real sun position for the current time — by default the live system
// clock, so a building's apparent shading drifts as real time passes.
// User-reported 2026-08-29.
//
// CesiumJS has no public "unlit" mode for 3D Tiles/glTF PBR models —
// confirmed still an open, unresolved feature request from 2019
// (github.com/CesiumGS/cesium/issues/7870, "Consider adding an unlit
// mode for 3D Tilesets"; the one prototype posted there patches
// Cesium's own shader source directly, never shipped as a public API).
// Best available approximation using only stable, public APIs: a fixed
// (not clock-driven) DirectionalLight at low intensity — removes the
// time-dependence entirely and minimizes, though doesn't fully zero
// out, the directional shading Cesium's PBR shader still computes from
// surface normals. Not independently confirmed by live rendering this
// session (same `document.visibilityState: "hidden"` limitation as
// every other viewer check) — worth the user's own look.
//
// Intensity raised 0.35 → 1.0 and the building color brightened toward
// pure white (see BUILDING_BASE_COLOR/style below) after the user
// reported the first pass too dark and asked for a bright white,
// Corbusier-like look — 2026-08-29.
viewer.scene.light = new Cesium.DirectionalLight({
  direction: new Cesium.Cartesian3(0.35, -0.85, -0.35),
  intensity: 1.0,
});

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
  flashingTiles = [];
  window.__practicalConsumptionDiagnostics = { url, label, ready: false };

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
    // typical of real Hokkaido buildings. Overriding to a flat, near-white
    // color is a viewer-only style choice — it doesn't touch the
    // GLB data itself, so it doesn't affect Explicit/Implicit comparison
    // or any determinism/validation finding.
    //
    // Found 2026-08-27 after the user reported buildings still didn't
    // look off-white: `tileset.style` alone isn't enough.
    // `Cesium3DTileset.colorBlendMode` defaults to `HIGHLIGHT`, which
    // *multiplies* the style color onto the source material rather than
    // replacing it (confirmed against Cesium's own API docs). Multiplying
    // the already-saturated orange roof ([1.0, 0.5, 0.25]) by this
    // near-white style color barely changes it (~[0.95, 0.47, 0.23] —
    // still visibly orange), which is exactly why it looked unchanged.
    // `REPLACE` makes the style color the actual rendered color.
    //
    // Brightened #F2EFE6 → #FAFAFA (near-pure white) 2026-08-29, at the
    // user's request for a brighter, "Corbusier white" look — paired
    // with raising scene.light's intensity above (BUILDING_BASE_COLOR
    // must stay in sync with this literal, since the tile-flash fade
    // eases back to that constant).
    tileset.style = new Cesium.Cesium3DTileStyle({
      color: "color('#FAFAFA')",
    });
    tileset.colorBlendMode = Cesium.Cesium3DTileColorBlendMode.REPLACE;

    tileset.tileLoad.addEventListener((tile) => {
      if (firstVisibleTime === null) {
        firstVisibleTime = performance.now() - loadStartTime;
        updateDiagnostic('d-first-visible', formatMs(firstVisibleTime));
        window.__practicalConsumptionDiagnostics = window.__practicalConsumptionDiagnostics || {};
        window.__practicalConsumptionDiagnostics.firstVisibleTime = firstVisibleTime;
      }

      // Flash: tint every feature in the just-loaded tile pale yellow;
      // postRender below fades it back to BUILDING_BASE_COLOR. Setting a
      // feature's .color (not creating an entity/primitive) is explicitly
      // fine to do from a tileLoad handler per Cesium's own docs.
      const content = tile.content;
      if (content && content.featuresLength > 0) {
        for (let i = 0; i < content.featuresLength; i++) {
          content.getFeature(i).color = TILE_FLASH_COLOR;
        }
        flashingTiles.push({
          content,
          featuresLength: content.featuresLength,
          startTime: performance.now(),
        });
      }
    });

    setStatus(`読み込み完了。視点へ移動しています…`);
  } catch (err) {
    setStatus(`エラー: ${err.message || err}`);
    console.error('Tileset load error:', err);
  }
}

// Marks "useful view reached" — the camera has settled on its target and
// the scene is interactive (docs/test-plan.md's "First useful view").
// Called from both camera-movement paths: flyTo's animated completion
// (dropdown selection) and setView's instant positioning (URL hash
// restore, restoreFromHash() below) — both are real "useful view reached"
// moments, they just differ in whether there's an animation to wait for.
// Originally only wired into flyTo's completion; the hash-restore path
// used setView without this call, silently leaving
// window.__practicalConsumptionDiagnostics.ready (and thus
// viewer/measure_practical_consumption.js) permanently unset for anyone
// loading a viewpoint via #dataset=<key> instead of the dropdown — found
// 2026-08-28 when a real Sapporo measurement via the hash-load path timed
// out waiting for a completion that was never going to fire.
function markUsefulView() {
  if (usefulViewTime === null && currentTileset) {
    usefulViewTime = performance.now() - loadStartTime;
    updateDiagnostic('d-useful-view', formatMs(usefulViewTime));
    window.__practicalConsumptionDiagnostics = window.__practicalConsumptionDiagnostics || {};
    window.__practicalConsumptionDiagnostics.usefulViewTime = usefulViewTime;
    window.__practicalConsumptionDiagnostics.ready = true;
  }
}

// Fly to predefined viewpoint
function flyTo(destination, orientation) {
  viewer.camera.flyTo({
    destination,
    orientation,
    duration: 2.0,
    complete: () => {
      markUsefulView();
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
      markUsefulView();
      hashRestoring = false;
    });
  } else if (customUrl) {
    document.getElementById('customUrl').value = customUrl;
    currentCustomUrl = customUrl;
    loadTileset(customUrl, customUrl).then(() => {
      if (cam) viewer.camera.setView(cam);
      markUsefulView();
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

// Fade out flashing (just-loaded) tiles toward the normal building color.
// Runs every frame (unlike the FPS/heap block below, which is throttled
// to 1Hz) since a 600ms color fade needs finer granularity than that.
viewer.scene.postRender.addEventListener(() => {
  if (flashingTiles.length === 0) return;
  const now = performance.now();
  flashingTiles = flashingTiles.filter(({ content, featuresLength, startTime }) => {
    const t = Math.min((now - startTime) / TILE_FLASH_DURATION_MS, 1.0);
    const color = Cesium.Color.lerp(
      TILE_FLASH_COLOR,
      BUILDING_BASE_COLOR,
      t,
      new Cesium.Color()
    );
    for (let i = 0; i < featuresLength; i++) {
      content.getFeature(i).color = color;
    }
    return t < 1.0;
  });
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
