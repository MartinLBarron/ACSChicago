// Exercise the same pure calculation loaded by the webpage against R fixtures.
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const context = { window: {} };
vm.runInNewContext(fs.readFileSync("html/model-effects.js", "utf8"), context);
const fixtures = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
for (const test of fixtures) {
  const result = context.window.ChicagoModelEffects.contrast(test.variable, test.coefficient, test.target);
  for (const field of ["estimate", "low", "high"]) {
    assert.ok(Math.abs(result[field]-test.expected[field]) < 1e-9, `${test.variable.term}: ${field}`);
  }
  assert.ok(result.low <= result.estimate+1e-10 && result.estimate <= result.high+1e-10);
}
console.log(`PASS: ${fixtures.length} observed-range contrasts, including reference and negative-direction interval ordering`);
