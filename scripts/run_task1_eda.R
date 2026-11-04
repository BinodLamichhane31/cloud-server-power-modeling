# =============================================================================
# run_task1_eda.R
# Coursework: STW7089CEM Introduction to Statistical Methods for Data Science
# Task 1: Preliminary Data Analysis (Complete End-to-End Execution Pipeline)
#
# Sections:
#   1. Data Ingestion & Quality Audit
#   2. Time Series Profiling (Full & Zoomed)
#   3. Temporal Autocorrelation & Stationarity (ACF, PACF, Ljung-Box, Trends)
#   4. Distributional Analysis & Nonparametric Moments (Histograms, KDE, Boxplots)
#   5. Bivariate Dependencies & Multicollinearity (Pearson, Spearman, VIF, Scatter Matrix)
#   6. Baseline Multiple Linear Regression Model & Nonlinear Necessity Proof
#
# Generated Deliverables:
#   Outputs: data/processed/server_data_clean.csv
#   Tables:  outputs/tables/table1_data_audit.csv
#            outputs/tables/table1_variable_dictionary.csv
#            outputs/tables/table1_temporal_tests.csv
#            outputs/tables/table1_descriptive_statistics.csv
#            outputs/tables/table1_correlations_pearson.csv
#            outputs/tables/table1_correlations_spearman.csv
#            outputs/tables/table1_vif.csv
#            outputs/tables/table1_baseline_linear_model.csv
#   Figures: outputs/figures/fig1_timeseries_telemetry.png
#            outputs/figures/fig1b_timeseries_zoom.png
#            outputs/figures/fig2_acf_pacf.png
#            outputs/figures/fig3_signal_distributions.png
#            outputs/figures/fig3b_signal_boxplots.png
#            outputs/figures/fig4_correlation_matrix.png
#            outputs/figures/fig5_scatter_matrix.png
#            outputs/figures/fig6_baseline_linear_residuals.png
# =============================================================================

local({
  root <- if (file.exists("R/00_utils_io.R")) "." else ".."
  for (f in c("00_utils_io.R", "06_theme_apa7.R", "01_eda_functions.R")) {
    source(file.path(root, "R", f))
  }
}, envir = globalenv())

paths <- project_paths()
dir.create(paths$tables, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$figures, showWarnings = FALSE, recursive = TRUE)

cat("=============================================================================\n")
cat("TASK 1: PRELIMINARY DATA ANALYSIS PIPELINE\n")
cat("=============================================================================\n\n")

# -----------------------------------------------------------------------------
# 1. Data Ingestion & Quality Audit
# -----------------------------------------------------------------------------
cat("--- Step 1: Data Ingestion & Quality Audit ---\n")
raw    <- load_raw_data(paths$raw)
merged <- validate_and_merge(raw)
df     <- merged$data

save_processed(df, paths$processed)
write.csv(merged$audit, file.path(paths$tables, "table1_data_audit.csv"), row.names = FALSE)
write.csv(variable_dictionary(), file.path(paths$tables, "table1_variable_dictionary.csv"), row.names = FALSE)

print(merged$audit, right = FALSE, row.names = FALSE)

N  <- nrow(df)
dt <- stats::median(diff(df$time))
fs <- 1 / dt

# -----------------------------------------------------------------------------
# 2. Time Series Profiling (Full and Zoomed)
# -----------------------------------------------------------------------------
cat("\n--- Step 2: Time Series Profiling ---\n")
window <- 100  # 100 samples = 10 s at 10 Hz

fig1 <- plot_timeseries(df, window = window, fs = fs)
save_apa_figure(fig1, "fig1_timeseries_telemetry.png", paths$figures, width = 6.5, height = 8)

fig1b <- plot_timeseries_zoom(df, t_max = 20)
save_apa_figure(fig1b, "fig1b_timeseries_zoom.png", paths$figures, width = 6.5, height = 7)
cat("Saved: fig1_timeseries_telemetry.png and fig1b_timeseries_zoom.png\n")

# -----------------------------------------------------------------------------
# 3. Temporal Autocorrelation & Stationarity Diagnostics
# -----------------------------------------------------------------------------
cat("\n--- Step 3: Temporal Autocorrelation & Stationarity Tests ---\n")
lag_max <- 40  # 4 seconds of history
acf_df  <- acf_pacf_table(df, lag_max = lag_max)
fig2    <- plot_acf_pacf(acf_df, n = N, fs = fs)
save_apa_figure(fig2, "fig2_acf_pacf.png", paths$figures, width = 6.5, height = 7.5)

tt <- temporal_tests(df, n_blocks = 10, lag_max = lag_max)
write.csv(tt, file.path(paths$tables, "table1_temporal_tests.csv"), row.names = FALSE)

fmt_p <- function(p) ifelse(p < .001, "< .001", sub("^0", "", formatC(p, digits = 3, format = "f")))
tt_view <- data.frame(
  Signal        = tt$label,
  `max|r(k)|`   = sprintf("%.3f (k=%d)", tt$max_abs_acf, tt$max_abs_acf_lag),
  `ACF > 95%`   = sprintf("%d/%d", tt$acf_exceed, tt$acf_lags_tested),
  `pHolm(Q10)`  = fmt_p(tt$ljung_box_p10_holm),
  `pHolm(Q20)`  = fmt_p(tt$ljung_box_p20_holm),
  `rho(trend)`  = sprintf("%.3f", tt$spearman_rho),
  `pHolm(rho)`  = fmt_p(tt$spearman_p_holm),
  `drift %`     = sprintf("%.1f", tt$trend_pct_of_mean_over_record),
  `pHolm(KW)`   = fmt_p(tt$kruskal_p_holm),
  `pHolm(FK)`   = fmt_p(tt$fligner_p_holm),
  check.names = FALSE
)
print(tt_view, right = FALSE, row.names = FALSE)
cat("Saved: fig2_acf_pacf.png and table1_temporal_tests.csv\n")

# -----------------------------------------------------------------------------
# 4. Distributional Analysis & Nonparametric Moments
# -----------------------------------------------------------------------------
cat("\n--- Step 4: Distributional Moments & Nonparametric Diagnostics ---\n")
summary_stats <- compute_summary_statistics(df)
write.csv(summary_stats, file.path(paths$tables, "table1_descriptive_statistics.csv"), row.names = FALSE)

apa_table1 <- format_apa_table1(summary_stats)
print(apa_table1, right = FALSE, row.names = FALSE)

dist_tests <- test_distribution_families(df)
write.csv(dist_tests, file.path(paths$tables, "table1_distribution_fit_tests.csv"), row.names = FALSE)
cat("\nInferred Theoretical Distribution Families & Goodness-of-Fit Tests:\n")
print(data.frame(
  Variable  = dist_tests$Variable,
  Family    = dist_tests$Inferred_Family,
  `KS Stat` = sprintf("%.4f", dist_tests$KS_Statistic_D),
  `KS p`    = sprintf("%.4f", dist_tests$KS_p_value),
  `Gauss p` = sprintf("%.4f", dist_tests$Gaussian_KS_p),
  Fit       = dist_tests$Goodness_of_Fit,
  check.names = FALSE
), right = FALSE, row.names = FALSE)

fig3 <- plot_distributions(df)
save_apa_figure(fig3, "fig3_signal_distributions.png", paths$figures, width = 6.5, height = 7.5)

fig3b <- plot_boxplots(df)
save_apa_figure(fig3b, "fig3b_signal_boxplots.png", paths$figures, width = 6.5, height = 3.5)
cat("Saved: fig3_signal_distributions.png, fig3b_signal_boxplots.png, table1_descriptive_statistics.csv, and table1_distribution_fit_tests.csv\n")

# -----------------------------------------------------------------------------
# 5. Bivariate Dependencies & Multicollinearity (VIF)
# -----------------------------------------------------------------------------
cat("\n--- Step 5: Bivariate Dependencies & Multicollinearity (VIF) ---\n")
cor_res <- compute_correlation_matrices(df)
write.csv(cor_res$pearson_r, file.path(paths$tables, "table1_correlations_pearson.csv"))
write.csv(cor_res$spearman_r, file.path(paths$tables, "table1_correlations_spearman.csv"))

fig4 <- plot_correlation_matrix(cor_res)
save_apa_figure(fig4, "fig4_correlation_matrix.png", paths$figures, width = 6.5, height = 4)

fig5 <- plot_scatter_matrix(df)
save_apa_figure(fig5, "fig5_scatter_matrix.png", paths$figures, width = 6.5, height = 6)

vif_df <- compute_vif(df)
write.csv(vif_df, file.path(paths$tables, "table1_vif.csv"), row.names = FALSE)
cat("Variance Inflation Factors (VIF):\n")
print(data.frame(
  Variable = vif_df$Label,
  R2       = sprintf("%.5f", vif_df$R2_with_others),
  VIF      = sprintf("%.3f", vif_df$VIF)
), right = FALSE, row.names = FALSE)
cat("Saved: fig4_correlation_matrix.png, fig5_scatter_matrix.png, table1_vif.csv, and correlation matrices\n")

# -----------------------------------------------------------------------------
# 6. Baseline Multiple Linear Regression Model & Nonlinear Justification
# -----------------------------------------------------------------------------
cat("\n--- Step 6: Baseline Multiple Linear Regression Model ---\n")
baseline <- fit_baseline_linear_model(df)
write.csv(baseline$coefficients, file.path(paths$tables, "table1_baseline_linear_model.csv"), row.names = FALSE)

cat("Baseline Model Parameter Estimates (APA 7 format):\n")
base_view <- data.frame(
  Term      = baseline$coefficients$Term,
  Estimate  = sprintf("%.3f", baseline$coefficients$Estimate),
  SE        = sprintf("%.3f", baseline$coefficients$StdError),
  t         = sprintf("%.3f", baseline$coefficients$t_value),
  p         = fmt_p(baseline$coefficients$p_value),
  `95% CI`  = sprintf("[%.3f, %.3f]", baseline$coefficients$CI_lower, baseline$coefficients$CI_upper),
  check.names = FALSE
)
print(base_view, right = FALSE, row.names = FALSE)

cat(sprintf("\nGoodness-of-Fit: R2 = %.4f, Adj R2 = %.4f, RMSE = %.3f, F(4, 9995) = %.1f, p < .001\n",
            baseline$metrics$R2, baseline$metrics$Adj_R2, baseline$metrics$RMSE, baseline$metrics$F_Statistic))

fig6 <- plot_baseline_residuals(baseline, df)
save_apa_figure(fig6, "fig6_baseline_linear_residuals.png", paths$figures, width = 6.5, height = 6)
cat("Saved: fig6_baseline_linear_residuals.png and table1_baseline_linear_model.csv\n")

cat("\n=============================================================================\n")
cat("TASK 1 EXECUTION COMPLETE: All figures & tables generated in outputs/\n")
cat("=============================================================================\n")
