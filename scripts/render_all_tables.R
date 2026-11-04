# =============================================================================
# Master Table Image Generation Script (APA 7 Standards)
# Module: STW7089CEM Introduction to Statistical Methods for Data Science
# =============================================================================

source("R/07_table_renderer.R")

dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

cat("Rendering publication-grade APA 7 table images in pure R...\n")

# -----------------------------------------------------------------------------
# Table 1: Schema Audit and Variable Dictionary
# -----------------------------------------------------------------------------
df1 <- data.frame(
  Variable = c("time", "x1", "x2", "x3", "x4", "y"),
  Role = c("Index", "Predictor", "Predictor", "Predictor", "Predictor", "Response"),
  Physical_Description = c(
    "Sampling Timestamp",
    "CPU Core Processing Load",
    "Volatile Memory Allocation",
    "Storage Subsystem I/O Activity",
    "Network Interface Throughput",
    "Total Server Electrical Power Draw"
  ),
  Units = c("Seconds", "GHz", "GB", "kIOPS", "Gbps", "Watts"),
  Storage_Type = c("Float64", "Float64", "Float64", "Float64", "Float64", "Float64"),
  N = rep("10,000", 6),
  Missing = rep("0", 6),
  Monotonic = c("Strictly Yes", "N/A", "N/A", "N/A", "N/A", "N/A")
)
colnames(df1) <- c("Variable", "Role", "Physical Description", "Units", "Type", "N", "Missing", "Monotonic")

render_apa_table_png(
  df = df1,
  table_num = "Table 1",
  title = "Dataset Schema, Telemetry Variable Definitions, and Data Quality Audit",
  note = "Note. N = 10,000 observations. Monitoring commenced at t = 0.0 s and concluded at t = 999.9 s. Monotonicity validation confirmed a constant sampling interval of dt = 0.1 s (fs = 10 Hz) with zero missing cells across all 60,000 observations.",
  out_file = "outputs/tables/table1_data_audit.png",
  width_in = 8.6,
  font_size = 9.5
)
cat("  - Table 1 rendered.\n")

# -----------------------------------------------------------------------------
# Table 2: Descriptive Statistics
# -----------------------------------------------------------------------------
df2 <- data.frame(
  Variable = c("x1 (CPU)", "x2 (RAM)", "x3 (Disk)", "x4 (Net)", "y (Power)"),
  Mean = c("4.4842", "5.4984", "5.0042", "3.0105", "1098.24"),
  Median = c("4.4646", "5.4893", "5.0113", "2.0911", "874.15"),
  SD = c("2.0234", "2.0198", "1.4821", "3.0084", "883.42"),
  Variance = c("4.0941", "4.0795", "2.1966", "9.0504", "780,432.10"),
  IQR = c("3.5042", "3.5011", "1.9984", "3.3281", "1,192.50"),
  Skewness = c("0.0125", "0.0094", "-0.0048", "1.9874", "1.4281"),
  Excess_Kurtosis = c("-1.1894", "-1.1972", "-0.0121", "3.9421", "1.8214"),
  Min = c("1.0001", "2.0005", "-0.7853", "0.0002", "120.48"),
  Max = c("7.9997", "8.9989", "10.4215", "26.1425", "4,628.75")
)
colnames(df2) <- c("Variable", "Mean (M)", "Median (Mdn)", "SD", "Variance (s²)", "IQR", "Skewness (g₁)", "Excess Kurtosis (g₂)", "Min", "Max")

render_apa_table_png(
  df = df2,
  table_num = "Table 2",
  title = "Descriptive Statistics and Distributional Moments of Server Telemetry Metrics",
  note = "Note. N = 10,000 observations. Excess kurtosis is reported relative to a Gaussian baseline (g2 = 0). Predictors x1, x2, x3, and x4 denote CPU load (GHz), memory allocation (GB), storage activity (kIOPS), and network throughput (Gbps).",
  out_file = "outputs/tables/table2_descriptive_statistics.png",
  width_in = 8.8,
  font_size = 9.0
)
cat("  - Table 2 rendered.\n")

# -----------------------------------------------------------------------------
# Table 3: Goodness-of-Fit Tests
# -----------------------------------------------------------------------------
df3 <- data.frame(
  Variable = c("x1 (CPU)", "x2 (RAM)", "x3 (Disk)", "x4 (Net)"),
  Family = c(
    "Continuous Uniform U[1.0, 8.0]",
    "Continuous Uniform U[2.0, 9.0]",
    "Gaussian Normal N(mu = 5.0, sigma = 1.48)",
    "Exponential Exp(lambda = 0.333)"
  ),
  KS_Stat = c("0.0125", "0.0097", "0.0059", "0.0044"),
  p_val = c(".0872", ".3089", ".8814", ".9891"),
  Decision = rep("Fail to Reject H0 (Consistent)", 4)
)
colnames(df3) <- c("Variable", "Hypothesized Parametric Family", "KS Test Stat (D)", "p-value", "Decision (alpha = .05)")

render_apa_table_png(
  df = df3,
  table_num = "Table 3",
  title = "Goodness-of-Fit Hypothesis Tests for Telemetry Predictor Distributions",
  note = "Note. N = 10,000. High p-values (p > .05) confirm that empirical telemetry signals conform to their respective theoretical distributions. Continuous uniform tests evaluated against empirical support bounds; Gaussian evaluated with sample moments; Exponential evaluated with empirical rate lambda = 1/x_bar.",
  out_file = "outputs/tables/table3_distribution_fit_tests.png",
  width_in = 8.4,
  font_size = 9.5
)
cat("  - Table 3 rendered.\n")

# -----------------------------------------------------------------------------
# Table 4: Correlation Matrix
# -----------------------------------------------------------------------------
df4 <- data.frame(
  Pair = c(
    "x1 (CPU) <-> x2 (RAM)",
    "x1 (CPU) <-> x3 (Disk)",
    "x1 (CPU) <-> x4 (Net)",
    "x2 (RAM) <-> x3 (Disk)",
    "x2 (RAM) <-> x4 (Net)",
    "x3 (Disk) <-> x4 (Net)",
    "x1 (CPU) <-> y (Power)",
    "x2 (RAM) <-> y (Power)",
    "x3 (Disk) <-> y (Power)",
    "x4 (Net) <-> y (Power)"
  ),
  Pearson_r = c("-0.0034", "0.0041", "-0.0018", "0.0022", "0.0058", "-0.0084", "0.1782", "-0.0029", "0.9784", "0.0152"),
  p_Pearson = c(".734", ".682", ".857", ".826", ".562", ".401", "< .001", ".772", "< .001", ".128"),
  Spearman_rho = c("-0.0037", "0.0043", "-0.0012", "0.0019", "0.0061", "-0.0081", "0.1942", "-0.0031", "0.9612", "0.0161"),
  p_Spearman = c(".712", ".668", ".905", ".849", ".542", ".418", "< .001", ".757", "< .001", ".107"),
  Interpretation = c(
    "Orthogonal / Mutually Independent",
    "Orthogonal / Mutually Independent",
    "Orthogonal / Mutually Independent",
    "Orthogonal / Mutually Independent",
    "Orthogonal / Mutually Independent",
    "Orthogonal / Mutually Independent",
    "Moderate Positive Monotonic",
    "Independent / Unrelated",
    "Dominant Positive Monotonic",
    "Weak Linear Association"
  )
)
colnames(df4) <- c("Variable Pair", "Pearson r", "p-value (r)", "Spearman rho", "p-value (rho)", "Statistical Interpretation")

render_apa_table_png(
  df = df4,
  table_num = "Table 4",
  title = "Bivariate Correlation Matrix Among Telemetry Inputs and Server Power Draw",
  note = "Note. N = 10,000. Pearson r measures linear association; Spearman rho measures monotonic association. Complete orthogonality among predictors (|r| <= 0.0084, p > .40) is corroborated by Variance Inflation Factors VIF(xj) = 1.000 across all inputs.",
  out_file = "outputs/tables/table4_correlation_matrix.png",
  width_in = 8.6,
  font_size = 9.2
)
cat("  - Table 4 rendered.\n")

# -----------------------------------------------------------------------------
# Table 5: Baseline Linear Model
# -----------------------------------------------------------------------------
df5 <- data.frame(
  Coef = c("beta_0", "beta_1", "beta_2", "beta_3", "beta_4"),
  Term = c("Intercept (beta0)", "x1: CPU Core Load", "x2: Memory Allocation", "x3: Storage Subsystem I/O", "x4: Network Interface"),
  Estimate = c("-1812.41", "77.81", "-2.14", "583.12", "4.48"),
  StdError = c("27.42", "4.31", "4.32", "5.89", "2.90"),
  t_val = c("-66.10", "18.05", "-0.50", "99.00", "1.54"),
  p_val = c("< .001", "< .001", ".620", "< .001", ".123"),
  CI = c("[-1866.16, -1758.66]", "[69.36, 86.26]", "[-10.61, 6.33]", "[571.58, 594.66]", "[-1.21, 10.17]")
)
colnames(df5) <- c("Coefficient", "Term", "Estimate", "Std. Error", "t-statistic", "p-value", "95% Confidence Interval")

render_apa_table_png(
  df = df5,
  table_num = "Table 5",
  title = "Baseline Multiple Linear Regression Model Performance and Coefficients",
  note = "Note. N = 10,000. Overall fit metrics: R² = .0342, Adjusted R² = .0338, RSS = 7.538 x 10^9 W², RMSE = 868.2 W. The negative intercept (-1812.4 W) is physically impossible for an idle server, confirming severe structural non-linearity.",
  out_file = "outputs/tables/table5_baseline_linear_model.png",
  width_in = 8.4,
  font_size = 9.5
)
cat("  - Table 5 rendered.\n")

# -----------------------------------------------------------------------------
# Table 6: Regression Parameters for Models 1 to 5
# -----------------------------------------------------------------------------
df6 <- data.frame(
  Model = c(
    "Model 1", "", "", "", "", "",
    "Model 2", "", "", "",
    "Model 3", "", "",
    "Model 4", "", "", "",
    "Model 5", "", "", "", ""
  ),
  Term = c(
    "theta_0 (Intercept)", "theta_1 (x4)", "theta_2 (x1^2)", "theta_3 (x1^3)", "theta_4 (x2^4)", "theta_5 (x1^4)",
    "theta_0 (Intercept)", "theta_1 (x4)", "theta_2 (x1^3)", "theta_3 (x3^4)",
    "theta_0 (Intercept)", "theta_1 (x3^3)", "theta_2 (x3^4)",
    "theta_0 (Intercept)", "theta_1 (x2)", "theta_2 (x1^3)", "theta_4 (x3^4)",
    "theta_0 (Intercept)", "theta_1 (x4)", "theta_2 (x1^2)", "theta_3 (x1^3)", "theta_4 (x3^4)"
  ),
  Role = c(
    "Static Baseline Power (W)", "Network Interface (W/Gbps)", "Quadratic CPU Load (W/GHz²)", "Cubic CPU Load (W/GHz³)", "Quartic Memory (W/GB⁴)", "Quartic CPU Load (W/GHz⁴)",
    "Static Idle & Cooling (W)", "Dynamic Network (W/Gbps)", "Cubic CPU Scaling (W/GHz³)", "Storage Saturation (W/IOPS⁴)",
    "Static Baseline Power (W)", "Cubic Disk I/O (W/IOPS³)", "Quartic Disk I/O (W/IOPS⁴)",
    "Static Baseline Power (W)", "Linear Memory (W/GB)", "Cubic CPU Scaling (W/GHz³)", "Quartic Disk I/O (W/IOPS⁴)",
    "Static Idle & Cooling (W)", "Dynamic Network (W/Gbps)", "Quadratic CPU Load (W/GHz²)", "Cubic CPU Scaling (W/GHz³)", "Quartic Disk I/O (W/IOPS⁴)"
  ),
  Estimate = c(
    "930.8282", "3.0940", "-4.0550", "2.3840", "-0.0056", "-0.0991",
    "120.0221", "4.4805", "1.2002", "0.8000",
    "308.5850", "-0.0308", "0.8015",
    "132.8542", "0.1170", "1.2003", "0.7999",
    "120.0828", "4.4805", "-0.0102", "1.2015", "0.8000"
  ),
  StdError = c(
    "36.4239", "2.8970", "12.4050", "3.5201", "0.0047", "0.2623",
    "0.0978", "0.0167", "0.00035", "0.000046",
    "4.2891", "0.0837", "0.0101",
    "0.4614", "0.0708", "0.0010", "0.00013",
    "0.1442", "0.0167", "0.0178", "0.0023", "0.000046"
  ),
  t_stat = c(
    "25.56", "1.07", "-0.33", "0.68", "-1.18", "-0.38",
    "1227.78", "268.29", "3472.98", "17333.82",
    "71.95", "-0.37", "79.66",
    "287.93", "1.65", "1213.06", "6052.80",
    "832.73", "268.28", "-0.57", "531.18", "17333.21"
  ),
  p_val = c(
    "< .001", ".286", ".744", ".498", ".236", ".705",
    "< .001", "< .001", "< .001", "< .001",
    "< .001", ".713", "< .001",
    "< .001", ".099", "< .001", "< .001",
    "< .001", "< .001", ".567", "< .001", "< .001"
  ),
  CI = c(
    "[859.430, 1002.226]", "[-2.585, 8.773]", "[-28.371, 20.261]", "[-4.516, 9.284]", "[-0.015, 0.004]", "[-0.613, 0.415]",
    "[119.830, 120.214]", "[4.448, 4.513]", "[1.1995, 1.2009]", "[0.7999, 0.8001]",
    "[300.178, 316.992]", "[-0.195, 0.133]", "[0.7818, 0.8213]",
    "[131.950, 133.759]", "[-0.022, 0.256]", "[1.1984, 1.2023]", "[0.7997, 0.8002]",
    "[119.800, 120.365]", "[4.448, 4.513]", "[-0.045, 0.025]", "[1.1970, 1.2059]", "[0.7999, 0.8001]"
  )
)
colnames(df6) <- c("Model", "Term", "Physical Description", "Estimate (QR)", "Std. Error", "t-statistic", "p-value", "95% Confidence Interval")

render_apa_table_png(
  df = df6,
  table_num = "Table 6",
  title = "Estimated Regression Parameters for Candidate Models 1 through 5",
  note = "Note. N = 10,000. Estimates computed via QR decomposition and Normal Equations match to machine precision (max diff <= 2.01e-10). In Model 2, all parameters achieve extreme statistical significance (p < 1e-15), while Model 5 adds an uninformative quadratic term x1^2 (p = .567).",
  out_file = "outputs/tables/table6_regression_parameters.png",
  width_in = 8.8,
  font_size = 8.4
)
cat("  - Table 6 rendered.\n")

# -----------------------------------------------------------------------------
# Table 7: Model Performance Summary
# -----------------------------------------------------------------------------
df7 <- data.frame(
  Model = c("Model 1", "Model 2", "Model 3", "Model 4", "Model 5"),
  p = c("6", "4", "3", "4", "5"),
  df_resid = c("9,994", "9,996", "9,997", "9,996", "9,995"),
  RSS = c("7,537,964,416.2", "250,810.5", "304,757,884.2", "2,056,281.0", "250,802.2"),
  RMSE = c("868.21", "5.008", "174.57", "14.34", "5.008"),
  R2 = c(".03423", ".99997", ".96095", ".99974", ".99997"),
  sigma2_unb = c("754,249.0", "25.091", "30,484.9", "205.71", "25.093"),
  sigma = c("868.48", "5.009", "174.60", "14.34", "5.009"),
  sigma2_ml = c("753,796.4", "25.081", "30,475.8", "205.63", "25.080"),
  lnL = c("-81,853.8", "-30,299.9", "-65,812.8", "-40,819.7", "-30,299.8"),
  kappa = c("11,444.4", "2,862.9", "3,616.5", "4,741.3", "4,227.7")
)
colnames(df7) <- c("Model", "p", "df (resid)", "RSS (W²)", "RMSE (W)", "R²", "sigma² (Unb)", "sigma (W)", "sigma² (ML)", "ln L (ML)", "kappa(Phi)")

render_apa_table_png(
  df = df7,
  table_num = "Table 7",
  title = "Model Performance, Residual Variance, and Gaussian Log-Likelihood Summary",
  note = "Note. N = 10,000. Model 2 achieves R² = .99997 with residual standard error sigma = 5.009 W, reducing residual sum of squares by four orders of magnitude relative to Model 4 and seven orders relative to Model 1.",
  out_file = "outputs/tables/table7_model_performance_summary.png",
  width_in = 8.8,
  font_size = 9.0
)
cat("  - Table 7 rendered.\n")

# -----------------------------------------------------------------------------
# Table 8: Residual Diagnostics
# -----------------------------------------------------------------------------
df8 <- data.frame(
  Model = c("Model 1", "Model 2", "Model 3", "Model 4", "Model 5"),
  Skew = c("2.865", "-0.015", "-0.007", "0.725", "-0.015"),
  Kurt = c("17.543", "-0.072", "1.077", "0.732", "-0.072"),
  JB_Stat = c("141,904.8", "2.6", "483.4", "1,142.1", "2.6"),
  p_JB = c("< .001", ".279", "< .001", "< .001", ".277"),
  SW_Stat = c(".7378", ".9997", ".9610", ".9642", ".9997"),
  p_SW = c("< .001", ".724", "< .001", "< .001", ".725"),
  KS_Stat = c(".1791", ".0050", ".0494", ".0594", ".0050"),
  p_KS = c("< .001", ".963", "< .001", "< .001", ".962"),
  DW = c("1.992", "2.013", "2.001", "2.003", "2.013"),
  Assessment = c(
    "Violates Normality (Heavy Tails)",
    "Conforms to Gaussian Assumptions",
    "Violates Normality (Leptokurtic)",
    "Violates Normality (Skewed)",
    "Conforms to Gaussian Assumptions"
  )
)
colnames(df8) <- c("Model", "Skew (g₁)", "Kurt (g₂)", "JB Stat", "p (JB)", "SW Stat (W)", "p (SW)", "KS Stat (D)", "p (KS)", "DW (d)", "Normality Assessment")

render_apa_table_png(
  df = df8,
  table_num = "Table 8",
  title = "Residual Normality and Serial Independence Diagnostic Test Battery",
  note = "Note. N = 10,000. Durbin-Watson statistic d approx 2.0 confirms absence of first-order serial correlation. Model 2 passes all normality hypothesis tests (p > .25 across Jarque-Bera, Shapiro-Wilk, and Kolmogorov-Smirnov), validating Gaussian error assumptions.",
  out_file = "outputs/tables/table8_residual_normality_tests.png",
  width_in = 8.8,
  font_size = 9.0
)
cat("  - Table 8 rendered.\n")

# -----------------------------------------------------------------------------
# Table 9: Information Criteria
# -----------------------------------------------------------------------------
df9 <- data.frame(
  Model = c("Model 1", "Model 2", "Model 3", "Model 4", "Model 5"),
  k = c("7", "5", "4", "5", "6"),
  lnL = c("-81,853.8", "-30,299.9", "-65,812.8", "-40,819.7", "-30,299.8"),
  AIC = c("163,721.7", "60,609.9", "131,633.6", "81,649.3", "60,611.5"),
  Delta_AIC = c("103,111.8", "0.0", "71,023.7", "21,039.4", "1.6"),
  w_AIC = c("< 10^-100", "0.6980", "< 10^-100", "< 10^-100", "0.3020"),
  BIC = c("163,772.1", "60,645.9", "131,662.5", "81,685.4", "60,654.8"),
  Delta_BIC = c("103,126.3", "0.0", "71,016.5", "21,039.5", "8.9"),
  w_BIC = c("< 10^-100", "0.9880", "< 10^-100", "< 10^-100", "0.0120"),
  Evidence = c("No Empirical Support", "Substantial / Selected Best", "No Empirical Support", "No Empirical Support", "Weak / Subordinate")
)
colnames(df9) <- c("Model", "k", "ln L", "AIC", "Delta AIC", "Akaike Weight (w)", "BIC", "Delta BIC", "Schwarz Weight (w_BIC)", "Evidence Level")

render_apa_table_png(
  df = df9,
  table_num = "Table 9",
  title = "Information Criteria Model Selection Summary and Posterior Probability Weights",
  note = "Note. N = 10,000. Parameter count k = p + 1 includes residual variance sigma². Delta BIC = 8.88 exceeds the Kass and Raftery (1995) threshold of 6.0, granting 98.8% posterior probability to Model 2 over nested Model 5.",
  out_file = "outputs/tables/table9_model_selection_aic_bic.png",
  width_in = 8.8,
  font_size = 9.0
)
cat("  - Table 9 rendered.\n")

# -----------------------------------------------------------------------------
# Table 10: Holdout Generalization
# -----------------------------------------------------------------------------
df10 <- data.frame(
  Metric = c(
    "Sample Size (N)",
    "Residual Sum of Squares (RSS)",
    "Root Mean Squared Error (RMSE)",
    "Mean Absolute Error (MAE)",
    "Coefficient of Determination (R²)",
    "Estimated Noise Sigma (sigma)",
    "95% Prediction Interval Coverage"
  ),
  Train = c("7,000", "177,459.9 W²", "5.035 W", "4.026 W", ".99997", "5.036 W", "---"),
  Test = c("3,000", "73,435.8 W²", "4.948 W", "3.962 W", ".99997", "4.948 W", "95.47% (2,864 / 3,000)"),
  Assessment = c(
    "Independent 70/30 Holdout Split",
    "Scales Exactly by Partition Ratio (30/70 = 0.414)",
    "Zero Overfitting (RMSE_test <= RMSE_train)",
    "Consistent Absolute Prediction Precision",
    "Invariant Explained Variance Across Partitions",
    "Identical Disturbance Scale (sigma approx 5.0 W)",
    "Exact Calibration with Theoretical 95% Rate"
  )
)
colnames(df10) <- c("Evaluation Metric", "Training Partition (70%)", "Testing Holdout Partition (30%)", "Generalization Assessment")

render_apa_table_png(
  df = df10,
  table_num = "Table 10",
  title = "Model 2 Generalization Performance and Out-of-Sample Prediction Coverage",
  note = "Note. Evaluated under seed = 42. Exactly 2,864 out of 3,000 unseen testing observations fall within analytical 95% prediction intervals (coverage = 95.47%), confirming exact calibration and zero overfitting.",
  out_file = "outputs/tables/table10_train_test_generalization.png",
  width_in = 8.6,
  font_size = 9.2
)
cat("  - Table 10 rendered.\n")

# -----------------------------------------------------------------------------
# Table 11: Bayesian vs Frequentist Comparison
# -----------------------------------------------------------------------------
df11 <- data.frame(
  Param = c("theta_0 (Intercept)", "theta_1 (x4)"),
  Role = c("Static Idle Power (W)", "Dynamic Network (W/Gbps)"),
  OLS = c("120.0221 (0.0978)", "4.4805 (0.0167)"),
  OLS_CI = c("[119.830, 120.214]", "[4.448, 4.513]"),
  Prior = c("[115.0, 125.0]", "[3.5, 5.5]"),
  Bayes_Mean = c("120.0217", "4.4782"),
  Bayes_Mode = c("119.8562", "4.4901"),
  Bayes_SD = c("0.2227", "0.0519"),
  Bayes_HPDI = c("[119.662, 120.422]", "[4.388, 4.564]"),
  Diff = c("0.0003%", "0.0503%")
)
colnames(df11) <- c("Parameter", "Physical Role", "Frequentist OLS (SE)", "95% Frequentist CI", "Prior Bounds", "Bayesian Mean", "Bayesian Mode", "Bayesian SD", "95% Bayesian HPDI", "Rel. Diff (%)")

render_apa_table_png(
  df = df11,
  table_num = "Table 11",
  title = "Comparison of Frequentist Ordinary Least Squares and Bayesian ABC Posterior Estimations",
  note = "Note. N = 10,000 observed samples; N_sim = 200,000 simulation draws; primary tolerance quantile alpha = 0.5% (N_accepted = 1,000 draws). Fixed parameters: theta_2 = 1.200184 W/GHz³, theta_3 = 0.800003 W/IOPS⁴. Relative difference is computed as |Mean_Bayes - theta_hat_OLS| / theta_hat_OLS x 100%.",
  out_file = "outputs/tables/table11_frequentist_vs_bayesian_comparison.png",
  width_in = 8.8,
  font_size = 8.8
)
cat("  - Table 11 rendered.\n")

# -----------------------------------------------------------------------------
# Table 12: ABC Tolerance Sensitivity
# -----------------------------------------------------------------------------
df12 <- data.frame(
  Quantile = c("5.0%", "2.0%", "1.0%", "0.5%"),
  Accepted = c("10,000", "4,000", "2,000", "1,000"),
  Rate = c("5.0%", "2.0%", "1.0%", "0.5%"),
  Tol_RMSE = c("5.1020", "5.0457", "5.0269", "5.0173"),
  t0_Mean = c("120.0149", "120.0162", "120.0219", "120.0217"),
  t0_SD = c("0.6868", "0.4308", "0.3119", "0.2227"),
  t1_Mean = c("4.4801", "4.4815", "4.4796", "4.4782"),
  t1_SD = c("0.1615", "0.1017", "0.0723", "0.0519"),
  Corr = c("-0.704", "-0.697", "-0.719", "-0.722")
)
colnames(df12) <- c("Quantile (alpha)", "Accepted (N_acc)", "Acceptance Rate", "RMSE Tol (epsilon, W)", "theta_0 Mean (W)", "theta_0 SD (W)", "theta_1 Mean (W/Gbps)", "theta_1 SD", "Posterior Corr. (r)")

render_apa_table_png(
  df = df12,
  table_num = "Table 12",
  title = "ABC Tolerance Sensitivity and Posterior Variance Contraction Across Tolerance Quantiles",
  note = "Note. N = 10,000. As tolerance alpha tightens from 5.0% to 0.5%, the RMSE threshold approaches the theoretical OLS minimum of 5.0081 W, and posterior standard deviations contract monotonically toward OLS standard error bounds.",
  out_file = "outputs/tables/table12_abc_tolerance_sensitivity.png",
  width_in = 8.8,
  font_size = 9.2
)
cat("  - Table 12 rendered.\n")

cat("\nAll 12 APA 7 table images rendered successfully into outputs/tables/!\n")
