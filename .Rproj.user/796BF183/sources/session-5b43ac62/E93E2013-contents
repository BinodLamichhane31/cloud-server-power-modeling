# =============================================================================
# 00_utils_io.R
# STW7089CEM Coursework - Modeling Cloud Server Power Consumption
# Data ingestion, schema validation and integrity audit
# -----------------------------------------------------------------------------
# Raw inputs (data/raw/):
#   X.csv    : 4 input telemetry signals (cpu_utilization, memory_usage,
#              disk_io, network_traffic)  -> x1, x2, x3, x4
#   y.csv    : output signal (power_consumption)  -> y
#   time.csv : sampling time in seconds (time_seconds)  -> time
# Output:
#   A single tidy data frame with columns time, x1, x2, x3, x4, y and an
#   audit table documenting every integrity check that was performed.
# =============================================================================

#' Locate the project root so scripts run from the root or from scripts/.
find_project_root <- function() {
  candidates <- c(".", "..")
  for (p in candidates) {
    if (file.exists(file.path(p, "R", "00_utils_io.R"))) {
      return(normalizePath(p))
    }
  }
  stop("Project root not found. Run scripts from the project root directory.")
}

#' Standard project paths (all relative to the project root).
project_paths <- function(root = find_project_root()) {
  list(
    root      = root,
    raw       = file.path(root, "data", "raw"),
    processed = file.path(root, "data", "processed"),
    figures   = file.path(root, "outputs", "figures"),
    tables    = file.path(root, "outputs", "tables")
  )
}

#' Variable dictionary: maps raw column names to coursework notation.
variable_dictionary <- function() {
  data.frame(
    variable    = c("time", "x1", "x2", "x3", "x4", "y"),
    raw_column  = c("time_seconds", "cpu_utilization", "memory_usage",
                    "disk_io", "network_traffic", "power_consumption"),
    source_file = c("time.csv", "X.csv", "X.csv", "X.csv", "X.csv", "y.csv"),
    role        = c("index", "input", "input", "input", "input", "output"),
    description = c("Sampling time (s)", "CPU utilization",
                    "Memory usage", "Disk I/O", "Network traffic",
                    "Total power consumption"),
    stringsAsFactors = FALSE
  )
}

#' Read the three raw CSV files and check their expected schemas.
load_raw_data <- function(raw_dir) {
  files <- c(X = "X.csv", y = "y.csv", time = "time.csv")
  paths <- file.path(raw_dir, files)
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) {
    stop("Missing raw data file(s): ", paste(missing, collapse = ", "))
  }

  X    <- read.csv(paths[1], check.names = FALSE)
  y    <- read.csv(paths[2], check.names = FALSE)
  time <- read.csv(paths[3], check.names = FALSE)

  expected_X <- c("cpu_utilization", "memory_usage", "disk_io",
                  "network_traffic")
  if (!identical(names(X), expected_X)) {
    stop("Unexpected X.csv columns: ", paste(names(X), collapse = ", "))
  }
  if (ncol(y) != 1 || ncol(time) != 1) {
    stop("y.csv and time.csv must each contain exactly one column.")
  }

  list(X = X, y = y, time = time)
}

#' Validate the raw inputs, merge them and record an audit trail.
#'
#' @param raw   list returned by load_raw_data()
#' @param dt_tol tolerance (s) when checking the sampling interval, needed
#'               because time.csv contains floating-point accumulation error
#'               (e.g. 999.9000000000001).
#' @return list(data = tidy data frame, audit = data frame of checks)
validate_and_merge <- function(raw, dt_tol = 1e-6) {
  n_X <- nrow(raw$X); n_y <- nrow(raw$y); n_t <- nrow(raw$time)
  if (!(n_X == n_y && n_y == n_t)) {
    stop(sprintf("Row counts differ: X=%d, y=%d, time=%d", n_X, n_y, n_t))
  }

  df <- data.frame(
    time = raw$time[[1]],
    x1   = raw$X$cpu_utilization,
    x2   = raw$X$memory_usage,
    x3   = raw$X$disk_io,
    x4   = raw$X$network_traffic,
    y    = raw$y[[1]]
  )

  # Sampling-interval checks (on the raw, unrounded timestamps)
  dt         <- diff(df$time)
  dt_nominal <- stats::median(dt)
  regular    <- all(abs(dt - dt_nominal) < dt_tol)
  monotonic  <- all(dt > 0)

  # Remove floating-point accumulation error in the time stamps
  df$time <- round(df$time, 6)

  n_missing   <- sum(is.na(df))
  n_nonfinite <- sum(!is.finite(as.matrix(df)))
  n_dup_time  <- sum(duplicated(df$time))
  n_dup_rows  <- sum(duplicated(df[, c("x1", "x2", "x3", "x4", "y")]))
  neg_counts  <- vapply(df[, c("x1", "x2", "x3", "x4", "y")],
                        function(v) sum(v < 0), integer(1))

  audit <- data.frame(
    check = c(
      "Rows per file (X, y, time)",
      "Merged dimensions (rows x columns)",
      "Missing values (NA)",
      "Non-finite values (Inf/NaN)",
      "Duplicate timestamps",
      "Duplicate observation rows",
      "Timestamps strictly increasing",
      "Sampling interval regular",
      "Nominal sampling interval (s)",
      "Sampling frequency (Hz)",
      "Recording duration (s)",
      "Negative values in x1, x2, x3, x4, y"
    ),
    result = c(
      sprintf("%d, %d, %d", n_X, n_y, n_t),
      sprintf("%d x %d", nrow(df), ncol(df)),
      as.character(n_missing),
      as.character(n_nonfinite),
      as.character(n_dup_time),
      as.character(n_dup_rows),
      ifelse(monotonic, "Yes", "No"),
      ifelse(regular, "Yes", "No"),
      format(round(dt_nominal, 6), nsmall = 1),
      format(round(1 / dt_nominal, 3), nsmall = 1),
      format(round(max(df$time) - min(df$time), 3), nsmall = 1),
      paste(neg_counts, collapse = ", ")
    ),
    status = c(
      "Pass",
      "Pass",
      ifelse(n_missing == 0, "Pass", "Fail"),
      ifelse(n_nonfinite == 0, "Pass", "Fail"),
      ifelse(n_dup_time == 0, "Pass", "Fail"),
      ifelse(n_dup_rows == 0, "Pass", "Flag"),
      ifelse(monotonic, "Pass", "Fail"),
      ifelse(regular, "Pass", "Fail"),
      "Info",
      "Info",
      "Info",
      ifelse(sum(neg_counts) == 0, "Pass", "Flag")
    ),
    stringsAsFactors = FALSE
  )

  if (any(audit$status == "Fail")) {
    print(audit)
    stop("Data integrity audit failed. See table above.")
  }

  list(data = df, audit = audit, negative_counts = neg_counts)
}

#' Write the merged data set to data/processed/.
save_processed <- function(df, processed_dir,
                           filename = "server_data_clean.csv") {
  dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(processed_dir, filename)
  write.csv(df, path, row.names = FALSE)
  invisible(path)
}

