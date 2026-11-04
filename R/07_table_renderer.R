# =============================================================================
# Publication-Grade APA 7 Table Image Rendering Engine
# Module: STW7089CEM Introduction to Statistical Methods for Data Science
# =============================================================================

suppressPackageStartupMessages({
  library(gridExtra)
  library(grid)
  library(gtable)
})

#' Render a publication-grade APA 7 styled table as a high-resolution PNG image
#'
#' @param df Data frame containing the table body
#' @param table_num String, e.g. "Table 1"
#' @param title String, table title
#' @param note String, explanatory note below the table
#' @param out_file Character, target PNG file path
#' @param width_in Numeric, figure width in inches (default 8.5)
#' @param font_size Numeric, base font size in pt (default 9.5)
#' @param col_align Character vector of alignments ("left", "right", "center")
render_apa_table_png <- function(df, table_num, title, note, out_file,
                                 width_in = 8.5, font_size = 9.5,
                                 col_align = NULL) {
  df_chr <- as.data.frame(lapply(df, as.character), stringsAsFactors = FALSE)
  n_rows <- nrow(df_chr)
  n_cols <- ncol(df_chr)
  
  if (is.null(col_align)) {
    # Default: first column left, rest right if numeric-like, else left
    col_align <- sapply(df, function(col) {
      if (is.numeric(col)) "right" else "left"
    })
    col_align[1] <- "left"
  }
  
  # Map alignment to hjust and x positions
  hjust_vec <- ifelse(col_align == "right", 1, ifelse(col_align == "center", 0.5, 0))
  x_pos_vec <- ifelse(col_align == "right", 0.95, ifelse(col_align == "center", 0.5, 0.05))
  
  # Format cell theme
  tt <- ttheme_default(
    base_size = font_size,
    base_family = "sans",
    padding = unit(c(4.5, 5.0), "mm"),
    core = list(
      fg_params = list(
        hjust = rep(hjust_vec, each = n_rows),
        x = rep(x_pos_vec, each = n_rows),
        fontsize = font_size,
        col = "#1a1a1a"
      ),
      bg_params = list(fill = c("#ffffff", "#f8f9fa"))
    ),
    colhead = list(
      fg_params = list(
        hjust = hjust_vec,
        x = x_pos_vec,
        fontface = "bold",
        fontsize = font_size + 0.5,
        col = "#111111"
      ),
      bg_params = list(fill = "#ffffff")
    )
  )
  
  tg <- tableGrob(df_chr, rows = NULL, theme = tt)
  
  # Add horizontal borders (APA 7 rules: no vertical borders)
  # Top border (heavy rule above header)
  tg <- gtable_add_grob(
    tg,
    grobs = segmentsGrob(x0 = unit(0, "npc"), y0 = unit(1, "npc"),
                         x1 = unit(1, "npc"), y1 = unit(1, "npc"),
                         gp = gpar(lwd = 2.2, col = "#111111")),
    t = 1, l = 1, r = n_cols
  )
  # Mid-rule (horizontal rule below header)
  tg <- gtable_add_grob(
    tg,
    grobs = segmentsGrob(x0 = unit(0, "npc"), y0 = unit(0, "npc"),
                         x1 = unit(1, "npc"), y1 = unit(0, "npc"),
                         gp = gpar(lwd = 1.0, col = "#222222")),
    t = 1, l = 1, r = n_cols
  )
  # Bottom border (heavy rule below table body)
  tg <- gtable_add_grob(
    tg,
    grobs = segmentsGrob(x0 = unit(0, "npc"), y0 = unit(0, "npc"),
                         x1 = unit(1, "npc"), y1 = unit(0, "npc"),
                         gp = gpar(lwd = 2.2, col = "#111111")),
    t = nrow(tg), l = 1, r = n_cols
  )
  
  # Title grobs
  title_grob1 <- textGrob(table_num, x = 0.015, just = "left",
                          gp = gpar(fontface = "bold", fontsize = font_size + 2.5, col = "#111111"))
  title_grob2 <- textGrob(title, x = 0.015, just = "left",
                          gp = gpar(fontface = "italic", fontsize = font_size + 1.2, col = "#222222"))
  
  # Note grob with line wrapping
  char_wrap_width <- floor(width_in * 13.5)
  wrapped_note <- paste(strwrap(note, width = char_wrap_width), collapse = "\n")
  note_lines <- length(strsplit(wrapped_note, "\n")[[1]])
  note_grob <- textGrob(wrapped_note, x = 0.015, just = c("left", "top"),
                        gp = gpar(fontface = "plain", fontsize = font_size - 1.0, col = "#333333"))
  
  # Estimate total canvas height
  row_height_in <- 0.28
  header_height_in <- 0.65
  note_height_in <- (note_lines * 0.20) + 0.15
  table_height_in <- (n_rows + 1) * row_height_in
  total_height_in <- header_height_in + table_height_in + note_height_in + 0.25
  
  # Render PNG
  png(out_file, width = width_in * 300, height = total_height_in * 300, res = 300)
  grid.newpage()
  
  pushViewport(viewport(layout = grid.layout(
    nrow = 5, ncol = 1,
    heights = unit(c(0.28, 0.28, table_height_in, 0.08, note_height_in), "inches")
  )))
  
  pushViewport(viewport(layout.pos.row = 1, layout.pos.col = 1))
  grid.draw(title_grob1)
  popViewport()
  
  pushViewport(viewport(layout.pos.row = 2, layout.pos.col = 1))
  grid.draw(title_grob2)
  popViewport()
  
  pushViewport(viewport(layout.pos.row = 3, layout.pos.col = 1))
  grid.draw(tg)
  popViewport()
  
  pushViewport(viewport(layout.pos.row = 5, layout.pos.col = 1))
  grid.draw(note_grob)
  popViewport()
  
  dev.off()
  invisible(out_file)
}
