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
  return { isCount, breaks: isCount ? countBreaks : rentBreaks };
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
const geographyControl = document.getElementById("geography");
function renderLegend() {
  document.getElementById("legend-title").textContent = measureControl.selectedOptions[0].textContent;
  document.getElementById("map-heading").textContent = measureControl.selectedOptions[0].textContent;
  const list = document.getElementById("legend");
  list.replaceChildren();
  const { isCount } = selectedScale();
  const labels = isCount
    ? ["0 units (estimated)", "1–99 units", "100–249 units", "250–499 units", "500–999 units", "1,000–1,999 units", "2,000 or more units", "No estimate available"]
    : ["Under $750", "$750 to under $1,000", "$1,000 to under $1,250", "$1,250 to under $1,500",
      "$1,500 to under $2,000", "$2,000 to under $2,500", "$2,500 or more", "No estimate available"];
  list.setAttribute("aria-label", isCount ? "Estimated housing-unit count color scale" : "Monthly rent color scale");
  document.getElementById("legend-note").textContent = isCount
    ? "Estimated housing-unit counts, not percentages or density. Breaks are shared across both counts and geography levels. Zero is an estimate, not proof of no rental housing. Gray means no estimate."
    : "Monthly 2024 dollars. Rent breaks are shared across both measures and geography levels. Gross rent includes utilities and fuels. Gray means no estimate.";
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
  map.addControl(new maplibregl.NavigationControl(), "top-right");
  map.addControl(new maplibregl.ScaleControl());
  map.on("error", () => { status.textContent = "A map resource failed to load. Check your connection and reload."; });
  const loaded = new Promise(resolve => map.on("load", resolve));
  const data = await Promise.all(definitions.map(async definition => {
    const response = await fetch(`data/web/${definition.file}.geojson`);
    if (!response.ok) throw new Error(`Could not load data/web/${definition.file}.geojson (HTTP ${response.status}). Upload the complete html folder contents, including data/web.`);
    return response.json();
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
  const reset = () => map.fitBounds(bounds, { padding: 35, duration: 0 });
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
    const features = layerData[geographyControl.value].features;
    const unavailable = features.filter(feature => typeof feature.properties[field] !== "number" || feature.properties[field] < 0).length;
    status.textContent = `${features.length.toLocaleString()} ${geographyControl.selectedOptions[0].textContent.toLowerCase()} · ${unavailable.toLocaleString()} without an estimate`;
  }
  document.getElementById("layers").disabled = false;
  document.getElementById("rent-controls").disabled = false;
  document.getElementById("reset").disabled = false;
  document.getElementById("reset").addEventListener("click", reset);
  measureControl.addEventListener("change", updateMap);
  geographyControl.addEventListener("change", updateMap);
  document.querySelectorAll("[data-layer]").forEach(input => {
    input.addEventListener("change", () => {
      map.setLayoutProperty(`${input.dataset.layer}-line`, "visibility", input.checked ? "visible" : "none");
    });
  });
  map.on("click", event => {
    const features = map.queryRenderedFeatures(event.point, { layers: ["communities-fill", `${geographyControl.value}-fill`] });
    const community = features.find(feature => feature.layer.id === "communities-fill");
    const area = features.find(feature => feature.layer.id === `${geographyControl.value}-fill`);
    const details = document.createElement("div");
    details.className = "area-popup";
    const lines = [];
    if (community) lines.push(`Community: ${community.properties.community} (area ${community.properties.area_numbe})`);
    if (area) {
      lines.push(`${area.properties.NAME} · GEOID ${area.properties.GEOID}`);
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
