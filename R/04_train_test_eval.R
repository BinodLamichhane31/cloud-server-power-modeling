# =============================================================================
# 04_train_test_eval.R
# Coursework: STW7089CEM Introduction to Statistical Methods for Data Science
# Task 2: Regression: Modeling the Relationship Between Server Metrics
#
# Tasks covered:
#   Task 2.7: Generalization and Prediction Intervals:
#     - Split data into 70% train and 30% test sets (set.seed(42))
#     - Estimate model parameters using the training dataset
#     - Compute model predictions on the testing dataset
#     - Calculate exact 95% model prediction confidence intervals
#     - Plot test observations, predictions, and 95% error bars
#     - Evaluate out-of-sample generalization metrics and empirical coverage
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(dplyr)
})

#' Partition dataset into training (70%) and testing (30%) subsets.
#'
#' @param df Merged data frame
#' @param train_frac Proportion for training (default 0.70)
#' @param seed Reproducible random seed (default 42)
#' @return List with train and test data frames
split_dataset <- function(df, train_frac = 0.70, seed = 42) {
  set.seed(seed)
  n <- nrow(df)
  train_size <- round(train_frac * n)
  train_idx  <- sort(sample(seq_len(n), size = train_size, replace = FALSE))
  test_idx   <- setdiff(seq_len(n), train_idx)
  
  df_train <- df[train_idx, ]
  df_test  <- df[test_idx, ]
  
  # Ensure chronological ordering within subsets for time-series analysis
  df_train <- df_train[order(df_train$time), ]
  df_test  <- df_test[order(df_test$time), ]
  
  list(train = df_train, test = df_test, train_idx = train_idx, test_idx = test_idx)
}

#' Train selected model on training data and evaluate generalization on test data.
#'
#' @param df_train Training data frame
#' @param df_test Testing data frame
#' @param model_id Model identifier (default "Model2")
#' @return Evaluation object with parameters, predictions, intervals, and metrics
evaluate_train_test <- function(df_train, df_test, model_id = "Model2") {
  Phi_train <- build_design_matrix(df_train, model_id)
  Phi_test  <- build_design_matrix(df_test, model_id)
  
  y_train <- df_train$y
  y_test  <- df_test$y
  
  N_train <- nrow(df_train)
  N_test  <- nrow(df_test)
  p       <- ncol(Phi_train)
  df_tr   <- N_train - p
  
  # 1. Fit model strictly on training data using QR decomposition
  m_train  <- fit_polynomial_model(Phi_train, y_train, model_id = model_id)
  theta_tr <- m_train$theta
  s_tr     <- m_train$sigma_unbiased
  
  # In-sample training predictions & metrics
  y_train_hat <- m_train$fitted_values
  e_train     <- m_train$residuals
  rmse_train  <- m_train$RMSE
  mae_train   <- mean(abs(e_train))
  r2_train    <- m_train$R2
  
  # 2. Out-of-sample predictions on testing data: y_hat_test = Phi_test * theta_train
  y_test_hat <- as.vector(Phi_test %*% theta_tr)
  e_test     <- y_test - y_test_hat
  
  rmse_test  <- sqrt(mean(e_test^2))
  mae_test   <- mean(abs(e_test))
  tss_test   <- sum((y_test - mean(y_test))^2)
  rss_test   <- sum(e_test^2)
  r2_test    <- 1 - (rss_test / tss_test)
  
  # 3. Compute 95% Model Prediction Confidence Intervals
  # Inv(Phi_train^T Phi_train) via QR R matrix
  inv_PhiTPhi <- chol2inv(qr.R(qr(Phi_train)))
  
  # Leverage (variance of mean prediction): h_* = x_*^T (Phi^T Phi)^(-1) x_*
  h_test <- rowSums((Phi_test %*% inv_PhiTPhi) * Phi_test)
  
  # Standard error of the mean response E[y|x_*]
  se_mean <- s_tr * sqrt(h_test)
  
  # Standard error of an individual prediction y_* = x_* theta + epsilon_*
  se_pred <- s_tr * sqrt(1 + h_test)
  
  # Critical t value at alpha = 0.05 (two-tailed, df = N_train - p)
  t_crit <- stats::qt(0.975, df = df_tr)
  
  # 95% Prediction Interval bounds
  pi_lower <- y_test_hat - t_crit * se_pred
  pi_upper <- y_test_hat + t_crit * se_pred
  
  # 95% Confidence Interval of the mean response bounds
  ci_mean_lower <- y_test_hat - t_crit * se_mean
  ci_mean_upper <- y_test_hat + t_crit * se_mean
  
  # Empirical coverage rate: percentage of test observations inside 95% PI
  is_covered    <- (y_test >= pi_lower) & (y_test <= pi_upper)
  coverage_rate <- mean(is_covered) * 100
  n_covered     <- sum(is_covered)
  
  # Assemble test results data frame
  test_results <- data.frame(
    time          = df_test$time,
    y_actual      = y_test,
    y_pred        = y_test_hat,
    residual      = e_test,
    se_pred       = se_pred,
    pi_lower_95   = pi_lower,
    pi_upper_95   = pi_upper,
    ci_mean_lower = ci_mean_lower,
    ci_mean_upper = ci_mean_upper,
    is_covered    = is_covered,
    stringsAsFactors = FALSE
  )
  
  # Comparison metrics table
  metrics_comparison <- data.frame(
    Metric = c("Sample Size (N)", "Parameters (p)", "Degrees of Freedom",
               "Residual Sum of Squares (RSS)", "Root Mean Squared Error (RMSE)",
               "Mean Absolute Error (MAE)", "Coefficient of Determination (R^2)",
               "Estimated Noise Sigma (W)", "95% Prediction Coverage Rate (%)"),
    Training_Set = c(
      as.character(N_train), as.character(p), as.character(df_tr),
      sprintf("%.2f", m_train$RSS), sprintf("%.3f", rmse_train),
      sprintf("%.3f", mae_train), sprintf("%.5f", r2_train),
      sprintf("%.3f", s_tr), "---"
    ),
    Testing_Set = c(
      as.character(N_test), as.character(p), as.character(N_test - p),
      sprintf("%.2f", rss_test), sprintf("%.3f", rmse_test),
      sprintf("%.3f", mae_test), sprintf("%.5f", r2_test),
      sprintf("%.3f", rmse_test), sprintf("%.2f%% (%d/%d)", coverage_rate, n_covered, N_test)
    ),
    stringsAsFactors = FALSE
  )
  
  list(
    model_id           = model_id,
    m_train            = m_train,
    theta_train        = theta_tr,
    sigma_train        = s_tr,
    test_results       = test_results,
    metrics_comparison = metrics_comparison,
    rmse_test          = rmse_test,
    mae_test           = mae_test,
    r2_test            = r2_test,
    coverage_rate      = coverage_rate,
    n_covered          = n_covered,
    N_test             = N_test,
    N_train            = N_train
  )
}

#' Plot test observations, model predictions, and 95% confidence error bars.
#'
#' Follows APA 7 figure standards:
#'   Panel A: Overview of full test trajectory (N = 3,000) with 95% prediction ribbon.
#'   Panel B: High-resolution zoom on 50 consecutive test observations showing
#'            individual data points, model predictions, and connecting trajectory.
#'   Panel C: Prediction error residuals with discrete 95% error bars (±1.96 SE_pred)
#'            and coverage status (highlighting 95.47% empirical coverage).
#'
#' @param eval_res Output from evaluate_train_test()
#' @param t_start Start time for zoomed panels (default 20.0s)
#' @param t_end End time for zoomed panels (default 35.0s)
#' @return Combined patchwork ggplot object
plot_prediction_intervals <- function(eval_res, t_start = 20.0, t_end = 35.0) {
  df_test <- eval_res$test_results
  
  # Panel A: Full timeline (N = 3,000)
  p_a <- ggplot(df_test, aes(x = time)) +
    geom_ribbon(aes(ymin = pi_lower_95, ymax = pi_upper_95), fill = "grey80", alpha = 0.6) +
    geom_line(aes(y = y_pred), colour = apa_colours$bound, linewidth = 0.4) +
    geom_point(aes(y = y_actual), colour = apa_colours$main, size = 0.3, alpha = 0.3) +
    labs(
      subtitle = "A: Full Out-of-Sample Test Set (N = 3,000) with 95% Prediction Confidence Ribbon",
      x = "Sampling Time (s)",
      y = "Total Power (W)"
    ) +
    theme_apa7(base_size = 9) +
    theme(plot.subtitle = element_text(face = "bold", size = 10, hjust = 0))
  
  # Panel B: Dynamic telemetry window
  df_b <- df_test[df_test$time >= t_start & df_test$time <= t_end, ]
  p_b <- ggplot(df_b, aes(x = time)) +
    geom_errorbar(aes(ymin = pi_lower_95, ymax = pi_upper_95),
                  colour = "grey40", width = 0.15, linewidth = 0.4) +
    geom_line(aes(y = y_pred), colour = apa_colours$bound, linewidth = 0.5) +
    geom_point(aes(y = y_pred, shape = "Model Prediction"), colour = apa_colours$bound, size = 1.3, fill = "white") +
    geom_point(aes(y = y_actual, shape = "Test Sample"), colour = apa_colours$main, size = 1.2) +
    scale_shape_manual(values = c("Model Prediction" = 21, "Test Sample" = 16)) +
    labs(
      subtitle = sprintf("B: High-Resolution Telemetry Window (t = %.1fs to %.1fs, N = %d) with 95%% Prediction Error Bars",
                         min(df_b$time), max(df_b$time), nrow(df_b)),
      x = "Sampling Time (s)",
      y = "Total Power (W)"
    ) +
    theme_apa7(base_size = 9) +
    theme(legend.position = "right",
          plot.subtitle = element_text(face = "bold", size = 10, hjust = 0))
  
  # Panel C: Prediction errors with ±1.96 SE_pred error bars
  df_c <- df_b
  p_c <- ggplot(df_c, aes(x = time, y = residual)) +
    geom_hline(yintercept = 0, colour = "black", linetype = "dashed", linewidth = 0.4) +
    geom_ribbon(aes(ymin = -1.96 * se_pred, ymax = 1.96 * se_pred), fill = "grey85", alpha = 0.7) +
    geom_errorbar(aes(ymin = residual - 1.96 * se_pred, ymax = residual + 1.96 * se_pred),
                  colour = "grey40", width = 0.15, linewidth = 0.4) +
    geom_point(aes(colour = is_covered), size = 1.3) +
    scale_colour_manual(values = c("TRUE" = "black", "FALSE" = apa_colours$highlight),
                        labels = c("TRUE" = "Inside 95% Interval", "FALSE" = "Outside (Exceedance)")) +
    labs(
      subtitle = sprintf("C: Prediction Error Residuals with 95%% Error Bars and Coverage (Empirical Test Coverage = %.2f%%)",
                         eval_res$coverage_rate),
      x = "Sampling Time (s)",
      y = "Residual Error e = y - y_hat (W)",
      colour = "Coverage Status"
    ) +
    theme_apa7(base_size = 9) +
    theme(legend.position = "right",
          plot.subtitle = element_text(face = "bold", size = 10, hjust = 0))
  
  p_combined <- p_a / p_b / p_c + plot_layout(heights = c(1, 1.1, 1.1))
  p_combined
}
