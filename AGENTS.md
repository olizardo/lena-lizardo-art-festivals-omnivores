# Agent Memory: The Making of an 'Omnivorous Generation' Project

This document serves as the project memory for AI agents assisting with the data analysis pipeline for **"The Making of an 'Omnivorous Generation': A Modern APC Analysis"**.

---

## 1. Project Directory and Key Files

- **Root Directory**: `/home/omarlizardo/CULTURE PROJECTS/OMAR PROJECTS/lena-lizardo-art-festivals-omnivores`
- **Primary Data File**: `[sppa1982-2012_stata.dta](sppa1982-2012_stata.dta)` — Cumulative Survey of Public Participation in the Arts (SPPA) dataset spanning years 1982 to 2012.
- **Analytical Core**: `[omnivorous-generation-analysis.qmd](omnivorous-generation-analysis.qmd)` — Self-contained Quarto Markdown file containing data cleaning, descriptive visualizations, and hierarchical modeling.
- **Methodological Report**: `[METHODOLOGICAL_REPORT.md](METHODOLOGICAL_REPORT.md)` — Comprehensive summary of the modernized pipeline, robustness checks, and compositional analyses.
- **Plots Directory**: `[Plots/](Plots/)` — Location of exported high-resolution visualizations in PNG format.
- **Tables Directory**: `[Tabs/](Tabs/)` — Location of exported regression tables in HTML format.

---

## 2. Data Schema and Variable Cleaning

### Primary Outcomes (Binary: `1 = Yes`, `0 = No`)
- `jazz`: Jazz concert attendance
- `classical`: Classical music (Symphony) attendance
- `opera`: Opera attendance
- `musical`: Musicals attendance
- `ballet`: Ballet attendance
- `artmuseum`: Art museum/gallery attendance
- `craft_fair`: Craft fair/Art festival attendance (Focal outcome for robustness checks)
- `park`: Historic monument/park visit

### Demographic Covariates
- `age`: Continuous age of respondent (filtered to range 15 to 95 to avoid extreme outliers).
- `age2`: Quadratic age term ($$Age^2 / 100$$).
- `age3`: Cubic age term ($$Age^3 / 1000$$).
- `agecat`: 5-year age categories (ranging from 1 to 17, representing brackets from 15 to 100).
- `woman`: Binary indicator for female respondents (`1 = Yes`, `0 = No`).
- `college`: Binary indicator for college graduate or higher education (`1 = Yes`, `0 = No`).
- `education`: 6-category education classification factor.
- `white`: Binary indicator for white respondents (`1 = Yes`, `0 = No`).
- `black`: Binary indicator for black respondents (`1 = Yes`, `0 = No`).
- `weight_normalized`: Normalized survey weights.

### Temporal Identification Variables
- `year`: Survey year (1982, 1985, 1992, 2002, 2008, 2012).
- `cohort`: Birth cohort, calculated as `year - age`.
- `cohort_bins` (2, 4, 5, 6, 8-year options): Custom-binned birth cohort variables designed to handle varying bandwidth robustness checks.

---

## 3. Current Analytical Status

### Hierarchical Age-Period-Cohort (HAPC) / CCREM
We fit Cross-Classified Random Effects Models (CCREM) using the `lme4::glmer` package in R, modeling birth cohorts as random intercepts and survey periods (years) as fixed effects or random intercepts:
$$\text{logit}(P(Y_{ic} = 1)) = \beta_0 + \beta_1 \text{Age}_i + \beta_2 \text{Age}^2_i + \beta_3 \text{Age}^3_i + \boldsymbol{\delta} \mathbf{X}_{ic} + \gamma_{\text{Period}(i)} + u_{\text{Cohort}(c)}$$
The baseline models run fast and reliably by leveraging the Laplace approximation optimization (`nAGQ = 0`).

---

## 4. Advanced Methodological Extensions (Completed)

To address advanced reviewer critique and completely isolate the linear identification problem of APC models, the project implements:

1. **Fosse & Winship Bounded APC Analysis**:
   - Decomposes cohort effects into identified non-linear deviations and underidentified linear trends.
   - Applies weak qualitative assumptions on Age and Period trends to calculate a mathematically bound interval $$[s_{\min}, s_{\max}]$$ for the cohort slope.
   - Plots the cohort curves across this interval for the primary outcome (`craft_fair`) and secondary outcomes (`jazz`, `artmuseum`) to demonstrate that the cohort peaks represent a robust, physical historical signal rather than statistical artifacts of linear identification constraints.
   - Exported plots: `[Plots/cohort_bounds_fosse_winship.png](Plots/cohort_bounds_fosse_winship.png)`, `[Plots/cohort_bounds_jazz.png](Plots/cohort_bounds_jazz.png)`, `[Plots/cohort_bounds_museums.png](Plots/cohort_bounds_museums.png)`

2. **Generalized Additive Models (GAMs) & Lexis Surfaces**:
   - Bypasses parametric constraints by modeling Age and Period as a smooth, bivariate tensor product using `mgcv::gam`: `te(age, year)`.
   - Visualizes participation as a 2D Lexis Surface heatmap to inspect cohort diagonals.
   - Exported plot: `[Plots/lexis_surface_gam.png](Plots/lexis_surface_gam.png)`
