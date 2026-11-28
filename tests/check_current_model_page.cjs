// Exercise production model-page summaries and tables against the current export.
const fs=require("node:fs"),vm=require("node:vm"),assert=require("node:assert/strict"),d3=require("../html/vendor/d3.v7.9.0.min.js");
const html=fs.readFileSync("html/model.html","utf8"),source=fs.readFileSync("html/model.js","utf8");
const supplied=JSON.parse(fs.readFileSync("html/data/web/block_group_model_2024.json","utf8"));
const nodes={};function element(tag){return{tag,children:[],textContent:"",attrs:{},append(...items){this.children.push(...items)},replaceChildren(){this.children=[]},setAttribute(key,value){this.attrs[key]=value}}}
for(const match of html.matchAll(/\bid="([^"]+)"/g)){assert.ok(!nodes[match[1]]);nodes[match[1]]=element("div")}
const context={supplied,d3,document:{getElementById:id=>{assert.ok(nodes[id],id);return nodes[id]},createElement:element}};
vm.createContext(context);
const helpers=source.slice(source.indexOf("  const $"),source.indexOf("  let data;"));
const row=source.slice(source.indexOf("  function cellRow("),source.indexOf("  function svgRoot("));
const tables=source.slice(source.indexOf("  function overview()"),source.indexOf("  function coefficientChart()"));
vm.runInContext(helpers+"\nlet data=supplied;\n"+row+tables+"\noverview();formalSpecification();",context);
assert.equal(supplied.version,4);
for(const term of ["college_10pp","structure_20_plus_10pp"]) {
 assert.ok(!supplied.coefficients.some(row=>row.term===term));
 assert.ok(!supplied.formal_coefficients.some(row=>row.term===term));
}
assert.deepEqual(supplied.models.map(m=>m.model), ["M1","M2","M3","M4"]);
assert.ok(supplied.effects.every(row=>row.term==="crime_rate"));
assert.ok(!/\bM0\b/.test(html));
assert.match(nodes["summary-results"].textContent,/57.5 crimes per 1,000 residents/);
assert.match(nodes["summary-results"].textContent,/−0.07%/);
assert.match(nodes["summary-results"].textContent,/−1.22% to \+1.08%/);
for(const [id,count] of [["model-table",4],["formal-coefficients",92],["formal-fit",5],["period-checks",3],["crime-estimates",4]])
 assert.equal(nodes[id].children.length,count,id);
assert.match(nodes["crime-estimates-caption"].textContent,/57\.5 more recorded violent crimes per 1,000 residents/);
for (const [index, model] of supplied.models.entries()) {
 const effect=supplied.effects.find(row=>row.model===model.model);
 const pct=d3.format("+.2f");
 assert.deepEqual(nodes["crime-estimates"].children[index].children.map(cell=>cell.textContent),
   [`${model.model} · ${model.label}`, `${pct(effect.percent_estimate)}%`,
    `${pct(effect.percent_hc3_conf_low)}% to ${pct(effect.percent_hc3_conf_high)}%`]);
}
assert.match(nodes["formal-reference"].textContent,/20\+-unit/);
for(const id of ["spatial-table","spatial-note","spatial-robustness","vif-table","diagnostic-table","sensitivity-table"])
 assert.ok(!nodes[id],id);
assert.ok(!html.includes("These checks explain why the current model is a starting point."));
assert.ok(!html.includes("bachelor’s degree or higher and without"));
assert.ok(!html.includes("rental shares in 2–4, 5–19 and 20+"));
for(const match of source.matchAll(/\$\("([^"]+)"\)/g))assert.ok(nodes[match[1]],match[1]);
console.log("PASS: reduced coefficients and fit, rate-based HC3 summary, remaining tables, removed diagnostic sections and DOM references");
