library(tidyverse)
library(here)
library(survey)

# Ensure output directory exists
dir.create(here("output"), showWarnings = FALSE)

# 1. Load data
ess_raw <- read_csv(here("data", "ESS8e02_3-ESS9e03_3-ESS10e03_3-ESS11e04_2-subset.csv"))

# 2. Clean and recode variables
ess_clean <- ess_raw %>%
  select(
    essround, cntry, pspwght,
    brncntr, health, eisced, hinctnta,
    agea, gndr
  ) %>%
  # Filter strictly for Switzerland, valid birth country, and valid health scores
  filter(
    cntry == "CH",
    brncntr %in% c(1, 2),
    health %in% c(1, 2, 3, 4, 5)
  ) %>%
  mutate(
    # Recode Migration Status: 0 = Swiss-born, 1 = Foreign-born
    migrant = ifelse(brncntr == 2, "Foreign-born", "Swiss-born"),
    migrant = factor(migrant, levels = c("Swiss-born", "Foreign-born")),
    
    # Binary Outcome: Fair, bad or very bad self-rated health (3,4,5 vs 1,2)
    poor_health = ifelse(health >= 3, 1, 0),
    
    # Recode Age & Gender
    age = ifelse(agea > 110, NA, agea),
    gender = case_when(
      gndr == 1 ~ "Male",
      gndr == 2 ~ "Female",
      TRUE ~ NA_character_
    ),
    
    # Clean Education (ISCED): Exclude 55 (other) and missing codes (77, 88, 99)
    education = ifelse(eisced %in% c(55, 77, 88, 99), NA, eisced),
    
    # Clean Income (1-10 scale, exclude refusal/don't know)
    income = if_else(hinctnta %in% 1:10, hinctnta, NA_real_)
  )

# 3. Enforce Complete Cases Across All Models (Same Sample for M1 & M2)
ess_cc <- ess_clean %>% 
  drop_na(poor_health, migrant, age, gender, education, income, pspwght, essround)

cat("--- Sample Size Metrics ---\n")
cat("Total Analysis N =", nrow(ess_cc), "\n")
cat("Foreign-born n =", sum(ess_cc$migrant == "Foreign-born"), "\n")
cat("Swiss-born n =", sum(ess_cc$migrant == "Swiss-born"), "\n---------------------------\n")

# 4. Save Data Report on Missingness
missing_report <- colSums(is.na(ess_clean)) %>%
  enframe(name = "variable", value = "missing_count") %>%
  mutate(missing_pct = round((missing_count / nrow(ess_clean)) * 100, 2))

write_csv(missing_report, here("output", "missing_data_report.csv"))

# 5. Set up Survey Weights Design (Using complete cases)
ess_design <- svydesign(
  ids = ~1,
  weights = ~pspwght,
  data = ess_cc
)

# 6. Fit Logistic Regressions with Round Fixed Effects
# Model 1: Unadjusted (Migrant status + ESS round fixed effects)
m1 <- svyglm(poor_health ~ migrant + factor(essround), design = ess_design, family = quasibinomial())

# Model 2: Fully Adjusted for Age, Gender, Education, Income, and ESS Round
m2 <- svyglm(poor_health ~ migrant + age + gender + education + income + factor(essround), design = ess_design, family = quasibinomial())

# Extract Model Results (Odds Ratios & 95% CI)
format_model <- function(mod, mod_name) {
  broom::tidy(mod, exponentiate = TRUE, conf.int = TRUE) %>%
    filter(str_detect(term, "migrant")) %>%
    mutate(model = mod_name) %>%
    select(model, term, estimate, conf.low, conf.high, p.value)
}

results <- bind_rows(
  format_model(m1, "M1: Unadjusted"),
  format_model(m2, "M2: Fully Adjusted")
)

write_csv(results, here("output", "table2_odds_ratios.csv"))

# 7. Generate Weighted Plot: Poor Health Prevalence by Migration Status
plot_data <- svyby(~poor_health, ~migrant, ess_design, svymean) %>%
  mutate(pct_poor_health = poor_health * 100)

fig1 <- ggplot(plot_data, aes(x = migrant, y = pct_poor_health, fill = migrant)) +
  geom_col(width = 0.5, show.legend = FALSE) +
  scale_fill_manual(values = c("Swiss-born" = "#2b5c8f", "Foreign-born" = "#d95f02")) +
  labs(
    title = "Prevalence of Fair, Bad or Very Bad Self-Rated Health in Switzerland",
    subtitle = "European Social Survey (Rounds 8–11, Weighted)",
    x = "Migration Status",
    y = "Percentage Reporting Fair, Bad or Very Bad Health (%)"
  ) +
  theme_minimal(base_size = 14)

ggsave(here("output", "fig1_poor_health_by_group.png"), fig1, width = 7, height = 5)

cat("--- Pipeline Completed Successfully! Outputs written to output/ ---\n")
print(results)
writeLines(capture.output(sessionInfo()), here("output", "session_info.txt"))
