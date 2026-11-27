const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const read = path => JSON.parse(fs.readFileSync(path, "utf8"));
const context = { window: {} };
vm.runInNewContext(fs.readFileSync("html/measures.js", "utf8"), context);
const measures = context.window.ChicagoMeasures;
assert.equal(measures.length, 27);
assert.equal(measures.filter(m => m.latestOnly).length, 0);
assert.equal(measures.filter(m => m.supplemental).length, 20);
assert.equal(measures.filter(m => m.comparison === false).length, 1);
for (const year of [2014,2019,2024]) {
const city = read("html/data/web/chicago_city_statistics.json").find(r => r.acs_end_year === year);
Object.assign(city, read(`html/data/web/chicago_city_model_measures_${year}.json`)[0]);
for (const measure of measures) {
  assert.ok(Number.isFinite(city[`${measure.id}_estimate`]), `City ${measure.id}`);
  if (measure.percent) assert.ok(city[`${measure.id}_estimate`] >= 0 && city[`${measure.id}_estimate`] <= 100);

}
const mapSource = fs.readFileSync("html/map.js", "utf8");
const scales = mapSource.slice(mapSource.indexOf("const rentBreaks"), mapSource.indexOf("const colors"));
context.measureControl = { value: "median_contract_rent" };
context.geographyControl = { value: "blocks" };
vm.runInNewContext(`(() => { ${scales}; globalThis.selectedScale = selectedScale; })()`, context);
for (const geography of ["blocks", "tracts"]) {
  context.geographyControl.value = geography;
  for (const measure of measures) {
    context.measureControl.value = measure.id;
    const scale = context.selectedScale();
    assert.equal(scale.breaks.length, 6, measure.id);
    assert.ok(scale.breaks.every((v, i, a) => Number.isFinite(v) && (i === 0 || v > a[i-1])));
  }
}
for (const [tag, key] of [["block_group", "blocks"], ["tract", "tracts"]]) {
  const base = read(`html/data/web/${tag}_rent_${year}.geojson`);
  const rows = read(`html/data/web/${tag}_model_measures_${year}.json`);
  const lookup = new Map(rows.map(r => [r.GEOID, r]));
  assert.equal(base.features.length, rows.length);
  for (const feature of base.features) {
    const row = lookup.get(feature.properties.GEOID);
    assert.ok(row, `${key}: ${feature.properties.GEOID}`);
    const joined = { ...feature.properties, ...row };
    for (const measure of measures) {
      assert.ok(Object.hasOwn(joined, `${measure.id}_estimate`), measure.id);
      assert.ok(Object.hasOwn(joined, `${measure.id}_moe`), measure.id);
    }
  }
}
assert.equal(city.violent_crime_count_moe, null);
assert.ok(context.window.chicagoMeasureForYear(measures.find(m=>m.id==="recent_movers_pct"),year).label.includes(String(year-4)));
assert.ok(context.window.chicagoMeasureForYear(measures.find(m=>m.administrative),year).label.includes(String(year)));
}
const crime = measures.find(m => m.id === "violent_crime_count");
assert.equal(crime.percent, false);
assert.equal(crime.administrative, true);
assert.equal(context.window.formatChicagoValue(100, crime), "100");
assert.equal(context.window.formatChicagoValue(50000, measures.find(m => m.id === "area_median_income")), "$50,000");
const mapSource=fs.readFileSync("html/map.js","utf8");
assert.ok(!mapSource.includes("pumas"));
assert.ok(!fs.readFileSync("html/index.html", "utf8").includes('value="pumas"'));
const annual=read("html/data/web/chicago_annual_violent_crime.json");
assert.equal(annual.length,15);
for(const year of [2014,2019,2024]) {
  const series=annual.filter(r=>r.acs_end_year>=year-4 && r.acs_end_year<=year);
  const city=read(`html/data/web/chicago_city_model_measures_${year}.json`)[0];
  assert.equal(series.length,5);
  assert.equal(series.reduce((sum,r)=>sum+r.violent_crime_count_estimate,0),city.violent_crime_count_estimate);
}
console.log("PASS: 27 measures across all periods, readable units/cutoffs, geometry joins, MOEs and annual crime reconciliation");
