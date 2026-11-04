# =============================================================================
# 02_regression_engine.R
# Coursework: STW7089CEM Introduction to Statistical Methods for Data Science
# Task 2: Regression: Modeling the Relationship Between Server Metrics
#
# Tasks covered:
#   Task 2.1: Model parameter estimation using least squares (Normal equations
#             and numerically stable QR decomposition)
#   Task 2.2: Compute residual errors for each candidate model
#   Task 2.3: Estimate noise variance (unbiased and Maximum Likelihood)
#   Task 2.4: Calculate Gaussian log-likelihood for each candidate model
#
# Candidate Model Specifications:
#   Model 1: y = theta_1*x4 + theta_2*x1^2 + theta_3*x1^3 + theta_4*x2^4 +
#                theta_5*x1^4 + theta_0 + e     (p = 6)
#   Model 2: y = theta_1*x4 + theta_2*x1^3 + theta_3*x3^4 + theta_0 + e (p = 4)
#   Model 3: y = theta_1*x3^3 + theta_2*x3^4 + theta_0 + e               (p = 3)
#   Model 4: y = theta_1*x2 + theta_2*x1^3 + theta_4*x3^4 + theta_0 + e  (p = 4)
#   Model 5: y = theta_1*x4 + theta_2*x1^2 + theta_3*x1^3 + theta_4*x3^4 +
#                theta_0 + e                   (p = 5)
# =============================================================================

#' Model metadata dictionary defining term names, formulas, and physical roles.
model_specifications <- function() {
  list(
    Model1 = list(
      name         = "Model 1",
      formula_str  = "y = theta_0 + theta_1*x4 + theta_2*x1^2 + theta_3*x1^3 + theta_4*x2^4 + theta_5*x1^4",
      term_names   = c("theta_0 (Intercept)", "theta_1 (x4)", "theta_2 (x1^2)",
                       "theta_3 (x1^3)", "theta_4 (x2^4)", "theta_5 (x1^4)"),
      physical_roles = c("Static Baseline Power (W)", "Network Interface (W/Gbps)",
                         "Quadratic CPU Load (W/GHz^2)", "Cubic CPU Load (W/GHz^3)",
                         "Quartic Memory Pressure (W/GB^4)", "Quartic CPU Load (W/GHz^4)"),
      p            = 6
    ),
    Model2 = list(
      name         = "Model 2",
      formula_str  = "y = theta_0 + theta_1*x4 + theta_2*x1^3 + theta_3*x3^4",
      term_names   = c("theta_0 (Intercept)", "theta_1 (x4)", "theta_2 (x1^3)",
                       "theta_3 (x3^4)"),
      physical_roles = c("Static Idle Leakage & Cooling (W)",
                         "Dynamic Network Processing (W/Gbps)",
                         "Dynamic CPU Scaling via DVFS Law (W/GHz^3)",
                         "Storage Subsystem Saturation (W/IOPS^4)"),
      p            = 4
    ),
    Model3 = list(
      name         = "Model 3",
      formula_str  = "y = theta_0 + theta_1*x3^3 + theta_2*x3^4",
      term_names   = c("theta_0 (Intercept)", "theta_1 (x3^3)", "theta_2 (x3^4)"),
      physical_roles = c("Static Baseline Power (W)", "Cubic Disk I/O (W/IOPS^3)",
                         "Quartic Disk I/O (W/IOPS^4)"),
      p            = 3
    ),
    Model4 = list(
      name         = "Model 4",
      formula_str  = "y = theta_0 + theta_1*x2 + theta_2*x1^3 + theta_4*x3^4",
      term_names   = c("theta_0 (Intercept)", "theta_1 (x2)", "theta_2 (x1^3)",
                       "theta_4 (x3^4)"),
      physical_roles = c("Static Baseline Power (W)", "Linear Memory Allocation (W/GB)",
                         "Cubic CPU Load via DVFS (W/GHz^3)", "Quartic Disk I/O (W/IOPS^4)"),
      p            = 4
    ),
    Model5 = list(
      name         = "Model 5",
      formula_str  = "y = theta_0 + theta_1*x4 + theta_2*x1^2 + theta_3*x1^3 + theta_4*x3^4",
      term_names   = c("theta_0 (Intercept)", "theta_1 (x4)", "theta_2 (x1^2)",
                       "theta_3 (x1^3)", "theta_4 (x3^4)"),
      physical_roles = c("Static Idle Leakage & Cooling (W)", "Dynamic Network Processing (W/Gbps)",
                         "Quadratic CPU Load (Uninformative Noise, p > .05)",
                         "Cubic CPU Load via DVFS (W/GHz^3)", "Quartic Disk I/O (W/IOPS^4)"),
      p            = 5
    )
  )
}

#' Construct design matrix Phi for a specified candidate model.
#'
#' @param df Data frame containing columns x1, x2, x3, x4
#' @param model_id Integer (1 to 5) or character ("Model1" to "Model5")
#' @return Matrix Phi of dimension N x p with column names
build_design_matrix <- function(df, model_id) {
  if (is.numeric(model_id)) {
    model_id <- paste0("Model", model_id)
  }
  
  n <- nrow(df)
  x1 <- df$x1
  x2 <- df$x2
  x3 <- df$x3
  x4 <- df$x4
  
  if (model_id == "Model1") {
    Phi <- cbind(
      Intercept = rep(1, n),
      x4        = x4,
      x1_sq     = x1^2,
      x1_cube   = x1^3,
      x2_quad   = x2^4,
      x1_quad   = x1^4
    )
  } else if (model_id == "Model2") {
    Phi <- cbind(
      Intercept = rep(1, n),
      x4        = x4,
      x1_cube   = x1^3,
      x3_quad   = x3^4
    )
  } else if (model_id == "Model3") {
    Phi <- cbind(
      Intercept = rep(1, n),
      x3_cube   = x3^3,
      x3_quad   = x3^4
    )
  } else if (model_id == "Model4") {
    Phi <- cbind(
      Intercept = rep(1, n),
      x2        = x2,
      x1_cube   = x1^3,
      x3_quad   = x3^4
    )
  } else if (model_id == "Model5") {
    Phi <- cbind(
      Intercept = rep(1, n),
      x4        = x4,
      x1_sq     = x1^2,
      x1_cube   = x1^3,
      x3_quad   = x3^4
    )
  } else {
    stop("Unknown model_id: ", model_id)
  }
  
  as.matrix(Phi)
}

#' Fit candidate polynomial model using both Normal Equations and QR decomposition.
#'
#' Evaluates Tasks 2.1, 2.2, 2.3, and 2.4.
#'
#' @param Phi Design matrix (N x p)
#' @param y Response vector (N x 1)
#' @param model_id Model identifier ("Model1" through "Model5")
#' @return Fitted model object list containing parameters, diagnostics, residuals
fit_polynomial_model <- function(Phi, y, model_id = "Model2") {
  if (is.numeric(model_id)) model_id <- paste0("Model", model_id)
  specs <- model_specifications()[[model_id]]
  
  N <- length(y)
  p <- ncol(Phi)
  df_resid <- N - p
  
  # ---------------------------------------------------------------------------
  # Task 2.1: Model Parameter Estimation
  # Method A: Closed-form Normal Equations: theta = (Phi^T Phi)^(-1) Phi^T y
  # Method B: Numerically stable QR decomposition: Phi = Q R => R theta = Q^T y
  # ---------------------------------------------------------------------------
  PhiT_Phi <- t(Phi) %*% Phi
  PhiT_y   <- t(Phi) %*% y
  
  # Condition numbers (2-norm)
  svd_phi     <- svd(Phi)$d
  cond_phi    <- svd_phi[1] / svd_phi[length(svd_phi)]
  cond_normal <- cond_phi^2
  
  # Normal Equations point estimates
  theta_normal <- as.vector(solve(PhiT_Phi) %*% PhiT_y)
  
  # QR Decomposition point estimates
  qr_decomp  <- qr(Phi)
  theta_qr   <- as.vector(qr.solve(qr_decomp, y))
  
  # Max absolute numerical discrepancy between Normal Equations and QR
  ne_qr_discrepancy <- max(abs(theta_normal - theta_qr))
  
  # ---------------------------------------------------------------------------
  # Task 2.2: Compute Residual Errors
  # e = y - Phi * theta
  # ---------------------------------------------------------------------------
  y_hat     <- as.vector(Phi %*% theta_qr)
  residuals <- as.vector(y - y_hat)
  
  RSS  <- sum(residuals^2)
  MSE  <- RSS / N
  RMSE <- sqrt(MSE)
  
  y_mean <- mean(y)
  TSS    <- sum((y - y_mean)^2)
  R2     <- 1 - (RSS / TSS)
  R2_adj <- 1 - ((RSS / df_resid) / (TSS / (N - 1)))
  
  # ---------------------------------------------------------------------------
  # Task 2.3: Estimate Noise Variance
  # Unbiased: sigma^2 = RSS / (N - p)
  # Maximum Likelihood (ML): sigma_ML^2 = RSS / N
  # ---------------------------------------------------------------------------
  sigma2_unbiased <- RSS / df_resid
  sigma_unbiased  <- sqrt(sigma2_unbiased)
  
  sigma2_ml       <- RSS / N
  sigma_ml        <- sqrt(sigma2_ml)
  
  # ---------------------------------------------------------------------------
  # Task 2.4: Calculate Gaussian Log-Likelihood
  # ln L(theta, sigma_ML^2) = -N/2 * ln(2*pi) - N/2 * ln(sigma_ML^2) - RSS / (2*sigma_ML^2)
  #                         = -N/2 * [ln(2*pi * sigma_ML^2) + 1]
  # ---------------------------------------------------------------------------
  log_likelihood_ml <- -0.5 * N * (log(2 * pi * sigma2_ml) + 1)
  
  # Also compute log-likelihood evaluated at unbiased variance for comparison
  log_likelihood_unbiased <- -0.5 * N * log(2 * pi * sigma2_unbiased) - (0.5 * RSS / sigma2_unbiased)
  
  # ---------------------------------------------------------------------------
  # Statistical Inference on Estimated Parameters (Covariance, SE, t, p-values)
  # Cov(theta) = sigma^2 * (Phi^T Phi)^(-1) via R matrix inverse of QR
  # ---------------------------------------------------------------------------
  R_mat <- qr.R(qr_decomp)
  cov_theta <- sigma2_unbiased * chol2inv(R_mat)
  se_theta  <- sqrt(diag(cov_theta))
  t_stat    <- theta_qr / se_theta
  p_values  <- 2 * stats::pt(-abs(t_stat), df = df_resid)
  
  t_crit <- stats::qt(0.975, df = df_resid)
  ci_lower <- theta_qr - t_crit * se_theta
  ci_upper <- theta_qr + t_crit * se_theta
  
  param_table <- data.frame(
    Model            = model_id,
    Term             = specs$term_names,
    Physical_Role    = specs$physical_roles,
    Estimate_QR      = theta_qr,
    Estimate_NE      = theta_normal,
    Std_Error        = se_theta,
    t_statistic      = t_stat,
    p_value          = p_values,
    CI_95_Lower      = ci_lower,
    CI_95_Upper      = ci_upper,
    stringsAsFactors = FALSE
  )
  
  list(
    model_id                = model_id,
    formula                 = specs$formula_str,
    p                       = p,
    N                       = N,
    df_resid                = df_resid,
    theta                   = theta_qr,
    theta_normal            = theta_normal,
    cov_theta               = cov_theta,
    se_theta                = se_theta,
    param_table             = param_table,
    fitted_values           = y_hat,
    residuals               = residuals,
    RSS                     = RSS,
    MSE                     = MSE,
    RMSE                    = RMSE,
    TSS                     = TSS,
    R2                      = R2,
    R2_adj                  = R2_adj,
    sigma2_unbiased         = sigma2_unbiased,
    sigma_unbiased          = sigma_unbiased,
    sigma2_ml               = sigma2_ml,
    sigma_ml                = sigma_ml,
    log_likelihood_ml       = log_likelihood_ml,
    log_likelihood_unbiased = log_likelihood_unbiased,
    cond_phi                = cond_phi,
    cond_normal             = cond_normal,
    ne_qr_discrepancy       = ne_qr_discrepancy
  )
}

#' Fit all 5 candidate polynomial regression models on a dataset.
#'
#' @param df Data frame with x1, x2, x3, x4, y
#' @return List of 5 fitted model objects
fit_all_candidate_models <- function(df) {
  y <- df$y
  models <- list()
  for (i in 1:5) {
    m_id <- paste0("Model", i)
    Phi  <- build_design_matrix(df, m_id)
    models[[m_id]] <- fit_polynomial_model(Phi, y, model_id = m_id)
  }
  models
}

#' Combine parameter estimates across all 5 models into an APA 7 table.
#'
#' @param models_list List of fitted models from fit_all_candidate_models()
#' @return Data frame formatted for APA 7 publication
compile_parameters_table <- function(models_list) {
  do.call(rbind, lapply(models_list, function(m) m$param_table))
}

#' Summary performance table across all 5 models (Tasks 2.1 - 2.4).
#'
#' @param models_list List of fitted models from fit_all_candidate_models()
#' @return Data frame summarizing RSS, variance, R2, Log-Likelihood
compile_performance_summary <- function(models_list) {
  rows <- lapply(models_list, function(m) {
    data.frame(
      Model           = m$model_id,
      Formula         = m$formula,
      Parameters_p    = m$p,
      Resid_DF        = m$df_resid,
      RSS             = m$RSS,
      RMSE            = m$RMSE,
      R_Squared       = m$R2,
      Adj_R_Squared   = m$R2_adj,
      Sigma2_Unbiased = m$sigma2_unbiased,
      Sigma_Unbiased  = m$sigma_unbiased,
      Sigma2_ML       = m$sigma2_ml,
      Sigma_ML        = m$sigma_ml,
      Log_Likelihood  = m$log_likelihood_ml,
      Cond_Phi        = m$cond_phi,
      Cond_PhiT_Phi   = m$cond_normal,
      NE_QR_Discrep   = m$ne_qr_discrepancy,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
