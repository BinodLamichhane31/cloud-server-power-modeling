# =============================================================================
# 03_diagnostics_metrics.R
# Coursework: STW7089CEM Introduction to Statistical Methods for Data Science
# Task 2: Regression: Modeling the Relationship Between Server Metrics
#
# Tasks covered:
#   Task 2.5: Residual diagnostics and error distributions (Q-Q plots,
#             histograms with theoretical Gaussian overlays, residuals vs.
#             fitted values, and formal normality hypothesis tests)
#   Task 2.6: Information-theoretic model selection (AIC, AICc, BIC, delta
#             criteria, Akaike weights, and identification of best model)
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(patchwork)
})

# -----------------------------------------------------------------------------
# Task 2.6: Information-Theoretic Model Selection Criteria
# -----------------------------------------------------------------------------

#' Compute AIC, small-sample AICc, BIC, delta criteria, and evidence weights.
#'
#' @param models_list List of fitted models from fit_all_candidate_models()
#' @return Data frame with complete model selection metrics
compute_model_selection_criteria <- function(models_list) {
  rows <- lapply(models_list, function(m) {
    N <- m$N
    p <- m$p
    k <- p + 1  # Total estimated parameters (p regression terms + sigma^2)
    
    rss <- m$RSS
    ll  <- m$log_likelihood_ml
    
    # Akaike Information Criterion
    aic  <- 2 * k - 2 * ll
    
    # Small-sample corrected AIC
    aicc <- aic + (2 * k * (k + 1)) / (N - k - 1)
    
    # Bayesian Information Criterion
    bic  <- k * log(N) - 2 * ll
    
    data.frame(
      Model          = m$model_id,
      Formula        = m$formula,
      p_terms        = p,
      k_total        = k,
      RSS            = rss,
      RMSE           = m$RMSE,
      R_Squared      = m$R2,
      Sigma_Unbiased = m$sigma_unbiased,
      Log_Likelihood = ll,
      AIC            = aic,
      AICc           = aicc,
      BIC            = bic,
      stringsAsFactors = FALSE
    )
  })
  
  df <- do.call(rbind, rows)
  
  # Compute relative deltas
  min_aic  <- min(df$AIC)
  min_aicc <- min(df$AICc)
  min_bic  <- min(df$BIC)
  
  df$Delta_AIC  <- df$AIC - min_aic
  df$Delta_AICc <- df$AICc - min_aicc
  df$Delta_BIC  <- df$BIC - min_bic
  
  # Compute Akaike and Schwarz weights (evidence probabilities)
  aic_rel_lik  <- exp(-0.5 * df$Delta_AIC)
  df$Akaike_Weight <- aic_rel_lik / sum(aic_rel_lik)
  
  bic_rel_lik  <- exp(-0.5 * df$Delta_BIC)
  df$Schwarz_Weight <- bic_rel_lik / sum(bic_rel_lik)
  
  # Model ranking (1 = best)
  df$Rank_AIC <- rank(df$AIC)
  df$Rank_BIC <- rank(df$BIC)
  
  df
}

# -----------------------------------------------------------------------------
# Task 2.5: Formal Hypothesis Testing Battery for Residual Normality
# -----------------------------------------------------------------------------

#' Perform a comprehensive battery of statistical tests on model residuals.
#'
#' Evaluates:
#'   1. Sample moments: Mean, Standard Deviation, Skewness, Excess Kurtosis
#'   2. Jarque-Bera test of joint normality
#'   3. Shapiro-Wilk test (on random subsample of 5000 due to R base limit)
#'   4. One-sample Kolmogorov-Smirnov test against N(0, sigma^2)
#'   5. Durbin-Watson statistic for first-order serial independence
#'
#' @param models_list List of fitted models
#' @param seed Random seed for reproducibility of Shapiro-Wilk subsampling
#' @return Data frame summarizing test statistics and p-values
compute_residual_normality_battery <- function(models_list, seed = 42) {
  set.seed(seed)
  
  rows <- lapply(models_list, function(m) {
    e <- m$residuals
    N <- length(e)
    
    # Sample moments
    m_e  <- mean(e)
    sd_e <- stats::sd(e)
    
    # Skewness: m3 / m2^(3/2)
    s_val <- sum((e - m_e)^3) / (N * (sd_e^3))
    
    # Excess Kurtosis: m4 / m2^2 - 3
    k_val <- sum((e - m_e)^4) / (N * (sd_e^4)) - 3
    
    # Jarque-Bera Test: JB = N/6 * [S^2 + K^2/4] ~ ChiSq(2)
    jb_stat <- (N / 6) * (s_val^2 + (k_val^2 / 4))
    jb_p    <- 1 - stats::pchisq(jb_stat, df = 2)
    
    # Shapiro-Wilk Test (subsample of 5,000 if N > 5,000)
    e_sub <- if (N > 5000) sample(e, 5000) else e
    sw <- stats::shapiro.test(e_sub)
    
    # Kolmogorov-Smirnov Test against theoretical N(0, sigma_unbiased^2)
    ks <- stats::ks.test(e, "pnorm", mean = 0, sd = m$sigma_unbiased)
    
    # Durbin-Watson statistic for serial correlation: d = sum((e_t - e_{t-1})^2) / sum(e_t^2)
    dw_stat <- sum(diff(e)^2) / sum(e^2)
    
    data.frame(
      Model          = m$model_id,
      Mean_Resid     = m_e,
      SD_Resid       = sd_e,
      Skewness       = s_val,
      Excess_Kurtosis = k_val,
      Jarque_Bera_Stat = jb_stat,
      Jarque_Bera_p    = jb_p,
      Shapiro_Wilk_W   = sw$statistic,
      Shapiro_Wilk_p   = sw$p.value,
      KS_D_Stat        = ks$statistic,
      KS_p             = ks$p.value,
      Durbin_Watson    = dw_stat,
      Normality_Pass   = ifelse(ks$p.value > 0.05 && jb_p > 0.05, "Yes (Gaussian)", "No (Non-Gaussian)"),
      stringsAsFactors = FALSE
    )
  })
  
  do.call(rbind, rows)
}

# -----------------------------------------------------------------------------
# Task 2.5: Graphical Visualizations for Residual Diagnostics
# -----------------------------------------------------------------------------

#' Multi-panel Q-Q plots for all 5 candidate models with 95% confidence bands.
#'
#' @param models_list List of fitted models
#' @return ggplot object containing a 5-panel Q-Q diagnostic grid
plot_qq_grid <- function(models_list) {
  plot_data_list <- list()
  
  for (nm in names(models_list)) {
    m <- models_list[[nm]]
    e <- m$residuals
    n <- length(e)
    
    # Standardize residuals
    e_std <- (e - mean(e)) / sd(e)
    
    # Theoretical quantiles
    probs <- (1:n - 0.5) / n
    q_theo <- stats::qnorm(probs)
    q_emp  <- sort(e_std)
    
    # 95% point-wise confidence envelope (standard normal order statistics)
    # SE of q_k: sqrt(p * (1-p) / (n * f(q_theo)^2))
    f_q <- stats::dnorm(q_theo)
    se_q <- sqrt(probs * (1 - probs) / n) / pmax(f_q, 1e-6)
    lower_band <- q_theo - 1.96 * se_q
    upper_band <- q_theo + 1.96 * se_q
    
    # Downsample points for vector rendering speed (keep 1,000 quantiles)
    idx <- round(seq(1, n, length.out = min(n, 1000)))
    
    plot_data_list[[nm]] <- data.frame(
      Model      = nm,
      Theoretical = q_theo[idx],
      Sample     = q_emp[idx],
      Lower      = lower_band[idx],
      Upper      = upper_band[idx]
    )
  }
  
  all_qq <- do.call(rbind, plot_data_list)
  all_qq$Model <- factor(all_qq$Model, levels = paste0("Model", 1:5),
                         labels = paste("Model", 1:5))
  
  p <- ggplot(all_qq, aes(x = Theoretical, y = Sample)) +
    geom_ribbon(aes(ymin = Lower, ymax = Upper), fill = "grey85", alpha = 0.6) +
    geom_abline(slope = 1, intercept = 0, colour = apa_colours$bound,
                linetype = "dashed", linewidth = 0.5) +
    geom_point(colour = apa_colours$main, size = 0.6, alpha = 0.4) +
    facet_wrap(~ Model, scales = "free", ncol = 3) +
    labs(
      x = "Theoretical Normal Quantiles",
      y = "Standardized Residual Quantiles"
    ) +
    theme_apa7(base_size = 9)
  
  p
}

#' Multi-panel histograms of residuals with theoretical Gaussian density curve.
#'
#' @param models_list List of fitted models
#' @return ggplot object
plot_residual_histograms <- function(models_list) {
  plots <- list()
  
  for (i in 1:5) {
    nm <- paste0("Model", i)
    m  <- models_list[[nm]]
    e  <- m$residuals
    sd_e <- m$sigma_unbiased
    
    df_e <- data.frame(e = e)
    
    # Dynamic binwidth based on Freedman-Diaconis rule
    iqr_val <- stats::IQR(e)
    bw <- if (iqr_val > 0) 2 * iqr_val / (length(e)^(1/3)) else (max(e) - min(e)) / 50
    if (bw <= 0 || is.na(bw)) bw <- (max(e) - min(e)) / 50
    
    p_i <- ggplot(df_e, aes(x = e)) +
      geom_histogram(aes(y = after_stat(density)), binwidth = bw,
                     fill = "grey80", colour = "grey40", linewidth = 0.3) +
      stat_function(fun = stats::dnorm, args = list(mean = 0, sd = sd_e),
                    colour = apa_colours$highlight, linewidth = 0.7) +
      labs(
        title = paste("Model", i),
        x     = "Residual Error (W)",
        y     = "Density"
      ) +
      theme_apa7(base_size = 9) +
      theme(plot.title = element_text(face = "bold", size = 10, hjust = 0))
    
    plots[[nm]] <- p_i
  }
  
  wrap_plots(plots, ncol = 3)
}

#' Multi-panel Residuals vs. Fitted values scatter plots evaluating homoscedasticity.
#'
#' @param models_list List of fitted models
#' @return ggplot object
plot_residuals_vs_fitted <- function(models_list) {
  plot_data_list <- list()
  
  for (nm in names(models_list)) {
    m <- models_list[[nm]]
    # Subsample 1,500 points for clean visual rendering
    n <- length(m$fitted_values)
    idx <- round(seq(1, n, length.out = min(n, 1500)))
    
    plot_data_list[[nm]] <- data.frame(
      Model     = nm,
      Fitted    = m$fitted_values[idx],
      Residuals = m$residuals[idx]
    )
  }
  
  all_rvf <- do.call(rbind, plot_data_list)
  all_rvf$Model <- factor(all_rvf$Model, levels = paste0("Model", 1:5),
                          labels = paste("Model", 1:5))
  
  p <- ggplot(all_rvf, aes(x = Fitted, y = Residuals)) +
    geom_hline(yintercept = 0, colour = apa_colours$bound, linetype = "dashed", linewidth = 0.5) +
    geom_point(colour = apa_colours$main, size = 0.6, alpha = 0.35) +
    geom_smooth(method = "loess", formula = y ~ x, colour = apa_colours$highlight,
                se = FALSE, linewidth = 0.7) +
    facet_wrap(~ Model, scales = "free", ncol = 3) +
    labs(
      x = "Fitted Power Consumption (W)",
      y = "Residual Error (W)"
    ) +
    theme_apa7(base_size = 9)
  
  p
}

# -----------------------------------------------------------------------------
# Task 2.6: Information Criteria Comparison Plot
# -----------------------------------------------------------------------------

#' Dual-panel figure comparing absolute AIC/BIC and relative delta penalties.
#'
#' Panel A: Absolute AIC and BIC values across all 5 candidate models.
#' Panel B: Relative Delta penalties (Delta = Criterion - min(Criterion)) for
#'          top competing candidates, annotated with the Kass & Raftery (1995)
#'          strong evidence threshold (Delta = 6).
#'
#' @param selection_df Output from compute_model_selection_criteria()
#' @return ggplot patchwork object
plot_model_selection <- function(selection_df) {
  # Panel A: Absolute criteria across all 5 models
  df_long_abs <- data.frame(
    Model     = rep(selection_df$Model, 2),
    Criterion = rep(c("AIC", "BIC"), each = nrow(selection_df)),
    Value     = c(selection_df$AIC, selection_df$BIC),
    stringsAsFactors = FALSE
  )
  df_long_abs$Model <- factor(df_long_abs$Model, levels = paste0("Model", 1:5),
                              labels = paste("Model", 1:5))
  
  p_a <- ggplot(df_long_abs, aes(x = Model, y = Value, fill = Criterion)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.7),
             width = 0.6, colour = "black", linewidth = 0.3) +
    scale_fill_manual(values = c("AIC" = "grey35", "BIC" = "grey75")) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      subtitle = "A: Absolute Information Criteria Across All Candidate Models",
      x = "Candidate Polynomial Model",
      y = "Information Criterion Value",
      fill = "Metric"
    ) +
    theme_apa7(base_size = 9) +
    theme(legend.position = "right",
          plot.subtitle = element_text(face = "bold", size = 10, hjust = 0))
  
  # Panel B: Delta criteria for top candidates (Model 2 vs Model 5)
  df_comp <- selection_df[selection_df$Model %in% c("Model2", "Model5"), ]
  df_long_delta <- data.frame(
    Model     = rep(df_comp$Model, 2),
    Criterion = rep(c("Delta AIC", "Delta BIC"), each = nrow(df_comp)),
    Delta     = c(df_comp$Delta_AIC, df_comp$Delta_BIC),
    stringsAsFactors = FALSE
  )
  df_long_delta$Model <- factor(df_long_delta$Model, levels = c("Model2", "Model5"),
                                labels = c("Model 2 (Parsimonious)", "Model 5 (Nested Extra x1^2)"))
  
  p_b <- ggplot(df_long_delta, aes(x = Model, y = Delta, fill = Criterion)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.6),
             width = 0.5, colour = "black", linewidth = 0.3) +
    geom_hline(yintercept = 2.0, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
    geom_hline(yintercept = 6.0, linetype = "solid", colour = apa_colours$highlight, linewidth = 0.5) +
    annotate("text", x = 0.7, y = 2.3, label = "Delta = 2 (Positive Evidence)", size = 2.7, hjust = 0, colour = "grey30") +
    annotate("text", x = 0.7, y = 6.3, label = "Delta = 6 (Strong Evidence Threshold, Kass & Raftery 1995)", size = 2.7, hjust = 0, colour = apa_colours$highlight) +
    scale_fill_manual(values = c("Delta AIC" = "grey35", "Delta BIC" = "grey75")) +
    scale_y_continuous(limits = c(0, 10), breaks = seq(0, 10, by = 2)) +
    labs(
      subtitle = "B: Information Penalty Delta (Delta = Criterion - min(Criterion)) for Top Candidates",
      x = "Candidate Polynomial Model",
      y = "Information Delta",
      fill = "Penalty Delta"
    ) +
    theme_apa7(base_size = 9) +
    theme(legend.position = "right",
          plot.subtitle = element_text(face = "bold", size = 10, hjust = 0))
  
  p_combined <- p_a / p_b + patchwork::plot_layout(heights = c(1, 1.1))
  p_combined
}
