/* Shared definitions keep map legends, city cards, and D3 charts consistent. */
"use strict";
window.ChicagoMeasures = [
  { id: "median_contract_rent", label: "Median contract rent", unit: "per month", money: true, group: "core", color: "#2b6550", description: "Renter-occupied homes paying cash rent" },
  { id: "median_gross_rent", label: "Median gross rent", unit: "per month", money: true, group: "core", color: "#2b6550", description: "Includes renter-paid utilities and fuels" },
  { id: "cash_rent_units", label: "Occupied units paying cash rent", count: true, unit: "housing units", group: "core", color: "#986345", description: "Occupied rental homes with cash rent" },
  { id: "renter_occupied_units", label: "Renter-occupied units", count: true, unit: "housing units", group: "core", color: "#986345", description: "Includes homes occupied without cash rent" },
  { id: "renter_occupied_pct", label: "Renter-occupied share", unit: "percent of occupied homes", percent: true, group: "core", breaks: [20, 35, 50, 65, 80, 90], description: "Percentage of occupied homes that are rented; excludes vacant homes" },
  { id: "rent_burden_30plus_pct", label: "Rent burden: 30% or more", percent: true, group: "burden", description: "Share of renters with computed rent/income ratios spending 30% or more of income on gross rent" },
  { id: "rent_burden_50plus_pct", label: "Rent burden: 50% or more", percent: true, group: "burden", description: "Share of renters with computed rent/income ratios spending 50% or more of income on gross rent" }
  ,{ id: "small_bedrooms_pct", label: "Rentals: studio or one bedroom", description: "Share of renter-occupied units with a studio or one bedroom", breaks: [10,25,40,55,70,85] }
  ,{ id: "two_bedrooms_pct", label: "Rentals: two bedrooms", description: "Share of renter-occupied units with exactly two bedrooms" }
  ,{ id: "large_bedrooms_pct", label: "Rentals: three or more bedrooms", description: "Share of renter-occupied units with three or more bedrooms", breaks: [5,10,20,30,40,60] }
  ,{ id: "structure_1_unit_pct", label: "Rentals in one-unit buildings", description: "Share of renter-occupied units in one-unit buildings, including detached homes and attached homes such as row houses" }
  ,{ id: "structure_2_4_pct", label: "Rentals in 2–4-unit buildings", description: "Share of renter-occupied units in buildings with 2–4 units" }
  ,{ id: "structure_5_19_pct", label: "Rentals in 5–19-unit buildings", description: "Share of renter-occupied units in buildings with 5–19 units" }
  ,{ id: "structure_20_plus_pct", label: "Rentals in 20+-unit buildings", description: "Share of renter-occupied units in buildings with at least 20 units" }
  ,{ id: "pre1940_pct", label: "Rentals built before 1940", description: "Share of renter-occupied units in buildings constructed before 1940" }
  ,{ id: "built2000_plus_pct", label: "Rentals built in 2000 or later", description: "Share of renter-occupied units in buildings constructed in 2000 or later", breaks: [1,5,10,20,35,50] }
  ,{ id: "recent_movers_pct", label: "Recent renter move-ins", description: "Share of renter households whose householder moved into the unit during the period; not an annual turnover rate" }
  ,{ id: "young_renters_pct", label: "Renter householders under 35", description: "Share of renter-occupied households with a householder under age 35" }
  ,{ id: "older_renters_pct", label: "Renter householders age 65+", description: "Share of renter-occupied households with a householder age 65 or older", breaks: [5,10,15,25,40,60] }
  ,{ id: "poverty_pct", label: "Poverty rate", unit: "percent of people with poverty status determined", description: "Population below the poverty threshold divided by the population for whom poverty status is determined", breaks: [5,10,15,20,30,40] }
  ,{ id: "area_median_income", label: "Median household income", money: true, percent: false, unit: "per year", description: "Median annual income of all households, including owners and renters", breaks: [25000,50000,75000,100000,150000,200000] }
  ,{ id: "college_pct", label: "Adults with a bachelor’s degree or higher", unit: "percent of adults age 25+", description: "Share of adults age 25+ with at least a bachelor’s degree", breaks: [10,25,40,55,70,85] }
  ,{ id: "no_high_school_pct", label: "Adults without a high-school diploma or GED", unit: "percent of adults age 25+", description: "Share of adults age 25+ without a high-school diploma or GED", breaks: [2,5,10,15,25,40] }
  ,{ id: "total_population", label: "Total population", count: true, percent: false, unit: "residents", description: "Estimated number of residents of all ages in the selected geography", breaks: [1,500,1000,1500,2000,3000], tractBreaks: [1,1000,2500,4000,5500,7500] }
  ,{ id: "nh_black_pct", label: "Non-Hispanic Black population share", unit: "percent of residents", description: "Share of the total population identifying as Black alone and not Hispanic or Latino", breaks: [5,15,30,50,70,90] }
  ,{ id: "hispanic_pct", label: "Hispanic/Latino population share", unit: "percent of residents", description: "Share of the total population identifying as Hispanic or Latino, of any race", breaks: [5,15,30,50,70,90] }
  ,{ id: "violent_crime_count", comparison: false, label: "Recorded violent crime", administrative: true, percent: false, count: true, unit: "recorded crimes over five years", description: "Count of selected violent crimes recorded by CPD; map excludes unusable coordinates, citywide total includes them", breaks: [1,10,25,50,100,250], tractBreaks: [1,25,75,150,300,600], color: "#986345" }
 ].map((measure,index) => ({ unit: "percent of eligible units", color: "#2b6550",
  ...(index >= 7 ? { supplemental: true, comparison: true, percent: true, group: "model", unit: "percent of renter-occupied homes" } : {}), ...measure }));
window.ChicagoMeasureGroups = {
  rent: "Rent and affordability",
  tenure: "Rental stock and tenure",
  housing: "Housing characteristics",
  renters: "Renter profile",
  economics: "Income and poverty",
  education: "Education",
  population: "Population, race and ethnicity",
  crime: "Violent crime"
};
const measureGroupMembers = {
  rent: ["median_contract_rent", "median_gross_rent", "rent_burden_30plus_pct", "rent_burden_50plus_pct"],
  tenure: ["cash_rent_units", "renter_occupied_units", "renter_occupied_pct"],
  housing: ["small_bedrooms_pct", "two_bedrooms_pct", "large_bedrooms_pct", "structure_1_unit_pct", "structure_2_4_pct", "structure_5_19_pct", "structure_20_plus_pct", "pre1940_pct", "built2000_plus_pct"],
  renters: ["recent_movers_pct", "young_renters_pct", "older_renters_pct"],
  economics: ["area_median_income", "poverty_pct"],
  education: ["college_pct", "no_high_school_pct"],
  population: ["total_population", "nh_black_pct", "hispanic_pct"],
  crime: ["violent_crime_count"]
};
for (const [group, ids] of Object.entries(measureGroupMembers)) {
  ids.forEach(id => { window.ChicagoMeasures.find(measure => measure.id === id).group = group; });
}
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
  const statusLabels = { zero_denominator: "No eligible population or units in the estimated denominator", missing_source_estimate: "A source estimate is unavailable", numerator_exceeds_denominator: "Source counts do not form a valid percentage", missing_source_moe: "A source margin of error is unavailable" };
  for (const suffix of ["estimate_status", "moe_status", "source_status"]) {
    const text = statusLabels[row[`${measure.id}_${suffix}`]];
    if (text && !notes.includes(text)) notes.push(text);
  }
  if (measure.administrative) notes.push("CPD recorded crimes, not an ACS estimate; no sampling MOE applies");
  return notes.join(". ");
};

// Period-specific definitions remain explicit in controls, cards and tooltips.
window.chicagoMeasureForYear = (measure, year) => {
  const start = Number(year) - 4;
  if (measure.id === "recent_movers_pct") return { ...measure,
    label: `Renters who moved in during ${start} or later`,
    description: `Share of renter households whose householder moved into the unit in ${start} or later; not an annual turnover rate` };
  if (measure.administrative) return { ...measure, label: `Recorded violent crime, ${start}–${year}` };
  return measure;
};
