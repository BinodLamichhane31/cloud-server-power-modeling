# =============================================================================
# run_task3_abc.R
# Coursework: STW7089CEM Introduction to Statistical Methods for Data Science
# Task 3: Approximate Bayesian Computation (ABC)
#
# Complete End-to-End Execution Pipeline for Task 3:
#   Task 3.1: Dominant Parameter Isolation from Selected Model (Model 2)
#   Task 3.2: Prior Distribution Formulation & Theoretical Justification
#   Task 3.3: High-Performance Vectorized Rejection ABC Engine
#   Task 3.4: Bayesian Posterior Inferences & Frequentist Paradigm Comparison
#   Task 3.5: Multi-Panel Publication-Grade APA 7 Visualizations
#
# Generated Deliverables:
#   Tables:  outputs/tables/table3_frequentist_vs_bayesian_comparison.csv
#            outputs/tables/table3_abc_tolerance_sensitivity.csv
#   Figures: outputs/figures/fig12_abc_marginal_posteriors.png
#            outputs/figures/fig13_abc_joint_posterior.png
#            outputs/figures/fig14_abc_tolerance_convergence.png
# =============================================================================

local({
  root <- if (file.exists("R/00_utils_io.R")) "." else ".."
  for (f in c("00_utils_io.R", "06_theme_apa7.R", "02_regression_engine.R",
              "05_abc_engine.R")) {
    source(file.path(root, "R", f))
  }
}, envir = globalenv())

paths <- project_paths()
dir.create(paths$tables,  showWarnings = FALSE, recursive = TRUE)
dir.create(paths$figures, showWarnings = FALSE, recursive = TRUE)

cat("=============================================================================\n")
cat("TASK 3: APPROXIMATE BAYESIAN COMPUTATION (ABC) SIMULATION & INFERENCE\n")
cat("=============================================================================\n\n")

# Load preprocessed clean server telemetry data
clean_file <- file.path(paths$processed, "server_data_clean.csv")
if (!file.exists(clean_file)) {
  stop("Processed data not found at: ", clean_file, ". Run run_task1_eda.R first.")
}
df <- read.csv(clean_file)
cat(sprintf("Loaded clean dataset: N = %d observations, 6 variables (time, x1..x4, y)\n\n", nrow(df)))

# -----------------------------------------------------------------------------
# Task 3.1: Fit Selected Model (Model 2) & Isolate Dominant Parameters
# -----------------------------------------------------------------------------
cat("--- Task 3.1: Isolating Dominant Parameters from Selected Model (Model 2) ---\n")
Phi2 <- build_design_matrix(df, "Model2")
ols_model2 <- fit_polynomial_model(Phi2, df$y, model_id = "Model2")

# Identify the two parameters with largest absolute value
dominant_struct <- identify_dominant_parameters(ols_model2)
dom <- dominant_struct$dominant_params
fix <- dominant_struct$fixed_params

cat("Model 2 OLS Parameter Absolute Magnitudes:\n")
for (i in seq_along(ols_model2$theta)) {
  term_name <- ols_model2$param_table$Term[i]
  est_val   <- ols_model2$theta[i]
  abs_val   <- abs(est_val)
  is_dom    <- term_name %in% dom$terms
  cat(sprintf("  [%s] %-20s: Estimate = %10.4f  |Magnitude| = %10.4f %s\n",
              ifelse(is_dom, "SELECTED", "  FIXED "),
              term_name, est_val, abs_val,
              ifelse(is_dom, "<-- Top 2 Absolute Magnitude", "")))
}

cat("\nIsolated Dominant Parameters for ABC Inversion:\n")
cat(sprintf("  Parameter 1: %s (Estimate = %.4f W, SE = %.4f)\n",
            dom$terms[1], dom$estimates[1], dom$std_errors[1]))
cat(sprintf("  Parameter 2: %s (Estimate = %.4f W/Gbps, SE = %.4f)\n",
            dom$terms[2], dom$estimates[2], dom$std_errors[2]))

cat("\nFixed Parameters Held Constant at Least Squares Values:\n")
for (k in seq_along(fix$terms)) {
  cat(sprintf("  Fixed %s: %s = %.6f (%s)\n",
              fix$names[k], fix$terms[k], fix$values[k], fix$roles[k]))
}

# -----------------------------------------------------------------------------
# Task 3.2: Prior Formulation & Justification
# -----------------------------------------------------------------------------
cat("\n--- Task 3.2: Prior Distribution Formulation & Theoretical Justification ---\n")
# Define uniform priors centered at OLS point estimates:
# theta_0: [115, 125] W (width 10 W, ~51 x SE)
# theta_1: [3.5, 5.5] W/Gbps (width 2.0 W/Gbps, ~60 x SE)
priors <- define_priors(dom, explicit_ranges = list(
  Intercept = c(min = 115.0, max = 125.0),
  x4        = c(min = 3.5,   max = 5.5)
))

for (p_nm in names(priors)) {
  pr <- priors[[p_nm]]
  cat(sprintf("  Prior for %-10s: %s over [%.2f, %.2f]\n",
              pr$param_name, pr$type, pr$min, pr$max))
  cat(sprintf("    Width = %.2f | OLS Estimate = %.4f | Width in OLS SEs = %.1f x SE\n",
              pr$width, pr$ols_est, pr$se_span))
}
cat("Theoretical Justification:\n")
cat("  1. Continuous uniform priors represent maximum-entropy uninformative priors over\n")
cat("     physically realistic parameter bounds (idle power 115-125 W, network load 3.5-5.5 W/Gbps).\n")
cat("  2. Prior spans exceed 50x to 60x Frequentist standard errors, ensuring the resulting\n")
cat("     posteriors are entirely data-driven and not constrained by prior boundaries.\n\n")

# -----------------------------------------------------------------------------
# Task 3.3: High-Performance Vectorized Rejection ABC Engine
# -----------------------------------------------------------------------------
cat("--- Task 3.3: Vectorized Rejection ABC Simulation Engine ---\n")
n_sim <- 200000
tolerance_quantiles <- c(0.05, 0.02, 0.01, 0.005)
cat(sprintf("Executing Rejection ABC with N_sim = %s candidate draws...\n",
            format(n_sim, big.mark = ",")))

t_start <- Sys.time()
abc_results <- run_rejection_abc(
  df                  = df,
  dominant_params     = dom,
  fixed_params        = fix,
  priors              = priors,
  n_sim               = n_sim,
  tolerance_quantiles = tolerance_quantiles,
  seed                = 42
)
t_elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
cat(sprintf("Rejection ABC simulation completed in %.2f seconds (%.0f draws/sec)!\n\n",
            t_elapsed, n_sim / t_elapsed))

# Compile tolerance sensitivity table across tolerance levels
sens_table <- build_tolerance_sensitivity_table(abc_results)
write.csv(sens_table, file.path(paths$tables, "table3_abc_tolerance_sensitivity.csv"),
          row.names = FALSE)

cat("Tolerance Sensitivity & Posterior Convergence Summary:\n")
sens_view <- data.frame(
  Quantile    = sprintf("%.1f%%", sens_table$Tolerance_Quantile * 100),
  Accepted    = format(sens_table$Accepted_Count, big.mark = ","),
  `RMSE Tol (W)` = sprintf("%.4f", sens_table$Threshold_RMSE_W),
  `Theta0 Mean`  = sprintf("%.3f", sens_table$Theta0_Mean),
  `Theta0 SD`    = sprintf("%.3f", sens_table$Theta0_SD),
  `Theta1 Mean`  = sprintf("%.4f", sens_table$Theta1_Mean),
  `Theta1 SD`    = sprintf("%.4f", sens_table$Theta1_SD),
  `r(t0, t1)`    = sprintf("%.3f", sens_table$Posterior_Correlation_r),
  check.names = FALSE
)
print(sens_view, right = FALSE, row.names = FALSE)
cat("Saved: table3_abc_tolerance_sensitivity.csv\n\n")

# -----------------------------------------------------------------------------
# Task 3.4: Compute Posterior Inferences & Frequentist Paradigm Comparison
# -----------------------------------------------------------------------------
cat("--- Task 3.4: Bayesian Posterior Inferences & Paradigm Comparison ---\n")
primary_acc <- abc_results$primary_accepted
cat(sprintf("Primary Inferences based on tolerance alpha = %s%% (N = %d accepted draws):\n",
            abc_results$primary_q, primary_acc$n_accepted))

post_t0 <- compute_posterior_statistics(primary_acc$theta0_acc, prob = 0.95)
post_t1 <- compute_posterior_statistics(primary_acc$theta1_acc, prob = 0.95)

# Build APA 7 Table 3
table3_df <- build_frequentist_bayesian_comparison(dom, priors, post_t0, post_t1)
write.csv(table3_df, file.path(paths$tables, "table3_frequentist_vs_bayesian_comparison.csv"),
          row.names = FALSE)

cat("\nAPA 7 Table 3: Frequentist OLS vs. Bayesian ABC Comparison:\n")
table3_view <- data.frame(
  Parameter     = table3_df$Parameter,
  `Frequentist (SE)` = sprintf("%.4f (%.4f)", table3_df$Frequentist_Estimate, table3_df$Frequentist_SE),
  `95% OLS CI`       = sprintf("[%.3f, %.3f]", table3_df$Frequentist_CI95_Lower, table3_df$Frequentist_CI95_Upper),
  `Bayesian Mean`    = sprintf("%.4f", table3_df$Bayesian_Mean),
  `Bayesian Mode`    = sprintf("%.4f", table3_df$Bayesian_Mode),
  `Bayesian SD`      = sprintf("%.4f", table3_df$Bayesian_SD),
  `95% HPDI`         = sprintf("[%.3f, %.3f]", table3_df$Bayesian_HPDI95_Lower, table3_df$Bayesian_HPDI95_Upper),
  `Diff (%)`         = sprintf("%.3f%%", table3_df$Abs_Relative_Diff_Pct),
  check.names        = FALSE
)
print(table3_view, right = FALSE, row.names = FALSE)
cat("Saved: table3_frequentist_vs_bayesian_comparison.csv\n\n")

# -----------------------------------------------------------------------------
# Task 3.5: Multi-Panel Publication-Grade Visualizations (APA 7)
# -----------------------------------------------------------------------------
cat("--- Task 3.5: Generating Publication-Grade Visualizations (APA 7) ---\n")

# Figure 12: Marginal Posterior Probability Distributions
fig12 <- plot_marginal_posteriors(abc_results, priors, post_t0, post_t1, ols_model2)
save_apa_figure(fig12, "fig12_abc_marginal_posteriors.png", paths$figures,
                width = 6.5, height = 4.0)

# Figure 13: Joint Posterior Distribution & Covariance Contours
fig13 <- plot_joint_posterior(abc_results, ols_model2)
save_apa_figure(fig13, "fig13_abc_joint_posterior.png", paths$figures,
                width = 6.0, height = 4.8)

# Figure 14: ABC Tolerance Sensitivity and Contraction Analysis
fig14 <- plot_tolerance_convergence(abc_results, ols_model2)
save_apa_figure(fig14, "fig14_abc_tolerance_convergence.png", paths$figures,
                width = 6.5, height = 3.6)

cat("Saved Figures:\n")
cat("  - outputs/figures/fig12_abc_marginal_posteriors.png\n")
cat("  - outputs/figures/fig13_abc_joint_posterior.png\n")
cat("  - outputs/figures/fig14_abc_tolerance_convergence.png\n\n")

# -----------------------------------------------------------------------------
# Academic Synthesis and Scientific Interpretation
# -----------------------------------------------------------------------------
cat("=============================================================================\n")
cat("TASK 3 SCIENTIFIC SYNTHESIS & STATISTICAL EXPLANATION\n")
cat("=============================================================================\n")
cat("1. Consistency and Asymptotic Convergence (Bernstein-von Mises Theorem):\n")
cat(sprintf("   - Intercept theta_0: Bayesian Mean = %.3f W vs. Frequentist OLS = %.3f W (|Diff| = %.3f%%).\n",
            post_t0$mean, dom$estimates[1], table3_df$Abs_Relative_Diff_Pct[1]))
cat(sprintf("   - Network theta_1:   Bayesian Mean = %.4f W/Gbps vs. Frequentist OLS = %.4f W/Gbps (|Diff| = %.3f%%).\n",
            post_t1$mean, dom$estimates[2], table3_df$Abs_Relative_Diff_Pct[2]))
cat("   - The near-identical central tendencies confirm that with N = 10,000 observations\n")
cat("     and flat uninformative priors, the posterior distribution is overwhelmingly\n")
cat("     data-driven and converges precisely to the Maximum Likelihood point estimate.\n\n")

cat("2. Parameter Interdependence & Negative Posterior Correlation:\n")
r_joint <- cor(primary_acc$theta0_acc, primary_acc$theta1_acc)
cat(sprintf("   - Empirical posterior correlation: r(theta_0, theta_1) = %.3f.\n", r_joint))
cat("   - Theoretical Explanation: The network activity variable x_4 is strictly positive\n")
cat("     (x_4 >= 0, Mean = 3.01 Gbps). Consequently, the off-diagonal element of the Gram\n")
cat("     matrix (Phi^T Phi)_{0,1} = sum(x_4) = 30,105 > 0. In the inverted covariance\n")
cat("     matrix, this induces a negative covariance Cov(theta_0, theta_1) < 0.\n")
cat("   - Physically, any candidate simulation with a slightly elevated network coefficient\n")
cat("     must be compensated by a reduced static intercept to maintain the observed mean\n")
cat("     power level, generating the tilted bivariate ellipse observed in Figure 13.\n\n")

cat("3. ABC Tolerance Sensitivity & Variance Contraction:\n")
cat("   - As tolerance quantile alpha tightens from 5.0% down to 0.5%:\n")
cat(sprintf("     * RMSE threshold contracts from %.3f W to %.3f W (approaching theoretical min = 5.008 W).\n",
            sens_table$Threshold_RMSE_W[1], sens_table$Threshold_RMSE_W[4]))
cat(sprintf("     * Posterior SD for theta_0 contracts from %.3f W down to %.3f W.\n",
            sens_table$Theta0_SD[1], sens_table$Theta0_SD[4]))
cat(sprintf("     * Posterior SD for theta_1 contracts from %.4f down to %.4f W/Gbps.\n",
            sens_table$Theta1_SD[1], sens_table$Theta1_SD[4]))
cat("   - This empirically demonstrates the core ABC theorem: as epsilon -> 0,\n")
cat("     the approximate posterior p(theta | d <= epsilon) converges asymptotically\n")
cat("     to the exact theoretical posterior distribution p(theta | y).\n\n")

cat("4. Epistemic Paradigm Comparison (Bayesian vs. Frequentist):\n")
cat("   - Frequentist Confidence Interval: Under hypothetical infinite repetitions of the\n")
cat("     experiment, 95% of constructed intervals [theta_hat +/- 1.96*SE] will contain\n")
cat("     the true, fixed physical parameters.\n")
cat("   - Bayesian Credible Interval (HPDI): The parameter is treated as a random variable;\n")
cat("     there is an explicit 95% subjective posterior probability that the true parameter\n")
cat("     lies within the Highest Posterior Density Interval [HPDI_lower, HPDI_upper],\n")
cat("     given the observed data and specified prior belief.\n\n")

cat("Task 3 successfully completed! All tables and figures generated to APA 7 standards.\n")
cat("=============================================================================\n")
