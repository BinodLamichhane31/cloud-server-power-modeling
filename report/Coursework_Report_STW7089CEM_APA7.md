# Modeling Cloud Server Power Consumption Using Polynomial Regression and Approximate Bayesian Computation

**Module:** STW7089CEM Introduction to Statistical Methods for Data Science  
**Academic Style:** American Psychological Association (APA) 7th Edition  
**Target Specification:** Master Level Academic Coursework Report (3,000–4,000 Words)

---

# Author Note
This coursework report investigates empirical telemetry from enterprise cloud server infrastructure to characterize, model, and infer power consumption dynamics across heterogeneous computational workloads. All statistical analyses, closed-form matrix calculations, diagnostic tests, and simulation algorithms were developed and executed using pure R (Version 4.4.1). Complete annotated code listings, reproducible master execution scripts, and supplementary artifact tables are provided in the appendices and accompanying project repository.

---

# Abstract
Modern cloud data centers face stringent operational challenges regarding electrical provisioning, thermal management, and carbon efficiency. Accurate predictive modeling of server power consumption as a function of multi-subsystem resource utilization is essential for dynamic power capping and workload scheduling. This study presents an end-to-end statistical framework to model server power consumption using 10,000 synchronous telemetry observations of processor core load ($x_1$), memory utilization ($x_2$), storage I/O operations ($x_3$), and network throughput ($x_4$). Exploratory data analysis identified parametric distributions across subsystem metrics, verified temporal stationarity and predictor orthogonality ($\text{VIF} \approx 1.000$), and demonstrated the failure of multiple linear regression ($R^2 = .0342$). Five candidate polynomial models were formulated and estimated using both closed-form Normal Equations and numerically stable QR decomposition. Information-theoretic criteria ($\text{AIC} = 60,609.9; \text{BIC} = 60,645.9$), supported by nested analysis of variance ($F = 0.328, p = .567$), definitively selected Model 2 ($y = \theta_0 + \theta_1 x_4 + \theta_2 x_1^3 + \theta_3 x_3^4 + \epsilon$) as the true data-generating process ($R^2 = .99997, \hat{\sigma} = 5.009\text{ W}$). Model 2 residuals satisfied Gaussian assumptions across a formal testing battery (Kolmogorov-Smirnov $p = .963$, Jarque-Bera $p = .279$, Shapiro-Wilk $p = .724$). On an unseen 30% holdout split ($N = 3,000$), Model 2 achieved an empirical 95% prediction interval coverage of 95.47%. Finally, vectorized Rejection Approximate Bayesian Computation (ABC) was conducted for the two dominant parameters ($\theta_0$ and $\theta_1$). Posterior means converged to within 0.05% of Frequentist estimates, validating the Bernstein-von Mises theorem, while uncovering negative posterior parameter coupling ($r = -0.722$) driven by the non-negative support of network throughput. Physical interpretations and data center power management implications are discussed.

*Keywords:* Cloud Server Power Modeling, Polynomial Regression, QR Decomposition, Model Selection, Residual Diagnostics, Approximate Bayesian Computation (ABC), Highest Posterior Density Interval, APA 7th Edition.

---

# Introduction

Electrical energy expenditure constitutes the primary operational cost in cloud data centers, directly constraining infrastructure density, cooling overhead, and carbon efficiency (Barroso et al., 2018). In dual-socket rack server architecture, aggregate electrical power draw varies dynamically across four primary subsystems: the central processing unit (CPU), volatile memory (RAM), secondary storage, and network interface controllers (NICs). Because electrical over-provisioning requires excessive capital expenditure while under-provisioning risks tripping rack power distribution units (PDUs), facility operators rely on mathematical power models for dynamic power capping, energy-aware virtual machine placement, and proactive thermal management.

Semiconductor power dissipation in complementary metal-oxide-semiconductor (CMOS) digital logic comprises static leakage and dynamic switching power (Rabaey et al., 2003):
$$P_{total} = P_{static} + P_{dynamic} = V_{dd} I_{leak} + \alpha C_{eff} V_{dd}^2 f$$
where $V_{dd}$ is supply voltage, $I_{leak}$ denotes sub-threshold leakage current, $\alpha$ is the switching activity factor, $C_{eff}$ is load capacitance, and $f$ is operational clock frequency.

Under dynamic voltage and frequency scaling (DVFS), modern operating system governors modulate clock frequency $f$ proportionally to workload intensity, concurrently scaling voltage $V_{dd} \propto f$. Because dynamic power scales with $V_{dd}^2 f$, processor power exhibits a cubic relationship with operational frequency ($P_{dynamic} \propto f^3$). Similarly, secondary storage subsystems exhibit non-linear power consumption during heavy queue saturation due to write amplification, controller direct memory access (DMA) overhead, and flash translation layer (FTL) wear leveling.

Despite these physical phenomena, industrial monitoring architectures frequently rely on simplistic linear approximations that fail to capture non-linear resource interactions. This investigation addresses this limitation by developing an end-to-end statistical modeling framework in pure R (Version 4.4.1), structured into three core components:
1. **Task 1: Preliminary Data Analysis:** Ingest and audit 10,000 synchronized telemetry observations, evaluate temporal stationarity, identify underlying parametric distributions, quantify dependency structures, and demonstrate baseline linear model failure.
2. **Task 2: Regression Modeling and Diagnostics:** Formulate five candidate polynomial models, estimate parameter vectors via closed-form Normal Equations and QR decomposition, compute variance estimators and Gaussian log-likelihoods, conduct residual hypothesis testing, perform information-theoretic model selection (AIC, AICc, BIC, nested ANOVA), and validate out-of-sample generalization with analytical 95% prediction intervals.
3. **Task 3: Approximate Bayesian Computation:** Implement a high-performance vectorized Rejection ABC simulation engine to infer posterior probability distributions for the two dominant model parameters, evaluate tolerance sensitivity, construct 95% Highest Posterior Density Intervals (HPDI), explain bivariate parameter coupling, and contrast Bayesian subjective credible intervals against Frequentist confidence intervals.

---

# Task 1: Preliminary Data Analysis

## Task 1.1: Data Ingestion, Schema Audit, and Sampling Characteristics
The experimental dataset comprises three synchronized files: `X.csv` containing four subsystem activity metrics, `y.csv` recording total server power draw measured in Watts, and `time.csv` providing sampling timestamps in seconds. Telemetry ingestion was executed via a dedicated pipeline ([`00_utils_io.R`](file:///Users/binodlamichhane/Documents/cloud-server-power-modeling/R/00_utils_io.R)) that audits schema conformity, detects missing observations, and handles floating-point timestamp sequences.

Table 1 summarizes the structural audit of the ingested telemetry signals.

**Table 1**  
*Dataset Schema, Telemetry Variable Definitions, and Data Quality Audit*

![Table 1: Dataset Schema and Data Quality Audit](tables/table1_data_audit.png){width=100%}

*Note.* $N = 10,000$ observations. Monitoring commenced at $t = 0.0\text{ s}$ and concluded at $t = 999.9\text{ s}$. Monotonicity validation confirmed a constant sampling interval of $\Delta t = 0.1\text{ s}$ ($f_s = 10\text{ Hz}$) with zero missing cells across all 60,000 observations.

Inspection of the temporal grid verified that measurements were collected at an invariant sampling rate of $10\text{ Hz}$ across a continuous monitoring window of $999.9\text{ seconds}$ (approximately $16.67\text{ minutes}$) with zero missing values across all $60,000$ data cells. Total power draw ($y$) exhibits substantial dynamic range, oscillating between an idle baseline of approximately $120\text{ W}$ and workload-induced peaks exceeding $4,500\text{ W}$ (Figure 1). High-resolution inspection across a 15-second window (Figure 1b) indicates rapid, non-monotonic burstiness across all input channels.

**Figure 1**  
*Synchronous Multi-Panel Time-Series Telemetry and Total Power Consumption Profiles*

![Figure 1: Synchronous Multi-Panel Time-Series Telemetry](figures/fig1_timeseries_telemetry.png){width=95%}

*Note.* $N = 10,000$ telemetry observations at $f_s = 10\text{ Hz}$ ($\Delta t = 0.1\text{ s}$). Subsystems comprise CPU clock speed ($x_1$), RAM allocation ($x_2$), storage I/O ($x_3$), and network throughput ($x_4$) plotted alongside total electrical power draw ($y$).

**Figure 1b**  
*High-Resolution Time-Series Telemetry Zoom Across 15-Second Operational Window*

![Figure 1b: High-Resolution Time-Series Telemetry Zoom](figures/fig1b_timeseries_zoom.png){width=95%}

*Note.* Workload burstiness across a 15-second slice ($t \in [100.0, 115.0]\text{ s}$) demonstrating rapid high-frequency fluctuations.

Sample Autocorrelation Functions (ACF) and Partial Autocorrelation Functions (PACF) up to lag $k = 40$ (Figure 2) drop immediately into the 95% Bartlett confidence band ($\pm 1.96/\sqrt{N} = \pm 0.0196$) at lag $k = 1$: $r_1(x_1) = 0.004$, $r_1(x_2) = -0.009$, $r_1(x_3) = 0.011$, and $r_1(x_4) = -0.003$. Augmented Dickey-Fuller (ADF) tests rejected the null hypothesis of a unit root ($p < .01$), confirming that all inputs behave as strictly stationary stochastic processes.

**Figure 2**  
*Sample Autocorrelation (ACF) and Partial Autocorrelation (PACF) Diagnostic Profiles*

![Figure 2: Sample Autocorrelation and Partial Autocorrelation Profiles](figures/fig2_acf_pacf.png){width=95%}

*Note.* ACF and PACF computed up to lag $k = 40$. Dashed blue lines indicate 95% Bartlett confidence limits ($\pm 1.96/\sqrt{N} = \pm 0.0196$).

## Task 1.2: Distribution for Each Signal and Parametric Goodness-of-Fit
To characterize telemetry properties, non-parametric sample moments were computed: mean ($M$), median ($Mdn$), standard deviation ($SD$), sample variance ($s^2$), interquartile range ($IQR$), Fisher-Pearson standardized skewness ($g_1$), and excess kurtosis ($g_2$) (Table 2).

**Table 2**  
*Descriptive Statistics and Distributional Moments of Server Telemetry Metrics*

![Table 2: Descriptive Statistics of Server Telemetry](tables/table2_descriptive_statistics.png){width=100%}

*Note.* $N = 10,000$ observations. Excess kurtosis is reported relative to a Gaussian baseline ($g_2 = 0$). Predictors $x_1, x_2, x_3$, and $x_4$ denote CPU load (GHz), memory allocation (GB), storage activity (kIOPS), and network throughput (Gbps).

The moments reveal three distinct parametric families:
* **Processor ($x_1$) and Memory ($x_2$):** Both exhibit excess kurtosis matching the theoretical platykurtic bound of continuous uniform distributions: $g_2(\mathcal{U}[a, b]) = -1.200$ ($g_2(x_1) = -1.1894, g_2(x_2) = -1.1972$), with sample variances matching theoretical uniform variance $\sigma^2 = (b-a)^2/12 \approx 4.083$ over $x_1 \sim \mathcal{U}[1, 8]\text{ GHz}$ and $x_2 \sim \mathcal{U}[2, 9]\text{ GB}$.
* **Storage ($x_3$):** Conforms to a Gaussian distribution ($M = 5.0042, Mdn = 5.0113, g_1 = -0.0048, g_2 = -0.0121$), yielding $x_3 \sim \mathcal{N}(5.0, 1.48^2)$. Exactly 5 observations are negative ($\min = -0.7853$), matching the expected theoretical tail: $P(X \le 0) = \Phi(-3.376) \approx 0.00037 \implies 10,000 \times 0.00037 \approx 4$ samples.
* **Network ($x_4$):** Strictly non-negative ($\min = 0.0002\text{ Gbps}$), with empirical mean ($3.0105$) matching standard deviation ($3.0084$), skewness $g_1 \approx 2.0$, and kurtosis $g_2 \approx 4.0$, confirming an exponential distribution: $x_4 \sim \text{Exp}(\lambda = 1/3)$.

One-sample Kolmogorov-Smirnov ($KS$) tests formally validated these distributions (Table 3, Figures 3 and 3b).

**Table 3**  
*Goodness-of-Fit Hypothesis Tests for Telemetry Predictor Distributions*

![Table 3: Goodness-of-Fit Hypothesis Tests](tables/table3_distribution_fit_tests.png){width=100%}

*Note.* $N = 10,000$. High $p$-values confirm that empirical telemetry signals conform to their respective theoretical distributions.

**Figure 3**  
*Empirical Distributions of Server Telemetry Metrics and Total Electrical Power Draw*

![Figure 3: Empirical Distributions of Server Telemetry](figures/fig3_signal_distributions.png){width=95%}

*Note.* Histograms with empirical kernel density estimates (solid blue) and theoretical parametric overlays (dashed red). Subsystems $x_1$ and $x_2$ fit uniform distributions; $x_3$ fits Gaussian; $x_4$ fits exponential.

**Figure 3b**  
*Subsystem Telemetry Boxplots and Quantile Dispersion Visualizations*

![Figure 3b: Subsystem Telemetry Boxplots](figures/fig3b_signal_boxplots.png){width=95%}

*Note.* Tukey boxplots illustrating interquartile ranges, median values, and outlier profiles across standardized telemetry signals.

## Task 1.3: Correlation and Scatter Plots (Dependency Analysis)
Parametric Pearson linear correlation coefficients ($r$) and non-parametric Spearman rank correlation coefficients ($\rho$) were evaluated across all pairs (Table 4, Figures 4 and 5).

**Table 4**  
*Bivariate Correlation Matrix Among Telemetry Inputs and Server Power Draw*

![Table 4: Bivariate Correlation Matrix](tables/table4_correlation_matrix.png){width=100%}

*Note.* $N = 10,000$. Pearson $r$ measures linear association; Spearman $\rho$ measures monotonic association.

Table 4 confirms two properties:
1. **Predictor Orthogonality:** Pairwise correlations among inputs ($x_1, x_2, x_3, x_4$) are statistically zero ($|r| \le 0.0084, p > .40$). Variance Inflation Factors confirmed complete independence: $\text{VIF}(x_j) \approx 1.000$ across all inputs.
2. **Selective Subsystem Sensitivity:** Total power $y$ exhibits dominant positive monotonic dependence with storage load $x_3$ ($r = .9784, \rho = .9612$) and moderate dependence with processor utilization $x_1$ ($r = .1782, \rho = .1942$). Memory allocation $x_2$ shows zero correlation with power ($r = -.0029, p = .772$). Network load $x_4$ displays a weak bivariate linear correlation ($r = .0152, p = .128$), which unmasks a significant dynamic processing role once non-linear storage and processor effects are isolated.

**Figure 4**  
*Pearson Linear and Spearman Rank Correlation Heatmaps*

![Figure 4: Pearson and Spearman Correlation Heatmaps](figures/fig4_correlation_matrix.png){width=95%}

*Note.* Correlation matrices demonstrating complete mutual independence among inputs ($|r| < 0.01$) and strong selective associations between power ($y$) and subsystems $x_3$ and $x_1$.

**Figure 5**  
*Bivariate Scatter Plot Matrix Across Telemetry Predictors and Power Consumption*

![Figure 5: Bivariate Scatter Plot Matrix](figures/fig5_scatter_matrix.png){width=95%}

*Note.* Pairwise scatter plots with smoothed trendlines illustrating non-linear response curves between inputs and total power draw.

## Task 1.4: Baseline Multiple Linear Regression and Model Inadequacy
To establish an empirical baseline, a multiple linear regression model was fitted:
$$y_i = \beta_0 + \beta_1 x_{1,i} + \beta_2 x_{2,i} + \beta_3 x_{3,i} + \beta_4 x_{4,i} + \epsilon_i$$

Table 5 summarizes baseline linear model parameters.

**Table 5**  
*Baseline Multiple Linear Regression Model Performance and Coefficients*

![Table 5: Baseline Multiple Linear Regression Model](tables/table5_baseline_linear_model.png){width=100%}

*Note.* $N = 10,000$. Fit metrics: $R^2 = .0342$, $R^2_{adj} = .0338$, $\text{RSS} = 7.538 \times 10^9\text{ W}^2$, $\text{RMSE} = 868.2\text{ W}$.

The linear model demonstrates severe structural inadequacy:
1. Negligible explained variance ($R^2 = .0342$), leaving over **96.5% of power variance unexplained**.
2. Unacceptable prediction error ($\text{RMSE} = 868.2\text{ W}$), comparable to mean server power ($M = 1098.2\text{ W}$).
3. A physically impossible intercept ($\hat{\beta}_0 = -1812.4\text{ W}$), predicting negative power for an idle system.
4. Severe parabolic curvature in residuals plotted against fitted values (Figure 6), confirming strong non-linearity.

**Figure 6**  
*Residuals vs. Fitted Values Diagnostic Plot for Baseline Multiple Linear Regression*

![Figure 6: Residuals vs. Fitted Values for Baseline Linear Model](figures/fig6_baseline_linear_residuals.png){width=95%}

*Note.* Severe parabolic curvature demonstrates pronounced structural non-linearity, establishing the complete failure of first-order linear models.

---

# Task 2: Regression Modeling and Model Evaluation

## Task 2.1: Closed-Form Parameter Estimation (Normal Equations vs. QR Decomposition)
Task 2 evaluates five candidate polynomial models specified in the coursework brief:
* **Model 1:** $y = \theta_0 + \theta_1 x_4 + \theta_2 x_1^2 + \theta_3 x_1^3 + \theta_4 x_2^4 + \theta_5 x_1^4 + \epsilon$ ($p = 6$)
* **Model 2:** $y = \theta_0 + \theta_1 x_4 + \theta_2 x_1^3 + \theta_3 x_3^4 + \epsilon$ ($p = 4$)
* **Model 3:** $y = \theta_0 + \theta_1 x_3^3 + \theta_2 x_3^4 + \epsilon$ ($p = 3$)
* **Model 4:** $y = \theta_0 + \theta_1 x_2 + \theta_2 x_1^3 + \theta_4 x_3^4 + \epsilon$ ($p = 4$)
* **Model 5:** $y = \theta_0 + \theta_1 x_4 + \theta_2 x_1^2 + \theta_3 x_1^3 + \theta_4 x_3^4 + \epsilon$ ($p = 5$)

For each model $m \in \{1, \dots, 5\}$, design matrix $\mathbf{\Phi}_m \in \mathbb{R}^{N \times p}$ was constructed with a unit intercept column $\theta_0$. Parameters were estimated using both closed-form Normal Equations ($\hat{\boldsymbol{\theta}}_{NE} = (\mathbf{\Phi}^T \mathbf{\Phi})^{-1} \mathbf{\Phi}^T \mathbf{y}$) and Householder QR decomposition ($\mathbf{\Phi} = \mathbf{Q} \mathbf{R} \implies \hat{\boldsymbol{\theta}}_{QR} = \mathbf{R}^{-1} \mathbf{Q}^T \mathbf{y}$). Forming the Gram matrix squares the condition number: $\kappa(\mathbf{\Phi}^T \mathbf{\Phi}) = \kappa(\mathbf{\Phi})^2$. In Model 1, containing fourth-power terms, $\kappa(\mathbf{\Phi}) \approx 1.14 \times 10^4$ causes $\kappa(\mathbf{\Phi}^T \mathbf{\Phi}) \approx 1.31 \times 10^8$. Solving via QR decomposition (`qr.solve()`) sidesteps Gram matrix inversion, maintaining double-precision numerical stability (Golub & Van Loan, 2013).

Table 6 reports parameter estimates, standard errors, $t$-statistics, and 95% confidence intervals across all five candidate models.

**Table 6**  
*Estimated Regression Parameters for Candidate Models 1 through 5*

![Table 6: Estimated Regression Parameters](tables/table6_regression_parameters.png){width=100%}

*Note.* $N = 10,000$. Estimates computed via QR decomposition and Normal Equations match to machine precision ($\max |\hat{\boldsymbol{\theta}}_{NE} - \hat{\boldsymbol{\theta}}_{QR}| \le 2.01 \times 10^{-10}$).

In Model 2, all four parameters are highly significant ($p < 10^{-15}$), with $t$-statistics ranging from $268.29$ to $17,333.82$. In contrast, Model 5 includes an extraneous quadratic term $\theta_2 (x_1^2)$ whose estimate is $-0.0102$ ($SE = 0.0178, t = -0.573, p = .567$), demonstrating that $x_1^2$ contributes no predictive power beyond Model 2.

## Task 2.2: Model Residual Variance Calculation
Residual error vectors were evaluated as $\mathbf{e} = \mathbf{y} - \mathbf{\Phi}\hat{\boldsymbol{\theta}}$. Unbiased residual variance ($\hat{\sigma}^2 = \text{RSS}/(N-p)$) and Maximum Likelihood variance ($\hat{\sigma}_{ML}^2 = \text{RSS}/N$) were evaluated. Under independent Gaussian disturbances $\epsilon_i \overset{iid}{\sim} \mathcal{N}(0, \sigma^2)$, the exact log-likelihood is:
$$\ln L(\hat{\boldsymbol{\theta}}, \hat{\sigma}_{ML}^2) = -\frac{N}{2}\left[\ln(2\pi \hat{\sigma}_{ML}^2) + 1\right]$$

Table 7 displays performance and log-likelihood statistics across all models.

**Table 7**  
*Model Performance, Residual Variance, and Gaussian Log-Likelihood Summary*

![Table 7: Model Performance Summary](tables/table7_model_performance_summary.png){width=100%}

*Note.* $N = 10,000$. Model 2 achieves $R^2 = .99997$ with noise standard deviation $\hat{\sigma} = 5.009\text{ W}$, reducing residual sum of squares by four orders of magnitude relative to Model 4.

## Task 2.3: Gaussian Log-Likelihood Evaluation
Log-likelihood values were computed across all candidate models based on exact Gaussian densities (Table 7). Model 2 achieves $\ln L = -30,299.9$, outperforming Model 1 ($\ln L = -81,853.8$), Model 3 ($\ln L = -65,812.8$), and Model 4 ($\ln L = -40,819.7$) by tens of thousands of log-likelihood units.

## Task 2.4: Information-Theoretic Model Selection (AIC, AICc, BIC)
Model selection was conducted under an information-theoretic framework ($\text{AIC} = 2k - 2\ln L, \text{BIC} = k\ln(N) - 2\ln L$, with $k = p + 1$) (Table 9, Figure 10).

**Table 9**  
*Information Criteria Model Selection Summary and Posterior Probability Weights*

![Table 9: Information Criteria Model Selection](tables/table9_model_selection_aic_bic.png){width=100%}

*Note.* $N = 10,000$. Parameter count $k = p + 1$ includes estimated residual variance $\sigma^2$. $\Delta\text{BIC} = 8.88$ exceeds the Kass and Raftery (1995) threshold of $6.0$, providing strong evidence for Model 2.

Model 2 attains lowest AIC ($60,609.9$) and BIC ($60,645.9$). The $\Delta\text{BIC}$ of $8.88$ for Model 5 confers **$98.8\%$ posterior probability** to Model 2 over Model 5. Because Model 2 is nested within Model 5 (restricting $\theta_2 = 0$ for $x_1^2$), nested ANOVA ($F = 0.328, p = .567$) and Likelihood Ratio tests ($\text{LRT} = 0.328, p = .567$) confirm that the additional quadratic term is statistically indistinguishable from noise.

**Figure 10**  
*Model Selection via Information Criteria (AIC and BIC)*

![Figure 10: Model Selection Information Criteria](figures/fig10_aic_bic_model_selection.png){width=95%}

*Note.* Comparative profile of AIC and BIC across all candidate models, highlighting the decisive minimum achieved by Model 2.

## Task 2.5: Residual Diagnostics and Normality Battery
To evaluate regression assumptions, a diagnostic testing battery was conducted on model residuals: Jarque-Bera (JB), Shapiro-Wilk (SW), Kolmogorov-Smirnov (KS), and Durbin-Watson (DW) for serial independence (Table 8, Figures 7–9).

**Table 8**  
*Residual Normality and Serial Independence Diagnostic Test Battery*

![Table 8: Residual Normality Diagnostic Tests](tables/table8_residual_normality_tests.png){width=100%}

*Note.* $N = 10,000$. Durbin-Watson statistic $d \approx 2.0$ confirms absence of serial correlation. Model 2 passes all normality tests ($p > .25$ across JB, SW, and KS).

The diagnostic battery proves that **Model 2 fully satisfies Gaussian disturbance assumptions**:
* Kolmogorov-Smirnov $p = .963$ ($D = 0.0050$), Jarque-Bera $p = .279$ ($\text{JB} = 2.6$), and Shapiro-Wilk $p = .724$ fail to reject Gaussianity.
* Durbin-Watson statistic $d = 2.013$ confirms independent errors.
* Models 1, 3, and 4 reject normality ($p < 10^{-100}$), confirming functional misspecification.

**Figure 7**  
*Normal Q-Q Probability Plots Across Candidate Models 1 through 5*

![Figure 7: Normal Q-Q Plots Across Candidate Models](figures/fig7_qq_plots_grid.png){width=95%}

*Note.* Quantile-quantile comparisons against theoretical normal quantiles. Model 2 residuals follow the 45-degree reference line across all quantiles.

**Figure 8**  
*Standardized Residual Histograms Overlaid with Theoretical Gaussian Probability Densities*

![Figure 8: Standardized Residual Histograms](figures/fig8_residual_histograms.png){width=95%}

*Note.* Standardized residuals for Model 2 demonstrate near-zero skewness and mesokurtic dispersion, in contrast to heavy-tailed misspecification in Models 1, 3, and 4.

**Figure 9**  
*Residuals vs. Fitted Values Across Candidate Models 1 through 5*

![Figure 9: Residuals vs. Fitted Values Across Models](figures/fig9_residuals_vs_fitted.png){width=95%}

*Note.* Model 2 displays an ideal homoscedastic residual band around zero, confirming constant variance across the fitted power spectrum.

## Task 2.6: Final Model Selection and Justification
Synthesizing information criteria, nested hypothesis tests, and residual diagnostic evaluations:
1. **Parsimony and Penalized Likelihood:** Model 2 minimizes both AIC ($60,609.9$) and BIC ($60,645.9$), yielding a decisive $\Delta\text{BIC} = 8.88$ over Model 5.
2. **Residual Normality:** Model 2 is the simplest model whose disturbances conform strictly to Gaussian distributions across all three formal hypothesis tests ($KS\ p = .963, SW\ p = .724, JB\ p = .279$).
3. **Physical Congruence:** The parameters in Model 2 map directly to CMOS dynamic CPU power ($x_1^3$), storage saturation ($x_3^4$), network transfer energy ($x_4$), and idle uncore dissipation ($\theta_0$).
Consequently, **Model 2 is definitively selected as the true model**.

## Task 2.7: Out-of-Sample Holdout Partitioning and 95% Prediction Intervals
To assess generalization, the dataset was partitioned into a **70% training split** ($N_{train} = 7,000$) and a **30% holdout testing split** ($N_{test} = 3,000$) under seed `set.seed(42)`. Model 2 was trained exclusively on the 7,000 training observations ($\hat{\theta}_0 = 120.076\text{ W}, \hat{\theta}_1 = 4.479\text{ W/Gbps}, \hat{\theta}_2 = 1.20017\text{ W/GHz}^3, \hat{\theta}_3 = 0.80000\text{ W/IOPS}^4, \hat{\sigma}_{train} = 5.036\text{ W}$).

Analytical 95% prediction intervals were computed for unseen testing samples $\mathbf{x}_*$:
$$\hat{y}_* \pm t_{crit, 0.975} \cdot \hat{\sigma}_{train} \sqrt{1 + \mathbf{\phi}_*^T (\mathbf{\Phi}_{train}^T \mathbf{\Phi}_{train})^{-1} \mathbf{\phi}_*}$$
where $t_{crit, 0.975} = 1.9603$ for $df = 6,996$.

Table 10 reports train versus test generalization metrics.

**Table 10**  
*Model 2 Generalization Performance and Out-of-Sample Prediction Coverage*

![Table 10: Holdout Generalization Performance](tables/table10_train_test_generalization.png){width=100%}

*Note.* Evaluated under seed = 42. Exactly 2,864 out of 3,000 unseen testing observations fall within analytical 95% prediction intervals (coverage = 95.47%), confirming exact calibration and zero overfitting.

Test RMSE ($4.948\text{ W}$) is slightly lower than training RMSE ($5.035\text{ W}$), confirming zero overfitting. Crucially, **exactly 2,864 out of 3,000 testing observations (95.47%)** fall within the theoretical 95% prediction intervals (Figure 11).

**Figure 11**  
*Out-of-Sample Model Predictions with 95% Confidence Intervals Plotted Against Observed Test Data Samples*

![Figure 11: Out-of-Sample Model Predictions and Prediction Intervals](figures/fig11_test_prediction_intervals.png){width=95%}

*Note.* Top: Test set predictions overlaid on observed power. Bottom left: 100-sample zoom with analytical 95% prediction intervals. Bottom right: Empirical error distribution with nominal 95% coverage bounds.

---

# Task 3: Approximate Bayesian Computation (ABC)

## Task 3.1: Dominant Parameter Identification
Task 3 implements likelihood-free parameter inference via **Rejection Approximate Bayesian Computation (ABC)** for Model 2. Following the assignment brief, the **two parameters with largest absolute magnitude** from least squares estimation in Task 2.1 were selected for Bayesian estimation, while remaining parameters were fixed as constants:
1. $\theta_0$ (Static Intercept): $|\hat{\theta}_0| = \mathbf{120.0221\text{ W}}$ (**Rank 1 — Largest Magnitude**)
2. $\theta_1$ (Network Throughput Coefficient $x_4$): $|\hat{\theta}_1| = \mathbf{4.4805\text{ W/Gbps}}$ (**Rank 2 — Second Largest**)
3. $\theta_2$ (CPU Cubic Term $x_1^3$): $|\hat{\theta}_2| = 1.2002\text{ W/GHz}^3$ (Rank 3; fixed at $\theta_2^* = 1.20018440$)
4. $\theta_3$ (Storage Quartic Term $x_3^4$): $|\hat{\theta}_3| = 0.8000\text{ W/IOPS}^4$ (Rank 4; fixed at $\theta_3^* = 0.80000257$)

## Task 3.2: Prior Distribution Formulation and Justification
Independent continuous uniform priors were established around point estimates:
$$p(\boldsymbol{\theta}) = p(\theta_0) \cdot p(\theta_1), \quad \theta_0 \sim \mathcal{U}[115.0, 125.0]\text{ W}, \quad \theta_1 \sim \mathcal{U}[3.5, 5.5]\text{ W/Gbps}$$

The prior bounds were justified on theoretical and physical principles:
* **Standard Error Span:** For $\theta_0$, the range width of $10.0\text{ W}$ spans **$102.3 \times SE_{OLS}$** ($SE = 0.0978\text{ W}$). For $\theta_1$, the width of $2.0\text{ W/Gbps}$ spans **$119.8 \times SE_{OLS}$** ($SE = 0.0167\text{ W/Gbps}$).
* **Maximum Entropy Formulation:** Uniform distributions represent maximum-entropy uninformative priors over bounded domains (Jaynes, 1968). Because prior spans exceed 100 standard errors, posteriors are entirely data-driven.
* **Physical Plausibility:** Enterprise rack servers exhibit base idle power between $110\text{ W}$ and $130\text{ W}$, while 10/25 GbE network interfaces draw between $3.5$ and $5.5\text{ W}$ per Gbps of sustained throughput.

## Task 3.3: High-Performance Rejection ABC Engine
In Rejection ABC, candidate parameter vectors $\boldsymbol{\theta}^* = (\theta_0^*, \theta_1^*)$ are sampled from the prior and accepted if the distance $d_{RMSE}(\mathbf{y}, \hat{\mathbf{y}}(\boldsymbol{\theta}^*)) \le \epsilon$. To simulate $N_{sim} = 200,000$ draws without memory bottlenecks, an algebraic reduction of the residual sum of squares was derived:
$$\mathbf{y}_{target} = \mathbf{y} - (\theta_2^* \mathbf{x}_1^3 + \theta_3^* \mathbf{x}_3^4)$$
$$\text{RSS}(\theta_0^*, \theta_1^*) = \sum y_{target}^2 + N(\theta_0^*)^2 + (\theta_1^*)^2 \sum x_4^2 - 2\theta_0^* \sum y_{target} - 2\theta_1^* \sum (x_4 y_{target}) + 2\theta_0^*\theta_1^* \sum x_4$$

This formulation enabled simulating $200,000$ candidate draws in **$0.04\text{ seconds}$** ($5,500,000\text{ draws/second}$) in pure R under `set.seed(42)`. Multi-tolerance sensitivity was evaluated across four quantiles: $\alpha \in \{5.0\%, 2.0\%, 1.0\%, 0.5\%\}$. Primary inference was conducted at $\alpha = 0.5\%$ ($N_{accepted} = 1,000$ draws), corresponding to $\epsilon = 5.0173\text{ W}$—within $0.009\text{ W}$ of the theoretical OLS minimum ($\hat{\sigma}_{ML} = 5.0081\text{ W}$).

## Task 3.4: Joint and Marginal Posterior Distributions
Posterior moments were computed for accepted draws: Mean, Median, Mode (via 1D Gaussian kernel density peak), Standard Deviation ($SD_{post}$), and 95% Highest Posterior Density Intervals (HPDI) via non-parametric shortest-interval optimization (Table 11).

**Table 11**  
*Comparison of Frequentist Ordinary Least Squares and Bayesian ABC Posterior Estimations*

![Table 11: Bayesian vs Frequentist Comparison](tables/table11_frequentist_vs_bayesian_comparison.png){width=100%}

*Note.* $N = 10,000$ observed samples; $N_{sim} = 200,000$ simulation draws; primary tolerance quantile $\alpha = 0.5\%$ ($N_{accepted} = 1,000$ draws). Fixed parameters: $\theta_2 = 1.200184\text{ W/GHz}^3$, $\theta_3 = 0.800003\text{ W/IOPS}^4$. Relative difference is computed as $|\text{Mean}_{Bayes} - \hat{\theta}_{OLS}| / \hat{\theta}_{OLS} \times 100\%$.

Table 12 reports tolerance sensitivity and posterior contraction across all four tolerance levels.

**Table 12**  
*ABC Tolerance Sensitivity and Posterior Variance Contraction Across Tolerance Quantiles*

![Table 12: ABC Tolerance Sensitivity](tables/table12_abc_tolerance_sensitivity.png){width=100%}

*Note.* $N = 10,000$. As tolerance $\alpha$ tightens from 5.0% to 0.5%, the RMSE threshold approaches the theoretical OLS minimum of $5.0081\text{ W}$, and posterior standard deviations contract monotonically.

Figures 12, 13, and 14 display marginal posterior distributions, the bivariate joint posterior distribution with 95% confidence ellipse, and tolerance convergence curves.

**Figure 12**  
*Marginal Posterior Probability Distributions for Intercept and Network Parameters with 95% HPDI Intervals*

![Figure 12: Marginal Posterior Probability Distributions](figures/fig12_abc_marginal_posteriors.png){width=95%}

*Note.* Posterior densities for $\theta_0$ (left) and $\theta_1$ (right) at $\alpha = 0.5\%$. Orange vertical bars indicate 95% Highest Posterior Density Intervals (HPDI); dashed black lines denote OLS point estimates.

**Figure 13**  
*Joint Posterior Probability Distribution with Bivariate Contours and 95% Confidence Ellipse*

![Figure 13: Joint Posterior Probability Distribution](figures/fig13_abc_joint_posterior.png){width=95%}

*Note.* Bivariate scatter plot of accepted parameter pairs showing negative posterior coupling ($r = -0.722$), overlaid with 2D density contours, 95% confidence ellipse, and OLS point estimate (red diamond).

**Figure 14**  
*ABC Tolerance Sensitivity and Posterior Contraction across Acceptance Thresholds*

![Figure 14: ABC Tolerance Sensitivity and Posterior Contraction](figures/fig14_abc_tolerance_convergence.png){width=95%}

*Note.* Left: Acceptance thresholds across quantiles. Center & Right: Monotonic contraction of posterior standard deviations toward OLS standard error bounds as tolerance approaches zero.

## Task 3.5: Tolerance Sensitivity and Posterior Contraction
Multi-tolerance evaluation across $\alpha \in \{5.0\%, 2.0\%, 1.0\%, 0.5\%\}$ demonstrates systematic posterior variance contraction (Table 12, Figure 14). As tolerance quantile $\alpha$ tightens from $5.0\%$ to $0.5\%$, the RMSE distance threshold decreases from $5.1020\text{ W}$ to $5.0173\text{ W}$, closely approaching the theoretical OLS minimum ($\hat{\sigma}_{ML} = 5.0081\text{ W}$). Concurrently, posterior standard deviations contract monotonically from $0.6868\text{ W}$ to $0.2227\text{ W}$ for $\theta_0$, and from $0.1615$ to $0.0519\text{ W/Gbps}$ for $\theta_1$. This empirical progression verifies the foundational theorem of ABC: as acceptance tolerance approaches zero ($\epsilon \to 0$), the approximate posterior distribution $p(\boldsymbol{\theta} \mid d \le \epsilon)$ converges asymptotically to the true posterior distribution $p(\boldsymbol{\theta} \mid \mathbf{y})$.

---

# Discussion

## Physical Architecture and Hardware Mapping
The statistical parameters identified in Model 2 map directly to physical server architecture:
* **Static Baseline Power ($\hat{\theta}_0 \approx 120.02\text{ W}$):** Captures baseline dissipation when workload activity is zero ($x_1 = x_3 = x_4 = 0$), encompassing motherboard uncore power, semiconductor sub-threshold leakage, DRAM background refresh, PSU conversion loss, and base cooling fan rotation.
* **Network Dynamic Power ($\hat{\theta}_1 \approx 4.48\text{ W/Gbps}$):** Quantifies dynamic power per gigabit of throughput, reflecting physical layer (PHY) SerDes transceivers, packet buffering, PCIe bus transactions, and DMA memory transfers.
* **Cubic Processor Scaling ($\hat{\theta}_2 \approx 1.200\text{ W/GHz}^3$):** Represents dynamic CPU scaling under CMOS DVFS protocol. Because dynamic power scales cubically with operational frequency ($P \propto V_{dd}^2 f \propto f^3$), this cubic term governs the steep surge in dissipation as CPU clock frequencies scale toward turbo limits ($x_1 \to 8.0\text{ GHz}$).
* **Quartic Storage Saturation ($\hat{\theta}_3 \approx 0.8000\text{ W/IOPS}^4$):** Captures severe non-linear power escalation under queue saturation in solid-state and magnetic drive arrays, driven by parallel NAND channel activation, flash translation layer (FTL) caching, wear leveling, write amplification, and supplementary enclosure cooling.

## Negative Parameter Coupling and Joint Posterior Geometry
As established in Task 3, the joint posterior distribution exhibits an empirical correlation of **$r(\theta_0, \theta_1) = -0.722$** (Figure 13). This parameter coupling arises from structural mathematical and physical constraints:
* **Algebraic Derivation:** In design matrix $\mathbf{\Phi}$, the column for $\theta_0$ is the unit vector $\mathbf{1}$, and the column for $\theta_1$ is network throughput $\mathbf{x}_4$. Because network load is strictly non-negative ($x_4 \ge 0, \bar{x}_4 = 3.01\text{ Gbps}$), the off-diagonal Gram matrix element is positive:
  $$(\mathbf{\Phi}^T\mathbf{\Phi})_{0,1} = \sum_{i=1}^N 1 \cdot x_{4,i} = 30,105 > 0$$
  Matrix inversion induces a negative off-diagonal covariance entry:
  $$\text{Cov}(\theta_0, \theta_1) = -\frac{\bar{x}_4}{\sum (x_{4,i} - \bar{x}_4)^2}\sigma^2 < 0$$
  evaluating to a theoretical Frequentist correlation of $-0.5141$.
* **Physical Mechanism:** Observed server power has a fixed sample mean. During simulation, if candidate network coefficient $\theta_1^*$ is sampled above its true value, it over-predicts dynamic power for positive network states ($x_4 > 0$). To minimize residual sum of squares against observed power, intercept $\theta_0^*$ must compensate downward, generating the tilted bivariate posterior ellipse.

## Asymptotic Equivalence and Epistemic Paradigm Comparison
The empirical convergence between Frequentist OLS and Bayesian ABC validates the Bernstein-von Mises Theorem, establishing that likelihood-free ABC methods converge exactly to analytical MLE estimates under sufficient sample size ($N = 10,000$). While Frequentist intervals reflect asymptotic coverage under hypothetical resampling, Bayesian HPDIs provide facility operators with direct actionable probabilities conditioned on the single observed dataset.

## Operational Applications and Limitations
Model 2 provides direct actionable utility for enterprise data centers:
1. **Dynamic Power Capping:** Facilitates real-time power tracking with $99.997\%$ precision ($\text{RMSE} < 5.0\text{ W}$), allowing facilities to operate within 2% of breaker limits without tripping.
2. **Workload Consolidation:** The cubic CPU parameter ($\theta_2 = 1.200$) demonstrates that spreading load across multiple cores running at moderate clock speeds uses substantially less power than driving a single core into maximum turbo frequency.
3. **Thermal Management:** Strong storage-power coupling ($r = .9784$) pinpoints disk arrays as primary thermal hot-spots requiring localized cooling.

Future work should integrate ambient temperature telemetry ($I_{leak} \propto T^2$) and transition to Sequential Monte Carlo ABC (ABC-SMC) for higher-dimensional topologies.

---

# Conclusion

This coursework formulated, evaluated, and validated an end-to-end statistical modeling framework for enterprise cloud server power consumption:
1. **Task 1 Preliminary Analysis:** Verified stationarity across 10,000 synchronized observations, identified parametric distributions (uniform $x_1, x_2$; Gaussian $x_3$; exponential $x_4$), confirmed predictor orthogonality ($\text{VIF} \approx 1.000$), and demonstrated baseline linear model failure ($R^2 = .0342$).
2. **Task 2 Regression Modeling:** Estimated five polynomial models via QR decomposition. Information criteria ($\text{AIC} = 60,609.9, \text{BIC} = 60,645.9$), nested ANOVA ($p = .567$), and a comprehensive normality battery (KS $p = .963$, JB $p = .279$, SW $p = .724$) selected Model 2 ($y = \theta_0 + \theta_1 x_4 + \theta_2 x_1^3 + \theta_3 x_3^4 + \epsilon$) as the true data-generating process ($R^2 = .99997, \hat{\sigma} = 5.009\text{ W}$). Out-of-sample holdout validation ($N = 3,000$) achieved 95.47% empirical prediction coverage.
3. **Task 3 Approximate Bayesian Computation:** Executed vectorized Rejection ABC ($200,000$ draws) on the two dominant parameters ($\theta_0$ and $\theta_1$). Posterior means converged to within $0.05\%$ of OLS, confirming Bernstein-von Mises asymptotic equivalence, while explaining negative parameter coupling ($r = -0.722$) driven by non-negative network throughput.

The reproducible pipeline, publication figures, and empirical models provide a publication-grade foundation for data center energy optimization.

---

# References

* Akaike, H. (1974). A new look at the statistical model identification. *IEEE Transactions on Automatic Control*, 19(6), 716–723. https://doi.org/10.1109/TAC.1974.1100705
* Barroso, L. A., Hölzle, U., & Ranganathan, P. (2018). *The Datacenter as a Computer: Designing Warehouse-Scale Machines* (3rd ed.). Morgan & Claypool Publishers. https://doi.org/10.2200/S00874ED3V01Y201809CAC046
* Beaumont, M. A., Zhang, W., & Balding, D. J. (2002). Approximate Bayesian computation in population genetics. *Genetics*, 162(4), 2025–2035. https://doi.org/10.1093/genetics/162.4.2025
* Box, G. E., & Cox, D. R. (1964). An analysis of transformations. *Journal of the Royal Statistical Society: Series B (Methodological)*, 26(2), 211–243. https://doi.org/10.1111/j.2517-6161.1964.tb00553.x
* Burnham, K. P., & Anderson, D. R. (2002). *Model Selection and Multimodel Inference: A Practical Information-Theoretic Approach* (2nd ed.). Springer-Verlag.
* Chen, M. H., & Shao, Q. M. (1999). Monte Carlo estimation of Bayesian credible and HPD intervals. *Journal of Computational and Graphical Statistics*, 8(1), 69–92. https://doi.org/10.1080/10618600.1999.10474802
* Durbin, J., & Watson, G. S. (1950). Testing for serial correlation in least squares regression: I. *Biometrika*, 37(3/4), 409–428. https://doi.org/10.2307/2332388
* Golub, G. H., & Van Loan, C. F. (2013). *Matrix Computations* (4th ed.). Johns Hopkins University Press.
* Jarque, C. M., & Bera, A. K. (1987). A test for normality of observations and regression residuals. *International Statistical Review*, 55(2), 163–172. https://doi.org/10.2307/1403192
* Jaynes, E. T. (1968). Prior probabilities. *IEEE Transactions on Systems Science and Cybernetics*, 4(3), 227–241. https://doi.org/10.1109/TSSC.1968.300117
* Kass, R. E., & Raftery, A. E. (1995). Bayes factors. *Journal of the American Statistical Association*, 90(430), 773–795. https://doi.org/10.1080/01621459.1995.10476572
* Kolmogorov, A. N. (1933). Sulla determinazione empirica di una legge di distribuzione. *Giornale dell'Istituto Italiano degli Attuari*, 4, 83–91.
* McElreath, R. (2020). *Statistical Rethinking: A Bayesian Course with Examples in R and Stan* (2nd ed.). Chapman and Hall/CRC. https://doi.org/10.1201/9780429029608
* Pritchard, J. K., Seielstad, M. T., Perez-Lezaun, A., & Feldman, M. W. (1999). Population growth of human Y chromosomes: A study of Y chromosome microsatellites. *Molecular Biology and Evolution*, 16(12), 1791–1798. https://doi.org/10.1093/oxfordjournals.molbev.a026091
* Rabaey, J. M., Chandrakasan, A., & Nikolic, B. (2003). *Digital Integrated Circuits: A Design Perspective* (2nd ed.). Prentice Hall.
* Schwarz, G. (1978). Estimating the dimension of a model. *The Annals of Statistics*, 6(2), 461–464. https://doi.org/10.1214/aos/1176344136
* Shapiro, S. S., & Wilk, M. B. (1965). An analysis of variance test for normality (complete samples). *Biometrika*, 52(3/4), 591–611. https://doi.org/10.1093/biomet/52.3-4.591
* Sisson, S. A., Fan, Y., & Beaumont, M. (Eds.). (2018). *Handbook of Approximate Bayesian Computation*. CRC Press. https://doi.org/10.1201/9781315117195
* Tavaré, S., Balding, D. J., Griffiths, R. C., & Donnelly, P. (1997). Inferring coalescence times from DNA sequence data. *Genetics*, 145(2), 505–518. https://doi.org/10.1093/genetics/145.2.505
* Van der Vaart, A. W. (2000). *Asymptotic Statistics* (Vol. 3). Cambridge University Press. https://doi.org/10.1017/CBO9780511802256
* Wickham, H. (2016). *ggplot2: Elegant Graphics for Data Analysis*. Springer-Verlag. https://doi.org/10.1007/978-3-319-24277-4

---

# Appendices

All R programming scripts were authored specifically for this research, adhering to modular programming standards. The master pipeline can be executed via `Rscript scripts/run_all.R`.

## Appendix A: Task 1 Preliminary Data Analysis Engine (`R/01_eda_functions.R`)
```r
# =============================================================================
# Task 1: Preliminary Data Analysis Engine
# Module: STW7089CEM Introduction to Statistical Methods for Data Science
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

#' Compute non-parametric and parametric descriptive moments
compute_descriptive_stats <- function(df, exclude_cols = c("time")) {
  num_cols <- setdiff(names(df), exclude_cols)
  stats_list <- lapply(num_cols, function(col) {
    x <- df[[col]]
    n <- length(x)
    m <- mean(x)
    s <- sd(x)
    mdn <- median(x)
    iqr_val <- IQR(x)
    z <- (x - m) / s
    skew <- (n / ((n - 1) * (n - 2))) * sum(z^3)
    kurt <- ((n * (n + 1)) / ((n - 1) * (n - 2) * (n - 3))) * sum(z^4) -
            (3 * (n - 1)^2) / ((n - 2) * (n - 3))
    data.frame(
      Variable = col, Mean = m, Median = mdn, SD = s,
      Variance = s^2, IQR = iqr_val, Skewness = skew, Excess_Kurtosis = kurt
    )
  })
  do.call(rbind, stats_list)
}

#' Formal Kolmogorov-Smirnov distribution tests
test_distribution_families <- function(df) {
  ks_x1 <- ks.test(df$x1, "punif", min = 1.0, max = 8.0)
  ks_x2 <- ks.test(df$x2, "punif", min = 2.0, max = 9.0)
  ks_x3 <- ks.test(df$x3, "pnorm", mean = mean(df$x3), sd = sd(df$x3))
  ks_x4 <- ks.test(df$x4, "pexp", rate = 1 / mean(df$x4))
  data.frame(
    Variable = c("x1", "x2", "x3", "x4"),
    Hypothesis = c("Uniform U[1, 8]", "Uniform U[2, 9]", "Gaussian Normal", "Exponential"),
    KS_Stat = c(ks_x1$statistic, ks_x2$statistic, ks_x3$statistic, ks_x4$statistic),
    p_value = c(ks_x1$p.value, ks_x2$p.value, ks_x3$p.value, ks_x4$p.value)
  )
}
```

## Appendix B: Task 2 Regression Engine and Diagnostics (`R/02_regression_engine.R`)
```r
# =============================================================================
# Task 2: Polynomial Regression Engine and Parameter Estimation
# =============================================================================

#' Construct polynomial design matrices for candidate models 1 to 5
build_design_matrix <- function(df, model_id) {
  n <- nrow(df)
  x1 <- df$x1; x2 <- df$x2; x3 <- df$x3; x4 <- df$x4
  if (model_id == "Model1") {
    cbind(Intercept = 1, x4 = x4, x1_sq = x1^2, x1_cube = x1^3, x2_quad = x2^4, x1_quad = x1^4)
  } else if (model_id == "Model2") {
    cbind(Intercept = 1, x4 = x4, x1_cube = x1^3, x3_quad = x3^4)
  } else if (model_id == "Model3") {
    cbind(Intercept = 1, x3_cube = x3^3, x3_quad = x3^4)
  } else if (model_id == "Model4") {
    cbind(Intercept = 1, x2 = x2, x1_cube = x1^3, x3_quad = x3^4)
  } else if (model_id == "Model5") {
    cbind(Intercept = 1, x4 = x4, x1_sq = x1^2, x1_cube = x1^3, x3_quad = x3^4)
  }
}

#' Fit polynomial regression via QR decomposition and Normal Equations
fit_polynomial_model <- function(Phi, y, model_id = "Model2") {
  N <- length(y); p <- ncol(Phi); df_resid <- N - p
  # Normal Equations
  theta_normal <- as.vector(solve(t(Phi) %*% Phi) %*% (t(Phi) %*% y))
  # QR Decomposition
  qr_decomp <- qr(Phi)
  theta_qr <- as.vector(qr.solve(qr_decomp, y))
  # Residuals and Variance
  y_hat <- as.vector(Phi %*% theta_qr)
  residuals <- as.vector(y - y_hat)
  RSS <- sum(residuals^2)
  sigma2_unbiased <- RSS / df_resid
  sigma2_ml <- RSS / N
  # Gaussian Log-Likelihood
  log_likelihood_ml <- -0.5 * N * (log(2 * pi * sigma2_ml) + 1)
  # Parameter Covariance and Standard Errors
  R_mat <- qr.R(qr_decomp)
  cov_theta <- sigma2_unbiased * chol2inv(R_mat)
  se_theta <- sqrt(diag(cov_theta))
  t_stat <- theta_qr / se_theta
  p_values <- 2 * stats::pt(-abs(t_stat), df = df_resid)
  list(
    model_id = model_id, theta = theta_qr, se_theta = se_theta,
    RSS = RSS, RMSE = sqrt(RSS / N), R2 = 1 - (RSS / sum((y - mean(y))^2)),
    sigma_unbiased = sqrt(sigma2_unbiased), log_likelihood_ml = log_likelihood_ml,
    residuals = residuals, fitted_values = y_hat
  )
}
```

## Appendix C: Task 3 Approximate Bayesian Computation Engine (`R/05_abc_engine.R`)
```r
# =============================================================================
# Task 3: Approximate Bayesian Computation Engine (Rejection ABC)
# =============================================================================

#' High-performance vectorized Rejection ABC simulation
run_rejection_abc <- function(df, dominant_params, fixed_params, priors,
                              n_sim = 200000,
                              tolerance_quantiles = c(0.05, 0.02, 0.01, 0.005),
                              seed = 42) {
  set.seed(seed)
  n <- nrow(df); x4 <- df$x4; y <- df$y
  # Fixed component subtraction
  y_fixed <- fixed_params$values[1] * (df$x1^3) + fixed_params$values[2] * (df$x3^4)
  y_target <- y - y_fixed
  # Precompute sample sums for fast algebraic expansion
  sum_y_target <- sum(y_target); sum_y_target_sq <- sum(y_target^2)
  sum_x4 <- sum(x4); sum_x4_sq <- sum(x4^2)
  sum_x4_y_target <- sum(x4 * y_target)
  # Sample uniform priors
  sim_theta0 <- runif(n_sim, min = priors$Intercept$min, max = priors$Intercept$max)
  sim_theta1 <- runif(n_sim, min = priors$x4$min, max = priors$x4$max)
  # Vectorized Residual Sum of Squares (RSS)
  rss_vector <- sum_y_target_sq + n * (sim_theta0^2) + (sim_theta1^2) * sum_x4_sq -
                2 * sim_theta0 * sum_y_target - 2 * sim_theta1 * sum_x4_y_target +
                2 * sim_theta0 * sim_theta1 * sum_x4
  dist_rmse <- sqrt(rss_vector / n)
  # Multi-tolerance acceptance evaluation
  tolerance_levels <- list()
  for (q in tolerance_quantiles) {
    thresh <- as.numeric(quantile(dist_rmse, probs = q))
    acc_idx <- which(dist_rmse <= thresh)
    tolerance_levels[[as.character(q)]] <- list(
      quantile = q, threshold_rmse = thresh,
      n_accepted = length(acc_idx),
      theta0_acc = sim_theta0[acc_idx], theta1_acc = sim_theta1[acc_idx]
    )
  }
  list(n_sim = n_sim, tolerance_levels = tolerance_levels,
       primary_accepted = tolerance_levels[[as.character(min(tolerance_quantiles))]])
}

#' Non-parametric 95% Highest Posterior Density Interval (HPDI)
compute_hpdi <- function(samples, prob = 0.95) {
  sorted_s <- sort(samples); n <- length(sorted_s)
  n_in <- floor(prob * n); n_out <- n - n_in
  widths <- sorted_s[(n_in + 1):n] - sorted_s[1:n_out]
  min_idx <- which.min(widths)
  c(lower = sorted_s[min_idx], upper = sorted_s[min_idx + n_in])
}
```

## Appendix D: Publication-Grade Table Rendering Engine (`R/07_table_renderer.R`)
```r
# =============================================================================
# Appendix D: Publication-Grade APA 7 Table Image Rendering Engine
# =============================================================================

suppressPackageStartupMessages({
  library(gridExtra)
  library(grid)
  library(gtable)
})

render_apa_table_png <- function(df, table_num, title, note, out_file,
                                 width_in = 8.5, font_size = 9.5,
                                 col_align = NULL) {
  df_chr <- as.data.frame(lapply(df, as.character), stringsAsFactors = FALSE)
  n_rows <- nrow(df_chr); n_cols <- ncol(df_chr)
  if (is.null(col_align)) {
    col_align <- sapply(df, function(col) if (is.numeric(col)) "right" else "left")
    col_align[1] <- "left"
  }
  hjust_vec <- ifelse(col_align == "right", 1, ifelse(col_align == "center", 0.5, 0))
  x_pos_vec <- ifelse(col_align == "right", 0.95, ifelse(col_align == "center", 0.5, 0.05))
  tt <- ttheme_default(
    base_size = font_size, base_family = "sans", padding = unit(c(4.5, 5.0), "mm"),
    core = list(fg_params = list(hjust = rep(hjust_vec, each = n_rows),
                                 x = rep(x_pos_vec, each = n_rows),
                                 fontsize = font_size, col = "#1a1a1a"),
                bg_params = list(fill = c("#ffffff", "#f8f9fa"))),
    colhead = list(fg_params = list(hjust = hjust_vec, x = x_pos_vec,
                                    fontface = "bold", fontsize = font_size + 0.5, col = "#111111"),
                   bg_params = list(fill = "#ffffff"))
  )
  tg <- tableGrob(df_chr, rows = NULL, theme = tt)
  tg <- gtable_add_grob(tg, grobs = segmentsGrob(gp = gpar(lwd = 2.2, col = "#111111")), t = 1, l = 1, r = n_cols)
  tg <- gtable_add_grob(tg, grobs = segmentsGrob(y0 = unit(0, "npc"), y1 = unit(0, "npc"), gp = gpar(lwd = 1.0, col = "#222222")), t = 1, l = 1, r = n_cols)
  tg <- gtable_add_grob(tg, grobs = segmentsGrob(y0 = unit(0, "npc"), y1 = unit(0, "npc"), gp = gpar(lwd = 2.2, col = "#111111")), t = nrow(tg), l = 1, r = n_cols)
  title_grob1 <- textGrob(table_num, x = 0.015, just = "left", gp = gpar(fontface = "bold", fontsize = font_size + 2.5, col = "#111111"))
  title_grob2 <- textGrob(title, x = 0.015, just = "left", gp = gpar(fontface = "italic", fontsize = font_size + 1.2, col = "#222222"))
  wrapped_note <- paste(strwrap(note, width = floor(width_in * 13.5)), collapse = "\n")
  note_lines <- length(strsplit(wrapped_note, "\n")[[1]])
  note_grob <- textGrob(wrapped_note, x = 0.015, just = c("left", "top"), gp = gpar(fontsize = font_size - 1.0, col = "#333333"))
  table_height_in <- (n_rows + 1) * 0.28
  note_height_in <- (note_lines * 0.20) + 0.15
  total_height_in <- 0.65 + table_height_in + note_height_in + 0.25
  png(out_file, width = width_in * 300, height = total_height_in * 300, res = 300)
  grid.newpage()
  pushViewport(viewport(layout = grid.layout(5, 1, heights = unit(c(0.28, 0.28, table_height_in, 0.08, note_height_in), "inches"))))
  pushViewport(viewport(layout.pos.row = 1, layout.pos.col = 1)); grid.draw(title_grob1); popViewport()
  pushViewport(viewport(layout.pos.row = 2, layout.pos.col = 1)); grid.draw(title_grob2); popViewport()
  pushViewport(viewport(layout.pos.row = 3, layout.pos.col = 1)); grid.draw(tg); popViewport()
  pushViewport(viewport(layout.pos.row = 5, layout.pos.col = 1)); grid.draw(note_grob); popViewport()
  dev.off()
}
```
