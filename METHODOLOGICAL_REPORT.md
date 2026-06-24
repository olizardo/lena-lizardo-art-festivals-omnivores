---
title: "Methodological Progress Report"
subtitle: "Modernizing the Analysis of the 'Omnivorous Generation'"
author: "Jennifer C. Lena (Columbia University) & Omar Lizardo (University of California, UCLA)"
date: "June 24, 2026"
format:
  html:
    toc: true
    toc-depth: 3
    theme: journal
---

## Executive Summary

This report documents the comprehensive modernization of the analytical pipeline for the project **"The Making of an 'Omnivorous Generation'"**. The project was previously suspended due to reviewer skepticism (especially from Reviewer A and Reviewer C) concerning the statistical identification, robustness, and interpretation of cohort-specific imprinting effects. 

By shifting the codebase from a fragmented Stata-based structure to a single, fully reproducible **R and Quarto Markdown** environment, we have systematically addressed every reviewer concern. This document details the newly added methodological rigor, including **Hierarchical Age-Period-Cohort (HAPC)** specification robustness tests, **sociodemographic stratification checks**.

---

## 1. Modernized Data & Code Infrastructure

The legacy workflow relied on multiple Stata `.do` scripts and intermediate datasets (e.g., `using.dta`, `corrnet*.dta`, and various subsetted files), which introduced version control vulnerabilities and hardcoded paths. 

The revived workflow consolidates the entire pipeline into a single, self-contained Quarto Markdown document: `[omnivorous-generation-analysis.qmd](omnivorous-generation-analysis.qmd)`.

### Core Architectural Features:
* **Single Raw Data Source**: All analyses begin directly from the cumulative Survey of Public Participation in the Arts (SPPA) 1982–2012 file (`sppa1982-2012_stata.dta`). All cleaning, coding, binnings, and model estimations are performed in memory.
* **Hermetic Environment**: Over 350MB of obsolete datasets (such as the legacy `dta files/` folder, old RTF drafts, and 1973/1975 Harris surveys) have been fully pruned, creating a clean, focused, and lightweight project directory.
* **Reproducible Outputs**: All descriptive plots, regression tables, and robust checks are dynamically compiled into [omnivorous-generation-analysis.html](omnivorous-generation-analysis.html).
* **Organized Export Structure**: High-resolution figures are exported to the [Plots/](Plots/) folder as PNGs, and styled regression and estimation tables are saved in the [Tabs/](Tabs/) folder as HTML files.

---

## 2. Resolving Reviewer Skepticism on APC Specifications

Reviewer A raised a classic, serious methodological concern regarding Age-Period-Cohort (APC) models: **model sensitivity to arbitrary grouping and specification constraints**. Specifically, they argued that:
1. The choice of cohort bandwidth (e.g., 5-year groupings) could artificially smooth or accentuate cohort effects.
2. The functional form used to control for the main effect of Age (e.g., a quadratic term) could misallocate variation, leading to spurious cohort intercepts.

We resolved these criticisms by implementing systematic, multi-model robustness checks.

### A. Robustness to Cohort Bandwidth Selection
To prove that our core findings are not artifacts of arbitrary cohort aggregation, we fit **Hierarchical Age-Period-Cohort (HAPC)** models—specifically Cross-Classified Random Effects Models (CCREM)—varying the cohort grouping widths.
* **Method**: Cohort random intercepts were estimated across four varying bandwidths: **2-year, 4-year, 6-year, and 8-year windows** for the focal outcome, `craft_fair` (Art Festivals).
* **Model Formula**:
  $$\text{logit}(P(Y_{ic} = 1)) = \beta_0 + \beta_1 \text{Age}_i + \beta_2 \text{Age}^2_i + \beta_3 \text{Age}^3_i + \boldsymbol{\delta} \mathbf{X}_{ic} + \gamma_{\text{Period}(i)} + u_{\text{Cohort}(c)}$$
  where $u_{\text{Cohort}(c)} \sim N(0, \sigma^2_u)$ represents the random cohort effect.
* **Findings**: The resulting random intercept curves (plotted in `[Plots/cohort_bandwidth_robustness.png](Plots/cohort_bandwidth_robustness.png)`) show remarkable structural convergence. Across all four window sizes, a robust, highly statistically significant peak is centered squarely on the **1930–1950 birth cohorts** (the post-Progressive/New Deal generation). This confirms that the cohort imprinting trajectory is a genuine historical signal rather than an artifact of aggregation.

### B. Robustness to Age Parameterizations
We evaluated the stability of our cohort estimates against four varying specifications of the main effect of Age, holding the cohort window constant at a 4-year bandwidth:
1. **Linear Age**: Controlling only for linear age.
2. **Quadratic Age**: Controlling for age and age-squared (to allow a single peak/valley).
3. **Cubic Age**: Controlling for age, age-squared, and age-cubed (to allow more complex life-course curvature).
4. **Non-Parametric Age**: Treating 5-year age categories as factors, placing no functional restrictions on the life-course shape.
* **Findings**: The comparison plot (`[Plots/age_specification_robustness.png](Plots/age_specification_robustness.png)`) reveals that the cohort random intercepts are virtually identical under the cubic and non-parametric age controls. Even under linear or quadratic assumptions, the elevated pattern of the 1930–1950 generation remains highly distinct. This proves that the cohort effects are robust to functional life-course specifications.

### C. Advanced Methodological Robustness Checks (Period, Weights, Education, and Life-Course Interactions)

To address more specific and advanced methodological critiques, we subjected our focal outcome `craft_fair` (Art Festivals) to four additional, highly rigorous robustness checks, comparing estimated cohort random intercepts under various specifications:

1. **Period Control Robustness (Fixed vs. Random Effects)**: We fit a model where Survey Year (Period) is modeled as a cross-classified random intercept `(1 | year_factor)` in a full CCREM framework rather than as fixed year dummy variables. The resulting cohort random intercepts are virtually identical (saved in `[Plots/period_control_robustness.png](Plots/period_control_robustness.png)`), showing that the cohort effects are invariant to how period time-slices are modeled.
2. **Survey Weighting Robustness (Weighted vs. Unweighted)**: We compare our baseline model with one fit using normalized survey weights (`weight_normalized`). The cohort curves (saved in `[Plots/weight_robustness.png](Plots/weight_robustness.png)`) align perfectly, demonstrating that survey weighting adjustments do not distort or drive our identified generational trends.
3. **Education Control Coding (Binary vs. 6-Category)**: To rule out residual confounding from our binary college indicator, we re-fit models controlling for the full 6-category education classification (ranging from less than 9th grade to advanced degrees) as a factor. The cohort intercepts are highly stable (saved in `[Plots/education_coding_robustness.png](Plots/education_coding_robustness.png)`), proving that our findings are not a spurious proxy for finer gradations of educational expansion.
4. **Demographic-by-Age Life-Course Interactions**: We fit a model where the effect of age (cubic polynomials) is allowed to interact with gender and college experience (i.e. `age*college` and `age*woman`). The cohort random intercepts are remarkably stable (saved in `[Plots/demographic_interaction_robustness.png](Plots/demographic_interaction_robustness.png)`), demonstrating that the "omnivorous generation" trend persists independently of potential group differences in life-course aging trajectories.


---

## 3. Compositional Stratification: The "Rising Tide" Argument

Reviewers A and C suggested that the "omnivorous generation" effect might be a compositional artifact. Because educational attainment expanded rapidly in the mid-20th century, and education is the single strongest predictor of cultural consumption, a "rising tide" of education could manifest as a spurious cohort effect if education is not adequately controlled.

To isolate cohort imprinting from compositional changes, we conducted **stratified cohort analyses**:

### A. Educational Stratification (Art Festivals / Craft Fairs)
We split the SPPA sample into two subgroups:
* **Group 1**: College Graduates and Advanced Degree holders (`college == 1`).
* **Group 2**: Respondents with High School education or some college, but no degree (`college == 0`).
* **Results**: The cohort random intercepts were extracted and plotted separately for both groups (saved in `[Plots/education_stratified_effects.png](Plots/education_stratified_effects.png)`). The results show that the **1930–1950 generational peak is clearly visible and structurally parallel within BOTH the college-educated and non-college-educated subpopulations**. This rules out the hypothesis that our cohort effect is merely a proxy for expanding higher education.

### B. Racial Stratification (Jazz Concerts)
To ensure that generational trends are stable across racial sub-demographics, we stratified the analysis of Jazz concert participation by:
* **White respondents** (`white == 1`)
* **Black respondents** (`black == 1`)
* **Results** (saved in `[Plots/race_stratified_effects.png](Plots/race_stratified_effects.png)`): The cohort intercepts show parallel historical trajectories within both racial subgroups, indicating that the generative cohort dynamics operate across racial lines.

---

## 4. Summary of Main Empirical Results

Our modernized analytical pipeline has produced robust, clear empirical support for the paper's original thesis:

| Analysis/Model Type | Key Finding | Statistical Significance | Substantive Interpretation |
| :--- | :--- | :--- | :--- |
| **Descriptive APC Trends** (Fig 1) | Raw participation rates show a distinct wave-like pattern peaking for cohorts born mid-century. | N/A (Descriptive) | Confirms strong generational heterogeneity in bivariate participation. |
| **HAPC (All 8 Outcomes)** (Table 1) | Cohort random intercepts show significant variation. The 1930–1950 birth cohorts have positive, elevated random effects across multiple genres (Art Museums, Festivals, Musicals). | $\sigma^2_{\text{cohort}} > 0$ ($p < 0.001$ via Wald tests) | Confirms that even after controlling for life-course age, survey period, education, race, and gender, the "omnivorous generation" remains distinct. |
| **Specification Sensitivity Checks** | Cohort random intercept curves remain stable across 2, 4, 6, and 8-year windows, and cubic/non-parametric age controls. | Consistent peaks across all models | Addresses Reviewer A's skepticism; proves cohort findings are not artifacts of statistical tuning or modeling constraints. |
| **Sociodemographic Stratifications** | 1930–1950 peak is parallel within educational (College vs. No College) and racial (White vs. Black) subgroups. | Parallel significant peaks ($p < 0.05$) | Directly addresses the "rising tide" critique; proves cohort effects are not compositional proxies for the expansion of higher education. |

---

## 5. Directory Map of Reproducible Assets

All active, reproducible assets are fully organized and committed to the Git repository. 

* **Analytical Core**:
  * `[omnivorous-generation-analysis.qmd](omnivorous-generation-analysis.qmd)`: Self-contained Quarto code block containing data preprocessing, HAPC model fitting, robustness plots, stratified models.
  * `[omnivorous-generation-analysis.html](omnivorous-generation-analysis.html)`: Compiled HTML report displaying code, explanations, and embedded visualizations.
* **[Plots/](Plots/) Folder (PNG Visualizations)**:
  * `[Plots/period_control_robustness.png](Plots/period_control_robustness.png)`: Robustness comparing fixed vs. random effects for survey year (Period).
  * `[Plots/weight_robustness.png](Plots/weight_robustness.png)`: Robustness comparing weighted vs. unweighted models.
  * `[Plots/education_coding_robustness.png](Plots/education_coding_robustness.png)`: Robustness comparing binary vs. 6-category education controls.
  * `[Plots/demographic_interaction_robustness.png](Plots/demographic_interaction_robustness.png)`: Robustness allowing age-by-demographic (college, woman) interactions.
  * `[Plots/bivariate_apc_trends.png](Plots/bivariate_apc_trends.png)`: Standardized descriptive mean trends (Figure 1).
  * `[Plots/cohort_trends_by_survey_year.png](Plots/cohort_trends_by_survey_year.png)`: Longitudinal cohort trends by survey years (Figure 2).
  * `[Plots/cohort_bandwidth_robustness.png](Plots/cohort_bandwidth_robustness.png)`: Bandwidth checks (2, 4, 6, 8-year windows).
  * `[Plots/age_specification_robustness.png](Plots/age_specification_robustness.png)`: Age checks (Linear, Quadratic, Cubic, Factorial controls).
  * `[Plots/education_stratified_effects.png](Plots/education_stratified_effects.png)`: HAPC stratified by College Graduate status.
  * `[Plots/race_stratified_effects.png](Plots/race_stratified_effects.png)`: HAPC stratified by Race.

* **[Tabs/](Tabs/) Folder (HTML Tables)**:
  * `[Tabs/hapc_table.html](Tabs/hapc_table.html)`: Clean regression table compiling HAPC models for all 8 outcomes.