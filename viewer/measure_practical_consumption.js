/**
 * measure_practical_consumption.js — Paste-into-DevTools measurement
 * script for the "practical consumption" claim (docs/hypothesis.md /
 * docs/test-plan.md's "First useful view" criteria).
 *
 * Why this exists: the 2026-08-28 Sarabetsu/Muroran practical-consumption
 * numbers (docs/findings.md, Practical consumption row) came from an ad
 * hoc snippet pasted directly into the user's own Brave DevTools console
 * — never saved to the repo. This project's own browser-automation tool
 * cannot force real tile rendering (document.visibilityState: "hidden"
 * blocks it, confirmed repeatedly), so this measurement has to be run by
 * a human in a real, foregrounded browser tab. This script closes the
 * "never saved" gap so the same methodology is reusable for future
 * datasets without re-deriving it from scratch each time.
 *
 * Usage:
 *   1. Open the viewer URL for the dataset/mode you want to measure, with
 *      the dataset preselected via the URL hash, e.g.:
 *      https://dwg7.github.io/plateau-mago-implicit/#dataset=sapporo_explicit_full
 *   2. Wait for the page to finish its initial load (do NOT paste before
 *      navigating — resource timing needs to capture the full page load).
 *   3. Open DevTools console, paste this whole file, press Enter.
 *   4. Wait for it to print a result table (times out after 30s if the
 *      camera never reaches the predefined viewpoint).
 *   5. Report the printed JSON/table back.
 *
 * What it measures, matching docs/test-plan.md's "First useful view"
 * definition and the 2026-08-28 methodology exactly:
 *   - firstVisibleTime: ms from tileset load start to the first tile
 *     actually loading (viewer.js's own `d-first-visible` diagnostic).
 *   - usefulViewTime: ms from tileset load start to the camera's flyTo
 *     completing on the predefined viewpoint (viewer.js's own
 *     `d-useful-view` diagnostic) — "the camera has reached the
 *     predefined target, expected buildings are visible, the scene is
 *     interactive" per docs/test-plan.md.
 *   - requestCount: total network requests recorded via the Resource
 *     Timing API since navigation start, up to the moment usefulView is
 *     reached. Intentionally NOT filtered to just tileset content — a
 *     fresh page load's Cesium/library overhead is the same constant
 *     across Explicit/Implicit/any dataset, so it cancels out in a
 *     relative comparison, matching how the original measurement worked.
 *   - totalTransferredBytes: attempted via `transferSize`, but PLATEAU's
 *     current hosts (tunnel.optgeo.org / stars.optgeo.org) don't send
 *     `Timing-Allow-Origin`, so this reads 0 for cross-origin resources —
 *     a known, already-documented instrumentation gap
 *     (docs/findings.md's practical-consumption section), not
 *     re-investigated here. Reported anyway so a future host fix would
 *     make this script "just work" without changes.
 */
(function () {
  const TIMEOUT_MS = 30000;
  const POLL_MS = 200;
  const startedAt = performance.now();

  function summarize() {
    const diag = window.__practicalConsumptionDiagnostics || {};
    const resources = performance.getEntriesByType('resource');
    const totalTransferredBytes = resources.reduce(
      (sum, r) => sum + (r.transferSize || 0),
      0
    );
    const result = {
      url: diag.url || location.href,
      label: diag.label || null,
      firstVisibleTimeMs: diag.firstVisibleTime ?? null,
      usefulViewTimeMs: diag.usefulViewTime ?? null,
      requestCount: resources.length,
      totalTransferredBytes,
      note:
        totalTransferredBytes === 0
          ? 'totalTransferredBytes is 0 — expected, see script header (Timing-Allow-Origin gap)'
          : undefined,
    };
    console.log('=== practical-consumption measurement ===');
    console.table(result);
    console.log(JSON.stringify(result, null, 2));
    return result;
  }

  function poll() {
    const diag = window.__practicalConsumptionDiagnostics;
    if (diag && diag.ready) {
      summarize();
      return;
    }
    if (performance.now() - startedAt > TIMEOUT_MS) {
      console.warn(
        'measure_practical_consumption: timed out after ' +
          TIMEOUT_MS +
          'ms waiting for useful view. Reporting partial state.'
      );
      summarize();
      return;
    }
    setTimeout(poll, POLL_MS);
  }

  if (!('__practicalConsumptionDiagnostics' in window)) {
    console.warn(
      'measure_practical_consumption: window.__practicalConsumptionDiagnostics ' +
        'not found yet — make sure a dataset is loading (e.g. navigate with ' +
        '#dataset=<key> in the URL) before pasting this script.'
    );
  }
  poll();
})();
