"use strict";
// A one-variable contrast in the fitted log-linear model, not a causal effect.
window.ChicagoModelEffects = {
  contrast(variable, coefficient, value) {
    const delta = variable.unit === "dollars"
      ? Math.log(value / variable.median)
      : (value - variable.median) / (variable.unit === "count" ? 1 : 10);
    const bounds = [coefficient.hc3_conf_low, coefficient.hc3_conf_high]
      .map(beta => 100 * Math.expm1(beta * delta)).sort((a, b) => a - b);
    return { value, estimate: 100 * Math.expm1(coefficient.estimate * delta), low: bounds[0], high: bounds[1] };
  }
};
