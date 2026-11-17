/* global d3 */
"use strict";
(() => {
  const measures = [
    { id: "median_contract_rent", label: "Median contract rent", unit: "per month", money: true, color: "#2b6550", description: "Renter-occupied homes paying cash rent" },
    { id: "median_gross_rent", label: "Median gross rent", unit: "per month", money: true, color: "#2b6550", description: "Includes renter-paid utilities and fuels" },
    { id: "cash_rent_units", label: "Occupied units paying cash rent", unit: "housing units", color: "#986345", description: "Occupied rental homes with cash rent" },
    { id: "renter_occupied_units", label: "Renter-occupied units", unit: "housing units", color: "#986345", description: "Includes homes occupied without cash rent" }
  ];
  const isValue = value => typeof value === "number" && Number.isFinite(value) && value >= 0;
  const period = row => `${row.acs_start_year}–${row.acs_end_year}`;
  const format = (value, measure) => isValue(value)
    ? new Intl.NumberFormat("en-US", { ...(measure.money ? { style: "currency", currency: "USD" } : {}), maximumFractionDigits: 0 }).format(value)
    : "Not available";
  let rows = [];
  let selectedYear = document.getElementById("period").value;
  function annotations(row, measure) {
    return ["estimate_annotation", "moe_annotation"].flatMap(suffix => {
      const annotation = row[`${measure.id}_${suffix}`];
      return annotation && annotation !== "null" ? [`${suffix === "estimate_annotation" ? "Estimate" : "MOE"} annotation: ${annotation}`] : [];
    }).join(". ");
  }
  function summary(row, measure) {
    const moe = row[`${measure.id}_moe`];
    return `${period(row)}: ${format(row[`${measure.id}_estimate`], measure)}; 90% MOE ${isValue(moe) ? `±${format(moe, measure)}` : "not available"}${annotations(row, measure) ? `. ${annotations(row, measure)}` : ""}`;
  }
  function renderCards() {
    const row = rows.find(row => String(row.acs_end_year) === selectedYear);
    const root = document.getElementById("city-cards");
    root.replaceChildren();
    if (!row) return;
    document.getElementById("city-period").textContent = `${period(row)} ACS`;
    for (const measure of measures) {
      const card = document.createElement("article");
      card.className = "stat-card";
      const heading = document.createElement("h3"); heading.textContent = measure.label;
      const value = document.createElement("strong"); value.textContent = format(row[`${measure.id}_estimate`], measure);
      const unit = document.createElement("p"); unit.className = "stat-unit";
      unit.textContent = measure.money ? `${measure.unit} · ${row.dollar_year} dollars` : measure.unit;
      const moe = document.createElement("p"); moe.className = "stat-moe";
      const margin = row[`${measure.id}_moe`];
      moe.textContent = isValue(margin) ? `±${format(margin, measure)} · 90% margin of error` : "90% margin of error not available";
      const description = document.createElement("p"); description.className = "stat-description";
      description.textContent = `${measure.description}${annotations(row, measure) ? `. ${annotations(row, measure)}` : ""}`;
      card.append(heading, value, unit, moe, description); root.append(card);
    }
  }
  function renderCharts() {
    const root = d3.select("#city-charts"); root.selectAll("*").remove();
    measures.forEach((measure, index) => {
      const article = root.append("article").attr("class", "trend-chart");
      article.append("h3").text(measure.label);
      article.append("p").attr("class", "chart-unit").text(measure.money ? "Monthly dollars · not inflation-adjusted" : "Estimated housing units");
      const width = Math.max(290, article.node().getBoundingClientRect().width - 40);
      const height = 270;
      const margin = { top: 24, right: 24, bottom: 45, left: measure.money ? 62 : 72 };
      const valid = rows.filter(row => isValue(row[`${measure.id}_estimate`]));
      const upper = d3.max(valid, row => row[`${measure.id}_estimate`] + (isValue(row[`${measure.id}_moe`]) ? row[`${measure.id}_moe`] : 0)) || 1;
      const x = d3.scalePoint().domain(rows.map(row => row.acs_end_year)).range([margin.left, width - margin.right]).padding(0.25);
      const y = d3.scaleLinear().domain([0, upper * 1.12]).nice().range([height - margin.bottom, margin.top]);
      const svg = article.append("svg").attr("viewBox", `0 0 ${width} ${height}`).attr("role", "img")
        .attr("aria-labelledby", `trend-title-${index} trend-desc-${index}`);
      svg.append("title").attr("id", `trend-title-${index}`).text(`${measure.label} across three ACS periods`);
      svg.append("desc").attr("id", `trend-desc-${index}`).text(`${measure.money ? "Nominal monthly dollars, not inflation-adjusted. " : "Housing-unit counts. "}Vertical bars show 90% margins of error. ${rows.map(row => summary(row, measure)).join(". ")}`);
      svg.append("g").attr("class", "chart-grid").attr("transform", `translate(${margin.left},0)`)
        .call(d3.axisLeft(y).ticks(4).tickSize(-(width - margin.left - margin.right)).tickFormat(""))
        .call(g => g.select(".domain").remove());
      svg.append("g").attr("class", "chart-axis").attr("transform", `translate(0,${height - margin.bottom})`)
        .call(d3.axisBottom(x).tickSize(0).tickPadding(14).tickFormat(year => `${year - 4}–${year}`));
      svg.append("g").attr("class", "chart-axis").attr("transform", `translate(${margin.left},0)`)
        .call(d3.axisLeft(y).ticks(4).tickSize(0).tickPadding(10).tickFormat(measure.money ? d3.format("$,.0f") : d3.format("~s")))
        .call(g => g.select(".domain").remove());
      const estimate = row => row[`${measure.id}_estimate`];
      svg.append("path").datum(rows).attr("class", "trend-line").attr("stroke", measure.color)
        .attr("d", d3.line().defined(row => isValue(estimate(row))).x(row => x(row.acs_end_year)).y(row => y(estimate(row))));
      const intervals = svg.append("g").attr("stroke", measure.color).attr("stroke-width", 1.5)
        .selectAll("g").data(valid.filter(row => isValue(row[`${measure.id}_moe`]))).join("g");
      const low = row => y(Math.max(0, estimate(row) - row[`${measure.id}_moe`]));
      const high = row => y(estimate(row) + row[`${measure.id}_moe`]);
      intervals.append("line").attr("x1", row => x(row.acs_end_year)).attr("x2", row => x(row.acs_end_year)).attr("y1", low).attr("y2", high);
      for (const bound of [low, high]) intervals.append("line").attr("x1", row => x(row.acs_end_year) - 5).attr("x2", row => x(row.acs_end_year) + 5).attr("y1", bound).attr("y2", bound);
      const points = svg.append("g").selectAll("circle").data(valid).join("circle")
        .attr("cx", row => x(row.acs_end_year)).attr("cy", row => y(estimate(row)))
        .attr("r", row => String(row.acs_end_year) === selectedYear ? 6 : 4)
        .attr("fill", row => String(row.acs_end_year) === selectedYear ? "#fbfbf7" : measure.color)
        .attr("stroke", measure.color).attr("stroke-width", 2)
        .attr("tabindex", 0).attr("aria-label", row => summary(row, measure));
      points.append("title").text(row => summary(row, measure));
      const readout = article.append("p").attr("class", "chart-readout").attr("aria-live", "polite")
        .text("Hover or focus a point for its estimate and margin of error.");
      points.on("mouseenter focus", (_event, row) => readout.text(summary(row, measure)));
    });
  }
  function renderTable() {
    const table = document.createElement("table");
    const caption = table.createCaption(); caption.textContent = "Published Chicago city estimates and 90% margins of error. Rent in each period’s end-year dollars.";
    const head = table.createTHead().insertRow();
    for (const label of ["Measure", "Period", "Units", "Estimate", "90% MOE", "Annotations"]) {
      const th = document.createElement("th"); th.scope = "col"; th.textContent = label; head.append(th);
    }
    const body = table.createTBody();
    for (const measure of measures) for (const row of rows) {
      const tr = body.insertRow();
      const values = [measure.label, period(row), measure.money ? `${row.dollar_year} dollars/month` : "Housing units", format(row[`${measure.id}_estimate`], measure), format(row[`${measure.id}_moe`], measure), annotations(row, measure) || "None"];
      values.forEach(value => { const td = tr.insertCell(); td.textContent = value; });
    }
    document.getElementById("city-data-table").replaceChildren(table);
  }
  document.addEventListener("chicago:period-change", event => {
    selectedYear = String(event.detail.year);
    if (rows.length) { renderCards(); if (typeof d3 !== "undefined") renderCharts(); }
  });
  async function startCityStats() {
    const response = await fetch("data/web/chicago_city_statistics.json");
    if (!response.ok) throw new Error(`Citywide statistics could not load (HTTP ${response.status}). Upload data/web/chicago_city_statistics.json.`);
    rows = await response.json(); rows.sort((a, b) => a.acs_end_year - b.acs_end_year);
    if (rows.length !== 3 || rows.some(row => row.GEOID !== "1714000") || new Set(rows.map(row => row.acs_end_year)).size !== 3) throw new Error("Unexpected citywide statistics. Re-run the city web export.");
    renderCards(); renderTable();
    if (typeof d3 === "undefined") throw new Error("Cards and table are available, but D3 could not load. Check your connection to load the charts.");
    renderCharts();
    document.getElementById("city-status").textContent = "Cards follow the selected map period. Charts show all three periods.";
    let resizeFrame;
    window.addEventListener("resize", () => { cancelAnimationFrame(resizeFrame); resizeFrame = requestAnimationFrame(renderCharts); });
  }
  startCityStats().catch(error => { document.getElementById("city-status").textContent = error.message; });
})();
