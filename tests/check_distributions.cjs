const fs=require("node:fs"),vm=require("node:vm"),assert=require("node:assert/strict");
const d3=require("../html/vendor/d3.v7.9.0.min.js");
const source=fs.readFileSync("html/distributions.js","utf8");
const context={window:{},d3};
vm.createContext(context);
vm.runInContext(fs.readFileSync("html/measures.js","utf8"),context);
vm.runInContext(source.slice(source.indexOf("  function histogram("),source.indexOf("  async function render()")),context);
const histogram=context.window.ChicagoDistributionHistogram;
const read=path=>JSON.parse(fs.readFileSync(path,"utf8"));
let checks=0;
for(const year of [2014,2019,2024])for(const tag of ["tract","block_group"]){
 const base=read(`html/data/web/${tag}_rent_${year}.geojson`);
 const supplement=read(`html/data/web/${tag}_model_measures_${year}.json`);
 const lookup=new Map(supplement.map(row=>[row.GEOID,row]));
 const rows=base.features.map(f=>({...f.properties,...lookup.get(f.properties.GEOID)}));
 for(const measure of context.window.ChicagoMeasures){
  const values=rows.map(r=>r[`${measure.id}_estimate`]).filter(v=>typeof v==="number"&&Number.isFinite(v)&&v>=0);
  assert.ok(values.length>0);
  const result=histogram(values,30);
  assert.equal(result.bins.length,30,`${year}/${tag}/${measure.id}`);
  assert.equal(result.bins.reduce((sum,b)=>sum+b.length,0),values.length,"no data lost at boundaries");
  assert.ok(result.domain[0]<=Math.min(...values)&&result.domain[1]>=Math.max(...values));
  checks++;
 }
}
for(const values of [[0,0,0],[100,100],[0,1,2,3]])for(const count of [5,30,100]){
 const result=histogram(values,count);
 assert.equal(result.bins.length,count);
 assert.equal(result.bins.reduce((sum,b)=>sum+b.length,0),values.length);
 assert.ok(result.domain[1]>result.domain[0]);
}
console.log(`PASS: ${checks} measure/period/geography distributions; exact bin counts, all observations retained, constant/zero data`);
