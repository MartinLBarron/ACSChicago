# Presentation helpers; estimation is performed upstream, never inside the report.
bg_table <- function(x, digits = 3, caption = NULL) {
  knitr::kable(x, digits = digits, caption = caption, row.names = FALSE, format = "html")
}
bg_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", color = "#18354a"),
      axis.title = ggplot2::element_text(color = "#18354a"),
      plot.caption = ggplot2::element_text(hjust = 0, size = 9),
      strip.text = ggplot2::element_text(face = "bold"))
}
bg_coef_plot <- function(r, models = c("M1", "M2", "M3", "M4")) {
  x <- r$coefficients[r$coefficients$model %in% models & r$coefficients$term %in% bg_predictors, ]
  x$label <- factor(x$label, levels = rev(unname(bg_term_labels[bg_predictors])))
  ggplot2::ggplot(x, ggplot2::aes(x = percent_estimate, y = label, color = model)) +
    ggplot2::geom_vline(xintercept = 0, color = "grey70") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = percent_hc3_conf_low, xmax = percent_hc3_conf_high),
      orientation = "y", width = .25, position = ggplot2::position_dodge(width = .65)) +
    ggplot2::geom_point(position = ggplot2::position_dodge(width = .65), size = 2) +
    ggplot2::scale_color_manual(values = c(M1 = "#af7146", M2 = "#278f9b", M3 = "#18354a", M4 = "#80648f")) +
    ggplot2::labs(x = "Conditional difference in median contract rent (%)", y = NULL,
      color = "Model", caption = "Points: 100 × [exp(coefficient × increment) − 1]. Intervals: 95% HC3.\nIncome increment = 10%; share increment = 10 percentage points. Associations are ecological.") + bg_theme()
}
bg_map <- function(r, variable, title, diverging = FALSE) {
  geometry <- r$spatial$geometry
  geometry$value <- variable
  p <- ggplot2::ggplot(geometry) + ggplot2::geom_sf(ggplot2::aes(fill = value), color = NA) +
    ggplot2::coord_sf(datum = NA) + ggplot2::labs(title = title, fill = NULL) + bg_theme() +
    ggplot2::theme(axis.text = ggplot2::element_blank(), axis.title = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank())
  if (diverging) p + ggplot2::scale_fill_gradient2(low = "#287da0", mid = "#f5f1e7", high = "#bb453c", midpoint = 0)
  else p + ggplot2::scale_fill_viridis_c(option = "C")
}
