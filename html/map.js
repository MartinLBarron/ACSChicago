/* global maplibregl */
"use strict";
const status = document.getElementById("status");
const details = document.getElementById("details");
const definitions = [
  { id: "blocks", file: "chicago_block_groups_2025", color: "#72539b", width: 0.7, opacity: 0.04 },
  { id: "tracts", file: "chicago_tracts_2025", color: "#b16b08", width: 1.5, opacity: 0.02 },
  { id: "communities", file: "chicago_community_areas", color: "#126875", width: 1.8, opacity: 0.05 },
  { id: "city", file: "chicago_city", color: "#b83246", width: 3, opacity: 0 }
];
async function start() {
  if (typeof maplibregl === "undefined") throw new Error("MapLibre could not load. Check your internet connection.");
  const map = new maplibregl.Map({
    container: "map",
    style: {
      version: 8,
      sources: { osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256,
        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' } },
      layers: [{ id: "basemap", type: "raster", source: "osm", paint: { "raster-saturation": -0.8, "raster-opacity": 0.65 } }]
    },
    center: [-87.68, 41.84], zoom: 9.5
  });
  map.addControl(new maplibregl.NavigationControl(), "top-right");
  map.addControl(new maplibregl.ScaleControl());
  map.on("error", () => { status.textContent = "A map resource failed to load. Check your connection and reload."; });
  const loaded = new Promise(resolve => map.on("load", resolve));
  const data = await Promise.all(definitions.map(async definition => {
    const response = await fetch(`../data/web/${definition.file}.geojson`);
    if (!response.ok) throw new Error(`Missing ${definition.file}: run Rscript R/export_web_data.R, then serve the project root.`);
    return response.json();
  }));
  await loaded;
  definitions.forEach((definition, i) => {
    map.addSource(definition.id, { type: "geojson", data: data[i] });
    map.addLayer({ id: `${definition.id}-fill`, type: "fill", source: definition.id,
      paint: { "fill-color": definition.color, "fill-opacity": definition.opacity } });
    map.addLayer({ id: `${definition.id}-line`, type: "line", source: definition.id,
      paint: { "line-color": definition.color, "line-width": definition.width } });
  });
  const bounds = new maplibregl.LngLatBounds();
  function extend(coordinates) {
    if (typeof coordinates[0] === "number") bounds.extend(coordinates);
    else coordinates.forEach(extend);
  }
  const layerData = Object.fromEntries(definitions.map((definition, i) => [definition.id, data[i]]));
  layerData.city.features.forEach(feature => extend(feature.geometry.coordinates));
  const reset = () => map.fitBounds(bounds, { padding: 35, duration: 0 });
  reset();
  document.getElementById("layers").disabled = false;
  document.getElementById("reset").disabled = false;
  document.getElementById("reset").addEventListener("click", reset);
  document.querySelectorAll("[data-layer]").forEach(input => {
    input.addEventListener("change", () => {
      for (const type of ["fill", "line"]) map.setLayoutProperty(`${input.dataset.layer}-${type}`, "visibility", input.checked ? "visible" : "none");
    });
  });
  map.on("click", event => {
    const features = map.queryRenderedFeatures(event.point, { layers: ["communities-fill", "blocks-fill", "tracts-fill"] });
    const community = features.find(feature => feature.layer.id === "communities-fill");
    const block = features.find(feature => feature.layer.id === "blocks-fill");
    const tract = features.find(feature => feature.layer.id === "tracts-fill");
    const parts = [];
    if (community) parts.push(`Community: ${community.properties.community} (area ${community.properties.area_numbe})`);
    if (block) parts.push(`Block group GEOID: ${block.properties.GEOID}`);
    if (tract) parts.push(`Tract GEOID: ${tract.properties.GEOID}`);
    details.textContent = parts.join(" · ") || "No visible community area, tract, or block group at this location.";
  });
  status.textContent = `${layerData.communities.features.length} community areas · ${layerData.blocks.features.length.toLocaleString()} block groups · ${layerData.tracts.features.length.toLocaleString()} tracts`;
}
start().catch(error => { status.textContent = error.message; });
