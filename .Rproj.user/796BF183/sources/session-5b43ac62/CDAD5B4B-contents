# =============================================================================
# 05_abc_engine.R
# Coursework: STW7089CEM Introduction to Statistical Methods for Data Science
# Task 3: Approximate Bayesian Computation (ABC)
#
# Tasks covered:
#   Task 3.1: Identify the two dominant parameters with the largest absolute
#             values from least squares estimation of the selected regression
#             model (Model 2), and fix remaining parameters as constants.
#   Task 3.2: Specify continuous uniform prior distributions around the
#             estimated parameter values, establishing theoretical and physical
#             justifications for the prior ranges.
#   Task 3.3: High-performance vectorized Rejection ABC simulation engine to
#             generate candidate draws from priors and compute summary distances.
#   Task 3.4: Compute posterior moments, Highest Posterior Density Intervals
#             (95% HPDI), and tolerance sensitivity analysis.
#   Task 3.5: Multi-panel publication-grade APA 7 visualizations (marginal
#             posteriors, joint posterior covariance ellipse, and tolerance
#             convergence).
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

#' Identify the two parameters with the largest absolute value from Model 2.
#'
#' @param ols_fit Fitted Model 2 list containing theta_hat, se, ci_lower,
#'                ci_upper, and metadata.
#' @return A list containing dominant parameter details and fixed constants.
identify_dominant_parameters <- function(ols_fit) {
  pt <- ols_fit$param_table
  theta_hat <- pt$Estimate_QR
  se_vec    <- pt$Std_Error
  terms_vec <- pt$Term
  roles_vec <- pt$Physical_Role
  ci_low    <- pt$CI_95_Lower
  ci_upp    <- pt$CI_95_Upper
  abs_vals  <- abs(theta_hat)
  
  # Rank by absolute magnitude descending
  rank_idx <- order(abs_vals, decreasing = TRUE)
  dominant_idx <- rank_idx[1:2]
  fixed_idx <- rank_idx[3:length(rank_idx)]
  
  dom_names <- c("Intercept", "x4")
  dom_est   <- theta_hat[dominant_idx]
  dom_se    <- se_vec[dominant_idx]
  names(dom_est) <- dom_names
  names(dom_se)  <- dom_names
  
  dominant_params <- list(
    indices     = dominant_idx,
    names       = dom_names,
    terms       = terms_vec[dominant_idx],
    roles       = roles_vec[dominant_idx],
    estimates   = dom_est,
    std_errors  = dom_se,
    ci_lower    = ci_low[dominant_idx],
    ci_upper    = ci_upp[dominant_idx]
  )
  
  fix_names <- c("x1_cube", "x3_quad")
  fix_vals  <- theta_hat[fixed_idx]
  names(fix_vals) <- fix_names
  
  fixed_params <- list(
    indices     = fixed_idx,
    names       = fix_names,
    terms       = terms_vec[fixed_idx],
    roles       = roles_vec[fixed_idx],
    values      = fix_vals
  )
  
  list(
    dominant_params = dominant_params,
    fixed_params    = fixed_params
  )
}

#' Define continuous uniform priors centered around OLS point estimates.
#'
#' @param dominant_params Dominant parameters list from identify_dominant_parameters.
#' @param explicit_ranges Optional named list of 2-element vectors specifying
#'                        min and max for each parameter.
#' @return A structured list defining prior distributions and justifications.
define_priors <- function(dominant_params, explicit_ranges = NULL) {
  p_names <- dominant_params$names
  est     <- dominant_params$estimates
  se      <- dominant_params$std_errors
  
  if (is.null(explicit_ranges)) {
    # Default justifiable ranges:
    # theta_0 (Intercept): 120.02 W -> [115, 125] W (width 10 W, ~51 x SE)
    # theta_1 (x4 network): 4.48 W/Gbps -> [3.5, 5.5] W/Gbps (width 2.0 W/Gbps, ~60 x SE)
    ranges <- list()
    ranges[[p_names[1]]] <- c(min = 115.0, max = 125.0)
    ranges[[p_names[2]]] <- c(min = 3.5,   max = 5.5)
  } else {
    ranges <- explicit_ranges
  }
  
  priors <- list()
  for (nm in p_names) {
    rng <- ranges[[nm]]
    priors[[nm]] <- list(
      param_name  = nm,
      type        = "Continuous Uniform U[a, b]",
      min         = rng[1],
      max         = rng[2],
      width       = rng[2] - rng[1],
      midpoint    = (rng[1] + rng[2]) / 2,
      density_val = 1 / (rng[2] - rng[1]),
      ols_est     = as.numeric(est[nm]),
      ols_se      = as.numeric(se[nm]),
      se_span     = (rng[2] - rng[1]) / as.numeric(se[nm])
    )
  }
  
  priors
}

#' High-performance vectorized Rejection ABC simulation engine.
#'
#' Evaluates candidate parameter pairs against the observed telemetry response
#' via root mean squared distance d(y, y_hat(theta)) <= epsilon.
#'
#' @param df Data frame containing x1, x2, x3, x4, y.
#' @param dominant_params Dominant parameter specifications.
#' @param fixed_params Fixed parameter values.
#' @param priors Prior distribution bounds.
#' @param n_sim Total number of candidate draws (default: 200,000).
#' @param tolerance_quantiles Numeric vector of tolerance quantiles to evaluate.
#' @param seed Random seed for strict reproducibility.
#' @return List containing candidate draws, distances, and accepted subsets.
run_rejection_abc <- function(df, dominant_params, fixed_params, priors,
                              n_sim = 200000,
                              tolerance_quantiles = c(0.05, 0.02, 0.01, 0.005),
                              seed = 42) {
  set.seed(seed)
  n <- nrow(df)
  
  # Extract input vectors
  x1 <- df$x1
  x3 <- df$x3
  x4 <- df$x4
  y  <- df$y
  
  # Extract fixed parameter constants (Model 2: theta_2*x1^3 + theta_3*x3^4)
  # Fixed parameters: theta_2 for x1^3 and theta_3 for x3^4
  theta2_fix <- as.numeric(fixed_params$values[1])
  theta3_fix <- as.numeric(fixed_params$values[2])
  
  # Precompute deterministic constant component across all observations
  y_fixed <- theta2_fix * (x1^3) + theta3_fix * (x3^4)
  y_target <- y - y_fixed
  
  # Precompute sufficient sample sums for instant algebraic quadratic expansion
  sum_y_target    <- sum(y_target)
  sum_y_target_sq <- sum(y_target^2)
  sum_x4          <- sum(x4)
  sum_x4_sq       <- sum(x4^2)
  sum_x4_y_target <- sum(x4 * y_target)
  
  # Parameter names
  p0_name <- dominant_params$names[1] # "Intercept" or "theta_0"
  p1_name <- dominant_params$names[2] # "x4" or "theta_1"
  
  # Sample n_sim candidate parameters independently from continuous uniform priors
  p0_min <- priors[[p0_name]]$min
  p0_max <- priors[[p0_name]]$max
  p1_min <- priors[[p1_name]]$min
  p1_max <- priors[[p1_name]]$max
  
  sim_theta0 <- runif(n_sim, min = p0_min, max = p0_max)
  sim_theta1 <- runif(n_sim, min = p1_min, max = p1_max)
  
  # Vectorized calculation of Residual Sum of Squares (RSS):
  # RSS(theta0, theta1) = sum((y_target - (theta0 + theta1 * x4))^2)
  #                     = sum(y_target^2) + N*theta0^2 + theta1^2*sum(x4^2)
  #                       - 2*theta0*sum(y_target) - 2*theta1*sum(x4*y_target)
  #                       + 2*theta0*theta1*sum(x4)
  rss_vector <- sum_y_target_sq +
    n * (sim_theta0^2) +
    (sim_theta1^2) * sum_x4_sq -
    2 * sim_theta0 * sum_y_target -
    2 * sim_theta1 * sum_x4_y_target +
    2 * sim_theta0 * sim_theta1 * sum_x4
  
  # Distance metrics:
  # Euclidean distance: || y - y_hat ||_2 = sqrt(RSS)
  # Root Mean Squared Error (RMSE) summary distance: sqrt(RSS / N)
  dist_rmse <- sqrt(rss_vector / n)
  dist_euc  <- sqrt(rss_vector)
  
  # Multi-tolerance acceptance evaluation
  tolerance_levels <- list()
  for (q in tolerance_quantiles) {
    threshold_rmse <- as.numeric(quantile(dist_rmse, probs = q))
    threshold_euc  <- as.numeric(quantile(dist_euc,  probs = q))
    accepted_idx   <- which(dist_rmse <= threshold_rmse)
    
    tolerance_levels[[as.character(q)]] <- list(
      quantile       = q,
      threshold_rmse = threshold_rmse,
      threshold_euc  = threshold_euc,
      n_accepted     = length(accepted_idx),
      accepted_idx   = accepted_idx,
      theta0_acc     = sim_theta0[accepted_idx],
      theta1_acc     = sim_theta1[accepted_idx]
    )
  }
  
  # Primary accepted subset (finest tolerance quantile, e.g., top 0.5% = 1,000 samples)
  finest_q <- as.character(min(tolerance_quantiles))
  primary_acc <- tolerance_levels[[finest_q]]
  
  list(
    n_sim            = n_sim,
    seed             = seed,
    p0_name          = p0_name,
    p1_name          = p1_name,
    sim_theta0       = sim_theta0,
    sim_theta1       = sim_theta1,
    dist_rmse        = dist_rmse,
    dist_euc         = dist_euc,
    tolerance_levels = tolerance_levels,
    primary_q        = finest_q,
    primary_accepted = primary_acc
  )
}

#' Non-parametric computation of 95% Highest Posterior Density Interval (HPDI).
#'
#' Identifies the shortest contiguous interval that encloses (1 - alpha) of the
#' posterior sample mass.
#'
#' @param samples Numeric vector of posterior draws.
#' @param prob Credibility level (default: 0.95).
#' @return Two-element vector c(lower, upper).
compute_hpdi <- function(samples, prob = 0.95) {
  sorted_s <- sort(samples)
  n <- length(sorted_s)
  n_in <- floor(prob * n)
  n_out <- n - n_in
  
  if (n_out <= 0) {
    return(c(lower = min(sorted_s), upper = max(sorted_s)))
  }
  
  widths <- sorted_s[(n_in + 1):n] - sorted_s[1:n_out]
  min_idx <- which.min(widths)
  
  c(lower = sorted_s[min_idx], upper = sorted_s[min_idx + n_in])
}

#' Estimate the mode of a continuous posterior sample via Kernel Density Peak.
#'
#' @param samples Numeric vector of posterior draws.
#' @param n Number of evaluation points for density estimation.
#' @return Scalar mode estimate.
compute_mode <- function(samples, n = 1024) {
  d <- density(samples, n = n)
  d$x[which.max(d$y)]
}

#' Calculate comprehensive posterior summary statistics.
#'
#' @param samples Numeric vector of posterior draws.
#' @param prob Credibility level (default: 0.95).
#' @return Named list of posterior statistics.
compute_posterior_statistics <- function(samples, prob = 0.95) {
  n <- length(samples)
  m <- mean(samples)
  s <- sd(samples)
  mdn <- median(samples)
  mod <- compute_mode(samples)
  
  # Skewness and Excess Kurtosis
  z <- (samples - m) / s
  skew <- (n / ((n - 1) * (n - 2))) * sum(z^3)
  kurt <- ((n * (n + 1)) / ((n - 1) * (n - 2) * (n - 3))) * sum(z^4) -
          (3 * (n - 1)^2) / ((n - 2) * (n - 3))
  
  hpdi <- compute_hpdi(samples, prob = prob)
  alpha_tail <- (1 - prob) / 2
  eti <- quantile(samples, probs = c(alpha_tail, 1 - alpha_tail))
  
  list(
    n           = n,
    mean        = m,
    median      = mdn,
    mode        = mod,
    sd          = s,
    variance    = s^2,
    skewness    = skew,
    kurtosis    = kurt,
    hpdi_lower  = hpdi[1],
    hpdi_upper  = hpdi[2],
    eti_lower   = as.numeric(eti[1]),
    eti_upper   = as.numeric(eti[2])
  )
}

#' Construct Table 3: Frequentist OLS vs. Bayesian ABC Comparison (APA 7).
#'
#' @param dominant_params Dominant parameters from Model 2.
#' @param priors Prior distribution bounds.
#' @param post_t0 Posterior statistics for theta_0.
#' @param post_t1 Posterior statistics for theta_1.
#' @return Data frame formatted for APA 7 Table 3.
build_frequentist_bayesian_comparison <- function(dominant_params, priors,
                                                  post_t0, post_t1) {
  p_names <- dominant_params$names
  
  # Row 1: theta_0
  row1 <- data.frame(
    Parameter               = "theta_0 (Intercept)",
    Physical_Role           = dominant_params$roles[1],
    Frequentist_Estimate    = dominant_params$estimates[1],
    Frequentist_SE          = dominant_params$std_errors[1],
    Frequentist_CI95_Lower  = dominant_params$ci_lower[1],
    Frequentist_CI95_Upper  = dominant_params$ci_upper[1],
    Prior_Distribution      = priors[[p_names[1]]]$type,
    Prior_Range             = sprintf("[%0.1f, %0.1f]",
                                      priors[[p_names[1]]]$min,
                                      priors[[p_names[1]]]$max),
    Bayesian_Mean           = post_t0$mean,
    Bayesian_Median         = post_t0$median,
    Bayesian_Mode           = post_t0$mode,
    Bayesian_SD             = post_t0$sd,
    Bayesian_HPDI95_Lower   = post_t0$hpdi_lower,
    Bayesian_HPDI95_Upper   = post_t0$hpdi_upper,
    Bayesian_ETI95_Lower    = post_t0$eti_lower,
    Bayesian_ETI95_Upper    = post_t0$eti_upper,
    Abs_Relative_Diff_Pct   = abs((post_t0$mean - dominant_params$estimates[1]) /
                                  dominant_params$estimates[1]) * 100,
    stringsAsFactors        = FALSE
  )
  
  # Row 2: theta_1
  row2 <- data.frame(
    Parameter               = "theta_1 (x4)",
    Physical_Role           = dominant_params$roles[2],
    Frequentist_Estimate    = dominant_params$estimates[2],
    Frequentist_SE          = dominant_params$std_errors[2],
    Frequentist_CI95_Lower  = dominant_params$ci_lower[2],
    Frequentist_CI95_Upper  = dominant_params$ci_upper[2],
    Prior_Distribution      = priors[[p_names[2]]]$type,
    Prior_Range             = sprintf("[%0.1f, %0.1f]",
                                      priors[[p_names[2]]]$min,
                                      priors[[p_names[2]]]$max),
    Bayesian_Mean           = post_t1$mean,
    Bayesian_Median         = post_t1$median,
    Bayesian_Mode           = post_t1$mode,
    Bayesian_SD             = post_t1$sd,
    Bayesian_HPDI95_Lower   = post_t1$hpdi_lower,
    Bayesian_HPDI95_Upper   = post_t1$hpdi_upper,
    Bayesian_ETI95_Lower    = post_t1$eti_lower,
    Bayesian_ETI95_Upper    = post_t1$eti_upper,
    Abs_Relative_Diff_Pct   = abs((post_t1$mean - dominant_params$estimates[2]) /
                                  dominant_params$estimates[2]) * 100,
    stringsAsFactors        = FALSE
  )
  
  rbind(row1, row2)
}

#' Build tolerance sensitivity table across tolerance levels.
#'
#' @param abc_results List returned by run_rejection_abc.
#' @return Data frame summarizing convergence metrics across tolerance levels.
build_tolerance_sensitivity_table <- function(abc_results) {
  levels <- abc_results$tolerance_levels
  rows <- list()
  
  for (q_name in names(levels)) {
    lvl <- levels[[q_name]]
    t0 <- lvl$theta0_acc
    t1 <- lvl$theta1_acc
    
    t0_hpdi <- compute_hpdi(t0, prob = 0.95)
    t1_hpdi <- compute_hpdi(t1, prob = 0.95)
    r_t0_t1 <- cor(t0, t1)
    
    rows[[q_name]] <- data.frame(
      Tolerance_Quantile      = lvl$quantile,
      Accepted_Count          = lvl$n_accepted,
      Acceptance_Rate_Pct     = (lvl$n_accepted / abc_results$n_sim) * 100,
      Threshold_RMSE_W        = lvl$threshold_rmse,
      Threshold_Euclidean_W   = lvl$threshold_euc,
      Theta0_Mean             = mean(t0),
      Theta0_SD               = sd(t0),
      Theta0_HPDI95_Lower     = t0_hpdi[1],
      Theta0_HPDI95_Upper     = t0_hpdi[2],
      Theta1_Mean             = mean(t1),
      Theta1_SD               = sd(t1),
      Theta1_HPDI95_Lower     = t1_hpdi[1],
      Theta1_HPDI95_Upper     = t1_hpdi[2],
      Posterior_Correlation_r = r_t0_t1,
      stringsAsFactors        = FALSE
    )
  }
  
  do.call(rbind, rows)
}

#' Plot Marginal Posterior Probability Distributions (Figure 12, APA 7).
#'
#' @param abc_results List returned by run_rejection_abc.
#' @param priors Prior distribution bounds.
#' @param post_t0 Posterior statistics for theta_0.
#' @param post_t1 Posterior statistics for theta_1.
#' @param ols_fit Model 2 OLS fit.
#' @return Patchwork dual-panel ggplot object.
plot_marginal_posteriors <- function(abc_results, priors, post_t0, post_t1,
                                     ols_fit) {
  ols_theta <- if (!is.null(ols_fit$theta)) ols_fit$theta else ols_fit$theta_hat
  acc <- abc_results$primary_accepted
  df_plot <- data.frame(
    theta0 = acc$theta0_acc,
    theta1 = acc$theta1_acc
  )
  
  # Density data frames for HPDI shading
  d0 <- density(df_plot$theta0, n = 512)
  df_d0 <- data.frame(x = d0$x, y = d0$y)
  df_d0_hpdi <- subset(df_d0, x >= post_t0$hpdi_lower & x <= post_t0$hpdi_upper)
  
  d1 <- density(df_plot$theta1, n = 512)
  df_d1 <- data.frame(x = d1$x, y = d1$y)
  df_d1_hpdi <- subset(df_d1, x >= post_t1$hpdi_lower & x <= post_t1$hpdi_upper)
  
  # Prior uniform heights
  h_prior_t0 <- priors[[abc_results$p0_name]]$density_val
  h_prior_t1 <- priors[[abc_results$p1_name]]$density_val
  
  # Panel A: theta_0 (Intercept)
  p_t0 <- ggplot(df_plot, aes(x = theta0)) +
    # Histogram of accepted draws
    geom_histogram(aes(y = after_stat(density)), bins = 32,
                   fill = "grey85", colour = "white", linewidth = 0.3) +
    # Shaded 95% HPDI region
    geom_ribbon(data = df_d0_hpdi, aes(x = x, ymin = 0, ymax = y),
                fill = "#1f4e79", alpha = 0.25, inherit.aes = FALSE) +
    # Posterior KDE curve
    geom_line(data = df_d0, aes(x = x, y = y), colour = "black",
              linewidth = 0.85, inherit.aes = FALSE) +
    # Prior uniform line
    annotate("segment", x = 119.0, xend = 121.0,
             y = h_prior_t0, yend = h_prior_t0,
             linetype = "dashed", colour = "grey40", linewidth = 0.6) +
    # Posterior Mean line
    geom_vline(xintercept = post_t0$mean, colour = "#1f4e79",
               linewidth = 0.7, linetype = "solid") +
    # OLS Estimate line
    geom_vline(xintercept = ols_theta[1], colour = "#a33b20",
               linewidth = 0.7, linetype = "dotted") +
    annotate("text", x = 120.25, y = max(d0$y) * 0.95,
             label = sprintf("Mean = %0.3f\nMode = %0.3f\nSD = %0.3f\n95%% HPDI:\n[%0.2f, %0.2f]",
                             post_t0$mean, post_t0$mode, post_t0$sd,
                             post_t0$hpdi_lower, post_t0$hpdi_upper),
             hjust = 0, size = 2.7, family = "sans", colour = "black") +
    coord_cartesian(xlim = c(119.3, 120.75), ylim = c(0, max(d0$y) * 1.15)) +
    labs(
      x = expression(paste("Baseline Static Power ", theta[0], " (Watts)")),
      y = "Posterior Probability Density",
      subtitle = expression(paste("Panel A: Marginal Posterior of ", theta[0], " (Intercept)"))
    ) +
    theme_apa7(base_size = 9)
  
  # Panel B: theta_1 (Network processing)
  p_t1 <- ggplot(df_plot, aes(x = theta1)) +
    # Histogram of accepted draws
    geom_histogram(aes(y = after_stat(density)), bins = 32,
                   fill = "grey85", colour = "white", linewidth = 0.3) +
    # Shaded 95% HPDI region
    geom_ribbon(data = df_d1_hpdi, aes(x = x, ymin = 0, ymax = y),
                fill = "#1f4e79", alpha = 0.25, inherit.aes = FALSE) +
    # Posterior KDE curve
    geom_line(data = df_d1, aes(x = x, y = y), colour = "black",
              linewidth = 0.85, inherit.aes = FALSE) +
    # Prior uniform line
    annotate("segment", x = 4.25, xend = 4.70,
             y = h_prior_t1, yend = h_prior_t1,
             linetype = "dashed", colour = "grey40", linewidth = 0.6) +
    # Posterior Mean line
    geom_vline(xintercept = post_t1$mean, colour = "#1f4e79",
               linewidth = 0.7, linetype = "solid") +
    # OLS Estimate line
    geom_vline(xintercept = ols_theta[2], colour = "#a33b20",
               linewidth = 0.7, linetype = "dotted") +
    annotate("text", x = 4.53, y = max(d1$y) * 0.95,
             label = sprintf("Mean = %0.4f\nMode = %0.4f\nSD = %0.4f\n95%% HPDI:\n[%0.3f, %0.3f]",
                             post_t1$mean, post_t1$mode, post_t1$sd,
                             post_t1$hpdi_lower, post_t1$hpdi_upper),
             hjust = 0, size = 2.7, family = "sans", colour = "black") +
    coord_cartesian(xlim = c(4.31, 4.65), ylim = c(0, max(d1$y) * 1.15)) +
    labs(
      x = expression(paste("Network Load Coefficient ", theta[1], " (W/Gbps)")),
      y = "Posterior Probability Density",
      subtitle = expression(paste("Panel B: Marginal Posterior of ", theta[1], " (Network)"))
    ) +
    theme_apa7(base_size = 9)
  
  # Combine panels via patchwork
  p_t0 + p_t1 +
    plot_layout(ncol = 2) +
    plot_annotation(
      theme = theme(plot.margin = margin(6, 6, 6, 6))
    )
}

#' Plot Joint Posterior Distribution and Covariance Ellipse.
#'
#' @param abc_results List returned by run_rejection_abc.
#' @param ols_fit Model 2 OLS fit.
#' @return ggplot object representing the joint posterior distribution.
plot_joint_posterior <- function(abc_results, ols_fit) {
  ols_theta <- if (!is.null(ols_fit$theta)) ols_fit$theta else ols_fit$theta_hat
  acc <- abc_results$primary_accepted
  df_plot <- data.frame(
    theta0 = acc$theta0_acc,
    theta1 = acc$theta1_acc
  )
  
  ols_t0 <- as.numeric(ols_theta[1])
  ols_t1 <- as.numeric(ols_theta[2])
  post_mean_t0 <- mean(df_plot$theta0)
  post_mean_t1 <- mean(df_plot$theta1)
  r_val <- cor(df_plot$theta0, df_plot$theta1)
  
  ggplot(df_plot, aes(x = theta0, y = theta1)) +
    # Scatter of accepted simulation draws
    geom_point(colour = "grey55", alpha = 0.45, size = 1.3, shape = 16) +
    # 2D Kernel Density contour lines
    geom_density_2d(colour = "#1f4e79", linewidth = 0.65, bins = 7) +
    # Frequentist 95% confidence ellipse based on bivariate normal covariance
    stat_ellipse(level = 0.95, colour = "#a33b20", linetype = "dashed",
                 linewidth = 0.8) +
    # OLS point estimate
    annotate("point", x = ols_t0, y = ols_t1, colour = "#a33b20",
             size = 3.5, shape = 17) +
    # Bayesian posterior mean
    annotate("point", x = post_mean_t0, y = post_mean_t1, colour = "#1f4e79",
             size = 3.5, shape = 19) +
    annotate("text", x = 120.15, y = 4.60,
             label = sprintf("Bayesian Mean: (%.2f, %.3f)\nOLS Estimate: (%.2f, %.3f)\nPosterior Correlation: r = %.3f\nAccepted Draws: N = %d",
                             post_mean_t0, post_mean_t1, ols_t0, ols_t1, r_val, nrow(df_plot)),
             hjust = 0, size = 2.9, family = "sans", colour = "black") +
    coord_cartesian(xlim = c(119.25, 120.80), ylim = c(4.30, 4.65)) +
    labs(
      x = expression(paste("Baseline Static Power ", theta[0], " (Watts)")),
      y = expression(paste("Network Load Coefficient ", theta[1], " (W/Gbps)")),
      subtitle = expression(paste("Joint Posterior Distribution ", p(theta[0], theta[1] ~ "|" ~ y),
                                  " with 95% Confidence Ellipse"))
    ) +
    theme_apa7(base_size = 10)
}

#' Plot ABC Tolerance Sensitivity and Posterior Contraction (Figure 14, APA 7).
#'
#' @param abc_results List returned by run_rejection_abc.
#' @param ols_fit Model 2 OLS fit.
#' @return Patchwork 3-panel ggplot object.
plot_tolerance_convergence <- function(abc_results, ols_fit) {
  ols_theta <- if (!is.null(ols_fit$theta)) ols_fit$theta else ols_fit$theta_hat
  ols_se    <- if (!is.null(ols_fit$se_theta)) ols_fit$se_theta else ols_fit$se
  levels <- abc_results$tolerance_levels
  
  # Assemble multi-level data frame for marginal density comparison
  df_levels <- list()
  for (q_name in names(levels)) {
    lvl <- levels[[q_name]]
    pct_label <- sprintf("alpha == '%s%%'", as.character(lvl$quantile * 100))
    df_levels[[q_name]] <- data.frame(
      tolerance = pct_label,
      quantile  = lvl$quantile,
      theta0    = lvl$theta0_acc,
      theta1    = lvl$theta1_acc,
      stringsAsFactors = FALSE
    )
  }
  df_all_levels <- do.call(rbind, df_levels)
  # Ensure ordered factor for clean legend
  df_all_levels$tolerance <- factor(
    df_all_levels$tolerance,
    levels = c("alpha == '5%'", "alpha == '2%'", "alpha == '1%'", "alpha == '0.5%'")
  )
  
  # Panel A: theta_0 shrinkage across tolerance levels
  p_t0_shrink <- ggplot(df_all_levels, aes(x = theta0, colour = tolerance)) +
    geom_density(linewidth = 0.75) +
    geom_vline(xintercept = ols_theta[1], colour = "black",
               linetype = "dotted", linewidth = 0.6) +
    scale_colour_manual(
      values = c("grey70", "grey50", "#1f4e79", "#a33b20"),
      labels = c("alpha = 5.0%", "alpha = 2.0%", "alpha = 1.0%", "alpha = 0.5%"),
      name = "Tolerance"
    ) +
    coord_cartesian(xlim = c(ols_theta[1] - 2.0, ols_theta[1] + 2.0)) +
    labs(
      x = expression(paste("Baseline Power ", theta[0], " (W)")),
      y = "Posterior Probability Density",
      subtitle = expression(paste("Panel A: ", theta[0], " Shrinkage"))
    ) +
    theme_apa7(base_size = 9) +
    theme(legend.position = "none")
  
  # Panel B: theta_1 shrinkage across tolerance levels
  p_t1_shrink <- ggplot(df_all_levels, aes(x = theta1, colour = tolerance)) +
    geom_density(linewidth = 0.75) +
    geom_vline(xintercept = ols_theta[2], colour = "black",
               linetype = "dotted", linewidth = 0.6) +
    scale_colour_manual(
      values = c("grey70", "grey50", "#1f4e79", "#a33b20"),
      labels = c("alpha = 5.0%", "alpha = 2.0%", "alpha = 1.0%", "alpha = 0.5%"),
      name = "Tolerance"
    ) +
    coord_cartesian(xlim = c(ols_theta[2] - 0.5, ols_theta[2] + 0.5)) +
    labs(
      x = expression(paste("Network Coeff. ", theta[1], " (W/Gbps)")),
      y = "Posterior Probability Density",
      subtitle = expression(paste("Panel B: ", theta[1], " Shrinkage"))
    ) +
    theme_apa7(base_size = 9) +
    theme(
      legend.position = "bottom",
      legend.text = element_text(size = 7.5),
      legend.title = element_text(size = 8, face = "bold")
    )
  
  # Panel C: Posterior Standard Deviation Contraction Curve
  sens_tbl <- build_tolerance_sensitivity_table(abc_results)
  sens_plot_df <- data.frame(
    alpha_pct     = sens_tbl$Tolerance_Quantile * 100,
    rmse_thresh   = sens_tbl$Threshold_RMSE_W,
    theta0_sd     = sens_tbl$Theta0_SD,
    theta1_sd     = sens_tbl$Theta1_SD,
    theta0_ols_se = as.numeric(ols_se[1]),
    theta1_ols_se = as.numeric(ols_se[2])
  )
  
  p_sd_contraction <- ggplot(sens_plot_df, aes(x = alpha_pct)) +
    geom_line(aes(y = theta0_sd, linetype = "theta[0] (Intercept)"),
              colour = "#1f4e79", linewidth = 0.8) +
    geom_point(aes(y = theta0_sd), colour = "#1f4e79", size = 2) +
    geom_hline(aes(yintercept = theta0_ols_se, linetype = "theta[0] Frequentist SE"),
               colour = "#1f4e79", linewidth = 0.5) +
    scale_x_continuous(trans = "reverse", breaks = sens_plot_df$alpha_pct) +
    scale_linetype_manual(
      values = c("theta[0] (Intercept)" = "solid", "theta[0] Frequentist SE" = "dashed"),
      labels = c(expression(paste(SD[post], "(", theta[0], ")")),
                 expression(paste(SE[OLS], "(", theta[0], ")")))
    ) +
    labs(
      x = "Acceptance Tolerance Quantile (%)",
      y = "Posterior SD (W)",
      subtitle = expression(paste("Panel C: ", theta[0], " Contraction"))
    ) +
    theme_apa7(base_size = 9) +
    theme(legend.position = "bottom")
  
  # Shared legend layout
  (p_t0_shrink + p_t1_shrink + p_sd_contraction) +
    plot_layout(ncol = 3) +
    plot_annotation(
      theme = theme(plot.margin = margin(6, 6, 6, 6))
    )
}
