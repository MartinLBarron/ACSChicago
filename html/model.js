/* global d3 */
"use strict";
(() => {
  const $ = id => document.getElementById(id);
  const percent = d3.format(".1%");
  const number = d3.format(",.0f");
  const money = d3.format("$,.0f");
  const signed = value => `${value > 0 ? "+" : ""}${d3.format(".1f")(value)}%`;
  const probability = value => value < .001 ? "< 0.001" : d3.format(".3f")(value);
  const colors = { ink: "#183f35", green: "#518467", teal: "#287d87", rust: "#b44d3f", pale: "#dce7d6" };
  let data;
  const tooltip = document.createElement("div");
  tooltip.className = "chart-tooltip";
  tooltip.id = "model-tooltip";
  tooltip.setAttribute("role", "tooltip");
  tooltip.hidden = true;
  tooltip.style.position = "fixed";
  document.body.append(tooltip);
  function showTip(event, text) {
    tooltip.textContent = text;
    tooltip.hidden = false;
    const box = event.currentTarget.getBoundingClientRect();
    const left = event.type === "focus" ? box.right : event.clientX;
    const top = event.type === "focus" ? box.bottom : event.clientY;
    tooltip.style.left = `${Math.max(8, Math.min(left + 12, window.innerWidth - tooltip.offsetWidth - 12))}px`;
    tooltip.style.top = `${Math.max(8, Math.min(top + 12, window.innerHeight - tooltip.offsetHeight - 12))}px`;
  }
  const hideTip = () => { tooltip.hidden = true; };
  document.addEventListener("keydown", event => { if (event.key === "Escape") hideTip(); });
  function tips(selection, format, keyboard = false) {
    selection.on("pointerenter pointermove", function(event, row) { showTip(event, format(row)); })
      .on("pointerleave", hideTip);
    if (keyboard) selection.attr("tabindex", 0).attr("aria-label", format)
      .on("focus", function(event, row) { showTip(event, format(row)); }).on("blur", hideTip);
  }
  function cellRow(root, cells) {
    const row = document.createElement("tr");
    cells.forEach((text, i) => {
      const cell = document.createElement(i === 0 ? "th" : "td");
      if (i === 0) cell.scope = "row";
      cell.textContent = text;
      row.append(cell);
    });
    root.append(row);
  }
  function svgRoot(id, height, title, description, minimum = 320) {
    const root = d3.select(`#${id}`);
    root.selectAll("*").remove();
    const width = Math.max(minimum, root.node().getBoundingClientRect().width);
    const svg = root.append("svg").attr("viewBox", `0 0 ${width} ${height}`)
      .attr("role", "img").attr("aria-labelledby", `${id}-title ${id}-desc`);
    svg.append("title").attr("id", `${id}-title`).text(title);
    svg.append("desc").attr("id", `${id}-desc`).text(description);
    return { svg, width, height };
  }
  function frame(id, height, title, description, xDomain, yDomain, xLabel, yLabel, xFormat, yFormat) {
    const chart = svgRoot(id, height, title, description);
    const m = { left: 63, right: 20, top: 22, bottom: 64 };
    const x = d3.scaleLinear().domain(xDomain).nice().range([m.left, chart.width - m.right]);
    const y = d3.scaleLinear().domain(yDomain).nice().range([height - m.bottom, m.top]);
    chart.svg.append("g").attr("class", "chart-grid").attr("transform", `translate(${m.left},0)`)
      .call(d3.axisLeft(y).ticks(4).tickSize(-(chart.width - m.left - m.right)).tickFormat(""));
    chart.svg.append("g").attr("class", "chart-axis").attr("transform", `translate(0,${height-m.bottom})`)
      .call(d3.axisBottom(x).ticks(chart.width < 450 ? 3 : 5).tickFormat(xFormat).tickSize(0).tickPadding(10));
    chart.svg.append("g").attr("class", "chart-axis").attr("transform", `translate(${m.left},0)`)
      .call(d3.axisLeft(y).ticks(4).tickFormat(yFormat).tickSize(0).tickPadding(8)).call(g=>g.select(".domain").remove());
    chart.svg.append("text").attr("class","plot-label").attr("x",(m.left+chart.width-m.right)/2)
      .attr("y",height-12).attr("text-anchor","middle").text(xLabel);
    chart.svg.append("text").attr("x",m.left).attr("y",12).text(yLabel);
    return { ...chart, x, y, m };
  }
  function overview() {
    const m2 = data.models.find(d=>d.model==="M2");
    const m3 = data.models.find(d=>d.model==="M3");
    const m1 = data.models.find(d=>d.model==="M1");
    const m4 = data.models.find(d=>d.model==="M4");
    const gain = m4.r_squared-m3.r_squared;
    $("housing-location-finding").textContent = `Crime alone accounts for ${percent(m1.r_squared)} of log-rent variation. Its association changes as housing, socioeconomic conditions and community location enter the models. This does not identify an effect of crime on rent.`;
    const crimeOnly = data.effects.find(row=>row.model==="M1");
    const crimeFull = data.effects.find(row=>row.model==="M4");
    $("summary-data").textContent = `The study combines 2020–2024 ACS five-year estimates, matching 2024 Census boundaries and 2020–2024 Chicago Police Department records. It includes ${number(data.sample_n)} complete-case block groups across ${data.communities_n} community areas. Whole block groups must have at least half their area inside Chicago. Contract rent excludes separately paid utilities.`;
    $("summary-results").textContent = `Crime alone accounts for ${percent(m1.r_squared)} of observed log-rent variation. In M1, 100 additional recorded violent-crime rows are associated with ${signed(crimeOnly.percent_per100_estimate)} rent. That association becomes much smaller after adding the measured controls. The full M4 accounts for ${percent(m4.r_squared)} of log-rent variation, with ${percent(m4.predictive_R2)} held out in tract-blocked cross-validation.`;
    $("summary-uncertainty").textContent = `In M4, the crime association is ${signed(crimeFull.percent_per100_estimate)} per 100 additional records (95% HC3 interval: ${signed(crimeFull.percent_per100_hc3_conf_low)} to ${signed(crimeFull.percent_per100_hc3_conf_high)}). This interval includes zero; the community-clustered interval does not (${signed(crimeFull.percent_per100_cluster_conf_low)} to ${signed(crimeFull.percent_per100_cluster_conf_high)}). The evidence therefore depends on how uncertainty is estimated.`;
    const cards = [
      { title: "Block groups in the study", value: number(data.sample_n), note: `${data.communities_n} community areas · 2020–2024 ACS` },
      { title: "Variation accounted for by M4", value: percent(m4.r_squared), note: `Observed log-rent variation · ${percent(m4.predictive_R2)} held out` },
      { title: "Added fit from community location", value: `${d3.format(".1f")(gain*100)} pp`, note: `${percent(gain/(1-m3.r_squared))} of the variation remaining after measured controls` }
    ];
    for (const card of cards) {
      const article = document.createElement("article"); article.className="model-summary";
      const title=document.createElement("h3"); title.textContent=card.title;
      const value=document.createElement("strong"); value.textContent=card.value;
      const note=document.createElement("p"); note.textContent=card.note;
      article.append(title,value,note); $("model-overview").append(article);
    }
    $("community-finding").textContent = `After measured housing and contextual controls, community location adds ${d3.format(".1f")(gain*100)} percentage points of in-sample R². That is ${percent(gain/(1-m3.r_squared))} of the remaining variation—not the share of rent caused by neighborhoods.`;
    for (const m of data.models) cellRow($("model-table"), [m.model, `${m.label}: ${m.specification}`,number(m.n),m.parameters,percent(m.r_squared),percent(m.adjusted_r_squared)]);
    for (const row of data.spatial.filter(d=>d.weights==="queen")) cellRow($("spatial-table"), [row.model==="observed_log_rent"?"Observed log rent":`${row.model} residuals`,d3.format(".3f")(row.Moran_I),probability(row.permutation_p)]);
    const knn=data.spatial.find(d=>d.weights==="knn4" && d.model==="M4");
    $("spatial-note").textContent=`999 permutations, two-sided add-one probabilities. Fitted-residual tests are exploratory under unequal variance. The symmetric four-nearest-neighbor sensitivity gives M4 Moran’s I = ${d3.format(".3f")(knn.Moran_I)}, p = ${probability(knn.permutation_p)}. Clustering uncertainty by community does not resolve all spatial dependence.`;
    for (const row of data.diagnostics.filter(d=>["M3","M4"].includes(d.model))) cellRow($("diagnostic-table"),[row.model,row.test,Number.isFinite(row.statistic)?d3.format(".2f")(row.statistic):"—",probability(row.p_value)]);
    for (const row of data.sensitivity) cellRow($("sensitivity-table"),[row.sensitivity,number(row.n),percent(row.M2),percent(row.M3),percent(row.M4),`${d3.format(".1f")(row.increment*100)} pp`]);
    $("sample-note").textContent=`The outcome is median contract rent (B25058), excluding separately paid utilities. The ${number(data.majority_city_n)} majority-in-city block groups lose ${number(data.missing_rent_n)} without usable rent and another ${number(data.missing_income_n)} without median household income, leaving ${number(data.sample_n)} complete cases. Dollar values use 2024 dollars and matching 2024 TIGER block-group boundaries.`;
    $("caveat-note").textContent=`${data.open_ended_rent_n} rent medians represent $3,500 or more and are entered at the supplied $3,501 endpoint; an exclusion sensitivity is reported. ${data.singleton_n} community (Oakland) has only one usable block group and is fitted exactly. HC3 slopes use nonsingleton communities, with unchanged slope estimates. Cross-validation omits ${data.cv_excluded_n} block groups whose communities are absent from a training fold.`;
  }
  function formalSpecification() {
    const body=$("formal-coefficients"); body.replaceChildren();
    const coefficients=data.formal_coefficients;
    const terms=[...new Set(coefficients.map(row=>row.term))];
    const lookup=new Map(coefficients.map(row=>[`${row.model}:${row.term}`,row]));
    const coefficientFormat=d3.format(".4~g");
    for(const term of terms) {
      const row=document.createElement("tr");
      const heading=document.createElement("th"); heading.scope="row";
      heading.textContent=coefficients.find(coefficient=>coefficient.term===term).label;
      row.append(heading);
      for(const model of data.models) {
        const cell=document.createElement("td");
        const value=lookup.get(`${model.model}:${term}`);
        if(!value) { cell.textContent="—"; cell.setAttribute("aria-label","Not included"); }
        else {
          const estimate=document.createElement("div"); estimate.className="formal-estimate";
          estimate.textContent=coefficientFormat(value.estimate);
          const p=value.hc3_p_value;
          if(Number.isFinite(p) && p<.05) {
            const significance=document.createElement("sup");
            significance.textContent=p<.001?"***":p<.01?"**":"*";
            significance.setAttribute("aria-label",p<.001?"p less than 0.001":p<.01?"p less than 0.01":"p less than 0.05");
            estimate.append(significance);
          }
          const interval=document.createElement("span"); interval.className="formal-ci";
          interval.textContent=Number.isFinite(value.hc3_conf_low)&&Number.isFinite(value.hc3_conf_high)
            ? `[${coefficientFormat(value.hc3_conf_low)}, ${coefficientFormat(value.hc3_conf_high)}]` : "[NE]";
          cell.append(estimate,interval);
        }
        row.append(cell);
      }
      body.append(row);
    }
    $("formal-fit").replaceChildren();
    const overallF=model=>Number.isFinite(model.f_statistic)
      ? `${d3.format(".2f")(model.f_statistic)}${model.f_log10_p < -3 ? "***" : model.f_log10_p < -2 ? "**" : model.f_log10_p < Math.log10(.05) ? "*" : ""} (${model.f_df2})` : "N/A";
    const overallP=model=>Number.isFinite(model.f_log10_p)
      ? model.f_log10_p < -5 ? "<.00001" : d3.format(".2e")(10**model.f_log10_p) : "N/A";
    cellRow($("formal-fit"),["Overall F (df)",...data.models.map(overallF)]);
    cellRow($("formal-fit"),["Overall F p-value",...data.models.map(overallP)]);
    for(const [label,field,format] of [["R²","r_squared",percent],["Adjusted R²","adjusted_r_squared",percent],["N","n",number]])
      cellRow($("formal-fit"),[label,...data.models.map(model=>format(model[field]))]);
    $("formal-reference").textContent=`Reference categories: two-bedroom rentals; detached/attached one-unit buildings and mobile/other structures; buildings built in 1940–1999; renter householders age 35–64; and ${data.reference_community} for community location. Reference categories have no separate estimated coefficients.`;
  }
  function coefficientChart() {
    const model=$("coefficient-model").value;
    const rows=data.coefficients.filter(d=>d.model===model);
    const width=Math.max(320,$("coefficient-chart").getBoundingClientRect().width), small=width<720;
    const step=small?70:40, top=20, bottom=55;
    const {svg,height}=svgRoot("coefficient-chart",top+rows.length*step+bottom,`${model} conditional associations`,"Percent associations and 95% HC3 intervals. A complete accessible table with HC3 and community-clustered intervals follows.");
    const left=small?20:390, right=45;
    const lo=Math.min(0,d3.min(rows,d=>d.percent_hc3_conf_low)), hi=Math.max(0,d3.max(rows,d=>d.percent_hc3_conf_high));
    const pad=(hi-lo)*.08||1;
    const x=d3.scaleLinear().domain([lo-pad,hi+pad]).nice().range([left,width-right]);
    svg.append("g").attr("class","chart-grid").attr("transform",`translate(0,${height-bottom})`)
      .call(d3.axisBottom(x).ticks(5).tickFormat("").tickSize(-(height-top-bottom)));
    svg.append("line").attr("x1",x(0)).attr("x2",x(0)).attr("y1",top).attr("y2",height-bottom).attr("stroke","#8b9c8b");
    svg.append("g").attr("class","chart-axis").attr("transform",`translate(0,${height-bottom})`).call(d3.axisBottom(x).ticks(5).tickFormat(d=>`${d}%`));
    rows.forEach((row,i)=>{
      const y=top+i*step+(small?43:18);
      const label=svg.append("text").attr("class","plot-label").attr("x",small?left:left-18)
        .attr("y",small?y-27:y+4).attr("text-anchor",small?"start":"end");
      const words=row.label.split(" "); let line="", lines=[];
      for (const word of words) { if ((line+" "+word).length>(small?Math.floor((width-40)/6.3):62)) { lines.push(line); line=word; } else line+=(line?" ":"")+word; }
      lines.push(line);
      lines.forEach((text,j)=>label.append("tspan").attr("x",small?left:left-18).attr("dy",j===0?0:14).text(text));
      svg.append("line").attr("x1",x(row.percent_hc3_conf_low)).attr("x2",x(row.percent_hc3_conf_high)).attr("y1",y).attr("y2",y).attr("stroke",colors.green).attr("stroke-width",2);
      const dot=svg.append("circle").datum(row).attr("class","plot-hit").attr("cx",x(row.percent_estimate)).attr("cy",y).attr("r",5).attr("fill",colors.ink);
      tips(dot,d=>`${d.label}: ${signed(d.percent_estimate)} (95% HC3: ${signed(d.percent_hc3_conf_low)} to ${signed(d.percent_hc3_conf_high)}).`,true);
    });
    $("coefficient-table").replaceChildren();
    $("coefficient-caption").textContent=`${model} · percent differences in median contract rent`;
    for (const row of rows) cellRow($("coefficient-table"),[row.label,signed(row.percent_estimate),`${signed(row.percent_hc3_conf_low)} to ${signed(row.percent_hc3_conf_high)}`,`${signed(row.percent_cluster_conf_low)} to ${signed(row.percent_cluster_conf_high)}`]);
  }
  function diagnostics() {
    const maximum=d3.max(data.points,d=>Math.max(d.observed,d.fitted))*1.05;
    const obs=frame("observed-chart",300,"Observed versus fitted rent","A scatterplot with a one-to-one reference line. Points away from the diagonal indicate prediction errors.",[0,maximum],[0,maximum],"Fitted median rent ($)","Observed median rent ($)",d3.format("$~s"),d3.format("$~s"));
    obs.svg.append("line").attr("x1",obs.x(0)).attr("x2",obs.x(maximum)).attr("y1",obs.y(0)).attr("y2",obs.y(maximum)).attr("stroke",colors.rust).attr("stroke-dasharray","4,4");
    const op=obs.svg.append("g").selectAll("circle").data(data.points).join("circle").attr("cx",d=>obs.x(d.fitted)).attr("cy",d=>obs.y(d.observed)).attr("r",2.3).attr("fill",colors.teal).attr("opacity",.45);
    tips(op,d=>`${d.community}: observed ${money(d.observed)}; fitted ${money(d.fitted)}.`);
    const res=frame("residual-chart",300,"M4 residuals versus fitted rent","The scatterplot shows changing residual spread and some curvature, indicating specification problems.",d3.extent(data.points,d=>d.fitted),d3.extent(data.points,d=>d.residual),"Fitted median rent ($)","Residual (observed − fitted log rent)",d3.format("$~s"),d3.format(".1f"));
    res.svg.append("line").attr("x1",res.m.left).attr("x2",res.width-res.m.right).attr("y1",res.y(0)).attr("y2",res.y(0)).attr("stroke",colors.rust).attr("stroke-dasharray","4,4");
    const rp=res.svg.append("g").selectAll("circle").data(data.points).join("circle").attr("cx",d=>res.x(d.fitted)).attr("cy",d=>res.y(d.residual)).attr("r",2.3).attr("fill",colors.teal).attr("opacity",.45);
    tips(rp,d=>`${d.community}: log residual ${d3.format(".2f")(d.residual)}; observed rent ${signed(100*Math.expm1(d.residual))} versus fitted.`);
    const ordered=d3.sort(data.points,d=>d.fitted);
    const binned=Array.from(d3.group(ordered,(_d,i)=>Math.floor(i*18/ordered.length)).values(),
      rows=>({fitted:d3.mean(rows,d=>d.fitted),residual:d3.mean(rows,d=>d.residual)}));
    res.svg.append("path").datum(binned).attr("d",d3.line().x(d=>res.x(d.fitted)).y(d=>res.y(d.residual)))
      .attr("fill","none").attr("stroke",colors.rust).attr("stroke-width",2).attr("pointer-events","none");
    const qq=frame("qq-chart",300,"Normal Q–Q residual diagnostic","Heavy tails depart from the reference line at both ends.",d3.extent(data.qq,d=>d.theoretical),d3.extent(data.qq,d=>d.observed),"Normal theoretical quantile","Standardized residual",d3.format(".0f"),d3.format(".0f"));
    const domain=qq.x.domain();
    qq.svg.append("line").attr("x1",qq.x(domain[0])).attr("x2",qq.x(domain[1])).attr("y1",qq.y(data.qq_reference.intercept+data.qq_reference.slope*domain[0])).attr("y2",qq.y(data.qq_reference.intercept+data.qq_reference.slope*domain[1])).attr("stroke",colors.rust).attr("stroke-dasharray","4,4");
    qq.svg.append("g").selectAll("circle").data(data.qq).join("circle").attr("cx",d=>qq.x(d.theoretical)).attr("cy",d=>qq.y(d.observed)).attr("r",1.8).attr("fill",colors.teal).attr("opacity",.5);
    const reliable=data.points.filter(d=>Number.isFinite(d.relative_moe));
    const rel=frame("reliability-chart",300,"Rent-estimate relative margin of error","The 90% rent margin of error divided by the estimate; a dashed line marks one half. Open-ended medians without computable MOEs are omitted.",[0,d3.max(reliable,d=>d.observed)*1.05],[0,d3.max(reliable,d=>d.relative_moe)*1.08],"Median contract rent ($)","90% MOE / estimate",d3.format("$~s"),d3.format(".0%"));
    rel.svg.append("line").attr("x1",rel.m.left).attr("x2",rel.width-rel.m.right).attr("y1",rel.y(.5)).attr("y2",rel.y(.5)).attr("stroke",colors.rust).attr("stroke-dasharray","4,4");
    const points=rel.svg.append("g").selectAll("circle").data(reliable).join("circle").attr("cx",d=>rel.x(d.observed)).attr("cy",d=>rel.y(d.relative_moe)).attr("r",2.3).attr("fill",colors.teal).attr("opacity",.45);
    tips(points,d=>`${d.community}: median rent ${money(d.observed)}; 90% MOE is ${percent(d.relative_moe)} of estimate.`);
  }
  function render() { hideTip(); coefficientChart(); diagnostics(); }
  async function start() {
    try {
      const response=await fetch("data/web/block_group_model_2024.json?v=20261121-formal-fit-format", { cache: "no-cache" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      data=await response.json();
      if (data.version!==2 || data.synthetic_data || !data.models?.length || !data.coefficients?.length || !data.formal_coefficients?.length) throw new Error("Invalid model export");
      $("model-content").hidden=false;
      overview();
      $("coefficient-model").addEventListener("change",coefficientChart);
      formalSpecification();
      render();
      $("model-status").textContent="";
      let timeout;
      window.addEventListener("resize",()=>{ clearTimeout(timeout); timeout=setTimeout(render,150); });
    } catch (error) {
      console.error("Unable to load model page",error);
      $("model-content").hidden=true;
      $("model-status").textContent="Model results could not be loaded. Refresh the page; if this persists, check that the model data was included with the website upload.";
    }
  }
  start();
})();
