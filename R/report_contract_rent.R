# Report the completed first model comparison. Called by model_contract_rent.R.
puma <- contrasts$table
write_rent_model_plots <- function() {
  # Let Cairo write its font cache beneath the generated local output directory.
  cache_dir <- file.path(config$output_dir, ".cache")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  previous_cache <- Sys.getenv("XDG_CACHE_HOME", unset = NA_character_)
  Sys.setenv(XDG_CACHE_HOME = normalizePath(cache_dir))
  on.exit({
    if (is.na(previous_cache)) Sys.unsetenv("XDG_CACHE_HOME") else
      Sys.setenv(XDG_CACHE_HOME = previous_cache)
  }, add = TRUE)
  png_type <- if (capabilities("cairo")) "cairo" else getOption("bitmapType")
  grDevices::png(file.path(config$output_dir, "adjusted_puma_effects.png"),
    width = 2100, height = 1450, res = 180, type = png_type)
  par(mar = c(5, 27, 5, 2), family = "sans", fg = "#243b32", col.axis = "#243b32")
  plot_data <- puma[order(puma$percent_difference), ]
  labels <- paste(substr(plot_data$puma_geoid, 3, 7),
    gsub(" PUMA$", "", sub("^Chicago City ", "", plot_data$puma_name)))
  limits <- range(c(plot_data$percent_conf_low, plot_data$percent_conf_high))
  plot(plot_data$percent_difference, seq_len(nrow(plot_data)),
    xlim = limits, ylim = c(0.5, nrow(plot_data) + 0.5), yaxt = "n", pch = 19,
    col = "#2b6550", xlab = "Adjusted difference in fitted geometric rent (%)", ylab = "")
  abline(v = 0, lty = 2, col = "#8a948e")
  segments(plot_data$percent_conf_low, seq_len(nrow(plot_data)),
           plot_data$percent_conf_high, seq_len(nrow(plot_data)), col = "#2b6550", lwd = 1.8)
  points(plot_data$percent_difference, seq_len(nrow(plot_data)), pch = 19, col = "#2b6550")
  axis(2, at = seq_len(nrow(plot_data)), labels = labels, las = 1, tick = FALSE, cex.axis = 0.65)
  title(main = "Adjusted rent differences across Chicago PUMAs", line = 2, adj = 0, cex.main = 1.1)
  mtext("Housing-weighted PUMA benchmark = 0 · 95% pointwise replicate-weight intervals", side = 3, line = 0.6, adj = 0, cex = 0.8)
  if (SYNTHETIC_DATA) mtext("SYNTHETIC DATA", side = 1, line = 4, col = "red")
  grDevices::dev.off()
  
  grDevices::png(file.path(config$output_dir, "residual_diagnostics.png"),
    width = 1600, height = 720, res = 150, type = png_type)
  par(mfrow = c(1, 2), mar = c(5, 5, 4, 1), family = "sans", fg = "#243b32", col.axis = "#243b32")
  plot(bins$fitted_log_rent, bins$mean_log_residual, type = "b", pch = 19, col = "#2b6550",
    xlab = "Fitted log monthly rent", ylab = "Weighted mean log residual",
    main = "Residual pattern", ylim = range(c(0, bins$mean_log_residual)))
  abline(h = 0, lty = 2, col = "#8a948e")
  plot(bins$fitted_log_rent, bins$rmse_log, type = "b", pch = 19, col = "#b44d3f",
    xlab = "Fitted log monthly rent", ylab = "Weighted residual RMSE (log units)",
    main = "Residual spread")
  if (SYNTHETIC_DATA) mtext("SYNTHETIC DATA", side = 1, line = 4, col = "red")
  grDevices::dev.off()
}
write_rent_model_plots()

percent <- function(value) sprintf("%.1f%%", 100 * value)
number <- function(value) format(value, big.mark = ",", trim = TRUE, scientific = FALSE)
flow <- prepared$waterfall
final_coefficients <- coefficient_table(full, "housing_puma", config$confidence)
continuous <- final_coefficients[final_coefficients$term %in% c("bedrooms", "rooms", "household_size"), ]
lines <- c(
  "# First contract-rent models: ACS 2020–2024", "",
  if (SYNTHETIC_DATA) "**SYNTHETIC DATA**" else "Official ACS PUMS observations; descriptive associations.", "",
  sprintf("The common model sample contains **%s cash-rent housing units across 18 retained PUMAs**.", number(nrow(sample))),
  "The dependent variable is log monthly contract rent, adjusted once to 2024 dollars using ADJHSG.",
  "Both models use housing-unit weights. Uncertainty uses all 80 ACS housing replicate weights, SDR scaling 4/80, MSE centering, and model-specific residual degrees of freedom. Intervals are 95%.", "",
  "## How much does PUMA location add?", "",
  sprintf("Adding PUMA indicators raises housing-weighted, in-sample log-rent R² from **%s to %s** (a **%.1f percentage-point** increase).",
          percent(reduced$r_squared), percent(expanded$r_squared), 100 * point[["delta_r_squared"]]),
  sprintf("This is **%s of the residual weighted variation** left after the housing/household controls (partial R²).",
          percent(point[["partial_r_squared_puma"]])),
  "This is incremental descriptive fit, not a causal fraction of rent explained by neighborhoods or a random-effects ICC. See puma_incremental_fit.csv for replicate-weight standard errors and intervals.",
  sprintf("Joint design-based PUMA Wald test: F(%s, %s) = %.2f; p %s.", test$df, test$ddf,
          unname(test$Ftest), if (test$p < 0.001) "< 0.001" else paste0("= ", format.pval(test$p, digits = 3))), "",
  "| Model | Sample units | Weighted log-rent R² | Weighted RMSE (log units) | Parameters | Residual df |",
  "|---|---:|---:|---:|---:|---:|",
  vapply(seq_len(nrow(fit_table)), function(i) sprintf("| %s | %s | %s | %.3f | %s | %s |",
    fit_table$model[i], number(fit_table$sample_units[i]), percent(fit_table$r_squared[i]),
    fit_table$rmse_log[i], fit_table$parameters[i], fit_table$residual_df[i]), character(1)), "",
  "## Adjusted PUMA differences", "",
  "Each contrast is centered on the housing-weighted average PUMA component among model-sample cash-rent units. Intervals are pointwise, not adjusted for multiple comparisons. Centering is repeated using each replicate's weights and coefficients. Housing characteristics and household size are held constant; exponentiation describes fitted geometric-rent ratios, not arithmetic mean rents.", "",
  "![Adjusted PUMA contrasts with 95% intervals](adjusted_puma_effects.png)", "",
  "| PUMA | Adjusted difference | 95% interval | Sample units |", "|---|---:|---:|---:|",
  vapply(order(puma$percent_difference, decreasing = TRUE), function(i) sprintf("| %s | %+.1f%% | %+.1f%% to %+.1f%% | %s |",
    puma$puma_name[i], puma$percent_difference[i], puma$percent_conf_low[i],
    puma$percent_conf_high[i], number(puma$sample_units[i])), character(1)), "",
  "## Controls and interpretation", "",
  "Bedrooms, total rooms, and household size enter linearly. Building size and construction-year categories enter as unordered factors; the most housing-weighted common categories are references. Both models use the exact same sample. No interactions, automatic variable selection, trimming, or rent-allocation exclusions are applied.",
  sprintf("Reference building size: %s. Reference construction year: %s.",
    prepared$references$building_size, prepared$references$year_built), "",
  "| Full-model control | Adjusted difference per additional unit | 95% interval |",
  "|---|---:|---:|",
  vapply(seq_len(nrow(continuous)), function(i) sprintf("| %s | %+.1f%% | %+.1f%% to %+.1f%% |",
    continuous$term[i], continuous$percent_estimate[i], continuous$percent_conf_low[i],
    continuous$percent_conf_high[i]), character(1)),
  "Bedrooms and total rooms are strongly related; the bedroom coefficient holds total rooms fixed. Interpret these conditional associations together. Full coefficient estimates are in coefficients.csv.", "",
  "## Sample accounting", "", "| Stage | Remaining units | Excluded at this stage |", "|---|---:|---:|",
  vapply(seq_len(nrow(flow)), function(i) sprintf("| %s | %s | %s |", flow$stage[i],
    number(flow$remaining[i]), number(flow$excluded_at_stage[i])), character(1)), "",
  "The original prepared housing dataset still contains vacant, owner, and no-cash-rent units. Only the new model sample is restricted. Allocation/imputation flags are retained and reported in model_diagnostics.csv.", "",
  "## Diagnostics and limits", "",
  "![Weighted residual diagnostics by fitted-rent bins](residual_diagnostics.png)", "",
  "Residual patterns can reveal nonlinearity or omitted controls; changing residual spread can indicate heteroskedasticity. Replicate-weight inference does not cure misspecification. These are first baseline models, not validated predictions.",
  sprintf("%s building/year categories contain fewer than 30 sample units; see category_counts.csv. Sparse categories can have unstable coefficients even when the model is full rank.", sum(category_counts$sparse_under_30)),
  sprintf("The largest weighted leverage is %.3f. This flags a potentially influential observation; sparse-category estimates warrant sensitivity checks before the model is treated as a finished research result.", diagnostic_summary$max_leverage),
  "PUMAs are broad areas, not the 77 community areas. Results apply to the selected PUMAs and cash-rent sample; some Chicago territory is excluded and some retained areas extend beyond city limits. Missing attributes, subsidized housing, lease characteristics, PUMS top coding/allocation, and the crosswalked 2020–2021 PUMA assignments may affect interpretation. Household income and additional neighborhood controls are not yet included.",
  "Neither the PUMA indicators nor differences in fit identify a causal neighborhood effect. All fit measures are in-sample and on the log-rent scale.", "",
  "## Reproduce", "", "```sh", "Rscript R/model_contract_rent.R", "Rscript R/check_rent_model.R", "```", "",
  "Rerun the modeling step to confirm reproducibility. Microdata, model objects, sample audits, and results remain local; nothing is exported to the website.", "",
  "Methods: [Census PUMS user guide](https://www2.census.gov/programs-surveys/acs/tech_docs/pums/2020_2024ACS_PUMS_User_Guide.pdf), [survey replicate designs](https://r-survey.r-forge.r-project.org/pkgdown/docs/reference/svrepdesign.html), [survey regression](https://r-survey.r-forge.r-project.org/pkgdown/docs/reference/svyglm.html)."
)
writeLines(lines, file.path(config$output_dir, "report.md"))
