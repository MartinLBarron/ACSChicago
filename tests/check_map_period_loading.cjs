// Execute the production async loader, rather than reconstructing its join in a test.
const fs=require("node:fs"),vm=require("node:vm"),assert=require("node:assert/strict");
const source=fs.readFileSync("html/map.js","utf8");
const loader=source.slice(source.indexOf("  async function fetchLayer"),source.indexOf("  const initialPeriod"));
const read=path=>JSON.parse(fs.readFileSync(path,"utf8"));
function setup(stale=false) {
  const context={window:{},calls:[],fetch:async(url,options)=>{
    context.calls.push({url,options});
    const path=`html/${url.split("?")[0]}`;
    const payload=read(path);
    if(stale && url.includes("model_measures_2024")) payload.forEach(row=>{
      delete row.two_bedrooms_pct_estimate;delete row.two_bedrooms_pct_moe;
      delete row.structure_1_unit_pct_estimate;delete row.structure_1_unit_pct_moe;
    });
    return {ok:true,json:async()=>payload};
  }};
  vm.createContext(context);
  vm.runInContext(fs.readFileSync("html/measures.js","utf8"),context);
  vm.runInContext(loader+"\nglobalThis.load=loadPeriod;",context);
  return context;
}
(async()=>{
  const context=setup();
  for(const year of ["2024","2019","2014","2024"]) {
    const data=await context.load(year);
    for(const tag of ["blocks","tracts"])for(const id of ["two_bedrooms_pct","structure_1_unit_pct"]) {
      const values=data[tag].features.map(f=>f.properties[`${id}_estimate`]);
      assert.ok(values.filter(Number.isFinite).length>values.length*.95,`${year}/${tag}/${id}`);
      assert.ok(values.some(v=>v>0),"must contain nonzero values");
    }
  }
  assert.ok(context.calls.every(call=>call.options.cache==="no-cache"));
  // Reproduce the user's all-unavailable symptom with an older 2024 payload.
  const stale=setup(true);
  await assert.rejects(stale.load("2024"),/Outdated 2024.*two bedrooms/);
  await assert.rejects(stale.load("2024"),/Outdated 2024/); // Failures must not be cached.
  console.log("PASS: initial 2024 load, historical switches and return; stale 2024 schema rejected, no silent all-missing map");
})().catch(error=>{console.error(error);process.exitCode=1;});
