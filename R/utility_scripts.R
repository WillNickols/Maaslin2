######################
## TSS Normalization #
######################

TSSnorm = function(features) {
  # Convert to Matrix from Data Frame
  features_norm = as.matrix(features)
  dd <- colnames(features_norm)
  
  ##############
  # From vegan #
  ##############
  
  x <- as.matrix(features_norm)
  if (any(x < 0, na.rm = TRUE)) {
    k <- min(x, na.rm = TRUE)
    warning("input data contains negative entries: result may be non-sense")
  } else {
    k <- .Machine$double.eps
  }
  
  MARGIN <- 1
  
  tmp <- pmax(k, apply(x, MARGIN, sum, na.rm = TRUE))
  x <- sweep(x, MARGIN, tmp, "/")
  attr <- list(total = tmp, margin = MARGIN)
  if (any(is.nan(x))) 
    warning("result contains NaN, perhaps due to impossible mathematical\n
            operation\n")

  # Convert back to data frame
  features_TSS <- as.data.frame(x)
  
  # Rename the True Positive Features - Same Format as Before
  colnames(features_TSS) <- dd
  
  # Return
  return(features_TSS)
}

######################
## CLR Normalization #
######################

CLRnorm = function(features) {
  # Convert to Matrix from Data Frame
  features_norm = as.matrix(features)
  dd <- colnames(features_norm)
  
  #####################
  # from chemometrics #
  #####################
  
  # CLR Normalizing the Data
  X <- features_norm + 1
  Xgeom <- exp(1)^apply(log(X), 1, mean)
  features_CLR <- log(X/Xgeom)

  # Convert back to data frame
  features_CLR <- as.data.frame(features_CLR)
  
  # Rename the True Positive Features - Same Format as Before
  colnames(features_CLR) <- dd
  
  # Return
  return(features_CLR)
}

######################
## CSS Normalization #
######################

######################
# From metagenomeSeq #
######################

calcNormFactors <- function(x, p = cumNormStat(x)) {
  xx <- x
  xx[xx == 0] <- NA
  qs = matrixStats::colQuantiles(xx, probs = p, na.rm = TRUE)
  normFactors <- sapply(1:ncol(xx), function(i) {
    xx = (x[, i] - .Machine$double.eps)
    sum(xx[xx <= qs[i]])
  })
  names(normFactors) <- colnames(x)
  as.data.frame(normFactors)
}

cumNormStat <- function (counts, qFlag = TRUE, pFlag = FALSE, rel = 0.1, ...) {
  mat = counts
  if (any(colSums(mat) == 0)) 
    stop("Warning empty sample")
  smat = sapply(1:ncol(mat), function(i) {
    sort(mat[, i], decreasing = FALSE)
  })
  ref = rowMeans(smat)
  yy = mat
  yy[yy == 0] = NA
  ncols = ncol(mat)
  refS = sort(ref)
  k = which(refS > 0)[1]
  lo = (length(refS) - k + 1)
  if (qFlag == TRUE) {
    diffr = sapply(1:ncols, function(i) {
      refS[k:length(refS)] - quantile(yy[, i], p = seq(0, 
                                                       1, length.out = lo), na.rm = TRUE)
    })
  }
  if (qFlag == FALSE) {
    diffr = sapply(1:ncols, function(i) {
      refS[k:length(refS)] - approx(sort(yy[, i], decreasing = FALSE), 
                                    n = lo)$y
    })
  }
  diffr2 = matrixStats::rowMedians(abs(diffr), na.rm = TRUE)
  if (pFlag == TRUE) {
    plot(abs(diff(diffr2[diffr2 > 0]))/diffr2[diffr2 > 0][-1], 
         type = "h", ylab = "Relative difference for reference", 
         xaxt = "n", ...)
    abline(h = rel)
    axis(1, at = seq(0, length(diffr2), length.out = 5), 
         labels = seq(0, 1, length.out = 5))
  }
  x = which(abs(diff(diffr2))/diffr2[-1] > rel)[1]/length(diffr2)
  if (x <= 0.5) {
    message("Default value being used.")
    x = 0.5
  }
  return(x)
}

cumNormMat <- function (x, p = cumNormStat(x), sl = 1000) {
  xx <- x
  xx[xx == 0] <- NA
  qs = matrixStats::colQuantiles(xx, probs = p, na.rm = TRUE)
  newMat <- sapply(1:ncol(xx), function(i) {
    xx = (x[, i] - .Machine$double.eps)
    sum(xx[xx <= qs[i]])
  })
  nmat <- sweep(x, 2, newMat/sl, "/")
  return(nmat)
}

MRcounts <- function (counts, norm_factors, sl = 1000)  {
  if (any(is.na(norm_factors))) {
    x = cumNormMat(as.matrix(counts), sl = sl)
  } else {
    print(dim(counts))
    print(norm_factors/sl)
    x = sweep(as.matrix(counts), 2, norm_factors/sl, "/")
  }
  return(x)
}

CSSnorm = function(features) {
  features_norm = as.matrix(features)
  dd <- colnames(features_norm)
  
  counts = t(features_norm)
  norm_factors <- calcNormFactors(counts)$normFactors
  features_CSS <- as.data.frame(t(MRcounts(counts, norm_factors)))
  
  colnames(features_CSS) <- dd
  
  return(features_CSS)
}

######################
## TMM Normalization #
######################

##############
# From edgeR #
##############

.calcFactorQuantile <- function (data, lib.size, p=0.75)
  #	Generalized version of upper-quartile normalization
  #	Mark Robinson and Gordon Smyth
  #	Created 16 Aug 2010. Last modified 12 Sep 2020.
{
  f <- rep_len(1,ncol(data))
  for (j in seq_len(ncol(data))) f[j] <- quantile(data[,j], probs=p)
  if(min(f)==0) warning("One or more quantiles are zero")
  f / lib.size
}

.calcFactorTMM <- function(obs, ref, libsize.obs=NULL, libsize.ref=NULL, logratioTrim=.3, sumTrim=0.05, doWeighting=TRUE, Acutoff=-1e10)
  #	TMM between two libraries
  #	Mark Robinson
{
  obs <- as.numeric(obs)
  ref <- as.numeric(ref)
  
  if( is.null(libsize.obs) ) nO <- sum(obs) else nO <- libsize.obs
  if( is.null(libsize.ref) ) nR <- sum(ref) else nR <- libsize.ref
  
  logR <- log2((obs/nO)/(ref/nR))          # log ratio of expression, accounting for library size
  absE <- (log2(obs/nO) + log2(ref/nR))/2  # absolute expression
  v <- (nO-obs)/nO/obs + (nR-ref)/nR/ref   # estimated asymptotic variance
  
  #	remove infinite values, cutoff based on A
  fin <- is.finite(logR) & is.finite(absE) & (absE > Acutoff)
  
  logR <- logR[fin]
  absE <- absE[fin]
  v <- v[fin]
  
  if(max(abs(logR)) < 1e-6) return(1)
  
  #	taken from the original mean() function
  n <- length(logR)
  loL <- floor(n * logratioTrim) + 1
  hiL <- n + 1 - loL
  loS <- floor(n * sumTrim) + 1
  hiS <- n + 1 - loS
  
  #	keep <- (rank(logR) %in% loL:hiL) & (rank(absE) %in% loS:hiS)
  #	a fix from leonardo ivan almonacid cardenas, since rank() can return
  #	non-integer values when there are a lot of ties
  keep <- (rank(logR)>=loL & rank(logR)<=hiL) & (rank(absE)>=loS & rank(absE)<=hiS)
  
  if(doWeighting)
    f <- sum(logR[keep]/v[keep], na.rm=TRUE) / sum(1/v[keep], na.rm=TRUE)
  else
    f <- mean(logR[keep], na.rm=TRUE)
  
  #	Results will be missing if the two libraries share no features with positive counts
  #	In this case, return unity
  if(is.na(f)) f <- 0
  2^f
}

TMMnorm = function(features) {
  # Convert to Matrix from Data Frame
  features_norm = as.matrix(features)
  dd <- colnames(features_norm)
  
  # TMM Normalizing the Data
  X <- t(features_norm)
  x <- as.matrix(X)
  if (any(is.na(x)))
    stop("NA counts not permitted")
  nsamples <- ncol(x)
  lib.size <- colSums(x)
  method <- "TMM"
  allzero <- .rowSums(x > 0, nrow(x), nsamples) == 0L
  if (any(allzero))
    x <- x[!allzero, , drop = FALSE]
  if (nrow(x) == 0 || nsamples == 1)
    method = "none"
  
  f <- switch(method, TMM = {
    f75 <- suppressWarnings(.calcFactorQuantile(data = x, 
                                                lib.size = lib.size, p = 0.75))
    if (median(f75) < 1e-20) {
      refColumn <- which.max(colSums(sqrt(x)))
    } else {
      refColumn <- which.min(abs(f75 - mean(f75)))
    }
    f <- rep_len(NA_real_, nsamples)
    for (i in 1:nsamples) {
      f[i] <- .calcFactorTMM(obs = x[,i], ref = x[, refColumn], libsize.obs = lib.size[i], 
                             libsize.ref = lib.size[refColumn], logratioTrim = 0.3, 
                             sumTrim = 0.05, doWeighting = TRUE, Acutoff = -1e+10)
    }
    f
  }, 
  none = rep_len(1, nsamples))
  f <- f/exp(mean(log(f)))
  names(f) <- colnames(x)
  libSize <- f
  
  eff.lib.size = colSums(X) * libSize
  
  ref.lib.size = mean(eff.lib.size)
  #Use the mean of the effective library sizes as a reference library size
  X.output = sweep(X, MARGIN = 2, eff.lib.size, "/") * ref.lib.size
  #Normalized read counts
  
  # Convert back to data frame
  features_TMM <- as.data.frame(t(X.output))
  
  # Rename the True Positive Features - Same Format as Before
  colnames(features_TMM) <- dd
  
  # Return as list
  return(features_TMM)
}

#######################################
# Arc-Sine Square Root Transformation #
#######################################

AST <- function(x) {
  y <- sign(x) * asin(sqrt(abs(x)))
  if(any(is.na(y))) {
    logging::logerror(
      paste0("AST transform is only valid for values between -1 and 1. ",
             "Please select an appropriate normalization option or ",
             "normalize your data prior to running."))
    stop()
  }
  return(y)
}

########################
# Logit Transformation #
########################

# Zero-inflated Logit Transformation (Does not work well for microbiome data)
LOGIT <- function(p) {
  
  ########################
  # From the car package #
  ########################
  
  range.p <- range(p, na.rm = TRUE)
  if (range.p[2] > 1) {
    percents <- TRUE
    logging::loginfo("Note: largest value of p > 1 so values of p interpreted as percents")
  } else {
    percents <- FALSE
  }
  if (percents) {
    if (range.p[1] < 0 || range.p[2] > 100) 
      stop("p must be in the range 0 to 100")
    p <- p/100
    range.p <- range.p/100
  } else if (range.p[1] < 0 || range.p[2] > 1)  {
    stop("p must be in the range 0 to 1")
  }
  a <- 1
  y <- log((0.5 + a * (p - 0.5))/(1 - (0.5 + a * (p - 0.5))))
  y[!is.finite(y)] <- 0
  return(y)
}

######################
# Log Transformation #
######################

LOG <- function(x) {
  y <- replace(x, x == 0, min(x[x>0]) / 2)
  return(log2(y))
}

############################
# Write out the model fits #
############################

write_fits <- function(params_data_formula_fit) {
  param_list <- maaslin_parse_param_list(params_data_formula_fit[["param_list"]])
  output <- param_list[["output"]]
  fit_data <- params_data_formula_fit[["fit_data"]]

  fits_folder <- file.path(output, "fits")
  if (!file.exists(fits_folder)) {
    print("Creating output fits folder")
    dir.create(fits_folder)
  }
  
  ################################
  # Write out the raw model fits #
  ################################
  
  if (param_list[["save_models"]]) {
    model_file = file.path(fits_folder, "models.rds")
    # remove models file if already exists (since models append)
    if (file.exists(model_file)) {
      logging::logwarn(
        "Deleting existing model objects file: %s", model_file)
      unlink(model_file)
    }
    logging::loginfo("Writing model objects to file %s", model_file)
    saveRDS(fit_data$fits, file = model_file)   
  }
  
  ###########################
  # Write residuals to file #
  ###########################
  
  residuals_file = file.path(fits_folder, "residuals.rds")
  # remove residuals file if already exists (since residuals append)
  if (file.exists(residuals_file)) {
    logging::logwarn(
      "Deleting existing residuals file: %s", residuals_file)
    unlink(residuals_file)
  }
  logging::loginfo("Writing residuals to file %s", residuals_file)
  saveRDS(fit_data$residuals, file = residuals_file)
  
  ###############################
  # Write fitted values to file #
  ###############################
  
  fitted_file = file.path(fits_folder, "fitted.rds")
  # remove fitted file if already exists (since fitted append)
  if (file.exists(fitted_file)) {
    logging::logwarn(
      "Deleting existing fitted file: %s", fitted_file)
    unlink(fitted_file)
  }
  logging::loginfo("Writing fitted values to file %s", fitted_file)
  saveRDS(fit_data$fitted, file = fitted_file)
  
  #########################################################
  # Write extracted random effects to file (if specified) #
  #########################################################
  
  if (!is.null(param_list[["random_effects"]])) {
    ranef_file = file.path(fits_folder, "ranef.rds")
    # remove ranef file if already exists (since ranef append)
    if (file.exists(ranef_file)) {
      logging::logwarn(
        "Deleting existing ranef file: %s", ranef_file)
      unlink(ranef_file)
    }
    logging::loginfo("Writing extracted random effects to file %s", ranef_file)
    saveRDS(fit_data$ranef, file = ranef_file)
  }
}

write_results <- function(params_data_formula_fit) {
  param_list <- maaslin_parse_param_list(params_data_formula_fit[["param_list"]])
  output <- param_list[["output"]]
  max_significance <- param_list[["max_significance"]]
  fit_data <- params_data_formula_fit[["fit_data"]]

  #############################
  # Write all results to file #
  #############################
  
  results_file <- file.path(output, "all_results.tsv")
  logging::loginfo(
    "Writing all results to file (ordered by increasing q-values): %s",
    results_file)
  ordered_results <- fit_data$results[order(fit_data$results$qval), ]
  # Remove any that are NA for the q-value
  ordered_results <-
    ordered_results[!is.na(ordered_results$qval), ]
  write.table(
    ordered_results[c(
      "feature",
      "metadata",
      "value",
      "coef",
      "stderr",
      "N",
      "N.not.zero",
      "pval",
      "qval")],
    file = results_file,
    sep = "\t",
    quote = FALSE,
    col.names = c(
      "feature",
      "metadata",
      "value",
      "coef",
      "stderr",
      "N",
      "N.not.0",
      "pval",
      "qval"
    ),
    row.names = FALSE
  )
  
  ###########################################
  # Write results passing threshold to file #
  ###########################################
  
  significant_results <-
    ordered_results[ordered_results$qval <= max_significance, ]
  significant_results_file <-
    file.path(output, "significant_results.tsv")
  logging::loginfo(
    paste("Writing the significant results",
          "(those which are less than or equal to the threshold",
          "of %f ) to file (ordered by increasing q-values): %s"),
    max_significance,
    significant_results_file
  )
  write.table(
    significant_results[c(
      "feature",
      "metadata",
      "value",
      "coef",
      "stderr",
      "N",
      "N.not.zero",
      "pval",
      "qval")],
    file = significant_results_file,
    sep = "\t",
    quote = FALSE,
    col.names = c(
      "feature",
      "metadata",
      "value",
      "coef",
      "stderr",
      "N",
      "N.not.0",
      "pval",
      "qval"
    ),
    row.names = FALSE
  )
}



