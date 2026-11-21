// Check the production comparison loader plus every selectable ACS comparison.
const fs=require("node:fs"),vm=require("node:vm"),assert=require("node:assert/strict");
const read=path=>JSON.parse(fs.readFileSync(path,"utf8"));
const source=fs.readFileSync("html/comparisons.js","utf8");
const loader=source.slice(source.indexOf("  function loadData()"),source.indexOf("  async function render()"));
function setup(stale=false){
 const context={window:{},fetch:async(_url,options)=>{
  assert.equal(options.cache,"no-cache");
  const rows=read("html/data/web/comparison_statistics.json");
  if(stale)rows.forEach(row=>delete row.two_bedrooms_pct_estimate);
  return{ok:true,json:async()=>rows};
 }};
 vm.createContext(context);
 vm.runInContext(fs.readFileSync("html/measures.js","utf8"),context);
 vm.runInContext("let dataPromise;"+loader+"\nglobalThis.load=loadData;",context);
 return context;
}
(async()=>{
 const context=setup();const data=await context.load();
 const measures=context.window.ChicagoMeasures.filter(m=>!m.administrative);
 assert.equal(measures.length,25);assert.ok(measures.every(m=>m.comparison!==false));
 for(const year of [2014,2019,2024])for(const measure of measures){
  const includeNational=measure.money||measure.percent;
  const rows=data.filter(r=>r.acs_end_year===year&&(includeNational||r.comparison_id!=="united_states"));
  assert.equal(rows.length,includeNational?11:10);
  assert.equal(rows.some(r=>r.comparison_id==="united_states"),Boolean(includeNational));
  for(const row of rows)for(const suffix of ["estimate","moe"])assert.ok(Number.isFinite(row[`${measure.id}_${suffix}`]),`${year}/${measure.id}/${row.comparison_id}/${suffix}`);
 }
 await assert.rejects(setup(true).load(),/outdated/);
 console.log("PASS: 75 ACS measure/period comparisons, national-row rules, MOEs and stale-data rejection");
})().catch(error=>{console.error(error);process.exitCode=1;});
