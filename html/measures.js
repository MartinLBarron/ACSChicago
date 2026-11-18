/* Shared definitions keep map legends, city cards, and D3 charts consistent. */
"use strict";
window.ChicagoMeasures = [
  { id: "median_contract_rent", label: "Median contract rent", unit: "per month", money: true, group: "core", color: "#2b6550", description: "Renter-occupied homes paying cash rent" },
  { id: "median_gross_rent", label: "Median gross rent", unit: "per month", money: true, group: "core", color: "#2b6550", description: "Includes renter-paid utilities and fuels" },
  { id: "cash_rent_units", label: "Occupied units paying cash rent", unit: "housing units", group: "core", color: "#986345", description: "Occupied rental homes with cash rent" },
  { id: "renter_occupied_units", label: "Renter-occupied units", unit: "housing units", group: "core", color: "#986345", description: "Includes homes occupied without cash rent" },
  { id: "rent_burden_50plus_pct", label: "Rent burden: 50% or more", percent: true, group: "burden", description: "Share of renters with computed rent/income ratios spending 50% or more of income on gross rent" }
].map(measure => ({ unit: "percent of eligible units", color: "#2b6550", ...measure }));
window.ChicagoMeasureGroups = { core: "Rent and rental housing", burden: "Rent burden" };
window.formatChicagoValue = (value, measure, isMoe = false) => {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return "Not available";
  if (measure.percent) return `${value.toLocaleString("en-US", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}${isMoe ? " pp" : "%"}`;
  return new Intl.NumberFormat("en-US", { ...(measure.money ? { style: "currency", currency: "USD" } : {}), maximumFractionDigits: 0 }).format(value);
};
window.chicagoValueNotes = (row, measure) => {
  const notes = ["estimate_annotation", "moe_annotation"].flatMap(suffix => {
    const annotation = row[`${measure.id}_${suffix}`];
    return annotation && annotation !== "null" ? [`${suffix === "estimate_annotation" ? "Estimate" : "MOE"} annotation: ${annotation}`] : [];
  });
  const statusLabels = { zero_denominator: "No eligible units in the estimated denominator", missing_source_estimate: "A source estimate is unavailable", numerator_exceeds_denominator: "Source counts do not form a valid percentage", missing_source_moe: "A source margin of error is unavailable" };
  for (const suffix of ["estimate_status", "moe_status", "source_status"]) {
    const text = statusLabels[row[`${measure.id}_${suffix}`]];
    if (text && !notes.includes(text)) notes.push(text);
  }
  return notes.join(". ");
};
