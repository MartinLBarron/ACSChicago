/* global d3 */
"use strict";
(() => {
  const dialog = document.createElement("dialog");
  dialog.className = "comparison-dialog";
  dialog.setAttribute("aria-labelledby", "distribution-title");
  dialog.innerHTML = `<div class="comparison-header"><div><p class="eyebrow">Chicago distribution</p><h2 id="distribution-title"></h2></div><button class="comparison-close" type="button" aria-label="Close distribution">×</button></div><p id="distribution-period"></p><div class="distribution-controls"><label>Geography <select id="distribution-geography"><option value="tract">Census tracts</option><option value="block_group">Block groups</option></select></label><label>Bins <input id="distribution-bins" type="number" min="5" max="100" step="1" value="30"></label></div><div id="distribution-chart" role="status"></div><p id="distribution-note"></p>`;
  document.body.append(dialog);
  const chart = dialog.querySelector("#distribution-chart");
  const geography = dialog.querySelector("#distribution-geography");
  const binControl = dialog.querySelector("#distribution-bins");
  const cache = new Map();
  let measure, year, opener, request = 0;
  const valid = value => typeof value === "number" && Number.isFinite(value) && value >= 0;
  async function loadRows(tag, selectedYear) {
    const key = `${tag}-${selectedYear}`;
    if (!cache.has(key)) {
      const pending = Promise.all(["rent", "model_measures"].map(async kind => {
        const path = `data/web/${tag}_${kind}_${selectedYear}.${kind === "rent" ? "geojson" : "json"}`;
        const response = await fetch(`${path}?v=20261121-distributions`, { cache: "no-cache" });
        if (!response.ok) throw new Error(`Could not load ${path}. Upload the complete data/web folder.`);
        return response.json();
      })).then(([base, supplement]) => {
        const lookup = new Map(supplement.map(row => [row.GEOID, row]));
        if (lookup.size !== base.features.length || lookup.size !== supplement.length || supplement.some(row=>String(row.acs_end_year)!==String(selectedYear)) || base.features.some(f => !lookup.has(f.properties.GEOID))) throw new Error("Distribution data and boundaries do not match.");
        return base.features.map(f => ({ ...f.properties, ...lookup.get(f.properties.GEOID) }));
      }).catch(error => { cache.delete(key); throw error; });
      cache.set(key, pending);
    }
    return cache.get(key);
  }
  // Explicit equal-width thresholds guarantee the requested number of bins.
  function histogram(values, count) {
    let [lo, hi] = d3.extent(values);
    if (lo === hi) { lo = Math.max(0, lo - (Math.abs(lo) * .05 || .5)); hi += Math.abs(hi) * .05 || .5; }
    const edges = d3.range(1, count).map(i => lo + (hi - lo) * i / count);
    return { domain: [lo, hi], bins: d3.bin().domain([lo, hi]).thresholds(edges)(values) };
  }
  window.ChicagoDistributionHistogram = histogram;
  async function render() {
    const token = ++request;
    const selectedMeasure = measure, selectedYear = year, tag = geography.value;
    const count = Math.max(5, Math.min(100, Math.round(Number(binControl.value)) || 30));
    binControl.value = count;
    chart.textContent = "Loading distribution…";
    dialog.querySelector("#distribution-note").textContent = "";
    try {
      const rows = await loadRows(tag, selectedYear);
      if (token !== request || !dialog.open) return;
      const field = `${selectedMeasure.id}_estimate`;
      if (rows.some(row => !Object.hasOwn(row, field))) throw new Error("This measure is missing from the exported data. Upload the rebuilt data/web files.");
      const values = rows.map(row => row[field]).filter(valid);
      if (!values.length) throw new Error("No usable estimates for this measure and geography.");
      const { domain, bins } = histogram(values, count);
      const plural = tag === "tract" ? "tracts" : "block groups";
      const width = Math.max(300, chart.clientWidth), height = 380;
      const margin = { left: 55, right: 18, top: 25, bottom: 65 };
      const x = d3.scaleLinear().domain(domain).range([margin.left, width - margin.right]);
      const y = d3.scaleLinear().domain([0, d3.max(bins, bin => bin.length) || 1]).nice().range([height-margin.bottom, margin.top]);
      chart.replaceChildren();
      const svg = d3.select(chart).append("svg").attr("viewBox", `0 0 ${width} ${height}`).attr("role", "img").attr("aria-labelledby", "distribution-svg-title distribution-svg-desc");
      svg.append("title").attr("id", "distribution-svg-title").text(`${selectedMeasure.label}: Chicago ${plural}`);
      svg.append("desc").attr("id", "distribution-svg-desc").text(`${count} equal-width bins; ${values.length} areas with usable estimates. Each area counts once.`);
      svg.append("g").attr("class", "chart-grid").attr("transform", `translate(${margin.left},0)`).call(d3.axisLeft(y).ticks(Math.min(5,y.domain()[1])).tickFormat("").tickSize(-(width-margin.left-margin.right)));
      svg.append("g").attr("class", "chart-axis").attr("transform", `translate(${margin.left},0)`).call(d3.axisLeft(y).ticks(Math.min(5,y.domain()[1])).tickFormat(d3.format(",.0f")).tickSize(0)).call(g=>g.select(".domain").remove());
      svg.append("g").attr("class", "chart-axis").attr("transform", `translate(0,${height-margin.bottom})`).call(d3.axisBottom(x).ticks(width<450?3:6).tickFormat(selectedMeasure.money?d3.format("$~s"):selectedMeasure.percent?v=>`${v}%`:d3.format("~s")));
      const edge = value => `${selectedMeasure.money?"$":""}${d3.format(",.2f")(value)}${selectedMeasure.percent?"%":""}`;
      const binLabel = bin => `${edge(bin.x0)} to ${edge(bin.x1)}${bin.x1===domain[1]?" (upper bound included)":" (upper bound excluded)"}: ${bin.length.toLocaleString()} ${plural}`;
      svg.append("g").selectAll("rect").data(bins).join("rect").attr("x",bin=>x(bin.x0)+.5).attr("y",bin=>y(bin.length)).attr("width",bin=>Math.max(0,x(bin.x1)-x(bin.x0)-1)).attr("height",bin=>y(0)-y(bin.length)).attr("fill","#2b6550").attr("tabindex",0).attr("aria-label",binLabel).append("title").text(binLabel);
      svg.append("text").attr("x",margin.left).attr("y",14).text(`Number of ${plural}`);
      svg.append("text").attr("x",(margin.left+width-margin.right)/2).attr("y",height-12).attr("text-anchor","middle").text(selectedMeasure.money?`${selectedYear} dollars · ${selectedMeasure.unit}`:selectedMeasure.unit);
      dialog.querySelector("#distribution-note").textContent = `${values.length.toLocaleString()} ${plural} · ${(rows.length-values.length).toLocaleString()} unavailable. Each whole mapped area counts once; this is a distribution of area estimates, not individual homes. Areas may extend beyond city limits.`;
    } catch(error) { if(token===request) chart.textContent = error.message; }
  }
  window.openChicagoDistribution = (selectedMeasure, selectedYear, button) => {
    measure = selectedMeasure; year = String(selectedYear); opener = button;
    geography.value = "tract"; binControl.value = 30;
    dialog.querySelector("#distribution-title").textContent = measure.label;
    dialog.querySelector("#distribution-period").textContent = `${year-4}–${year} ${measure.rate?"CPD and ACS":measure.administrative?"CPD records":"ACS"}`;
    dialog.showModal(); render();
  };
  geography.addEventListener("change", render); binControl.addEventListener("change", render);
  dialog.querySelector(".comparison-close").addEventListener("click",()=>dialog.close());
  dialog.addEventListener("close",()=>{++request;opener?.focus();});
  dialog.addEventListener("click",event=>{
    const box=dialog.getBoundingClientRect();
    if(event.target===dialog&&(event.clientX<box.left||event.clientX>box.right||event.clientY<box.top||event.clientY>box.bottom)) dialog.close();
  });
  let frame;
  window.addEventListener("resize",()=>{if(dialog.open){cancelAnimationFrame(frame);frame=requestAnimationFrame(render);}});
})();
