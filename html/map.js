/* global maplibregl */
"use strict";
const status = document.getElementById("status");
// Each family shares breaks across tract and block-group views.
const rentBreaks = [750, 1000, 1250, 1500, 2000, 2500];
// A separate zero class distinguishes estimated zero from missing data.
const countBreaks = [1, 100, 250, 500, 1000, 2000];
const countMeasures = new Set(["cash_rent_units", "renter_occupied_units", "violent_crime_count"]);
function selectedScale() {
  const measure = window.ChicagoMeasures.find(measure => measure.id === measureControl.value);
  const isCount = countMeasures.has(measureControl.value);
  const breaks = geographyControl.value === "tracts" && measure.tractBreaks ? measure.tractBreaks :
    measure.breaks || (measure.percent ? [10,20,30,40,50,75] : isCount ? countBreaks : rentBreaks);
  return { isCount, isPercent: !!measure.percent, breaks };
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
// Native optgroups provide accessible headings without selectable separator rows.
const initialMeasure = measureControl.value;
measureControl.replaceChildren();
for (const [group, label] of Object.entries(window.ChicagoMeasureGroups)) {
  const section = document.createElement("optgroup");
  section.label = label;
  for (const measure of window.ChicagoMeasures.filter(measure => measure.group === group)) {
    const option = document.createElement("option");
    option.value = measure.id;
    option.textContent = measure.label;
    section.append(option);
  }
  measureControl.append(section);
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
  const measure = window.chicagoMeasureForYear(window.ChicagoMeasures.find(measure => measure.id === measureControl.value), periodControl.value);
  const unit = measure.administrative ? "recorded rows" : "units";
  const money = value => dollars.format(value);
  const labels = isPercent
    ? [`Under ${breaks[0]}%`, ...breaks.slice(0,-1).map((v,i)=>`${v}% to under ${breaks[i+1]}%`), `${breaks.at(-1)}% or more`, "Unavailable / no eligible population"]
    : isCount ? [`0 ${unit}`, ...breaks.slice(0,-1).map((v,i)=>`${v.toLocaleString()}–${(breaks[i+1]-1).toLocaleString()} ${unit}`), `${breaks.at(-1).toLocaleString()} or more ${unit}`, "Unavailable"]
    : [`Under ${money(breaks[0])}`, ...breaks.slice(0,-1).map((v,i)=>`${money(v)} to under ${money(breaks[i+1])}`), `${money(breaks.at(-1))} or more`, "Unavailable"];
  list.setAttribute("aria-label", `${measure.label} color scale`);
  document.getElementById("legend-note").textContent = measure.administrative
    ? `${periodLabel(periodControl.value)} CPD recorded rows with usable coordinates, within whole Census areas. Raw counts, not rates or resident risk. Zero means zero assigned records. No survey MOE applies.`
    : `${measure.description}. ${isPercent ? "MOEs are in percentage points." : measure.money ? `${periodControl.value} dollars ${measure.unit}; not inflation-adjusted.` : "Counts are survey estimates."} Gray means unavailable. Community names appear in the popup and boundary outlines.`;
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
    const response = await fetch(`data/web/${file}.geojson?v=20261120-model-measures`);
    if (!response.ok) throw new Error(`Could not load data/web/${file}.geojson (HTTP ${response.status}). Upload the complete html folder contents, including data/web.`);
    return response.json();
  }
  const periodCache = new Map();
  function loadPeriod(year) {
    if (!periodCache.has(year)) {
      const request = Promise.all([fetchLayer(`block_group_rent_${year}`), fetchLayer(`tract_rent_${year}`)])
        .then(async ([blocks, tracts]) => {
            await Promise.all([["block_group",blocks],["tract",tracts]].map(async ([tag,collection])=>{
              const response=await fetch(`data/web/${tag}_model_measures_${year}.json?v=20261121-all-periods`);
              if(!response.ok) throw new Error(`Could not load model measures (${response.status}). Upload the complete data/web folder.`);
              const rows=await response.json(); const lookup=new Map(rows.map(row=>[row.GEOID,row]));
              if(rows.length!==collection.features.length || lookup.size!==rows.length || rows.some(row=>row.acs_end_year!==Number(year)) || collection.features.some(feature=>!lookup.has(feature.properties.GEOID))) throw new Error(`Mismatched ${tag} measures for ${year}. Upload the complete data/web folder.`);
              collection.features.forEach(feature=>Object.assign(feature.properties,lookup.get(feature.properties.GEOID)));
            }));
          return {blocks,tracts};
        })
        .catch(error => { periodCache.delete(year); throw error; });
      periodCache.set(year, request);
    }
    return periodCache.get(year);
  }
  const initialPeriod = await loadPeriod(periodControl.value);
  const data = await Promise.all(definitions.map(async definition => {
    if (["blocks", "tracts"].includes(definition.id)) return initialPeriod[definition.id];
    return fetchLayer(definition.file);
  }));
  await loaded;
  definitions.forEach((definition, i) => {
    map.addSource(definition.id, { type: "geojson", data: data[i] });
    map.addLayer({ id: `${definition.id}-fill`, type: "fill", source: definition.id,
      paint: { "fill-color": missingColor, "fill-opacity": 0 } });
    map.addLayer({ id: `${definition.id}-line`, type: "line", source: definition.id,
      layout: { visibility: document.querySelector(`[data-layer="${definition.id}"]`).checked ? "visible" : "none" },
      paint: { "line-color": definition.color, "line-width": definition.width } });
  });
  // Keep optional outlines above the choropleth fills.
  definitions.forEach(definition => map.moveLayer(`${definition.id}-line`));
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
    for (const option of measureControl.options) {
      const measure=window.ChicagoMeasures.find(m=>m.id===option.value);
      option.disabled=false;
      option.textContent=window.chicagoMeasureForYear(measure,periodControl.value).label;
    }
    if(measureControl.selectedOptions[0]?.disabled) measureControl.value="median_contract_rent";
    const field = `${measureControl.value}_estimate`;
    const numeric = ["to-number", ["get", field], -1];
    const step = ["step", numeric, colors[0]];
    selectedScale().breaks.forEach((boundary, i) => step.push(boundary, colors[i + 1]));
    // Null must be tested explicitly: it must never become a zero observation.
    const fill = ["case", ["all", ["!=", ["get", field], null], [">=", numeric, 0]], step, missingColor];
    for (const id of ["blocks", "tracts"]) {
      map.setPaintProperty(`${id}-fill`, "fill-color", fill);
      const checked = document.querySelector(`[data-layer="${id}"]`).checked;
      const selected = id === geographyControl.value;
      map.setPaintProperty(`${id}-fill`, "fill-opacity", 0.82);
      map.setLayoutProperty(`${id}-fill`, "visibility", selected ? "visible" : "none");
      map.setLayoutProperty(`${id}-line`, "visibility", checked ? "visible" : "none");
    }
    renderLegend();
    document.dispatchEvent(new CustomEvent("chicago:period-change", { detail: { year: periodControl.value } }));
    const selectedMeasure = window.chicagoMeasureForYear(window.ChicagoMeasures.find(measure => measure.id === measureControl.value), periodControl.value);
    document.getElementById("map-period").textContent = selectedMeasure.administrative
      ? `${periodLabel(periodControl.value)} CPD records · ${periodControl.value} Census boundaries`
      : `${periodLabel(periodControl.value)} ACS · ${periodControl.value} boundaries`;
    status.textContent = "";
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
    // Hide prior-period Census geometry until all new sources are ready.
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
    const features = map.queryRenderedFeatures(event.point, { layers: [...new Set(["communities-fill", `${geographyControl.value}-fill`])] });
    const community = features.find(feature => feature.layer.id === "communities-fill");
    const area = features.find(feature => feature.layer.id === `${geographyControl.value}-fill`);
    const details = document.createElement("div");
    details.className = "area-popup";
    const lines = [];
    if (community) lines.push(`Community: ${community.properties.community} (area ${community.properties.area_numbe})`);
    if (area) {
      lines.push(`${area.properties.NAME} · GEOID ${area.properties.GEOID}`);
      lines.push(`${periodLabel(area.properties.acs_end_year)} ACS · ${area.properties.boundary_year} boundaries · rents in ${area.properties.dollar_year} dollars.`);
      const selectedMeasure = window.chicagoMeasureForYear(window.ChicagoMeasures.find(measure => measure.id === measureControl.value), periodControl.value);
      const selectedValue=window.formatChicagoValue(area.properties[`${selectedMeasure.id}_estimate`],selectedMeasure);
      const selectedMoe=window.formatChicagoValue(area.properties[`${selectedMeasure.id}_moe`],selectedMeasure,true);
      const selectedNotes = window.chicagoValueNotes(area.properties, selectedMeasure);
      lines.push(`${selectedMeasure.label}: ${selectedValue}${selectedMeasure.administrative ? " recorded rows; no sampling MOE" : selectedMoe==="Not available" ? " (MOE unavailable)" : ` ±${selectedMoe}`}. ${selectedMeasure.description}.${selectedNotes ? ` ${selectedNotes}.` : ""}`);
      if(area.properties.model_community)lines.push(`Block-group model community assignment: ${area.properties.model_community}`);
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
