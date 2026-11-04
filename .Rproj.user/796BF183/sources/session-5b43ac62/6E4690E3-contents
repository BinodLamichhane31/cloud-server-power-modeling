# =============================================================================
# 06_theme_apa7.R
# Shared ggplot2 styling following APA 7 figure guidance:
#   - white background, no gridlines, plain black axes
#   - sans-serif type, 8-14 pt equivalent when printed at page width
#   - figure number and title are NOT drawn inside the image; in APA 7 they
#     are placed above the figure in the report, with a Note below it
#   - grayscale-safe palette so figures remain legible when printed
# =============================================================================

suppressPackageStartupMessages(library(ggplot2))

#' APA 7 ggplot2 theme.
theme_apa7 <- function(base_size = 10, base_family = "") {
  theme_classic(base_size = base_size, base_family = base_family) +
    theme(
      axis.text         = element_text(colour = "black"),
      axis.title        = element_text(colour = "black"),
      axis.line         = element_line(colour = "black", linewidth = 0.4),
      axis.ticks        = element_line(colour = "black", linewidth = 0.4),
      strip.background  = element_blank(),
      strip.text        = element_text(face = "bold", hjust = 0,
                                       size = base_size),
      panel.spacing     = unit(0.8, "lines"),
      legend.position   = "bottom",
      legend.title      = element_blank(),
      legend.key        = element_blank(),
      plot.background   = element_rect(fill = "white", colour = NA),
      plot.margin       = margin(6, 10, 6, 6)
    )
}

#' Grayscale-safe palette (dark-to-light) used across all figures.
apa_colours <- list(
  raw       = "grey70",
  main      = "black",
  secondary = "grey35",
  bound     = "#1f4e79",   # muted blue for reference/critical bounds
  highlight = "#a33b20"    # muted red for exceedances / emphasis
)

#' Save a figure at 300 DPI on a white background.
#'
#' @param plot     ggplot / patchwork object
#' @param filename file name inside the figures directory
#' @param dir      output directory
#' @param width    width in inches (6.5 = full text width on A4 with
#'                 1-inch margins, as recommended for APA 7 papers)
#' @param height   height in inches
save_apa_figure <- function(plot, filename, dir, width = 6.5, height = 4.5,
                            dpi = 300) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(dir, filename)
  ggsave(path, plot = plot, width = width, height = height, units = "in",
         dpi = dpi, bg = "white")
  invisible(path)
}
