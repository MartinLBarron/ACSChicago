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
assert.equal(supplied.version,3);
for(const term of ["college_10pp","structure_20_plus_10pp"]) {
 assert.ok(!supplied.coefficients.some(row=>row.term===term));
 assert.ok(!supplied.formal_coefficients.some(row=>row.term===term));
}
assert.match(nodes["summary-results"].textContent,/72\.8%/);
assert.match(nodes["summary-results"].textContent,/−2\.3%/);
assert.match(nodes["summary-results"].textContent,/−0\.02%/);
assert.match(nodes["summary-results"].textContent,/statistically significant/);
assert.ok(!nodes["summary-results"].textContent.includes("not statistically significant"));
for(const [id,count] of [["model-table",5],["formal-coefficients",92],["formal-fit",5]])
 assert.equal(nodes[id].children.length,count,id);
assert.match(nodes["formal-reference"].textContent,/20\+-unit/);
for(const id of ["spatial-table","spatial-note","spatial-robustness","vif-table","diagnostic-table","sensitivity-table"])
 assert.ok(!nodes[id],id);
assert.ok(!html.includes("These checks explain why the current model is a starting point."));
assert.ok(!html.includes("bachelor’s degree or higher and without"));
assert.ok(!html.includes("rental shares in 2–4, 5–19 and 20+"));
for(const match of source.matchAll(/\$\("([^"]+)"\)/g))assert.ok(nodes[match[1]],match[1]);
console.log("PASS: reduced coefficients and fit, significant HC3 summary, remaining tables, removed diagnostic sections and DOM references");
