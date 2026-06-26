##################################
# Empirical Illustration
# Attitudes towards working women
# using the Allbus data
##################################

# This script contains all empirical analyses
# and generates Figure 5, Figure 6 and Figure 7
# to actually run the analysis, you have to first gain access
# to the ALLBUS data:
# ALLBUS-Kumulation 1980-2021, Version 1.1.0
# https://doi.org/10.4232/1.14333
# for details, see here: https://www.gesis.org/en/allbus/data-and-documentation
# You need to get the Stata version of the data (.dta)


###############
# Load data
###############
library(haven)
allbus <- read_dta(file = "Allbus/ZA5284_v1-1-0.dta/ZA5284_v1-1-0.dta")

# Look at items of interest
# 1 full agreement, 4 disagreement

# A working mother can have a just as trustful 
# relationship as one who does not work
table(allbus$fr01) 
# A toddler will surely suffer when the mother works
table(allbus$fr03a)
# It is actually good for a child when the mom works
table(allbus$fr05a)

# Only keep valid answers
allbus <- allbus[allbus$fr01 >= 1 & allbus$fr03a >= 1 & allbus$fr05a >= 1, ]

# Generate recoded variables
# (original allbus coding: higher value, lower agreement, which I find confusing)
allbus$loving <- 5 - allbus$fr01
allbus$suffer <- 5 - allbus$fr03a
allbus$good <- 5 - allbus$fr05a

library(psych)
psych::alpha(allbus[, c("loving", "suffer", "good")], check.keys = TRUE) # alpha of .69
cor.test(allbus$loving, allbus$suffer)
cor.test(allbus$loving, allbus$good)
cor.test(allbus$suffer, allbus$good)


allbus$approval <- ((allbus$loving) + (5 - allbus$suffer) + (allbus$good))/3
hist(allbus$approval)
summary(allbus$approval[allbus$year == 1992])
summary(allbus$approval[allbus$year == 2016])

# look at age
table(allbus$age)

# only keep people with known age
allbus <- allbus[allbus$age > 0, ]

# look at survey year
table(allbus$year)

# keep the years where the survey took party every 4 years
allbus <- allbus[allbus$year >= 1992,]

# lets work with a smaller dataset just containing the variables that we will need
smol <- allbus[, c("age", "approval", "year")]
rm(allbus)

# add cohort
smol$cohort <- smol$year - smol$age
table(smol$cohort)

table(smol$age) # no gaps

smol <- smol[smol$age < 70,]

# we will drop higher ages as concerns about selective mortality 
# may intensify past age 70

summary(smol$age)
sd(smol$age)
summary(smol$approval)

table(smol$cohort)
################
# Grouping of the variables
################
# The item was not asked in every survey (i.e., every other year)
# We will use data from 1992 to 2016, where the item was asked
# every four years
table(smol$years)

# the LAPC requires grouping of the temporal variable in equal-width bins
# So we have to re-categorize age and cohort


# Regroup age, always pool four consecutive years
smol$age_categories <- cut(smol$age, breaks = seq(from = 18, to = 70, by = 4), 
                           labels = seq(from = 18, to = 66, by = 4), right = FALSE)

# Period variable already always covers two years
smol$period_categories <- as.factor(smol$year)

# generate cohort variable
smol$cohort_categories <- as.numeric(as.character(smol$period_categories)) - as.numeric(as.character(smol$age_categories))
smol$cohort_categories <- as.factor(smol$cohort_categories)

# Descriptive
summary(smol$age)
sd(smol$age)
table(smol$year)

################
# Some descriptive plots
################
library(ggplot2)

# Generate mean scores
library(dplyr)


# Group by combinations of age_categories, period_categories, and year_categories
result_descriptive <- smol %>%
  group_by(age_categories, period_categories, cohort_categories) %>%
  summarize(
    n = n(),
    mean = mean(approval, na.rm = TRUE),
    lower_ci = mean(approval, na.rm = TRUE) - qt(0.975, df = n() - 1) * sd(approval, na.rm = TRUE) / sqrt(n()),
    upper_ci = mean(approval, na.rm = TRUE) + qt(0.975, df = n() - 1) * sd(approval, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )


# Plot over historic time
age_labels <- paste0(seq(from = 18, to = 66, by = 4), "-", seq(from = 21, to = 69, by = 4))
cohort_labels <- paste0(seq(from = 1923, to = 1998, by = 4), "-", seq(from = 1926, to = 2001, by = 4))

# Over time, by age
ggplot(data = result_descriptive, 
       aes(x = period_categories, y = mean, group = age_categories, color = age_categories)) +
  geom_point() +
  geom_line() +
  theme_classic(base_size = 18) +
  coord_cartesian(ylim = c(1, 4)) +
  ylab("Average approval") +
  xlab("Survey year") +
  labs(color = "Age") +
  scale_color_discrete(labels = age_labels)
#ggsave(width = 7, height = 7, filename = "Plots/Fig 6/period_by_age.png", dpi = 600)

# Over time, by cohort
ggplot(data = result_descriptive, 
       aes(x = period_categories, y = mean, group = cohort_categories, color = cohort_categories)) +
  geom_point() +
  geom_line() +
  theme_classic(base_size = 18) +
  coord_cartesian(ylim = c(1, 4)) +
  ylab("Average approval") +
  xlab("Survey year") +
  labs(color = "Birth cohort") +
  scale_color_discrete(labels = cohort_labels) #+
#scale_alpha_continuous(range = c(0.1, 1), guide = "none")
#ggsave(width = 7, height = 7, filename = "Plots/Fig 6/period_by_cohort.png", dpi = 600)


# Over age, by cohort
ggplot(data = result_descriptive, 
       aes(x = age_categories, y = mean, group = cohort_categories, color = cohort_categories)) +
  geom_point() +
  geom_line() +
  theme_classic(base_size = 18) +
  coord_cartesian(ylim = c(1, 4)) +
  ylab("Average approval") +
  xlab("Age") +
  labs(color = "Birth cohort") +
  scale_color_discrete(labels = cohort_labels) #+
  #scale_alpha_continuous(range = c(0.1, 1), guide = "none")
#ggsave(width = 7, height = 7, filename = "Plots/Fig 6/age_by_cohort.png", dpi = 600)

# Over age, by period
ggplot(data = result_descriptive, 
       aes(x = age_categories, y = mean, group = period_categories, color = period_categories)) +
  geom_point() +
  geom_line() +
  theme_classic(base_size = 18) +
  coord_cartesian(ylim = c(1, 4)) +
  ylab("Average approval") +
  xlab("Age") +
  labs(color = "Survey year")
#ggsave(width = 7, height = 7, filename = "Plots/Fig 6/age_by_period.png", dpi = 600)



################
# Do the apc
################
# apcR package downloaded from https://scholar.harvard.edu/apc/software-0
# approximately June 2024

library(apcR)


# run the linearized age-period-cohort model
results <- runapc(y = approval, a = age_categories, p = period_categories, c = cohort_categories, data = smol)

# saving model output
model.full <- results[["model.full"]] # full APC model with theta1, theta2, and APC nonlinearities

# examining output of APC models
summary(model.full) # full APC model with theta1, theta2, and APC nonlinearities

summary(model.full) # full APC model with theta1, theta2, and APC nonlinearities

# grabbing values of theta1 and theta2
theta1 <- results[["thetas"]][1] # theta1 = alpha + pi (age slope + period slope)
theta2 <- results[["thetas"]][2] # theta2 = gamma + pi (cohort slope + period slope)
print(theta1); print(theta2) # these two quantities determine the orientation of the canonical solution line


################
# Canonical solutions line
################
# (the scale labels dont have enough decimals to actually show the values
# which we will fix in post-production)

png("Plots/Fig 7/canonical.png", units="in", width=5, height=5, res=600)


twodapc(theta1=theta1, theta=theta2, by.ticks = 0.2,
        agelimits=c(-2,2), periodlimits=c(-2, 2), cohortlimits=c(-2, 2),
        rect.bounds = c(age=F, period=F, cohort=F), combined.rect=F,
        apc.bounds=c(age=c(-Inf, Inf), period= c(-Inf, Inf), cohort= c(-Inf, Inf)),
        main.title="Canonical Solution Line")


abline(h=0, col="black", lty=2) # age-zero line (i.e., line when alpha=0)
abline(h=((-1)*(theta2-theta1)), col="black", lty=2) # period-zero line (i.e., line when pi=0)
abline(v=0, col="black", lty=2) # gamma-zero line (i.e., line when gamma=0)
dev.off()

################
# Plot the nonlinearities
################
library(ggplot2)

# grabbing the nonlinear effects
AgeDeviations <- results[["AgeDeviations"]]
PeriodDeviations <- results[["PeriodDeviations"]]
CohortDeviations <- results[["CohortDeviations"]]

# Add the sample size, for plotting purposes
CohortDeviations$n <- as.numeric(table(smol$cohort_categories))
AgeDeviations$n <- as.numeric(table(smol$age_categories))
PeriodDeviations$n <- as.numeric(table(smol$period_categories))


ylim_dev <- c(-0.15, 0.15)
ref_color <- "#CCCCCC"

cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
age_color <- cbPalette[2]
period_color <- cbPalette[3]
cohort_color <- cbPalette[4]

# Age
ggplot(data = AgeDeviations, aes(x = Age, y = Deviation)) +
  geom_point(color = age_color) +
  coord_cartesian(ylim = ylim_dev) +
  theme_classic(base_size = 14) +
  geom_hline(yintercept = 0, color = ref_color) +
  geom_smooth(aes(weight = n), color = age_color, se = FALSE) +
  ylab("Age nonlinearity") +
  xlab("Age")
#ggsave(width = 4, height = 3, filename = "Plots/Fig 7/age.png", dpi = 600)


# Period
ggplot(data = PeriodDeviations, aes(x = Period, y = Deviation)) +
  geom_point(color = period_color) +
  coord_cartesian(ylim = ylim_dev) +
  theme_classic(base_size = 14) +
  geom_hline(yintercept = 0, color = ref_color) +
  geom_smooth(aes(weight = n), color = period_color, se = FALSE) +
  ylab("Period nonlinearity") +
  xlab("Period") +
  scale_x_continuous(breaks = PeriodDeviations$Period) +
  theme(axis.text.x = element_text(size = rel(0.6),angle = -45, vjust = 0.5, hjust=0.1))
#ggsave(width = 4, height = 3, filename = "Plots/Fig 7/period.png", dpi = 600)

# Cohort
# without legend (to ensure it is precisely the same format as age and period)
ggplot(data = CohortDeviations, aes(x = Cohort, y = Deviation, alpha = n, size = n)) +
  geom_point(color = cohort_color) +
  coord_cartesian(ylim = ylim_dev) +
  #scale_colour_continuous(trans = "reverse") +
  theme_classic(base_size = 14) +
  geom_hline(yintercept = 0, color = ref_color) +
  geom_smooth(aes(weight = n),color = cohort_color, se = FALSE) +
  ylab("Cohort nonlinearity") +
  xlab("Cohort") + 
  theme(legend.position="none")
#ggsave(width = 4, height = 3, filename = "Plots/Fig 7/cohort_nolegend.png", dpi = 600)

# Cohort, but with legend
# (we will use this legend and paste it to the figure in postproduction)
ggplot(data = CohortDeviations, aes(x = Cohort, y = Deviation, alpha = n)) +
  geom_point(color = cohort_color) +
  coord_cartesian(ylim = ylim_dev) +
  #scale_colour_continuous(trans = "reverse") +
  theme_classic(base_size = 14) +
  geom_hline(yintercept = 0, color = ref_color) +
  ylab("Nonlinear nonlinearity") +
  xlab("Cohort")
#ggsave(width = 4, height = 3, filename = "Plots/Fig 7/cohort_legend.png", dpi = 600)


################
# Recover the smoothed nonlinearities
################
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

# new colors
age_max <- "#0072B2"
cohort_max <- "#0072B2"
period_max <- "#D55E00"

age_min <- "#D55E00"
cohort_min <- "#D55E00"
period_min <- "#0072B2"

bound.effects.custom <- function(min.alpha = -0.25,
                          max.alpha = 0.25,
                          min.pi = -0.25,
                          max.pi = 0.25,
                          min.gamma = -0.25,
                          max.gamma = 0.25,
                          results = results,
                          y.ticks = 0.25,
                          ylim.age = c(5, 7),
                          ylim.period = c(5, 7),
                          ylim.cohort = c(4.5, 7),
                          xlim.age = c(15, 95),
                          xlim.period = c(1965, 2020),
                          xlim.cohort = c(1880, 1990),
                          age.ticks = 10,
                          period.ticks = 10,
                          cohort.ticks = 20,
                          show.intercept = TRUE,
                          color.min = "grey",
                          color.max = "black",
                          show.grid = FALSE) {
  min.alpha <- min.alpha
  max.alpha <- max.alpha
  min.pi <- min.pi
  max.pi <- max.pi
  min.gamma <- min.gamma
  max.gamma <- max.gamma
  
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
  
  AgeEffects$Min.Effect <-
    intercept + min.alpha * matA[, 1] + AgeDeviations$Deviation
  PeriodEffects$Min.Effect <-
    intercept + min.pi * matP[, 1] + PeriodDeviations$Deviation
  CohortEffects$Min.Effect <-
    intercept + min.gamma * matC[, 1] + CohortDeviations$Deviation
  
  AgeEffects$Max.Effect <-
    intercept + max.alpha * matA[, 1] + AgeDeviations$Deviation
  PeriodEffects$Max.Effect <-
    intercept + max.pi * matP[, 1] + PeriodDeviations$Deviation
  CohortEffects$Max.Effect <-
    intercept + max.gamma * matC[, 1] + CohortDeviations$Deviation
  
  par(mar = c(5.1, 4.1, 4.1, 2.1))
  par(mfrow = c(1, 3))
  
  plot(
    x = AgeEffects$Age,
    y = AgeEffects$Effect,
    col = "black",
    type = "n",
    ylim = ylim.age,
    xlim = xlim.age,
    xlab = "Age",
    ylab = "Approval",
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
  if (show.grid){
  abline(
    h = seq(
      from = min(ylim.age),
      to = max(ylim.age),
      by = y.ticks
    ),
    v = seq(
      from = min(xlim.age),
      to = max(xlim.age),
      by = age.ticks
    ),
    col = rgb(0, 0, 0, alpha = 0.8),
    lty = 2,
    lwd = 0.25
  )}
  
  if (show.intercept == TRUE) {
    abline(
      a = intercept,
      b = 0,
      lty = "dotted",
      col = "black",
      lwd = 1.5
    )
  }
  lines(
    x = AgeEffects$Age,
    y = (AgeEffects$Min.Effect + AgeEffects$Max.Effect) / 2,
    lty = 3,
    col = adjustcolor(age_color, alpha.f = 0.9)
  )
  lines(
    x = AgeEffects$Age,
    y = AgeEffects$Min.Effect,
    lty = 1,
    col = adjustcolor(age_min, alpha.f = 0.9)
  )
  lines(
    x = AgeEffects$Age,
    y = AgeEffects$Max.Effect,
    lty = 2,
    col = adjustcolor(age_max, alpha.f = 0.9)
  )
  
  polygon.x <- c(AgeEffects$Age, rev(AgeEffects$Age))
  polygon.y <- c(AgeEffects$Min.Effect, rev(AgeEffects$Max.Effect))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(age_color, alpha.f = 0.4),
    border = NA
  )
  

  points(
    x = AgeEffects$Age,
    y = (AgeEffects$Min.Effect + AgeEffects$Max.Effect) / 2,
    pch = 20
  )
  

  
  plot(
    x = PeriodEffects$Period,
    y = PeriodEffects$Effect,
    col = "black",
    type = "n",
    ylim = ylim.period,
    xlim = xlim.period,
    xlab = "Period",
    ylab = "Approval",
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
  if (show.grid){
  abline(
    h = seq(
      from = min(ylim.period),
      to = max(ylim.period),
      by = y.ticks
    ),
    v = seq(
      from = min(xlim.period),
      to = max(xlim.period),
      by = period.ticks
    ),
    col = rgb(0, 0, 0, alpha = 0.8),
    lty = 1,
    lwd = 0.25
  )}
  
  if (show.intercept == TRUE) {
    abline(
      a = intercept,
      b = 0,
      lty = "dotted",
      col = "black",
      lwd = 1.5
    )
  }
  
  polygon.x <- c(PeriodEffects$Period, rev(PeriodEffects$Period))
  polygon.y <-
    c(PeriodEffects$Min.Effect, rev(PeriodEffects$Max.Effect))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(period_color, alpha.f = 0.4),
    border = NA
  )
  
  lines(
    x = PeriodEffects$Period,
    y = (PeriodEffects$Min.Effect + PeriodEffects$Max.Effect) / 2,
    lty = 3,
    col = adjustcolor(period_color, alpha.f = 0.9)
  )
  points(
    x = PeriodEffects$Period,
    y = (PeriodEffects$Min.Effect + PeriodEffects$Max.Effect) / 2,
    pch = 20
  )
  
  lines(
    x = PeriodEffects$Period,
    y = PeriodEffects$Min.Effect,
    lty = 2,
    col = adjustcolor(period_min, alpha.f = 0.9)
  )
  lines(
    x = PeriodEffects$Period,
    y = PeriodEffects$Max.Effect,
    lty = 1,
    col = adjustcolor(period_max, alpha.f = 0.9)
  )
  
  plot(
    x = CohortEffects$Cohort,
    y = CohortEffects$Effect,
    col = "black",
    type = "n",
    ylim = ylim.cohort,
    xlim = xlim.cohort,
    xlab = "Cohort",
    ylab = "Approval",
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
  
  if (show.grid){
  abline(
    h = seq(
      from = min(ylim.cohort),
      to = max(ylim.cohort),
      by = y.ticks
    ),
    v = seq(
      from = min(xlim.cohort),
      to = max(xlim.cohort),
      by = cohort.ticks
    ),
    col = rgb(0, 0, 0, alpha = 0.8),
    lty = 2,
    lwd = 0.25
  )}
  
  if (show.intercept == TRUE) {
    abline(
      a = intercept,
      b = 0,
      lty = "dotted",
      col = "black",
      lwd = 1.5
    )
  }
  
  polygon.x <- c(CohortEffects$Cohort, rev(CohortEffects$Cohort))
  polygon.y <-
    c(CohortEffects$Min.Effect, rev(CohortEffects$Max.Effect))
  polygon(
    x = polygon.x,
    y = polygon.y,
    col = adjustcolor(cohort_color, alpha.f = 0.4),
    border = NA
  )
  
  lines(
    x = CohortEffects$Cohort,
    y = (CohortEffects$Min.Effect + CohortEffects$Max.Effect) / 2,
    lty = 3,
    col = adjustcolor(cohort_color, alpha.f = 0.9)
  )
  points(
    x = CohortEffects$Cohort,
    y = (CohortEffects$Min.Effect + CohortEffects$Max.Effect) / 2,
    pch = 20
  )
  
  lines(
    x = CohortEffects$Cohort,
    y = CohortEffects$Min.Effect,
    lty = 1,
    col = adjustcolor(cohort_min, alpha.f = 0.9)
  )
  lines(
    x = CohortEffects$Cohort,
    y = CohortEffects$Max.Effect,
    lty = 2,
    col = adjustcolor(cohort_max, alpha.f = 0.9)
  )
  
  par(mar = c(5.1, 4.1, 4.1, 2.1))
  par(mfrow = c(1, 1))
  
}


# using results and constraints to graph bounds on APC effects
png("Plots/Fig 8/bounds.png", units="in", width=8, height=4, res=600)
bound.effects.custom(min.alpha=min.alpha , max.alpha=max.alpha,
              min.pi=min.pi, max.pi=max.pi,
              min.gamma=min.gamma, max.gamma=max.gamma,
              results=results,
              ylim.age = c(1, 4), ylim.period = c(1, 4),
              ylim.cohort = c(1, 4),
              xlim.age = c(18, 70),
              xlim.period = c(1992, 2016),
              xlim.cohort = c(1932, 1998), show.intercept = FALSE,
              age.ticks = 8,
              period.ticks = 4,
              cohort.ticks = 8,
              y.ticks = .5)
dev.off()

save.image("prebootstrap.RData")


################################
# Using a different smoothing method
# Just to check the robustness
################################



################
# Recover the smoothed nonlinearities
################
# extract values
cohort_dev_v2 <- ggplot(data = CohortDeviations, aes(x = Cohort, y = Deviation, alpha = n, size = n)) +
  geom_smooth(aes(weight = n),color = cohort_color, se = FALSE, method = "gam")

# save trajectories for comparison
cohort_dev + coord_cartesian(ylim = c(-.15, .15))
ggsave("LOESS.png", width = 3.5, height = 3)

cohort_dev_v2 + coord_cartesian(ylim = c(-.15, .15))
ggsave("GAM.png", width = 3.5, height = 3)


# only look at variables and years of interest
smoothed_data_v2 <- ggplot_build(cohort_dev_v2)$data[[1]]
smoothed_data_v2 <- smoothed_data_v2[smoothed_data_v2$x > 1983, c("x", "y")]

# calculate the slope based on the smoothed values
smoothed_data_v2$x2[2:nrow(smoothed_data_v2)] <- smoothed_data_v2$x[1:(nrow(smoothed_data_v2) - 1)]
smoothed_data_v2$y2[2:nrow(smoothed_data_v2)] <- smoothed_data_v2$y[1:(nrow(smoothed_data_v2) - 1)]
smoothed_data_v2$slope <- (smoothed_data_v2$y2 - smoothed_data_v2$y)/(smoothed_data_v2$x2 - smoothed_data_v2$x)

# pick the strongest negative slope and calculate linear effect to cancel it out
cohort_min_v2 <- min(smoothed_data_v2$slope, na.rm = TRUE)*40*(-1)

# vs.
cohort_min <- min(smoothed_data$slope, na.rm = TRUE)*40*(-1)

cohort_min_v2
cohort_min


twod_v2 <- twodapc(theta1=theta1, theta=theta2, by.ticks = 0.2,
                agelimits=c(-2,2), periodlimits=c(-2, 2), cohortlimits=c(-2, 2),
                rect.bounds = c(age=T, period=T, cohort=T), combined.rect=T,
                apc.bounds=c(age=c(-Inf, Inf), period= c(0, Inf), cohort= c(cohort_min_v2, Inf)),
                main.title="")

min.alpha_v2 <- twod_v2$Slope[1]
twod$Slope[1] # min.alpha

max.alpha_v2 <- twod_v2$Slope[2]
twod$Slope[2] # max.alpha

min.pi_v2 <- twod_v2$Slope[3]
twod$Slope[3] # min.pi

max.pi_v2 <- twod_v2$Slope[4]
twod$Slope[4] # max.pi

min.gamma_v2 <- twod_v2$Slope[5]
twod$Slope[5] # min.gamma

max.gamma_v2<- twod_v2$Slope[6]
twod$Slope[6] # max.gamma


png("Plots/Fig 8/bounds_GAM smoothed.png", units="in", width=8, height=4, res=600)
bound.effects.custom(min.alpha=min.alpha_v2 , max.alpha=max.alpha_v2,
                     min.pi=min.pi_v2, max.pi=max.pi_v2,
                     min.gamma=min.gamma_v2, max.gamma=max.gamma_v2,
                     results=results,
                     ylim.age = c(1, 4), ylim.period = c(1, 4),
                     ylim.cohort = c(1, 4),
                     xlim.age = c(18, 70),
                     xlim.period = c(1992, 2016),
                     xlim.cohort = c(1932, 1998), show.intercept = FALSE,
                     age.ticks = 8,
                     period.ticks = 4,
                     cohort.ticks = 8,
                     y.ticks = .5)
dev.off()
