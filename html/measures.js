/* Shared definitions keep map legends, city cards, and D3 charts consistent. */
"use strict";
window.ChicagoMeasures = [
  { id: "median_contract_rent", label: "Median contract rent", unit: "per month", money: true, group: "core", color: "#2b6550", description: "Renter-occupied homes paying cash rent" },
  { id: "median_gross_rent", label: "Median gross rent", unit: "per month", money: true, group: "core", color: "#2b6550", description: "Includes renter-paid utilities and fuels" },
  { id: "cash_rent_units", label: "Occupied units paying cash rent", unit: "housing units", group: "core", color: "#986345", description: "Occupied rental homes with cash rent" },
  { id: "renter_occupied_units", label: "Renter-occupied units", unit: "housing units", group: "core", color: "#986345", description: "Includes homes occupied without cash rent" },
  { id: "rent_burden_30plus_pct", label: "Rent burden: 30% or more", percent: true, group: "burden", description: "Share of renters with computed rent/income ratios spending 30% or more of income on gross rent" },
  { id: "rent_burden_50plus_pct", label: "Rent burden: 50% or more", percent: true, group: "burden", description: "Share of renters with computed rent/income ratios spending 50% or more of income on gross rent" },
  { id: "rent_burden_not_computed_pct", label: "Rent/income ratio not computed", percent: true, group: "burden", description: "Share of all renter-occupied units without a computed rent/income ratio; excluded from burden percentages" },
  ...[["0", "Studio gross rent", "studio units"], ["1", "One-bedroom gross rent", "one-bedroom units"], ["2", "Two-bedroom gross rent", "two-bedroom units"], ["3", "Three-bedroom gross rent", "three-bedroom units"], ["4", "Four-bedroom gross rent", "four-bedroom units"], ["5plus", "Five-plus-bedroom gross rent", "units with five or more bedrooms"]].map(([code, label, description]) => ({
    id: `median_gross_rent_bedrooms_${code}`, label, money: true, unit: "per month", group: "bedrooms",
    description: `Published median gross rent for ${description} paying cash rent, including renter-paid utilities and fuels`
  })),
  { id: "utilities_included_pct", label: "No extra utility payment", percent: true, group: "utilities", description: "Share of all renter-occupied units paying no extra for any utilities" },
  { id: "utilities_extra_pct", label: "Extra utility payment", percent: true, group: "utilities", description: "Share of all renter-occupied units paying extra for one or more utilities" }
].map(measure => ({ unit: "percent of eligible units", color: "#2b6550", ...measure }));
window.ChicagoMeasureGroups = { core: "Rent and rental housing", burden: "Rent burden", bedrooms: "Rent by bedroom", utilities: "Utilities" };
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
  const statusLabels = { table_not_published: "Not published for this period: Census introduced this table in 2015", zero_denominator: "No eligible units in the estimated denominator", missing_source_estimate: "A source estimate is unavailable", numerator_exceeds_denominator: "Source counts do not form a valid percentage", missing_source_moe: "A source margin of error is unavailable" };
  for (const suffix of ["estimate_status", "moe_status", "source_status"]) {
    const text = statusLabels[row[`${measure.id}_${suffix}`]];
    if (text && !notes.includes(text)) notes.push(text);
  }
  return notes.join(". ");
};
