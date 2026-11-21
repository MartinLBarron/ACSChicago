const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const read = path => JSON.parse(fs.readFileSync(path, "utf8"));
const context = { window: {} };
vm.runInNewContext(fs.readFileSync("html/measures.js", "utf8"), context);
const measures = context.window.ChicagoMeasures;
assert.equal(measures.length, 23);
assert.equal(measures.filter(m => m.latestOnly).length, 17);
assert.equal(measures.filter(m => !m.latestOnly).length, 6);
const city = read("html/data/web/chicago_city_statistics.json").find(r => r.acs_end_year === 2024);
Object.assign(city, read("html/data/web/chicago_city_model_measures_2024.json")[0]);
for (const measure of measures) {
  assert.ok(Number.isFinite(city[`${measure.id}_estimate`]), `City ${measure.id}`);
  if (measure.percent) assert.ok(city[`${measure.id}_estimate`] >= 0 && city[`${measure.id}_estimate`] <= 100);
  if (measure.latestOnly) assert.equal(measure.comparison, false);
}
const mapSource = fs.readFileSync("html/map.js", "utf8");
const scales = mapSource.slice(mapSource.indexOf("const rentBreaks"), mapSource.indexOf("const colors"));
context.measureControl = { value: "median_contract_rent" };
context.geographyControl = { value: "blocks" };
vm.runInNewContext(scales, context);
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
  const base = read(`html/data/web/${tag}_rent_2024.geojson`);
  const rows = read(`html/data/web/${tag}_model_measures_2024.json`);
  const lookup = new Map(rows.map(r => [r.GEOID, r]));
  assert.equal(base.features.length, rows.length);
  for (const feature of base.features) {
    const row = lookup.get(feature.properties.GEOID);
    assert.ok(row, `${key}: ${feature.properties.GEOID}`);
    for (const measure of measures.filter(m => m.latestOnly)) {
      assert.ok(Object.hasOwn(row, `${measure.id}_estimate`), measure.id);
      assert.ok(Object.hasOwn(row, `${measure.id}_moe`), measure.id);
    }
  }
}
const crime = measures.find(m => m.id === "violent_crime_count");
assert.equal(crime.percent, false);
assert.equal(crime.administrative, true);
assert.equal(context.window.formatChicagoValue(100, crime), "100");
assert.equal(context.window.formatChicagoValue(50000, measures.find(m => m.id === "area_median_income")), "$50,000");
assert.equal(city.violent_crime_count_moe, null);
assert.ok(!mapSource.includes("pumas"));
assert.ok(!fs.readFileSync("html/index.html", "utf8").includes('value="pumas"'));
console.log("PASS: 23 measures, latest-period scope, readable units, geography-specific scales, sidecar joins and no PUMA controls");
