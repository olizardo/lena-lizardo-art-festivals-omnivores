##################################
# Custom bootstrapping of APC bounding analyses
##################################

# This script contains the custom bootstrap
# function for the empirical example in the manuscript
# Data are prepped in the previous scripts
# which you have to execute to be able to run this
load("prebootstrap.RData")

###################
# APC function
###################
# takes the data and the indices (later boostrapped)
# returns a flattened vector with bounds and middle line
# for all three temporal variables

data <- smol
indices <- sample(1:nrow(smol), size = nrow(smol), replace = TRUE)

apc_bounding <- function(data, indices) {
  ################
  # Resample the data
  ################
  resampled_data <- data[indices,]
  
  ################
  # Conduct bounding analysis
  ################
  library(apcR)
  results <- runapc(y = approval, a = age_categories, p = period_categories, c = cohort_categories, data = resampled_data)

  # grabbing values of theta1 and theta2
  theta1 <- results[["thetas"]][1] # theta1 = alpha + pi (age slope + period slope)
  theta2 <- results[["thetas"]][2] # theta2 = gamma + pi (cohort slope + period slope)
  # grabbing the deviations
  AgeDeviations <- results[["AgeDeviations"]]
  PeriodDeviations <- results[["PeriodDeviations"]]
  CohortDeviations <- results[["CohortDeviations"]]
  # Add the sample size
  CohortDeviations$n <- as.numeric(table(smol$cohort_categories))
  AgeDeviations$n <- as.numeric(table(smol$age_categories))
  PeriodDeviations$n <- as.numeric(table(smol$period_categories))
  
  ################
  # Recover the smoothed nonlinearities
  ################
  library(ggplot2)
  # extract values
  cohort_dev <- ggplot(data = CohortDeviations, aes(x = Cohort, y = Deviation, alpha = n, size = n)) +
    geom_smooth(aes(weight = n),color = cohort_color, se = FALSE)
  # only look at variables and years of interest
  smoothed_data <- ggplot_build(cohort_dev)$data[[1]]
  smoothed_data <- smoothed_data[smoothed_data$x > 1983, c("x", "y")]
  
  # calculate the slope based on the smoothed values
  smoothed_data$x2[2:nrow(smoothed_data)] <- smoothed_data$x[1:(nrow(smoothed_data) - 1)]
  smoothed_data$y2[2:nrow(smoothed_data)] <- smoothed_data$y[1:(nrow(smoothed_data) - 1)]
  smoothed_data$slope <- (smoothed_data$y2 - smoothed_data$y)/(smoothed_data$x2 - smoothed_data$x)
  
  # pick the strongest negative slope and calculate linear effect to cancel it out
  cohort_min <- min(smoothed_data$slope, na.rm = TRUE)*40*(-1)
  
  # the minimal cohort increased based on the nonlinearities may
  # actually turn out negative -- in that case use 0
  # since we assume that the cohort effect is positive
  if (cohort_min < 0) {
    cohort_min <- 0
  }
  
  # generate the bound values by putting everything together
  twod <- twodapc(theta1=theta1, theta=theta2, by.ticks = 0.2,
                  agelimits=c(-2,2), periodlimits=c(-2, 2), cohortlimits=c(-2, 2),
                  rect.bounds = c(age=T, period=T, cohort=T), combined.rect=T,
                  apc.bounds=c(age=c(-Inf, Inf), period= c(0, Inf), cohort= c(cohort_min, Inf)),
                  main.title="")
  min.alpha <- twod$Slope[1]
  max.alpha <- twod$Slope[2]
  min.pi <- twod$Slope[3]
  max.pi <- twod$Slope[4]
  min.gamma <- twod$Slope[5]
  max.gamma <- twod$Slope[6]
  
  # calculate bounds
  intercept <- results[["intercept"]]
  matA <- results[["matA"]]
  matP <- results[["matP"]]
  matC <- results[["matC"]]
  AgeDeviations <- results[["AgeDeviations"]]
  PeriodDeviations <- results[["PeriodDeviations"]]
  CohortDeviations <- results[["CohortDeviations"]]
  AgeEffects <- AgeDeviations
  PeriodEffects <- PeriodDeviations
  CohortEffects <- CohortDeviations
  
  # lower bound
  AgeEffects$Min.Effect <-
    intercept + min.alpha * matA[, 1] + AgeDeviations$Deviation
  PeriodEffects$Min.Effect <-
    intercept + min.pi * matP[, 1] + PeriodDeviations$Deviation
  CohortEffects$Min.Effect <-
    intercept + min.gamma * matC[, 1] + CohortDeviations$Deviation
  
  # upper bound
  AgeEffects$Max.Effect <-
    intercept + max.alpha * matA[, 1] + AgeDeviations$Deviation
  PeriodEffects$Max.Effect <-
    intercept + max.pi * matP[, 1] + PeriodDeviations$Deviation
  CohortEffects$Max.Effect <-
    intercept + max.gamma * matC[, 1] + CohortDeviations$Deviation
  
  # mid line
  AgeEffects$Mid.Effect <- (AgeEffects$Min.Effect + AgeEffects$Max.Effect)/2
  PeriodEffects$Mid.Effect <- (PeriodEffects$Min.Effect + PeriodEffects$Max.Effect)/2
  CohortEffects$Mid.Effect <- (CohortEffects$Min.Effect + CohortEffects$Max.Effect)/2
  
  # Generate output
  # the output is a single vector to make it maximally compatible with
  # the boot-package default approach
  return(c(AgeEffects$Min.Effect, AgeEffects$Mid.Effect, AgeEffects$Max.Effect,
           PeriodEffects$Min.Effect, PeriodEffects$Mid.Effect, PeriodEffects$Max.Effect,
           CohortEffects$Min.Effect, CohortEffects$Mid.Effect, CohortEffects$Max.Effect))
}

###################
# Bootstrapping
###################
library(boot)
set.seed(123)
bootstrap_results <- boot(data = smol, statistic = apc_bounding, R = 1000)
save(bootstrap_results, file = "bootstrap_results")

ci_list <- vector("list", length = ncol(bootstrap_results$t))

# Loop through each statistic
for (i in seq_len(ncol(bootstrap_results$t))) {
  print(i)
  # Try calculating the confidence interval for the current statistic
  ci_list[[i]] <- tryCatch({
    boot.ci(bootstrap_results, type = c("norm", "perc"), index = i)
  }, error = function(e) {
    # Handle errors gracefully
    list(error = paste("Error for index", i, ":", e$message))
  })
}

# Check the resulting list of CIs
ci_list
save(ci_list, file = "ci_list")

###################
# Plot confidence intervals
###################
###########
# Put all confidence intervals into a data-frame
###########
all_cis <- data.frame(matrix(NA, nrow = 117, ncol = 3))
names(all_cis) <- c("lb", "ub", "t0")
for (i in 1:117) {
  all_cis[i, c("lb", "ub")] <- ci_list[[i]]$percent[1, 4:5]
  all_cis[i, "t0"] <- ci_list[[i]]$t0
}

###########
# Extract age
###########
ci_age <- data.frame(matrix(NA, nrow = nrow(AgeDeviations), ncol = 10))
names(ci_age) <- c("Age", "lb_lower", "ub_lower", "t0_lower", "lb_middle", "ub_middle", "t0_middle", "lb_upper", "ub_upper", "t0_upper")
ci_age$Age <- AgeDeviations$Age

# Age min: 1:13, Age mid: 14:26, Age max: 27:39
ci_age[, c("lb_lower", "ub_lower")] <- all_cis[1:13, c("lb", "ub")]
ci_age$t0_lower <- all_cis[1:13, "t0"]
ci_age[, c("lb_middle", "ub_middle")] <- all_cis[14:26, c("lb", "ub")]
ci_age$t0_middle <- all_cis[14:26, "t0"]
ci_age[, c("lb_upper", "ub_upper")] <- all_cis[27:39, c("lb", "ub")]
ci_age$t0_upper <- all_cis[27:39, "t0"]

###########
# Extract period
###########
ci_period <- data.frame(matrix(NA, nrow = nrow(PeriodDeviations), ncol = 10))
names(ci_period) <- c("period", "lb_lower", "ub_lower", "t0_lower", "lb_middle", "ub_middle", "t0_middle","lb_upper", "ub_upper", "t0_upper")
ci_period$period <- PeriodDeviations$Period

# period min: 40:46, period mid: 47:53, period max: 54:60
ci_period[, c("lb_lower", "ub_lower")] <- all_cis[40:46, c("lb", "ub")]
ci_period$t0_lower <- all_cis[40:46, "t0"]
ci_period[, c("lb_middle", "ub_middle")] <- all_cis[47:53, c("lb", "ub")]
ci_period$t0_middle <- all_cis[47:53, "t0"]
ci_period[, c("lb_upper", "ub_upper")] <- all_cis[54:60, c("lb", "ub")]
ci_period$t0_upper <- all_cis[54:60, "t0"]
###########
# Extract cohort
###########
ci_cohort <- data.frame(matrix(NA, nrow = nrow(CohortDeviations), ncol = 10))
names(ci_cohort) <- c("cohort", "lb_lower", "ub_lower", "t0_lower","lb_middle", "ub_middle", "t0_middle","lb_upper", "ub_upper", "t0_upper")
ci_cohort$cohort <- CohortDeviations$Cohort

# cohort min: 61:79, cohort mid: 80:98 , cohort max: 99:117 
ci_cohort[, c("lb_lower", "ub_lower")] <- all_cis[61:79, c("lb", "ub")]
ci_cohort$t0_lower <- all_cis[61:79, "t0"]
ci_cohort[, c("lb_middle", "ub_middle")] <- all_cis[80:98, c("lb", "ub")]
ci_cohort$t0_middle <- all_cis[80:98, "t0"]
ci_cohort[, c("lb_upper", "ub_upper")] <- all_cis[99:117, c("lb", "ub")]
ci_cohort$t0_upper <- all_cis[99:117, "t0"]


###########
# Plot all of this
###########
age_max <- "#0072B2"
cohort_max <- "#0072B2"
period_max <- "#D55E00"

age_min <- "#D55E00"
cohort_min <- "#D55E00"
period_min <- "#0072B2"


ylim.age = c(1, 4)
ylim.period = c(1, 4)
ylim.cohort = c(1, 4)
xlim.age = c(18, 70)
xlim.period = c(1992, 2016)
xlim.cohort = c(1932, 1998)
age.ticks = 8
period.ticks = 4
cohort.ticks = 8
y.ticks = .5

show.grid = FALSE

png("Plots/Fig 8/bounds_ci.png", units="in", width=8, height=4, res=600)

# General setup
par(mar = c(5.1, 4.1, 4.1, 2.1))
par(mfrow = c(1, 3))
  
# Age setup
  plot(
    x = ci_age$Age,
    y = ci_age$lb_lower,
    col = "black",
    type = "n",
    ylim = ylim.age,
    xlim = xlim.age,
    xlab = "Age",
    ylab = "Approval (95% CI)",
    yaxt = "n",
    xaxt = "n",
    main = "Age effects"
  )
  
  axis(
    side = 2,
    at = seq(
      from = min(ylim.age),
      to = max(ylim.age),
      by = y.ticks
    ),
    las = 1,
    cex.axis = .8
  )
  axis(
    side = 1,
    at = seq(
      from = min(xlim.age),
      to = max(xlim.age),
      by = age.ticks
    ),
    las = 0,
    cex.axis = .8
  )

  # Age lower
  lines(
    x = ci_age$Age,
    y = ci_age$lb_lower,
    lty = 1,
    col = adjustcolor(age_min, alpha.f = 0.9)
  )
  
  lines(
    x = ci_age$Age,
    y = ci_age$ub_lower,
    lty = 1,
    col = adjustcolor(age_min, alpha.f = 0.9)
  )
  
  lines(
    x = ci_age$Age,
    y = ci_age$t0_lower,
    lty = 2,
    col = adjustcolor(age_min, alpha.f = 0.9)
  )

  polygon.x <- c(ci_age$Age, rev(ci_age$Age))
  polygon.y <- c(ci_age$lb_lower, rev(ci_age$ub_lower))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(age_min, alpha.f = 0.1),
    border = NA
  )
  
  # Age upper
  lines(
    x = ci_age$Age,
    y = ci_age$lb_upper,
    lty = 1,
    col = adjustcolor(age_max, alpha.f = 0.9)
  )
  
  lines(
    x = ci_age$Age,
    y = ci_age$ub_upper,
    lty = 1,
    col = adjustcolor(age_max, alpha.f = 0.9)
  )
  
  lines(
    x = ci_age$Age,
    y = ci_age$t0_upper,
    lty = 2,
    col = adjustcolor(age_max, alpha.f = 0.9)
  )
  
  polygon.x <- c(ci_age$Age, rev(ci_age$Age))
  polygon.y <- c(ci_age$lb_upper, rev(ci_age$ub_upper))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(age_max, alpha.f = 0.1),
    border = NA
  )
  
  # Age middle
  lines(
    x = ci_age$Age,
    y = ci_age$lb_middle,
    lty = 1,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  lines(
    x = ci_age$Age,
    y = ci_age$ub_middle,
    lty = 1,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  

  
  lines(
    x = ci_age$Age,
    y = ci_age$t0_middle,
    lty = 2,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  polygon.x <- c(ci_age$Age, rev(ci_age$Age))
  polygon.y <- c(ci_age$lb_middle, rev(ci_age$ub_middle))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor("grey", alpha.f = 0.1),
    border = NA
  )
  
  # Period panel
  plot(
    x = ci_period$period,
    y = ci_period$lb_lower,
    col = "black",
    type = "n",
    ylim = ylim.period,
    xlim = xlim.period,
    xlab = "Period",
    ylab = "Approval (95% CI)",
    yaxt = "n",
    xaxt = "n",
    main = "Period effects"
  )
  
  axis(
    side = 2,
    at = seq(
      from = min(ylim.period),
      to = max(ylim.period),
      by = y.ticks
    ),
    las = 1,
    cex.axis = .8
  )
  axis(
    side = 1,
    at = seq(
      from = min(xlim.period),
      to = max(xlim.period),
      by = period.ticks
    ),
    las = 0,
    cex.axis = .8
  )
  
  # Period lower
  lines(
    x = ci_period$period,
    y = ci_period$lb_lower,
    lty = 1,
    col = adjustcolor(period_min, alpha.f = 0.9)
  )
  
  lines(
    x = ci_period$period,
    y = ci_period$ub_lower,
    lty = 1,
    col = adjustcolor(period_min, alpha.f = 0.9)
  )
  
  lines(
    x = ci_period$period,
    y = ci_period$t0_lower,
    lty = 2,
    col = adjustcolor(period_min, alpha.f = 0.9)
  )

  polygon.x <- c(ci_period$period, rev(ci_period$period))
  polygon.y <-
    c(ci_period$lb_lower, rev(ci_period$ub_lower))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(period_min, alpha.f = 0.1),
    border = NA
  )
  
  # Period upper
  lines(
    x = ci_period$period,
    y = ci_period$lb_upper,
    lty = 1,
    col = adjustcolor(period_max, alpha.f = 0.9)
  )
  
  lines(
    x = ci_period$period,
    y = ci_period$ub_upper,
    lty = 1,
    col = adjustcolor(period_max, alpha.f = 0.9)
  )
  
  lines(
    x = ci_period$period,
    y = ci_period$t0_upper,
    lty = 2,
    col = adjustcolor(period_max, alpha.f = 0.9)
  )
  
  
  polygon.x <- c(ci_period$period, rev(ci_period$period))
  polygon.y <-
    c(ci_period$lb_upper, rev(ci_period$ub_upper))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(period_max, alpha.f = 0.1),
    border = NA
  )
  
  # Period middle
  lines(
    x = ci_period$period,
    y = ci_period$lb_middle,
    lty = 1,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  lines(
    x = ci_period$period,
    y = ci_period$ub_middle,
    lty = 1,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  
  lines(
    x = ci_period$period,
    y = ci_period$t0_middle,
    lty = 2,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  
  polygon.x <- c(ci_period$period, rev(ci_period$period))
  polygon.y <-
    c(ci_period$lb_middle, rev(ci_period$ub_middle))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor("grey", alpha.f = 0.1),
    border = NA
  )
  
  # Cohort
  plot(
    x = ci_cohort$cohort,
    y = ci_cohort$Effect,
    col = "black",
    type = "n",
    ylim = ylim.cohort,
    xlim = xlim.cohort,
    xlab = "Cohort",
    ylab = "Approval (95% CI)",
    yaxt = "n",
    xaxt = "n",
    main = "Cohort Effects"
  )
  
  axis(
    side = 2,
    at = seq(
      from = min(ylim.cohort),
      to = max(ylim.cohort),
      by = y.ticks
    ),
    las = 1,
    cex.axis = .8
  )
  axis(
    side = 1,
    at = seq(
      from = min(xlim.cohort),
      to = max(xlim.cohort),
      by = cohort.ticks
    ),
    las = 0,
    cex.axis = .8
  )
  
  # Cohort lower
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$lb_lower,
    lty = 1,
    col = adjustcolor(cohort_min, alpha.f = 0.9)
  )
  
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$ub_lower,
    lty = 1,
    col = adjustcolor(cohort_min, alpha.f = 0.9)
  )
  
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$t0_lower,
    lty = 2,
    col = adjustcolor(cohort_min, alpha.f = 0.9)
  )
  

  polygon.x <- c(ci_cohort$cohort, rev(ci_cohort$cohort))
  polygon.y <-
    c(ci_cohort$lb_lower, rev(ci_cohort$ub_lower))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(cohort_min, alpha.f = 0.1),
    border = NA
  )
  
  # Cohort upper
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$lb_upper,
    lty = 1,
    col = adjustcolor(cohort_max, alpha.f = 0.9)
  )
  
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$ub_upper,
    lty = 1,
    col = adjustcolor(cohort_max, alpha.f = 0.9)
  )
  
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$t0_upper,
    lty = 2,
    col = adjustcolor(cohort_max, alpha.f = 0.9)
  )
  
  
  polygon.x <- c(ci_cohort$cohort, rev(ci_cohort$cohort))
  polygon.y <-
    c(ci_cohort$lb_upper, rev(ci_cohort$ub_upper))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(cohort_max, alpha.f = 0.1),
    border = NA
  )
  
  # Cohort middle
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$lb_middle,
    lty = 1,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$ub_middle,
    lty = 1,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  lines(
    x = ci_cohort$cohort,
    y = ci_cohort$t0_middle,
    lty = 2,
    col = adjustcolor("grey", alpha.f = 0.9)
  )
  
  
  polygon.x <- c(ci_cohort$cohort, rev(ci_cohort$cohort))
  polygon.y <-
    c(ci_cohort$lb_middle, rev(ci_cohort$ub_middle))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor("grey", alpha.f = 0.1),
    border = NA
  )
  
  par(mar = c(5.1, 4.1, 4.1, 2.1))
  par(mfrow = c(1, 1))
dev.off()





###################
# Hypothesis Test: Period decrease 2012 to 2016
###################
# Index of the 2012 Mid Period Estimate
# First we have all three age estimates, then the period min effects, then period mid effects

index_2012 <- nrow(AgeDeviations)*3 + nrow(PeriodDeviations) + which(PeriodDeviations$Period == 2012)
# Same for 2016
index_2016 <- nrow(AgeDeviations)*3 + nrow(PeriodDeviations) + which(PeriodDeviations$Period == 2016)
# Boostrapped period diffs
period_diffs <- bootstrap_results$t[, index_2016] - bootstrap_results$t[, index_2012]

quantile(period_diffs, probs = c(.025, .5, .975))


# For upper bound
index_2012 <- nrow(AgeDeviations)*3 + nrow(PeriodDeviations)*2 + which(PeriodDeviations$Period == 2012)
index_2016 <- nrow(AgeDeviations)*3 + nrow(PeriodDeviations)*2 + which(PeriodDeviations$Period == 2016)
period_diffs <- bootstrap_results$t[, index_2016] - bootstrap_results$t[, index_2012]
quantile(period_diffs, probs = c(.025, .5, .975))

# for lower bound
index_2012 <- nrow(AgeDeviations)*3 + which(PeriodDeviations$Period == 2012)
index_2016 <- nrow(AgeDeviations)*3 + which(PeriodDeviations$Period == 2016)
period_diffs <- bootstrap_results$t[, index_2016] - bootstrap_results$t[, index_2012]
quantile(period_diffs, probs = c(.025, .5, .975))