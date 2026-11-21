/* global d3 */
"use strict";
(() => {
  const format = window.formatChicagoValue;
  const dialog = document.createElement("dialog");
  dialog.className = "comparison-dialog";
  dialog.setAttribute("aria-labelledby", "comparison-title");
  dialog.innerHTML = `<div class="comparison-header"><div><p class="eyebrow">City comparisons</p><h2 id="comparison-title"></h2></div><button class="comparison-close" type="button" aria-label="Close comparison">×</button></div><p id="comparison-period"></p><div id="comparison-chart" role="status"></div>`;
  document.body.append(dialog);
  const chart = dialog.querySelector("#comparison-chart");
  let dataPromise;
  let activeMeasure;
  let activeYear;
  let opener;
  let request = 0;
  const valid = value => typeof value === "number" && Number.isFinite(value) && value >= 0;
  const valueText = (row, measure) => `${format(row[`${measure.id}_estimate`], measure)} ±${format(row[`${measure.id}_moe`], measure, true)}`;
  const cityName = row => row.NAME.split(" city,")[0];
  function loadData() {
    if (!dataPromise) dataPromise = fetch("data/web/comparison_statistics.json?v=20261121-all-acs-peers", { cache: "no-cache" })
      .then(response => {
        if (!response.ok) throw new Error("Comparison data could not load. Upload data/web/comparison_statistics.json and try again.");
        return response.json();
      }).then(rows => {
        if (!Array.isArray(rows) || rows.length !== 33 || new Set(rows.map(row => `${row.GEOID}-${row.acs_end_year}`)).size !== 33) {
          throw new Error("Unexpected comparison data. Re-run the comparison pipeline.");
        }
        const measures = window.ChicagoMeasures.filter(measure=>!measure.administrative);
        if(measures.some(measure=>rows.some(row=>!Object.hasOwn(row,`${measure.id}_estimate`) || !Object.hasOwn(row,`${measure.id}_moe`)))) throw new Error("Comparison data is outdated. Upload the rebuilt data/web/comparison_statistics.json file.");
        return rows;
      }).catch(error => { dataPromise = undefined; throw error; });
    return dataPromise;
  }
  async function render() {
    const currentRequest = ++request;
    chart.textContent = "Loading comparisons…";
    const measure = activeMeasure;
    const year = activeYear;
    try {
      const rows = (await loadData()).filter(row => String(row.acs_end_year) === year);
      if (currentRequest !== request || !dialog.open) return;
      if (typeof d3 === "undefined") throw new Error("The chart library could not load. Reload the page to try again.");
      const includeNational = measure.money || measure.percent;
      const places = rows.filter(row => includeNational || row.comparison_id !== "united_states")
        .sort((a, b) => (b[`${measure.id}_estimate`] ?? -1) - (a[`${measure.id}_estimate`] ?? -1));
      if (places.length !== (includeNational ? 11 : 10) || !places.some(row => row.comparison_id === "chicago") || (includeNational && !places.some(row => row.comparison_id === "united_states"))) throw new Error("Comparison cities are missing for this period.");
      chart.replaceChildren();
      const width = Math.max(320, chart.clientWidth);
      const margin = { left: width < 500 ? 95 : 115, right: width < 500 ? 100 : 145, top: 36, bottom: 10 };
      const height = 510;
      const x = d3.scaleLinear().domain([0, d3.max(places, row => valid(row[`${measure.id}_estimate`]) ? row[`${measure.id}_estimate`] : 0) || 1]).nice()
        .range([margin.left, width - margin.right]);
      const y = d3.scaleBand().domain(places.map(row => row.GEOID)).range([margin.top, height - margin.bottom]).padding(0.3);
      const svg = d3.select(chart).append("svg").attr("viewBox", `0 0 ${width} ${height}`)
        .attr("role", "img").attr("aria-labelledby", "comparison-svg-title comparison-svg-desc");
      svg.append("title").attr("id", "comparison-svg-title").text(`${measure.label}, ${year - 4}–${year}`);
      svg.append("desc").attr("id", "comparison-svg-desc")
        .text(`${includeNational ? "City and United States" : "City"} estimates, ordered highest to lowest. ${places.map(row => `${cityName(row)}: ${valueText(row, measure)}`).join(". ")}`);
      svg.append("g").attr("class", "chart-grid").attr("transform", `translate(0,${margin.top - 8})`)
        .call(d3.axisTop(x).ticks(width < 500 ? 3 : 5).tickSize(-(height - margin.top - margin.bottom + 8))
          .tickFormat(measure.money ? d3.format("$~s") : measure.percent ? value => `${value}%` : d3.format("~s")))
        .call(g => g.select(".domain").remove());
      const groups = svg.selectAll(".comparison-row").data(places).join("g").attr("class", "comparison-row");
      groups.append("text").attr("x", margin.left - 10).attr("y", row => y(row.GEOID) + y.bandwidth() / 2)
        .attr("dy", "0.35em").attr("text-anchor", "end")
        .attr("font-weight", row => row.comparison_id === "chicago" ? 700 : 400).text(cityName);
      groups.append("rect").attr("x", x(0)).attr("y", row => y(row.GEOID)).attr("height", y.bandwidth())
        .attr("width", row => valid(row[`${measure.id}_estimate`]) ? x(row[`${measure.id}_estimate`]) - x(0) : 0)
        .attr("rx", 2).attr("fill", row => row.comparison_id === "chicago" ? "#b44d3f" : row.comparison_id === "united_states" ? "#7899ad" : "#2b6550");
      groups.append("text").attr("class", "comparison-value").attr("x", width - margin.right + 9)
        .attr("y", row => y(row.GEOID) + y.bandwidth() / 2).attr("dy", "0.35em")
        .attr("font-weight", row => row.comparison_id === "chicago" ? 700 : 400).text(row => valueText(row, measure));
    } catch (error) {
      if (currentRequest === request) chart.textContent = error.message;
    }
  }
  window.openChicagoComparison = (measure, year, button) => {
    activeMeasure = measure; activeYear = String(year); opener = button;
    dialog.querySelector("#comparison-title").textContent = measure.label;
    dialog.querySelector("#comparison-period").textContent = `${year - 4}–${year} ACS · ${measure.money ? `${year} dollars · ${measure.unit}` : measure.unit}`;
    dialog.showModal();
    render();
  };
  dialog.querySelector(".comparison-close").addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", event => {
    const bounds = dialog.getBoundingClientRect();
    if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
  });
  dialog.addEventListener("close", () => { ++request; opener?.focus(); });
  let frame;
  window.addEventListener("resize", () => {
    if (!dialog.open) return;
    cancelAnimationFrame(frame); frame = requestAnimationFrame(render);
  });
})();
