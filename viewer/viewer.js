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
// tilesetUrl is absolute and points at nginx's /tiles/ location (aliased to
// data/output/ — see config/nginx.conf and compose.yml), under a "latest"
// symlink that scripts/build.sh updates on every successful build to point
// at that build's timestamped BUILD_ID directory. This must stay in sync
// with the output path scripts/build.sh actually writes to.
const VIEWPOINTS = {
  sarabetsu_explicit_small: {
    label: 'Sarabetsu Village — Explicit (small)',
    tilesetUrl: '/tiles/sarabetsu/explicit/small/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(143.1, 42.6, 5000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-45),
      roll: 0,
    },
  },
  sarabetsu_implicit_small: {
    label: 'Sarabetsu Village — Implicit (small)',
    tilesetUrl: '/tiles/sarabetsu/implicit/small/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(143.1, 42.6, 5000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-45),
      roll: 0,
    },
  },
  muroran_explicit_small: {
    label: 'Muroran City — Explicit (small)',
    tilesetUrl: '/tiles/muroran/explicit/small/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(141.0, 42.3, 8000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-45),
      roll: 0,
    },
  },
  muroran_implicit_small: {
    label: 'Muroran City — Implicit (small)',
    tilesetUrl: '/tiles/muroran/implicit/small/latest/tileset.json',
    destination: Cesium.Cartesian3.fromDegrees(141.0, 42.3, 8000),
    orientation: {
      heading: Cesium.Math.toRadians(0),
      pitch: Cesium.Math.toRadians(-45),
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
  geocoder: false,
  homeButton: true,
  sceneModePicker: false,
  navigationHelpButton: false,
  animation: false,
  timeline: false,
  fullscreenButton: false,
  imageryProvider: new Cesium.OpenStreetMapImageryProvider({
    url: 'https://tile.openstreetmap.org/',
    credit: '© OpenStreetMap contributors',
  }),
  terrainProvider: new Cesium.EllipsoidTerrainProvider(),
  creditContainer: document.createElement('div'),
});

viewer.scene.fog.enabled = false;
viewer.scene.globe.depthTestAgainstTerrain = true;

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

  setStatus(`Loading: ${url}`);
  updateDiagnostic('d-dataset', `Dataset: ${label || url}`);
  updateDiagnostic('d-url', `URL: ${url}`);
  updateDiagnostic('d-first-visible', 'First visible: —');
  updateDiagnostic('d-useful-view', 'Useful view: —');

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
        updateDiagnostic('d-first-visible', `First visible: ${formatMs(firstVisibleTime)}`);
      }
    });

    setStatus(`Tileset loaded. Flying to viewpoint…`);
  } catch (err) {
    setStatus(`ERROR: ${err.message || err}`);
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
        updateDiagnostic('d-useful-view', `Useful view: ${formatMs(usefulViewTime)}`);
      }
      setStatus('Ready. Use controls to navigate.');
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
    setStatus('Enter a tileset URL.');
    return;
  }
  loadTileset(url, url);
});

// Diagnostics update loop
viewer.clock.onTick.addEventListener(() => {
  if (!currentTileset) return;

  updateDiagnostic('d-tiles-loaded',
    `Tiles loaded: ${currentTileset.statistics ? currentTileset.statistics.numberOfTilesWithContentReady : '—'}`
  );
  updateDiagnostic('d-tiles-pending',
    `Tiles pending: ${currentTileset.statistics ? currentTileset.statistics.numberOfPendingRequests : '—'}`
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
    updateDiagnostic('d-fps', `FPS: ${fps}`);
    frameCount = 0;
    lastFpsTime = now;

    if (performance.memory) {
      updateDiagnostic('d-heap',
        `Heap: ${formatBytes(performance.memory.usedJSHeapSize)} / ${formatBytes(performance.memory.jsHeapSizeLimit)}`
      );
    }
  }
});

// Initial message
setStatus('Select a dataset or enter a tileset URL.');
