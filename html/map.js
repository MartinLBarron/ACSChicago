/* global maplibregl */
"use strict";
const status = document.getElementById("status");
// Each family shares breaks across tract and block-group views.
const rentBreaks = [750, 1000, 1250, 1500, 2000, 2500];
// A separate zero class distinguishes estimated zero from missing data.
const countBreaks = [1, 100, 250, 500, 1000, 2000];
const countMeasures = new Set(["cash_rent_units", "renter_occupied_units"]);
function selectedScale() {
  const isCount = countMeasures.has(measureControl.value);
  const measure = window.ChicagoMeasures.find(measure => measure.id === measureControl.value);
  const isPercent = measure?.percent || false;
  return { isCount, isPercent, breaks: isPercent ? measure.breaks || [10, 20, 30, 40, 50, 75] : isCount ? countBreaks : rentBreaks };
}
const colors = ["#ffffcc", "#c7e9b4", "#7fcdbb", "#41b6c4", "#1d91c0", "#225ea8", "#0c2c84"];
const missingColor = "#bdbdbd";
const dollars = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });
const definitions = [
  { id: "blocks", file: "block_group_rent_2024", color: "#655c79", width: 0.5 },
  { id: "tracts", file: "tract_rent_2024", color: "#403a50", width: 0.8 },
  { id: "communities", file: "chicago_community_areas", color: "#126875", width: 1.8 },
  { id: "city", file: "chicago_city", color: "#b83246", width: 3 }
];
const measureControl = document.getElementById("measure");
// Keep all measures together in a single flat list.
const initialMeasure = measureControl.value;
measureControl.replaceChildren();
for (const measure of window.ChicagoMeasures) {
  const option = document.createElement("option");
  option.value = measure.id;
  option.textContent = measure.label;
  measureControl.append(option);
}
measureControl.value = initialMeasure;
const geographyControl = document.getElementById("geography");
const periodControl = document.getElementById("period");
const periodLabel = year => `${Number(year) - 4}–${year}`;
function renderLegend() {
  document.getElementById("legend-title").textContent = measureControl.selectedOptions[0].textContent;
  document.getElementById("map-heading").textContent = measureControl.selectedOptions[0].textContent;
  const list = document.getElementById("legend");
  list.replaceChildren();
  const { isCount, isPercent, breaks } = selectedScale();
  const labels = isPercent
    ? [`Under ${breaks[0]}%`, ...breaks.slice(0, -1).map((value, index) => `${value}% to under ${breaks[index + 1]}%`), `${breaks[breaks.length - 1]}% or more`, "Unavailable / no eligible units"]
    : isCount
    ? ["0 units (estimated)", "1–99 units", "100–249 units", "250–499 units", "500–999 units", "1,000–1,999 units", "2,000 or more units", "No estimate available"]
    : ["Under $750", "$750 to under $1,000", "$1,000 to under $1,250", "$1,250 to under $1,500",
      "$1,500 to under $2,000", "$2,000 to under $2,500", "$2,500 or more", "No estimate available"];
  list.setAttribute("aria-label", isPercent ? "Percentage color scale" : isCount ? "Estimated housing-unit count color scale" : "Monthly rent color scale");
  document.getElementById("legend-note").textContent = isPercent
    ? `${window.ChicagoMeasures.find(measure => measure.id === measureControl.value).description}. Fixed breaks across all periods. Gray includes missing inputs or no eligible units. MOEs are in percentage points.`
    : isCount
    ? "Estimated housing-unit counts, not percentages or density. Breaks are shared across both counts and geography levels. Zero is an estimate, not proof of no rental housing. Gray means no estimate."
    : `Monthly ${periodControl.value} dollars; not adjusted for inflation. ${window.ChicagoMeasures.find(measure => measure.id === measureControl.value).description}. Fixed dollar breaks across periods. Gray means no estimate.`;
  labels.forEach((label, i) => {
    const row = document.createElement("li");
    const swatch = document.createElement("span");
    swatch.className = "swatch";
    swatch.style.backgroundColor = colors[i] || missingColor;
    row.append(swatch, document.createTextNode(label));
    list.append(row);
  });
}
function rentText(properties, measure, label) {
  const value = properties[`${measure}_estimate`];
  const moe = properties[`${measure}_moe`];
  const valid = typeof value === "number" && Number.isFinite(value) && value >= 0;
  const validMoe = typeof moe === "number" && Number.isFinite(moe) && moe >= 0;
  let text = `${label}: ${valid ? dollars.format(value) : "Not available"}; 90% MOE: ${validMoe ? `±${dollars.format(moe)}` : "Not available"}.`;
  for (const suffix of ["estimate_annotation", "moe_annotation"]) {
    const annotation = properties[`${measure}_${suffix}`];
    if (annotation && annotation !== "null") text += ` ${suffix === "estimate_annotation" ? "Estimate" : "MOE"} annotation: ${annotation}.`;
  }
  return text;
}
function countText(properties, measure, label) {
  const value = properties[`${measure}_estimate`];
  const moe = properties[`${measure}_moe`];
  const format = value => typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value.toLocaleString("en-US") : "Not available";
  let text = `${label}: ${format(value)} units; 90% MOE: ${format(moe) === "Not available" ? "Not available" : `±${format(moe)} units`}.`;
  for (const suffix of ["estimate_annotation", "moe_annotation"]) {
    const annotation = properties[`${measure}_${suffix}`];
    if (annotation && annotation !== "null") text += ` ${suffix === "estimate_annotation" ? "Estimate" : "MOE"} annotation: ${annotation}.`;
  }
  return text;
}
function percentageText(properties, measure) {
  const value = window.formatChicagoValue(properties[`${measure.id}_estimate`], measure);
  const moe = window.formatChicagoValue(properties[`${measure.id}_moe`], measure, true);
  const notes = window.chicagoValueNotes(properties, measure);
  return `${measure.label}: ${value} ${moe === "Not available" ? "(MOE unavailable)" : `±${moe}`}. ${measure.description}.${notes ? ` ${notes}.` : ""}`;
}
function observeMapSize(map) {
  const container = map.getContainer();
  let frame;
  let width = 0;
  let height = 0;
  function scheduleResize() {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      const nextWidth = container.clientWidth;
      const nextHeight = container.clientHeight;
      if (nextWidth > 0 && nextHeight > 0 && (nextWidth !== width || nextHeight !== height)) {
        width = nextWidth;
        height = nextHeight;
        map.resize();
      }
    });
  }
  // MapLibre watches window resizes, but fonts and grid layout can resize the
  // container without changing the window. Keep its WebGL canvas in sync.
  const observer = new ResizeObserver(scheduleResize);
  observer.observe(container);
  scheduleResize();
  map.on("remove", () => {
    observer.disconnect();
    cancelAnimationFrame(frame);
  });
}

async function start() {
  if (typeof maplibregl === "undefined") throw new Error("MapLibre could not load. Check your internet connection.");
  const map = new maplibregl.Map({
    container: "map",
    style: {
      version: 8,
      sources: { osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256,
        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' } },
      layers: [{ id: "basemap", type: "raster", source: "osm", paint: { "raster-saturation": -0.8, "raster-opacity": 0.65 } }]
    }, center: [-87.68, 41.84], zoom: 9.5
  });
  observeMapSize(map);
  map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
  map.addControl(new maplibregl.ScaleControl());
  map.on("error", () => { status.textContent = "A map resource failed to load. Check your connection and reload."; });
  const loaded = new Promise(resolve => map.on("load", resolve));
  async function fetchLayer(file) {
    const response = await fetch(`data/web/${file}.geojson?v=20261118-renter-share`);
    if (!response.ok) throw new Error(`Could not load data/web/${file}.geojson (HTTP ${response.status}). Upload the complete html folder contents, including data/web.`);
    return response.json();
  }
  const periodCache = new Map();
  function loadPeriod(year) {
    if (!periodCache.has(year)) {
      const request = Promise.all([fetchLayer(`block_group_rent_${year}`), fetchLayer(`tract_rent_${year}`)])
        .then(([blocks, tracts]) => ({ blocks, tracts }))
        .catch(error => { periodCache.delete(year); throw error; });
      periodCache.set(year, request);
    }
    return periodCache.get(year);
  }
  const initialPeriod = await loadPeriod(periodControl.value);
  const data = await Promise.all(definitions.map(async definition => {
    if (definition.id === "blocks" || definition.id === "tracts") return initialPeriod[definition.id];
    return fetchLayer(definition.file);
  }));
  await loaded;
  definitions.forEach((definition, i) => {
    map.addSource(definition.id, { type: "geojson", data: data[i] });
    map.addLayer({ id: `${definition.id}-fill`, type: "fill", source: definition.id,
      paint: { "fill-color": missingColor, "fill-opacity": 0 } });
    map.addLayer({ id: `${definition.id}-line`, type: "line", source: definition.id,
      paint: { "line-color": definition.color, "line-width": definition.width } });
  });
  const layerData = Object.fromEntries(definitions.map((definition, i) => [definition.id, data[i]]));
  const bounds = new maplibregl.LngLatBounds();
  function extend(coordinates) {
    if (typeof coordinates[0] === "number") bounds.extend(coordinates);
    else coordinates.forEach(extend);
  }
  layerData.city.features.forEach(feature => extend(feature.geometry.coordinates));
  const reset = () => {
    map.resize();
    map.fitBounds(bounds, { padding: 35, duration: 0 });
  };
  const chicagoControl = {
    onAdd() {
      this.container = document.createElement("div");
      this.container.className = "maplibregl-ctrl maplibregl-ctrl-group chicago-reset-control";
      const button = document.createElement("button");
      button.type = "button";
      button.title = "Recenter and zoom to Chicago";
      button.setAttribute("aria-label", "Recenter and zoom to Chicago");
      button.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 10a9 9 0 1 1 2.6 8.4M3 4v6h6"/></svg>';
      button.addEventListener("click", reset);
      this.container.append(button);
      return this.container;
    },
    onRemove() { this.container.remove(); }
  };
  map.addControl(chicagoControl, "top-right");
  reset();
  let areaPopup;
  function updateMap() {
    if (areaPopup) areaPopup.remove();
    const field = `${measureControl.value}_estimate`;
    const numeric = ["to-number", ["get", field], -1];
    const step = ["step", numeric, colors[0]];
    selectedScale().breaks.forEach((boundary, i) => step.push(boundary, colors[i + 1]));
    // Null must be tested explicitly: it must never become a zero observation.
    const fill = ["case", ["all", ["!=", ["get", field], null], [">=", numeric, 0]], step, missingColor];
    for (const id of ["blocks", "tracts"]) {
      map.setPaintProperty(`${id}-fill`, "fill-color", fill);
      map.setPaintProperty(`${id}-fill`, "fill-opacity", 0.82);
      map.setLayoutProperty(`${id}-fill`, "visibility", id === geographyControl.value ? "visible" : "none");
      const checked = document.querySelector(`[data-layer="${id}"]`).checked;
      map.setLayoutProperty(`${id}-line`, "visibility", checked ? "visible" : "none");
    }
    renderLegend();
    document.dispatchEvent(new CustomEvent("chicago:period-change", { detail: { year: periodControl.value } }));
    document.getElementById("map-period").textContent = `${periodLabel(periodControl.value)} ACS · ${periodControl.value} boundaries`;
    const features = layerData[geographyControl.value].features;
    const unavailable = features.filter(feature => typeof feature.properties[field] !== "number" || feature.properties[field] < 0).length;
    status.textContent = `${periodLabel(periodControl.value)} · ${features.length.toLocaleString()} ${geographyControl.selectedOptions[0].textContent.toLowerCase()} · ${unavailable.toLocaleString()} without an estimate`;
  }
  document.getElementById("layers").disabled = false;
  document.getElementById("rent-controls").disabled = false;
  document.getElementById("reset").disabled = false;
  document.getElementById("reset").addEventListener("click", reset);
  let displayedYear = periodControl.value;
  let switchingPeriod = false;
  periodControl.addEventListener("change", async () => {
    const year = periodControl.value;
    switchingPeriod = true;
    if (areaPopup) areaPopup.remove();
    document.getElementById("rent-controls").disabled = true;
    status.textContent = `Loading ${periodLabel(year)}…`;
    // Hide prior-period Census geometry until both new sources are ready.
    for (const id of ["blocks", "tracts"]) {
      map.setLayoutProperty(`${id}-fill`, "visibility", "none");
      map.setLayoutProperty(`${id}-line`, "visibility", "none");
    }
    let failure;
    try {
      const next = await loadPeriod(year);
      for (const id of ["blocks", "tracts"]) {
        map.getSource(id).setData(next[id]);
        layerData[id] = next[id];
      }
      displayedYear = year;
    } catch (error) {
      periodControl.value = displayedYear;
      failure = error.message;
    } finally {
      switchingPeriod = false;
      document.getElementById("rent-controls").disabled = false;
      updateMap();
      if (failure) status.textContent = `${failure} Still displaying ${periodLabel(displayedYear)}.`;
    }
  });
  measureControl.addEventListener("change", updateMap);
  geographyControl.addEventListener("change", updateMap);
  document.querySelectorAll("[data-layer]").forEach(input => {
    input.addEventListener("change", () => {
      map.setLayoutProperty(`${input.dataset.layer}-line`, "visibility", input.checked ? "visible" : "none");
    });
  });
  map.on("click", event => {
    if (switchingPeriod) return;
    const features = map.queryRenderedFeatures(event.point, { layers: ["communities-fill", `${geographyControl.value}-fill`] });
    const community = features.find(feature => feature.layer.id === "communities-fill");
    const area = features.find(feature => feature.layer.id === `${geographyControl.value}-fill`);
    const details = document.createElement("div");
    details.className = "area-popup";
    const lines = [];
    if (community) lines.push(`Community: ${community.properties.community} (area ${community.properties.area_numbe})`);
    if (area) {
      lines.push(`${area.properties.NAME} · GEOID ${area.properties.GEOID}`);
      lines.push(`${periodLabel(area.properties.acs_end_year)} ACS · ${area.properties.boundary_year} boundaries · rents in ${area.properties.dollar_year} dollars.`);
      const selectedMeasure = window.ChicagoMeasures.find(measure => measure.id === measureControl.value);
      if (selectedMeasure.percent) lines.push(percentageText(area.properties, selectedMeasure));
      lines.push(rentText(area.properties, "median_contract_rent", "Median contract rent"));
      lines.push(rentText(area.properties, "median_gross_rent", "Median gross rent"));
      lines.push(countText(area.properties, "cash_rent_units", "Occupied units paying cash rent"));
      lines.push(countText(area.properties, "renter_occupied_units", "Renter-occupied units"));
      lines.push("These are survey estimates. An estimated zero does not establish that no rental units exist.");
    }
    if (!area) lines.push("No selected Census area at this location.");
    lines.forEach(line => { const paragraph = document.createElement("p"); paragraph.textContent = line; details.append(paragraph); });
    if (areaPopup) areaPopup.remove();
    areaPopup = new maplibregl.Popup({ maxWidth: "320px" })
      .setLngLat(event.lngLat).setDOMContent(details).addTo(map);
  });
  updateMap();
}
start().catch(error => { status.textContent = error.message; });
