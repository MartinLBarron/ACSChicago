// Exercise the actual tab/card renderer with local data and a small DOM substitute.
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const elements = {};
function element(tag = "div") {
  return { tag, children: [], listeners: {}, attrs: {}, value: "2024",
    setAttribute(key, value) { this.attrs[key] = value; },
    append(...children) { this.children.push(...children); children.forEach(child => { if(child.id) elements[child.id] = child; }); },
    replaceChildren() { this.children = []; },
    addEventListener(event, callback) { this.listeners[event] = callback; },
    querySelectorAll() { return this.children; },
    focus() {}, click() { this.listeners.click(); }
  };
}
for(const id of ["city-period","city-tabs","city-group-panel","city-cards"]) elements[id] = element();
const context = { window: {}, document: { getElementById: id => elements[id], createElement: element,
  createTextNode: text => ({ textContent: text }) } };
const comparisonCalls = [], distributionCalls = [];
context.window.openChicagoComparison = (m,y) => comparisonCalls.push([m.id,String(y)]);
context.window.openChicagoDistribution = (m,y) => distributionCalls.push([m.id,String(y)]);
vm.createContext(context);
vm.runInContext(fs.readFileSync("html/measures.js", "utf8"), context);
const city = JSON.parse(fs.readFileSync("html/data/web/chicago_city_statistics.json", "utf8"));
for(const row of city) Object.assign(row, JSON.parse(fs.readFileSync(`html/data/web/chicago_city_model_measures_${row.acs_end_year}.json`, "utf8"))[0]);
context.cityRows = city;
const source = fs.readFileSync("html/city-stats.js", "utf8");
vm.runInContext(source.slice(source.indexOf("  const allMeasures"), source.indexOf("  const revealedCharts")) +
  '\nrows=cityRows; globalThis.setYear=year=>{ selectedYear=String(year);renderTabs();renderCards(); };', context);
for(const year of [2014,2019,2024]) {
  context.setYear(year);
  assert.equal(elements["city-tabs"].children.length,8);
  for(const group of Object.keys(context.window.ChicagoMeasureGroups)) {
    const tab = elements[`city-tab-${group}`];
    assert.equal(tab.disabled,false);
    tab.click();
    assert.equal(elements["city-group-panel"].attrs["aria-labelledby"],tab.id);
    const measures = context.window.ChicagoMeasures.filter(m=>m.group===group);
    const cards = elements["city-cards"].children;
    assert.equal(cards.length,measures.length);
    measures.forEach((measure,i) => {
      const title = cards[i].children[0].textContent;
      assert.equal(title,context.window.chicagoMeasureForYear(measure,year).label);
      const actions = cards[i].children.find(child=>child.className==="stat-card-actions");
      const action = actions.children.find(child=>child.className==="stat-card-action");
      assert.ok(actions.children.some(child=>child.className==="stat-distribution-action"));
      assert.equal(Boolean(action),measure.comparison!==false);
      if(action) { action.click(); assert.deepEqual(comparisonCalls.at(-1),[measure.id,String(year)]); }
      actions.children.find(child=>child.className==="stat-distribution-action").click();
      assert.deepEqual(distributionCalls.at(-1),[measure.id,String(year)]);
    });
  }
}
elements["city-tab-crime"].listeners.keydown({key:"Home",preventDefault(){}});
assert.equal(elements["city-tab-rent"].attrs["aria-selected"],"true");
elements["city-tab-rent"].listeners.keydown({key:"ArrowRight",preventDefault(){}});
assert.equal(elements["city-tab-tenure"].attrs["aria-selected"],"true");
console.log("PASS: all 8 tabs and 26 cards in each period, labels, peer actions and keyboard navigation");
