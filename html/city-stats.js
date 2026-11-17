/* global d3 */
"use strict";
(() => {
  const allMeasures = window.ChicagoMeasures;
  const topicControl = document.getElementById("city-topic");
  const measuresForTopic = () => allMeasures.filter(measure => measure.group === topicControl.value);
  const isValue = value => typeof value === "number" && Number.isFinite(value) && value >= 0;
  const period = row => `${row.acs_start_year}–${row.acs_end_year}`;
  const format = window.formatChicagoValue;
  let rows = [];
  const statisticsPeriod = document.getElementById("city-period");
  let selectedYear = statisticsPeriod.value;
  const annotations = window.chicagoValueNotes;
  function summary(row, measure) {
    const moe = row[`${measure.id}_moe`];
    return `${period(row)}: ${format(row[`${measure.id}_estimate`], measure)} ${isValue(moe) ? `±${format(moe, measure, true)}` : "(MOE unavailable)"}${annotations(row, measure) ? `. ${annotations(row, measure)}` : ""}`;
  }
  function renderCards() {
    const row = rows.find(row => String(row.acs_end_year) === selectedYear);
    const root = document.getElementById("city-cards");
    root.replaceChildren();
    if (!row) return;
    for (const measure of measuresForTopic()) {
      const card = document.createElement("article");
      card.className = "stat-card";
      const heading = document.createElement("h3"); heading.textContent = measure.label;
      const valueLine = document.createElement("div"); valueLine.className = "stat-value-line";
      const value = document.createElement("strong"); value.textContent = format(row[`${measure.id}_estimate`], measure);
      const unit = document.createElement("p"); unit.className = "stat-unit";
      unit.textContent = measure.money ? `${measure.unit} · ${row.dollar_year} dollars` : measure.unit;
      const moe = document.createElement("span"); moe.className = "stat-moe";
      const margin = row[`${measure.id}_moe`];
      if (isValue(margin)) {
        const symbol = document.createElement("span");
        symbol.className = "moe-symbol";
        symbol.textContent = "±";
        moe.append(symbol, document.createTextNode(format(margin, measure, true)));
      } else {
        moe.textContent = "MOE unavailable";
      }
      moe.setAttribute("aria-label", isValue(margin)
        ? `90% margin of error: plus or minus ${format(margin, measure, true)}`
        : "90% margin of error unavailable");
      valueLine.append(value, moe);
      const description = document.createElement("p"); description.className = "stat-description";
      description.textContent = `${measure.description}${annotations(row, measure) ? `. ${annotations(row, measure)}` : ""}`;
      card.append(heading, valueLine, unit, description); root.append(card);
    }
  }
  function renderCharts() {
    const root = d3.select("#city-charts"); root.selectAll("*").remove();
    measuresForTopic().forEach((measure, index) => {
      const article = root.append("article").attr("class", "trend-chart");
      article.append("h3").text(measure.label);
      article.append("p").attr("class", "chart-unit").text(measure.money ? "Monthly dollars · not inflation-adjusted" : measure.percent ? "Percent of eligible units · MOEs in percentage points" : "Estimated housing units");
      const width = Math.max(290, article.node().getBoundingClientRect().width - 40);
      const height = 270;
      const margin = { top: 24, right: 24, bottom: 45, left: measure.money ? 62 : 72 };
      const valid = rows.filter(row => isValue(row[`${measure.id}_estimate`]));
      const upper = d3.max(valid, row => row[`${measure.id}_estimate`] + (isValue(row[`${measure.id}_moe`]) ? row[`${measure.id}_moe`] : 0)) || 1;
      const x = d3.scalePoint().domain(rows.map(row => row.acs_end_year)).range([margin.left, width - margin.right]).padding(0.25);
      const y = d3.scaleLinear().domain([0, measure.percent ? Math.max(100, upper * 1.05) : upper * 1.12]).nice().range([height - margin.bottom, margin.top]);
      const svg = article.append("svg").attr("viewBox", `0 0 ${width} ${height}`).attr("role", "img")
        .attr("aria-labelledby", `trend-title-${index} trend-desc-${index}`);
      svg.append("title").attr("id", `trend-title-${index}`).text(`${measure.label} across three ACS periods`);
      svg.append("desc").attr("id", `trend-desc-${index}`).text(`${measure.money ? "Nominal monthly dollars, not inflation-adjusted. " : measure.percent ? "Percentages; MOEs in percentage points. " : "Housing-unit counts. "}Vertical bars show 90% margins of error. ${rows.map(row => summary(row, measure)).join(". ")}`);
      svg.append("g").attr("class", "chart-grid").attr("transform", `translate(${margin.left},0)`)
        .call(d3.axisLeft(y).ticks(4).tickSize(-(width - margin.left - margin.right)).tickFormat(""))
        .call(g => g.select(".domain").remove());
      svg.append("g").attr("class", "chart-axis").attr("transform", `translate(0,${height - margin.bottom})`)
        .call(d3.axisBottom(x).tickSize(0).tickPadding(14).tickFormat(year => `${year - 4}–${year}`));
      svg.append("g").attr("class", "chart-axis").attr("transform", `translate(${margin.left},0)`)
        .call(d3.axisLeft(y).ticks(4).tickSize(0).tickPadding(10).tickFormat(measure.money ? d3.format("$,.0f") : measure.percent ? value => `${value}%` : d3.format("~s")))
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
        .attr("r", 4)
        .attr("fill", measure.color)
        .attr("stroke", measure.color).attr("stroke-width", 2)
        .attr("tabindex", 0).attr("aria-label", row => summary(row, measure));
      const tooltip = article.append("div").attr("class", "chart-tooltip").attr("role", "tooltip")
        .attr("id", `chart-tooltip-${index}`).attr("hidden", true);
      const readout = article.append("p").attr("class", "chart-readout").attr("aria-live", "polite")
        .text("Hover or focus a point for its estimate and margin of error.");
      function showPoint(event, row) {
        const point = d3.select(event.currentTarget);
        point.attr("r", 7).attr("fill", "#fbfbf7").attr("stroke-width", 3)
          .attr("aria-describedby", `chart-tooltip-${index}`);
        tooltip.text(summary(row, measure)).attr("hidden", null);
        const bounds = event.currentTarget.getBoundingClientRect();
        const container = article.node().getBoundingClientRect();
        const left = Math.max(8, Math.min(bounds.left + bounds.width / 2 - container.left - tooltip.node().offsetWidth / 2,
          container.width - tooltip.node().offsetWidth - 8));
        const above = bounds.top - container.top - tooltip.node().offsetHeight - 12;
        tooltip.style("left", `${left}px`).style("top", `${above >= 8 ? above : bounds.bottom - container.top + 12}px`);
        readout.text(summary(row, measure));
      }
      function hidePoint(event) {
        d3.select(event.currentTarget).attr("r", 4).attr("fill", measure.color).attr("stroke-width", 2)
          .attr("aria-describedby", null);
        tooltip.attr("hidden", true);
      }
      points.on("mouseenter focus", showPoint).on("mouseleave", event => {
        if (document.activeElement !== event.currentTarget) hidePoint(event);
      }).on("blur", hidePoint).on("keydown", event => {
        if (event.key === "Escape") hidePoint(event);
      });
    });
  }
  function renderTable() {
    const table = document.createElement("table");
    const caption = table.createCaption(); caption.textContent = "Chicago city estimates and margins of error. Derived percentage MOEs are approximate and in percentage points; rents are in end-year dollars.";
    const head = table.createTHead().insertRow();
    for (const label of ["Measure", "Period", "Units", "Estimate", "90% MOE", "Annotations"]) {
      const th = document.createElement("th"); th.scope = "col"; th.textContent = label; head.append(th);
    }
    const body = table.createTBody();
    for (const measure of measuresForTopic()) for (const row of rows) {
      const tr = body.insertRow();
      const values = [measure.label, period(row), measure.money ? `${row.dollar_year} dollars/month` : measure.percent ? "Percent (MOE: pp)" : "Housing units", format(row[`${measure.id}_estimate`], measure), format(row[`${measure.id}_moe`], measure, true), annotations(row, measure) || "None"];
      values.forEach(value => { const td = tr.insertCell(); td.textContent = value; });
    }
    document.getElementById("city-data-table").replaceChildren(table);
  }
  function renderTopicNote() {
    const notes = {
      core: "Counts describe occupied rental homes; rents are monthly amounts in each period’s end-year dollars.",
      burden: "Burden shares exclude renters without a computed rent/income ratio. The not-computed share uses all renter-occupied units as its denominator.",
      bedrooms: "Shares describe all renter-occupied units, including no-cash-rent homes. The three-plus category overlaps the three-, four-, and five-plus-bedroom categories.",
      utilities: "No extra utility payment is a share of all renter-occupied units. It does not measure utility spending."
    };
    document.getElementById("city-topic-note").textContent = notes[topicControl.value];
  }
  topicControl.addEventListener("change", () => {
    if (rows.length) { renderTopicNote(); renderCards(); renderTable(); if (typeof d3 !== "undefined") renderCharts(); }
  });
  statisticsPeriod.addEventListener("change", () => {
    selectedYear = statisticsPeriod.value;
    if (rows.length) { renderCards(); if (typeof d3 !== "undefined") renderCharts(); }
  });
  async function startCityStats() {
    const response = await fetch("data/web/chicago_city_statistics.json");
    if (!response.ok) throw new Error(`Citywide statistics could not load (HTTP ${response.status}). Upload data/web/chicago_city_statistics.json.`);
    rows = await response.json(); rows.sort((a, b) => a.acs_end_year - b.acs_end_year);
    if (rows.length !== 3 || rows.some(row => row.GEOID !== "1714000") || new Set(rows.map(row => row.acs_end_year)).size !== 3) throw new Error("Unexpected citywide statistics. Re-run the city web export.");
    renderTopicNote(); renderCards(); renderTable();
    if (typeof d3 === "undefined") throw new Error("Cards and table are available, but D3 could not load. Check your connection to load the charts.");
    renderCharts();
    document.getElementById("city-status").textContent = "This period selector updates the citywide cards independently of the map. Charts show all three periods.";
    let resizeFrame;
    window.addEventListener("resize", () => { cancelAnimationFrame(resizeFrame); resizeFrame = requestAnimationFrame(renderCharts); });
  }
  startCityStats().catch(error => { document.getElementById("city-status").textContent = error.message; });
})();
