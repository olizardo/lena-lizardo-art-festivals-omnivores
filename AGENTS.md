
# Agent Memory: The Making of an 'Omnivorous Generation' Project

This document serves as the project memory for AI agents assisting with the data analysis pipeline for **"The Making of an 'Omnivorous Generation': A Modern APC Analysis"**.

---

## 1. Project Directory and Key Files

- **Root Directory**: `/home/omarlizardo/CULTURE PROJECTS/OMAR PROJECTS/lena-lizardo-art-festivals-omnivores`
- **Primary Data File**: `[sppa1982-2012_stata.dta](sppa1982-2012_stata.dta)`
- **Analytical Core**: `[omnivorous-generation-analysis.qmd](omnivorous-generation-analysis.qmd)` — Self-contained Quarto Markdown file containing the new analytical pipeline.
- **Methodological Report**: `[METHODOLOGICAL_REPORT.md](METHODOLOGICAL_REPORT.md)` — Comprehensive summary of the modernized pipeline.
- **Plots Directory**: `[Plots/](Plots/)`

---

## 2. Data Schema and Variable Cleaning

### Primary Outcomes (Binary: `1 = Yes`, `0 = No`)
- `jazz`, `classical`, `opera`, `musical`, `ballet`, `artmuseum`, `craft_fair`, `park`
- `omnivore_score`: Aggregate sum of the 8 activities.

### Demographic Covariates
- `age`: Continuous age of respondent (filtered to range 15 to 95).
- `agecat`: 5-year age categories (ranging from 1 to 17, representing brackets from 15 to 100).
- `woman`, `college`, `white`, `black`, `weight_normalized`

### Temporal Identification Variables
- `year`: Survey year (1982, 1985, 1992, 2002, 2008, 2012).
- `cohort`: Birth cohort, calculated as `year - age`.
- `cohort5`: 5-year birth cohort bins.

---

## 3. Current Analytical Status

The project workflow was completely redesigned to drop Hierarchical Age-Period-Cohort (HAPC) models, which rely on untestable constraints and shrink cohort effects to zero. The new, modernized workflow consists of:

### Main Analysis: Fosse & Winship Bounding and Orthogonal Estimator (OE)
- **Bounding Analysis**: Decomposes cohort effects into identified non-linear deviations and underidentified linear trends. We apply weak qualitative assumptions on Age and Period trends to calculate a mathematically bound interval $[s_{\min}, s_{\max}]$ for the cohort slope.
- **Orthogonal Estimator (OE)**: We apply the robust OE constraint ($\alpha - \pi + \gamma = 0$) to extract a point estimate for the linear slope. The OE scalar perfectly aligns with the theoretical bounds for both the aggregate `omnivore_score` and the binary `craft_fair` outcome.
- We constructed a 2D Canonical Solution Line plot to visualize the bounds geometrically: `[Plots/2d_apc_canonical_solution.png](Plots/2d_apc_canonical_solution.png)`

### Robustness Checks
1. **Generalized Additive Models (GAMs) & Lexis Surfaces**: Bypasses parametric constraints by modeling Age and Period as a smooth, bivariate tensor product. Visualizes participation as a 2D Lexis Surface heatmap to inspect cohort diagonals.
2. **Bootstrapped Bounds (Rohrer 2025)**: Bootstraps the full bounded analysis to incorporate sampling error into the theoretical bounds, generating 95% confidence intervals around the boundaries.
3. **Age-Period-Cohort Interaction (APCI) Model**: Models Age-Period interaction effects to capture non-constant cohort deviations along the diagonals.

All results confirm a distinct, mid-century generational peak in cultural participation.

