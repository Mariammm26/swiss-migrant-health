# Analysis plan: self-rated health by migration background in Switzerland (ESS rounds 8-11)

**Status:** the main models (M1, M2 below) were completed before this file was written. Their code is in `scripts/` and their outputs are in `output/`. This document records what was done and lists planned extensions. It is not a pre-registration.

## 1. Question

Do foreign-born residents of Switzerland report fair, bad or very bad health more often than Swiss-born residents, after adjusting for age, gender, education, income and survey round? Planned extension: does the association differ between foreign-born groups by region of birth?

## 2. Data

European Social Survey, Switzerland only (`cntry` = "CH"), rounds 8-11 pooled. Variables used: `cntry` (country filter), `brncntr` (born in country), `health` (subjective general health), `eisced` (highest level of education, ES-ISCED), `hinctnta` (household net income, decile), `agea` (age), `gndr` (gender), `pspwght` (post-stratification weight), `essround` (survey round).

## 3. Completed analysis

- **Outcome:** `poor_health` = 1 if self-rated health is fair, bad or very bad (codes 3-5); 0 if good or very good (codes 1-2).
- **Exposure:** foreign-born (`brncntr` = 2) vs Swiss-born (`brncntr` = 1).
- **Covariates:** age (continuous), gender, education (ISCED, `eisced`, numeric score), household income (`hinctnta`, decile 1-10, numeric score), survey round (fixed effects).
- **Sample:** complete cases across all model variables, the same sample for M1 and M2 (N = 4,864; foreign-born n = 1,336). Refusal, don't-know and "other" codes for education and income were set to missing.
- **Missing data:** missingness report in `output/missing_data_report.csv`.
- **Models:** survey-weighted logistic regression (`survey::svyglm`, quasibinomial) with the post-stratification weight `pspwght`.
    - M1: migration status + survey round.
    - M2: M1 + age, gender, education, income.
- **Result (M2):** adjusted OR 1.29 (95% CI 1.08-1.54), foreign-born vs Swiss-born.

## 4. Planned extensions (not completed unless stated elsewhere in this repository)

1. **Origin groups:** replace the binary exposure with Swiss-born (reference), EU/EFTA-born and non-EU/EFTA-born. Groups too small to estimate will be merged and the merge reported.
2. **Sensitivity analyses, if time allows:** education entered as categories; multiple imputation as an alternative to complete cases.

## 5. Limitations

- Cross-sectional data: associations only, no causal claim.
- Birth country is a coarse proxy for migration experience. It does not capture years since arrival, reason for migration, legal status, language or second-generation status.
- The model uses the post-stratification weight only (`ids = ~1`, no strata or clustering information), so standard errors may be somewhat too small.
- Education and income are entered as numeric scores, which assumes equal spacing between categories.
- Complete-case analysis assumes missingness is unrelated to the outcome after adjustment; this was not tested.
- Self-rated health is a single subjective item, dichotomised at a fixed cut-point.
- Education and income may lie on the pathway between migration and health (mediators) or may be confounders, depending on when they were acquired. Comparing M1 with M2 shows how much the association changes after adjustment, but this is not a formal mediation analysis. See `dag.png`.
- Selection of healthier people into migration (the "healthy migrant" effect) is not measured; it appears in `dag.png` as an unmeasured variable.
