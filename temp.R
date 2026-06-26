## ----setup, message=FALSE, warning=FALSE-------------------------------------------------------------------------
library(tidyverse)
library(haven)
library(lme4)
library(modelsummary)
library(ggeffects)

# Set seed for reproducibility
set.seed(3759)


## ----data-load, cache=TRUE---------------------------------------------------------------------------------------
# Select columns to optimize memory usage
cols_to_keep <- c(
  "persid", "year", "age", "gender", "education", "race", "hispanic",
  "jazz", "classical", "opera", "musical", "ballet", "artmuseum", "craft_fair", "park",
  "weight_normalized"
)

# Load data
df_raw <- read_dta("sppa1982-2012_stata.dta", col_select = all_of(cols_to_keep))


## ----recoding----------------------------------------------------------------------------------------------------
# Define outcomes
outcomes <- c("jazz", "classical", "opera", "musical", "ballet", "artmuseum", "craft_fair", "park")

# Recode outcomes and demographics
df_clean <- df_raw |>
  # Standardize outcomes: 1 = yes, 2 = no -> 1 = yes, 0 = no
  mutate(across(all_of(outcomes), ~ case_when(
    . == 1 ~ 1,
    . == 2 ~ 0,
    TRUE ~ NA_real_
  ))) |>
  # Filter out rows missing our primary focal outcome
  filter(!is.na(craft_fair)) |>
  # Demographics
  mutate(
    woman = if_else(gender == 2, 1, 0),
    college = if_else(education > 4, 1, 0),
    white = if_else(race == 1, 1, 0),
    black = if_else(race == 2, 1, 0),
    # Age variables
    age2 = age^2 / 100,
    age3 = age^3 / 1000,
    # 5-year age categories from 15 to 100
    agecat = cut(age, breaks = seq(15, 100, by = 5), right = FALSE, labels = FALSE),
    # Cohort calculations
    cohort = year - age
  ) |>
  # Filter out extremely old or young age outliers to match original analysis windows
  filter(age >= 15 & age <= 95)

# Function to generate cohort bins with custom bandwidth and lowest-cohort adjustments
get_cohort_bins <- function(cohort_val, width, start_yr = 1885, end_yr = 1995) {
  breaks <- seq(start_yr, end_yr, by = width)
  bins <- cut(cohort_val, breaks = breaks, right = FALSE, labels = FALSE)
  # Map bin indexes back to lower-bound year labels
  bin_labels <- breaks[bins]
  
  # Recode lowest cohort category to avoid sparse cells (as in Stata code)
  if (width == 2) {
    bin_labels[bin_labels >= 1885 & bin_labels <= 1887] <- 1889
  } else if (width == 4) {
    bin_labels[bin_labels == 1885] <- 1889
  } else if (width == 5) {
    bin_labels[bin_labels == 1885] <- 1890
  }
  return(bin_labels)
}

# Generate varying cohort bandwidths
df_clean <- df_clean |>
  mutate(
    cohort2 = get_cohort_bins(cohort, 2),
    cohort4 = get_cohort_bins(cohort, 4),
    cohort5 = get_cohort_bins(cohort, 5),
    cohort6 = get_cohort_bins(cohort, 6),
    cohort8 = get_cohort_bins(cohort, 8),
    # Calculate aggregate Omnivore Score (0-8 activities)
    omnivore_score = rowSums(across(all_of(outcomes)), na.rm = TRUE)
  )

# Preview clean dataset
df_clean |> 
  select(year, age, cohort, cohort4, cohort5, omnivore_score, college, white) |> 
  head()


## ----figure1-prep, message=FALSE, warning=FALSE------------------------------------------------------------------
# 1. Bivariate by Age Category
age_trends <- df_clean |>
  group_by(agecat) |>
  summarise(Value = mean(omnivore_score, na.rm = TRUE))

# 2. Bivariate by Survey Year
year_trends <- df_clean |>
  group_by(year) |>
  summarise(Value = mean(omnivore_score, na.rm = TRUE))

# 3. Bivariate by Cohort (5-Year)
cohort_trends <- df_clean |>
  filter(cohort5 >= 1890 & cohort5 <= 1990) |>
  group_by(cohort5) |>
  summarise(Value = mean(omnivore_score, na.rm = TRUE))


## ----figure1-plot, fig.width=12, fig.height=5--------------------------------------------------------------------
p_age <- ggplot(age_trends, aes(x = agecat, y = Value)) +
  geom_line(linewidth = 0.8) +
  geom_point() +
  theme_minimal() +
  labs(title = "By Age Category", x = "5-Year Age Category (1-17)", y = "Mean Omnivore Score")

p_year <- ggplot(year_trends, aes(x = year, y = Value)) +
  geom_line(linewidth = 0.8) +
  geom_point() +
  theme_minimal() +
  labs(title = "By Survey Year", x = "Survey Year", y = "")

p_cohort <- ggplot(cohort_trends, aes(x = cohort5, y = Value)) +
  geom_line(linewidth = 0.8) +
  geom_point() +
  theme_minimal() +
  labs(title = "By Birth Cohort (5-Year)", x = "Cohort Year", y = "")

library(patchwork)
p_fig1 <- p_age + p_year + p_cohort + plot_layout(ncol = 3, widths = c(1, 1, 1.2))
p_fig1

# Save plot to Plots/ folder
ggsave("Plots/bivariate_apc_trends.png", p_fig1, width = 12, height = 5, dpi = 300)


## ----figure2-plot, fig.width=8, fig.height=5, warning=FALSE, message=FALSE---------------------------------------
df_fig2 <- df_clean |>
  filter(year %in% c(1982, 2002, 2012)) |>
  filter(cohort5 >= 1900 & cohort5 <= 1990) |>
  group_by(cohort5, year) |>
  summarise(Participation = mean(omnivore_score, na.rm = TRUE), .groups = "drop") |>
  mutate(year = as.factor(year))

p_fig2 <- ggplot(df_fig2, aes(x = cohort5, y = Participation, color = year, group = year)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.2) +
  scale_color_brewer(palette = "Set1") +
  theme_minimal() +
  labs(x = "5-Year Birth Cohort", y = "Mean Omnivore Score", color = "Survey Year") +
  theme(legend.position = "bottom", axis.text.x = element_text(angle = 45, hjust = 1))

p_fig2

# Save plot to Plots/ folder
ggsave("Plots/cohort_trends_by_survey_year.png", p_fig2, width = 8, height = 5, dpi = 300)


## ----hapc-models-------------------------------------------------------------------------------------------------
# Convert year to factor for fixed effects
df_clean$year_factor <- as.factor(df_clean$year)

# Initialize list to store models
hapc_models <- list()

# Fit HAPC model for the aggregate Omnivore Score using Poisson glmer
message("Fitting HAPC model for: omnivore_score")
hapc_models[["Cultural Omnivore Score"]] <- glmer(
  omnivore_score ~ age + age2 + age3 + woman + college + white + black + year_factor + (1 | cohort4),
  family = poisson(link = "log"),
  data = df_clean,
  nAGQ = 0 # Optimized Laplace approximation for high speed and robustness
)


## ----hapc-table, warning=FALSE-----------------------------------------------------------------------------------
# Create a clean summary table of our HAPC models
modelsummary(
  hapc_models,
  stars = TRUE,
  coef_rename = c(
    "(Intercept)" = "Constant",
    "age" = "Age",
    "age2" = "Age-Squared",
    "age3" = "Age-Cubed",
    "woman" = "Woman",
    "college" = "College Graduate",
    "white" = "White",
    "black" = "Black",
    "year_factor1985" = "Year: 1985",
    "year_factor1992" = "Year: 1992",
    "year_factor2002" = "Year: 2002",
    "year_factor2008" = "Year: 2008",
    "year_factor2012" = "Year: 2012"
  ),
  gof_map = c("nobs", "aic", "bic"),
  output = "markdown"
)

# Export the regression table as HTML
modelsummary(
  hapc_models,
  stars = TRUE,
  coef_rename = c(
    "(Intercept)" = "Constant",
    "age" = "Age",
    "age2" = "Age-Squared",
    "age3" = "Age-Cubed",
    "woman" = "Woman",
    "college" = "College Graduate",
    "white" = "White",
    "black" = "Black",
    "year_factor1985" = "Year: 1985",
    "year_factor1992" = "Year: 1992",
    "year_factor2002" = "Year: 2002",
    "year_factor2008" = "Year: 2008",
    "year_factor2012" = "Year: 2012"
  ),
  gof_map = c("nobs", "aic", "bic"),
  output = "Tabs/hapc_table.html"
)


## ----cohort-window-robustness------------------------------------------------------------------------------------
cohort_specs <- c("cohort2", "cohort4", "cohort6", "cohort8")
window_effects <- list()

for (spec in cohort_specs) {
  formula_str <- paste0(
    "omnivore_score ~ age + age2 + age3 + woman + college + white + black + year_factor + (1 | ", spec, ")"
  )
  mod <- glmer(as.formula(formula_str), family = poisson(link = "log"), data = df_clean, nAGQ = 0)
  
  # Extract random intercepts
  re <- ranef(mod)[[spec]]
  re_df <- data.frame(
    cohort_val = as.numeric(rownames(re)),
    re_effect = re[, 1],
    spec = recode(spec,
      "cohort2" = "2-Year Window",
      "cohort4" = "4-Year Window",
      "cohort6" = "6-Year Window",
      "cohort8" = "8-Year Window"
    )
  )
  window_effects[[spec]] <- re_df
}

df_window_robustness <- bind_rows(window_effects)

p_bandwidth <- ggplot(df_window_robustness, aes(x = cohort_val, y = re_effect, color = spec, linetype = spec)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Cohort Random Effects across Bandwidths (Omnivore Score)",
    x = "Birth Cohort",
    y = "Estimated Cohort Random Effect (Log-Count)",
    color = "Cohort Window Size",
    linetype = "Cohort Window Size"
  ) +
  theme(legend.position = "bottom")

p_bandwidth

# Save plot to Plots/ folder
ggsave("Plots/cohort_bandwidth_robustness.png", p_bandwidth, width = 8, height = 5, dpi = 300)


## ----age-spec-robustness-----------------------------------------------------------------------------------------
age_formulas <- list(
  "Linear" = "omnivore_score ~ age + woman + college + white + black + year_factor + (1 | cohort4)",
  "Quadratic" = "omnivore_score ~ age + age2 + woman + college + white + black + year_factor + (1 | cohort4)",
  "Cubic" = "omnivore_score ~ age + age2 + age3 + woman + college + white + black + year_factor + (1 | cohort4)",
  "Non-Parametric" = "omnivore_score ~ as.factor(agecat) + woman + college + white + black + year_factor + (1 | cohort4)"
)

age_effects <- list()

for (spec_name in names(age_formulas)) {
  mod <- glmer(as.formula(age_formulas[[spec_name]]), family = poisson(link = "log"), data = df_clean, nAGQ = 0)
  
  re <- ranef(mod)[["cohort4"]]
  re_df <- data.frame(
    cohort_val = as.numeric(rownames(re)),
    re_effect = re[, 1],
    spec = spec_name
  )
  age_effects[[spec_name]] <- re_df
}

df_age_robustness <- bind_rows(age_effects)

p_age_spec <- ggplot(df_age_robustness, aes(x = cohort_val, y = re_effect, color = spec, linetype = spec)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Cohort Random Effects across Age Controls (Omnivore Score)",
    x = "Birth Cohort",
    y = "Estimated Cohort Random Effect (Log-Count)",
    color = "Age Specification",
    linetype = "Age Specification"
  ) +
  theme(legend.position = "bottom")

p_age_spec

# Save plot to Plots/ folder
ggsave("Plots/age_specification_robustness.png", p_age_spec, width = 8, height = 5, dpi = 300)


## ----advanced-robustness-checks, message=FALSE, warning=FALSE----------------------------------------------------
# Baseline model (Fixed effects for Period, unweighted, binary education)
mod_base <- glmer(omnivore_score ~ age + age2 + age3 + woman + college + white + black + year_factor + (1 | cohort4), 
                  family = poisson(link = "log"), data = df_clean, nAGQ = 0)

# Check 1: Period as Random Intercept (Cross-Classified CCREM)
mod_re_year <- glmer(omnivore_score ~ age + age2 + age3 + woman + college + white + black + (1 | year_factor) + (1 | cohort4), 
                     family = poisson(link = "log"), data = df_clean, nAGQ = 0)

re_fe_year <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_base)[["cohort4"]])),
                         re_effect = ranef(mod_base)[["cohort4"]][, 1], Spec = "Period Fixed Effects (Baseline)")
re_re_year <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_re_year)[["cohort4"]])),
                         re_effect = ranef(mod_re_year)[["cohort4"]][, 1], Spec = "Period Random Intercepts")

p_period_check <- ggplot(bind_rows(re_fe_year, re_re_year), aes(x = cohort_val, y = re_effect, color = Spec, linetype = Spec)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(title = "Period Specification Robustness (Fixed vs. Random Year)",
       x = "Birth Cohort", y = "Estimated Cohort Random Effect (Log-Count)", color = "Period Model") +
  theme(legend.position = "bottom")

# Check 2: Weighted vs. Unweighted
mod_weighted <- glmer(omnivore_score ~ age + age2 + age3 + woman + college + white + black + year_factor + (1 | cohort4), 
                      family = poisson(link = "log"), data = df_clean, weights = weight_normalized, nAGQ = 0)

re_weighted <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_weighted)[["cohort4"]])),
                          re_effect = ranef(mod_weighted)[["cohort4"]][, 1], Spec = "Svy Weighted HAPC")
re_unweighted <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_base)[["cohort4"]])),
                            re_effect = ranef(mod_base)[["cohort4"]][, 1], Spec = "Unweighted (Baseline)")

p_weight_check <- ggplot(bind_rows(re_weighted, re_unweighted), aes(x = cohort_val, y = re_effect, color = Spec, linetype = Spec)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(title = "Survey Weighting Robustness (Weighted vs. Unweighted)",
       x = "Birth Cohort", y = "Estimated Cohort Random Effect (Log-Count)", color = "Weighting") +
  theme(legend.position = "bottom")

# Check 3: Education Category Refinement (Binary vs. 6-Category)
df_edu_clean <- df_clean |> filter(!is.na(education))
mod_base_edu <- glmer(omnivore_score ~ age + age2 + age3 + woman + college + white + black + year_factor + (1 | cohort4), 
                      family = poisson(link = "log"), data = df_edu_clean, nAGQ = 0)
mod_multi_edu <- glmer(omnivore_score ~ age + age2 + age3 + woman + as.factor(education) + white + black + year_factor + (1 | cohort4), 
                       family = poisson(link = "log"), data = df_edu_clean, nAGQ = 0)

re_binary_edu <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_base_edu)[["cohort4"]])),
                            re_effect = ranef(mod_base_edu)[["cohort4"]][, 1], Spec = "Binary (College/No College)")
re_multi_edu <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_multi_edu)[["cohort4"]])),
                           re_effect = ranef(mod_multi_edu)[["cohort4"]][, 1], Spec = "6-Category Education Level")

p_edu_check <- ggplot(bind_rows(re_binary_edu, re_multi_edu), aes(x = cohort_val, y = re_effect, color = Spec, linetype = Spec)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(title = "Education Control Robustness (Binary vs. 6-Category)",
       x = "Birth Cohort", y = "Estimated Cohort Random Effect (Log-Count)", color = "Education Control") +
  theme(legend.position = "bottom")

# Check 4: Age-by-Demographic Interactions
mod_inter_age <- glmer(omnivore_score ~ age*college + age2*college + age3*college + age*woman + age2*woman + age3*woman + white + black + year_factor + (1 | cohort4), 
                       family = poisson(link = "log"), data = df_clean, nAGQ = 0)

re_no_inter_age <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_base)[["cohort4"]])),
                              re_effect = ranef(mod_base)[["cohort4"]][, 1], Spec = "Main Effects (Baseline)")
re_inter_age <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_inter_age)[["cohort4"]])),
                            re_effect = ranef(mod_inter_age)[["cohort4"]][, 1], Spec = "Age*College & Age*Woman Interactions")

p_inter_check <- ggplot(bind_rows(re_no_inter_age, re_inter_age), aes(x = cohort_val, y = re_effect, color = Spec, linetype = Spec)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(title = "Life-Course Interaction Robustness (Age*Demographics)",
       x = "Birth Cohort", y = "Estimated Cohort Random Effect (Log-Count)", color = "Model Specification") +
  theme(legend.position = "bottom")

# Display the 4 plots individually
p_period_check
ggsave("Plots/robustness_period.png", p_period_check, width = 8, height = 5, dpi = 300)

p_weight_check
ggsave("Plots/robustness_weight.png", p_weight_check, width = 8, height = 5, dpi = 300)

p_edu_check
ggsave("Plots/robustness_education.png", p_edu_check, width = 8, height = 5, dpi = 300)

p_inter_check
ggsave("Plots/robustness_interaction.png", p_inter_check, width = 8, height = 5, dpi = 300)


## ----strat-college-----------------------------------------------------------------------------------------------
# Fit HAPC for College grads and Non-College separately on Omnivore Score
mod_coll <- glmer(omnivore_score ~ age + age2 + age3 + woman + white + black + year_factor + (1 | cohort4), 
                  family = poisson(link = "log"), data = filter(df_clean, college == 1), nAGQ = 0)

mod_nocoll <- glmer(omnivore_score ~ age + age2 + age3 + woman + white + black + year_factor + (1 | cohort4), 
                    family = poisson(link = "log"), data = filter(df_clean, college == 0), nAGQ = 0)

re_coll <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_coll)[["cohort4"]])),
                      re_effect = ranef(mod_coll)[["cohort4"]][, 1], Group = "College Experience")

re_nocoll <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_nocoll)[["cohort4"]])),
                        re_effect = ranef(mod_nocoll)[["cohort4"]][, 1], Group = "No College")

df_strat_coll <- bind_rows(re_coll, re_nocoll)

p_strat_coll <- ggplot(df_strat_coll, aes(x = cohort_val, y = re_effect, color = Group)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Omnivore Score Cohort Effects Stratified by Education",
    x = "Birth Cohort",
    y = "Estimated Cohort Random Effect (Log-Count)",
    color = "Education Level"
  ) +
  theme(legend.position = "bottom")

p_strat_coll

# Save plot to Plots/ folder
ggsave("Plots/education_stratified_effects.png", p_strat_coll, width = 8, height = 5, dpi = 300)


## ----strat-race--------------------------------------------------------------------------------------------------
# Fit HAPC for White and Black respondents separately on Omnivore Score
mod_white_omni <- glmer(omnivore_score ~ age + age2 + age3 + woman + college + year_factor + (1 | cohort4), 
                        family = poisson(link = "log"), data = filter(df_clean, white == 1), nAGQ = 0)

mod_black_omni <- glmer(omnivore_score ~ age + age2 + age3 + woman + college + year_factor + (1 | cohort4), 
                        family = poisson(link = "log"), data = filter(df_clean, black == 1), nAGQ = 0)

re_white_omni <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_white_omni)[["cohort4"]])),
                            re_effect = ranef(mod_white_omni)[["cohort4"]][, 1], Group = "White")

re_black_omni <- data.frame(cohort_val = as.numeric(rownames(ranef(mod_black_omni)[["cohort4"]])),
                            re_effect = ranef(mod_black_omni)[["cohort4"]][, 1], Group = "Black")

df_strat_race <- bind_rows(re_white_omni, re_black_omni)

p_strat_race <- ggplot(df_strat_race, aes(x = cohort_val, y = re_effect, color = Group)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Omnivore Score Cohort Effects Stratified by Race",
    x = "Birth Cohort",
    y = "Estimated Cohort Random Effect (Log-Count)",
    color = "Race"
  ) +
  theme(legend.position = "bottom")

p_strat_race

# Save plot to Plots/ folder
ggsave("Plots/race_stratified_effects.png", p_strat_race, width = 8, height = 5, dpi = 300)


## ----fosse-winship-bounds----------------------------------------------------------------------------------------
# Fit standard categorical APC GLM reference model on Omnivore Score using Poisson
fit_apc_omni <- glm(
  omnivore_score ~ as.factor(agecat) + as.factor(year) + as.factor(cohort5) + woman + college + white + black,
  family = poisson(link = "log"), 
  data = df_clean
)
coefs_omni <- coef(fit_apc_omni)

# Build coefficient vectors including reference category (0)
age_vals <- seq(15, 95, by = 5)
age_coefs_omni <- c(0, coefs_omni[grep("as.factor\\(agecat\\)", names(coefs_omni))])
names(age_coefs_omni) <- age_vals

period_years <- c(1982, 1985, 1992, 2002, 2008, 2012)
period_coefs_omni <- c(0, coefs_omni[grep("as.factor\\(year\\)", names(coefs_omni))])
names(period_coefs_omni) <- period_years

cohort_years <- seq(1890, 1990, by = 5)
cohort_coefs_omni <- c(0, coefs_omni[grep("as.factor\\(cohort5\\)", names(coefs_omni))])
names(cohort_coefs_omni) <- cohort_years

# Set reference years
A_ref <- 15
P_ref <- 1982
C_ref <- P_ref - A_ref

# Compute bounds on slope s
s_upper_age_o <- as.numeric((age_coefs_omni["50"] - age_coefs_omni["80"]) / 30)
s_upper_period_o <- as.numeric((period_coefs_omni["2012"] - period_coefs_omni["1982"] + 1.5) / 30)
s_lower_period_o <- as.numeric((period_coefs_omni["2012"] - period_coefs_omni["1982"]) / 30)

# Determine valid bounds
s_max_o <- min(s_upper_age_o, s_upper_period_o)
s_min_o <- s_lower_period_o
message("Computed Bounds on s: [", round(s_min_o, 4), ", ", round(s_max_o, 4), "]")

# Create bounded cohort curves
df_bounds_omni <- tibble(
  cohort = cohort_years,
  effect_min = cohort_coefs_omni + s_min_o * (cohort - C_ref),
  effect_zero = cohort_coefs_omni,
  effect_max = cohort_coefs_omni + s_max_o * (cohort - C_ref)
)

p_bounds_omni <- ggplot(df_bounds_omni, aes(x = cohort)) +
  geom_line(aes(y = effect_zero, color = "s = 0 (Baseline Reference)"), linewidth = 1) +
  geom_line(aes(y = effect_min, color = paste("s =", round(s_min_o, 4), "(Lower Bound)")), linewidth = 1, linetype = "dashed") +
  geom_line(aes(y = effect_max, color = paste("s =", round(s_max_o, 4), "(Upper Bound)")), linewidth = 1, linetype = "dotdash") +
  geom_hline(yintercept = 0, linetype = "solid", alpha = 0.3) +
  theme_minimal() +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "Bounded Cohort Effects for Omnivore Score",
    subtitle = "Fosse & Winship Bounding Approach (Poisson Model)",
    x = "Birth Cohort",
    y = "Cohort Effect (Log-Count)",
    color = "Slope Shift (s)"
  ) +
  theme(legend.position = "bottom")

p_bounds_omni

# Save plot to Plots/ folder
ggsave("Plots/cohort_bounds_omnivore.png", p_bounds_omni, width = 8, height = 5, dpi = 300)


## ----gam-lexis-surface-------------------------------------------------------------------------------------------
library(mgcv)

# Fit GAM with tensor-product spline of age and period for Omnivore Score using Poisson
fit_gam_omni <- gam(
  omnivore_score ~ te(age, year, k = c(5, 5)) + woman + college + white + black,
  family = poisson(link = "log"),
  data = df_clean
)

# Predict participation over continuous age-by-period grid
grid_data_omni <- expand_grid(
  age = seq(15, 90, by = 1),
  year = seq(1982, 2012, by = 1),
  woman = 1,
  college = 1,
  white = 1,
  black = 0
)

grid_data_omni$pred_count <- predict(fit_gam_omni, newdata = grid_data_omni, type = "response")

# Plot Lexis Surface Heatmap with cohort diagonals
p_lexis_omni <- ggplot(grid_data_omni, aes(x = year, y = age, fill = pred_count)) +
  geom_tile() +
  scale_fill_viridis_c(option = "plasma") +
  # Draw cohort diagonals for 1915, 1935, 1955, 1975
  geom_abline(intercept = -1915, slope = 1, color = "white", linetype = "dashed", linewidth = 0.8) +
  geom_abline(intercept = -1935, slope = 1, color = "white", linetype = "dashed", linewidth = 0.8) +
  geom_abline(intercept = -1955, slope = 1, color = "white", linetype = "dashed", linewidth = 0.8) +
  geom_abline(intercept = -1975, slope = 1, color = "white", linetype = "dashed", linewidth = 0.8) +
  theme_minimal() +
  labs(
    title = "Lexis Surface of Omnivore Score (GAM predictions)",
    subtitle = "Dashed lines represent cohort diagonals (Birth cohorts 1915, 1935, 1955, 1975)",
    x = "Survey Year (Period)",
    y = "Age",
    fill = "Expected Count"
  ) +
  theme(plot.title = element_text(face = "bold"))

p_lexis_omni

# Save plot to Plots/ folder
ggsave("Plots/lexis_surface_gam_omnivore.png", p_lexis_omni, width = 8, height = 5.5, dpi = 300)


## ----apci-omnivore-score, message=FALSE, warning=FALSE-----------------------------------------------------------
# Install APCI if not present
if (!require("APCI")) {
  install.packages("APCI")
  library(APCI)
}

# The APCI package requires age and period to be specified as sequential indices, 
# and it requires a fully crossed rectangular matrix without empty cells.
# We map agecat and year to sequential indices, and truncate age > 84 (agecat > 14) 
# where cells are sparse/empty in some survey periods.
df_apci <- df_clean |>
  mutate(
    age_idx = agecat,
    period_idx = as.numeric(as.factor(year)),
    cohort_idx = period_idx - age_idx
  ) |>
  filter(age_idx <= 14)

# Fit the APCI model
fit_apci <- apci(
  outcome = "omnivore_score",
  age = "age_idx",
  period = "period_idx",
  cohort = "cohort_idx",
  covariate = c("woman", "college", "white", "black"),
  weight = "weight_normalized",
  data = as.data.frame(df_apci),
  family = "gaussian",
  dev.test = FALSE
)

# Extract and inspect Intra-Cohort Life-Course Dynamics
# The package calculates the average cohort deviation from the age-period baseline
# and the linear slope of that deviation as the cohort ages.
intra_cohort_tests <- fit_apci$intra_cohort_test |>
  mutate(
    Hypothesis = case_when(
      sign(cohort_average) == sign(cohort_slope) & cohort_slope_p < 0.05 & cohort_average_p < 0.05 ~ "Cumulative (Dis)Advantage",
      sign(cohort_average) != sign(cohort_slope) & cohort_slope_p < 0.05 ~ "Age-as-leveler",
      cohort_slope_p >= 0.05 & cohort_average_p < 0.05 ~ "Constant Effects",
      TRUE ~ "No Clear Pattern"
    )
  ) |>
  select(cohort_slope_group, cohort_average, cohort_average_p, cohort_slope, cohort_slope_p, Hypothesis)

# Print a sample of these hypothesis tests
head(intra_cohort_tests, 10)

# Plot the interaction effects which represent the cohort deviations
p_apci <- apci.plot(fit_apci)

p_apci

# Save plot to Plots/ folder
ggsave("Plots/apci_interaction_omnivore.png", p_apci, width = 8, height = 6, dpi = 300)

