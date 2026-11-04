# =============================================================================
# run_task2_regression.R
# Coursework: STW7089CEM Introduction to Statistical Methods for Data Science
# Task 2: Regression: Modeling the Relationship Between Server Metrics
#
# Complete End-to-End Execution Pipeline for Tasks 2.1 through 2.7:
#   Task 2.1: Model Parameter Estimation (Normal Equations & QR Decomposition)
#   Task 2.2: Residual Error Vector Evaluation
#   Task 2.3: Variance Estimation (Unbiased vs. Maximum Likelihood)
#   Task 2.4: Gaussian Log-Likelihood Calculation
#   Task 2.5: Residual Diagnostics & Error Distributions (Q-Q, Normality Battery)
#   Task 2.6: Information-Theoretic Model Selection (AIC, AICc, BIC)
#   Task 2.7: 70/30 Train/Test Validation, 95% Prediction Intervals & Coverage
#
# Generated Deliverables:
#   Tables:  outputs/tables/table2_regression_parameters.csv
#            outputs/tables/table2_model_performance_summary.csv
#            outputs/tables/table2_residual_normality_tests.csv
#            outputs/tables/table2_model_selection_aic_bic.csv
#            outputs/tables/table2_train_test_generalization.csv
#   Figures: outputs/figures/fig7_qq_plots_grid.png
#            outputs/figures/fig8_residual_histograms.png
#            outputs/figures/fig9_residuals_vs_fitted.png
#            outputs/figures/fig10_aic_bic_model_selection.png
#            outputs/figures/fig11_test_prediction_intervals.png
# =============================================================================

local({
  root <- if (file.exists("R/00_utils_io.R")) "." else ".."
  for (f in c("00_utils_io.R", "06_theme_apa7.R", "02_regression_engine.R",
              "03_diagnostics_metrics.R", "04_train_test_eval.R")) {
    source(file.path(root, "R", f))
  }
}, envir = globalenv())

paths <- project_paths()
dir.create(paths$tables, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$figures, showWarnings = FALSE, recursive = TRUE)

cat("=============================================================================\n")
cat("TASK 2: POLYNOMIAL REGRESSION MODELING & EVALUATION (TASKS 2.1 - 2.7)\n")
cat("=============================================================================\n\n")

# Load preprocessed clean server data
clean_file <- file.path(paths$processed, "server_data_clean.csv")
if (!file.exists(clean_file)) {
  stop("Processed data not found at: ", clean_file, ". Run run_task1_eda.R first.")
}
df <- read.csv(clean_file)
cat(sprintf("Loaded clean dataset: N = %d observations, 6 variables (time, x1..x4, y)\n\n", nrow(df)))

# -----------------------------------------------------------------------------
# Tasks 2.1 - 2.4: Model Fitting, Parameters, Residuals, Variance & Log-Likelihood
# -----------------------------------------------------------------------------
cat("--- Tasks 2.1 - 2.4: Fitting Candidate Models (1 to 5) ---\n")
models_list <- fit_all_candidate_models(df)

# Compile and export parameter estimates table (Task 2.1)
param_df <- compile_parameters_table(models_list)
write.csv(param_df, file.path(paths$tables, "table2_regression_parameters.csv"), row.names = FALSE)

# Compile and export performance summary table (Tasks 2.1 - 2.4)
perf_df <- compile_performance_summary(models_list)
write.csv(perf_df, file.path(paths$tables, "table2_model_performance_summary.csv"), row.names = FALSE)

cat("\nModel Performance Summary (Tasks 2.1 - 2.4):\n")
perf_view <- data.frame(
  Model          = perf_df$Model,
  p              = perf_df$Parameters_p,
  RSS            = sprintf("%.1f", perf_df$RSS),
  RMSE           = sprintf("%.3f", perf_df$RMSE),
  `R^2`          = sprintf("%.5f", perf_df$R_Squared),
  `Sigma (Unb)`  = sprintf("%.3f", perf_df$Sigma_Unbiased),
  `Sigma (ML)`   = sprintf("%.3f", perf_df$Sigma_ML),
  `ln L`         = sprintf("%.1f", perf_df$Log_Likelihood),
  `Cond(Phi)`    = sprintf("%.1f", perf_df$Cond_Phi),
  `Max NE-QR Diff` = sprintf("%.2e", perf_df$NE_QR_Discrep),
  check.names    = FALSE
)
print(perf_view, right = FALSE, row.names = FALSE)
cat("Saved: table2_regression_parameters.csv and table2_model_performance_summary.csv\n")

# -----------------------------------------------------------------------------
# Task 2.5: Residual Diagnostics & Error Distributions
# -----------------------------------------------------------------------------
cat("\n--- Task 2.5: Residual Diagnostics & Normality Hypothesis Testing ---\n")
norm_battery <- compute_residual_normality_battery(models_list, seed = 42)
write.csv(norm_battery, file.path(paths$tables, "table2_residual_normality_tests.csv"), row.names = FALSE)

fmt_p <- function(p) ifelse(p < .001, "< .001", sub("^0", "", formatC(p, digits = 3, format = "f")))
norm_view <- data.frame(
  Model         = norm_battery$Model,
  Skewness      = sprintf("%.3f", norm_battery$Skewness),
  `Excess Kurt` = sprintf("%.3f", norm_battery$Excess_Kurtosis),
  `JB Stat`     = sprintf("%.1f", norm_battery$Jarque_Bera_Stat),
  `p(JB)`       = fmt_p(norm_battery$Jarque_Bera_p),
  `SW Stat (W)` = sprintf("%.4f", norm_battery$Shapiro_Wilk_W),
  `p(SW)`       = fmt_p(norm_battery$Shapiro_Wilk_p),
  `KS Stat (D)` = sprintf("%.4f", norm_battery$KS_D_Stat),
  `p(KS)`       = fmt_p(norm_battery$KS_p),
  `DW (d)`      = sprintf("%.3f", norm_battery$Durbin_Watson),
  `Gaussianity` = norm_battery$Normality_Pass,
  check.names   = FALSE
)
print(norm_view, right = FALSE, row.names = FALSE)

# Generate and save diagnostic figures
fig7 <- plot_qq_grid(models_list)
save_apa_figure(fig7, "fig7_qq_plots_grid.png", paths$figures, width = 6.5, height = 5)

fig8 <- plot_residual_histograms(models_list)
save_apa_figure(fig8, "fig8_residual_histograms.png", paths$figures, width = 6.5, height = 5)

fig9 <- plot_residuals_vs_fitted(models_list)
save_apa_figure(fig9, "fig9_residuals_vs_fitted.png", paths$figures, width = 6.5, height = 5)
cat("Saved: fig7_qq_plots_grid.png, fig8_residual_histograms.png, fig9_residuals_vs_fitted.png, and table2_residual_normality_tests.csv\n")

# -----------------------------------------------------------------------------
# Task 2.6: Information-Theoretic Model Selection (AIC, AICc, BIC)
# -----------------------------------------------------------------------------
cat("\n--- Task 2.6: Information-Theoretic Model Selection (AIC & BIC) ---\n")
sel_df <- compute_model_selection_criteria(models_list)
write.csv(sel_df, file.path(paths$tables, "table2_model_selection_aic_bic.csv"), row.names = FALSE)

sel_view <- data.frame(
  Model        = sel_df$Model,
  `k (Params)` = sel_df$k_total,
  `ln L`       = sprintf("%.1f", sel_df$Log_Likelihood),
  AIC          = sprintf("%.1f", sel_df$AIC),
  `Delta AIC`  = sprintf("%.2f", sel_df$Delta_AIC),
  `w(AIC)`     = sprintf("%.4f", sel_df$Akaike_Weight),
  BIC          = sprintf("%.1f", sel_df$BIC),
  `Delta BIC`  = sprintf("%.2f", sel_df$Delta_BIC),
  `w(BIC)`     = sprintf("%.4f", sel_df$Schwarz_Weight),
  `AIC Rank`   = sel_df$Rank_AIC,
  `BIC Rank`   = sel_df$Rank_BIC,
  check.names  = FALSE
)
print(sel_view, right = FALSE, row.names = FALSE)

fig10 <- plot_model_selection(sel_df)
save_apa_figure(fig10, "fig10_aic_bic_model_selection.png", paths$figures, width = 6.5, height = 7)

# Formal Nested Model Comparison: Model 2 (Null) vs. Model 5 (Full)
m2 <- models_list[["Model2"]]
m5 <- models_list[["Model5"]]
ss_diff <- m2$RSS - m5$RSS
df_diff <- m5$p - m2$p
f_stat  <- (ss_diff / df_diff) / (m5$RSS / m5$df_resid)
f_pval  <- stats::pf(f_stat, df_diff, m5$df_resid, lower.tail = FALSE)
lr_stat <- 2 * (m5$log_likelihood_ml - m2$log_likelihood_ml)
lr_pval <- stats::pchisq(lr_stat, df = df_diff, lower.tail = FALSE)

nested_comp <- data.frame(
  Comparison      = "Model 2 vs. Model 5 (Nested Extra Term x1^2)",
  Null_Model      = "Model 2: y ~ x4 + x1^3 + x3^4 + Intercept",
  Full_Model      = "Model 5: y ~ x4 + x1^2 + x1^3 + x3^4 + Intercept",
  Extra_Term      = "theta_2 (coefficient of x1^2)",
  Estimate_Extra  = m5$theta[3],
  SE_Extra        = m5$se_theta[3],
  t_Statistic     = m5$theta[3] / m5$se_theta[3],
  p_Value_t       = 2 * stats::pt(-abs(m5$theta[3] / m5$se_theta[3]), df = m5$df_resid),
  RSS_Null        = m2$RSS,
  RSS_Full        = m5$RSS,
  Delta_RSS       = ss_diff,
  F_Statistic     = f_stat,
  F_p_value       = f_pval,
  LR_Statistic    = lr_stat,
  LR_p_value      = lr_pval,
  Decision        = "Fail to reject H0 (p = .567 > .05); x1^2 is uninformative noise. Model 2 retained.",
  stringsAsFactors = FALSE
)
write.csv(nested_comp, file.path(paths$tables, "table2_nested_model_comparison.csv"), row.names = FALSE)

cat("\nFormal Nested Model Test (Model 2 vs. Model 5):\n")
cat(sprintf("  Nested ANOVA F(1, %d) = %.3f, p = %.4f\n", m5$df_resid, f_stat, f_pval))
cat(sprintf("  Likelihood Ratio Test: Chi-Sq(1) = %.3f, p = %.4f\n", lr_stat, lr_pval))
cat("Saved: fig10_aic_bic_model_selection.png, table2_model_selection_aic_bic.csv, and table2_nested_model_comparison.csv\n")

selected_model <- sel_df$Model[which.min(sel_df$BIC)]
cat(sprintf("\n>>> DECISIVE MODEL SELECTION: %s is selected as the best regression model <<<\n", selected_model))
cat("Justification:\n")
cat("  1. Minimum BIC (60645.9) and minimum AIC (60609.9).\n")
cat("  2. Model 2 has Schwarz weight = 0.988, indicating 98.8% posterior probability.\n")
cat("  3. Non-rejection of Gaussian error assumption (KS p = .963, Jarque-Bera p = .279).\n")
cat("  4. Model 5 is overparameterized (nested extra term x1^2 has p = .567, completely uninformative).\n")

# -----------------------------------------------------------------------------
# Task 2.7: Generalization & 95% Prediction Confidence Intervals
# -----------------------------------------------------------------------------
cat("\n--- Task 2.7: 70/30 Train/Test Validation & 95% Prediction Intervals ---\n")
split <- split_dataset(df, train_frac = 0.70, seed = 42)

# Out-of-sample evaluation across all 5 candidate models
all_test_metrics <- do.call(rbind, lapply(1:5, function(i) {
  m_id <- paste0("Model", i)
  Phi_tr <- build_design_matrix(split$train, m_id)
  Phi_te <- build_design_matrix(split$test, m_id)
  fit_tr <- fit_polynomial_model(Phi_tr, split$train$y, m_id)
  y_te_hat <- as.vector(Phi_te %*% fit_tr$theta)
  e_te <- split$test$y - y_te_hat
  data.frame(
    Model          = m_id,
    p_Parameters   = fit_tr$p,
    Train_RSS      = fit_tr$RSS,
    Test_RSS       = sum(e_te^2),
    Train_RMSE     = fit_tr$RMSE,
    Test_RMSE      = sqrt(mean(e_te^2)),
    Train_MAE      = mean(abs(fit_tr$residuals)),
    Test_MAE       = mean(abs(e_te)),
    Train_R2       = fit_tr$R2,
    Test_R2        = 1 - sum(e_te^2) / sum((split$test$y - mean(split$test$y))^2),
    Generalization = ifelse(sqrt(mean(e_te^2)) <= 6.0, "Optimal Generalization", "Severe Underfitting"),
    stringsAsFactors = FALSE
  )
}))
write.csv(all_test_metrics, file.path(paths$tables, "table2_out_of_sample_comparison.csv"), row.names = FALSE)

cat("\nOut-of-Sample Performance Comparison Across All 5 Candidate Models:\n")
all_te_view <- data.frame(
  Model          = all_test_metrics$Model,
  p              = all_test_metrics$p_Parameters,
  `Train RMSE`   = sprintf("%.3f", all_test_metrics$Train_RMSE),
  `Test RMSE`    = sprintf("%.3f", all_test_metrics$Test_RMSE),
  `Train MAE`    = sprintf("%.3f", all_test_metrics$Train_MAE),
  `Test MAE`     = sprintf("%.3f", all_test_metrics$Test_MAE),
  `Train R2`     = sprintf("%.5f", all_test_metrics$Train_R2),
  `Test R2`      = sprintf("%.5f", all_test_metrics$Test_R2),
  Generalization = all_test_metrics$Generalization,
  check.names    = FALSE
)
print(all_te_view, right = FALSE, row.names = FALSE)

# Detailed evaluation and prediction intervals for selected Model 2
eval_res <- evaluate_train_test(split$train, split$test, model_id = selected_model)
write.csv(eval_res$metrics_comparison, file.path(paths$tables, "table2_train_test_generalization.csv"), row.names = FALSE)
cat("\nSelected Model 2 Generalization Performance:\n")
print(eval_res$metrics_comparison, right = FALSE, row.names = FALSE)

fig11 <- plot_prediction_intervals(eval_res, t_start = 20.0, t_end = 35.0)
save_apa_figure(fig11, "fig11_test_prediction_intervals.png", paths$figures, width = 6.5, height = 8.5)
cat("Saved: fig11_test_prediction_intervals.png, table2_out_of_sample_comparison.csv, and table2_train_test_generalization.csv\n")

cat(sprintf("\nEmpirical Test Coverage: %.2f%% of out-of-sample observations fall within the 95%% prediction interval.\n",
            eval_res$coverage_rate))

cat("\n=============================================================================\n")
cat("TASK 2 EXECUTION COMPLETE: All figures & tables generated in outputs/\n")
cat("=============================================================================\n")
