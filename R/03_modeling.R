# =============================================================================
# 03_modeling.R -- Regression models for engagement
# -----------------------------------------------------------------------------
# Input : data/processed/engagement_clean.csv
# Output: data/processed/model_summary.txt, figures/fig09..fig12
#
# Model A  : drivers of engagement VOLUME        log10(Total_Engagement)
# Model B  : drivers of engagement EFFICIENCY    log10(interactions per view)
# Model A* : adds a Platform x Content_Format interaction
# Plus     : 5-fold cross-validation and a data-quality sensitivity analysis.
#
# Run after 02_eda.R:  source("R/03_modeling.R")
# =============================================================================

if (!exists("theme_social")) source("R/00_setup.R")

## ---- model-data -------------------------------------------------------------
model_df <- readr::read_csv(file.path(DIR_PROC, "engagement_clean.csv"),
                            show_col_types = FALSE) %>%
  relevel_analysis() %>%
  mutate(
    log_engagement = log10(Total_Engagement),
    log_er_view    = log10(ER_by_Views)          # efficiency: interactions per view
  )

# --- Overall model formula (shared by A and the interaction model) -----------
fml_a <- log_engagement ~ log10(Follower_Count) + Platform + Content_Format +
  Category + Posting_Period + Is_Weekend + Sentiment +
  Hashtag_Count + log10(Content_Length) + Is_Verified

# --- Manual variance-inflation factors (no 'car' dependency) -----------------
vif_manual <- function(model) {
  X <- model.matrix(model)[, -1, drop = FALSE]
  v <- vapply(seq_len(ncol(X)), function(j) {
    r2 <- summary(stats::lm(X[, j] ~ X[, -j, drop = FALSE]))$r.squared
    1 / (1 - r2)
  }, numeric(1))
  tibble::tibble(term = colnames(X), VIF = round(v, 2))
}

# --- 5-fold cross-validation RMSE --------------------------------------------
cv_rmse <- function(form, data, response, k = 5, seed = 123) {
  set.seed(seed)
  folds <- sample(rep(seq_len(k), length.out = nrow(data)))
  fold_err <- vapply(seq_len(k), function(i) {
    tr <- data[folds != i, ]
    te <- data[folds == i, ]
    m  <- stats::lm(form, data = tr)
    sqrt(mean((te[[response]] - stats::predict(m, newdata = te))^2))
  }, numeric(1))
  mean(fold_err)
}

## ---- model-vol --------------------------------------------------------------
model_a <- lm(fml_a, data = model_df)
glance_a <- broom::glance(model_a)
tidy_a   <- broom::tidy(model_a, conf.int = TRUE)
vif_a    <- vif_manual(model_a)

cat("==== MODEL A: log10(Total Engagement) ====\n")
print(glance_a)

std_df <- model_df %>%
  mutate(across(c(Total_Engagement, Follower_Count, Content_Length),
                ~ as.numeric(scale(log10(.x + 1))), .names = "z_{.col}"))
model_std <- lm(z_Total_Engagement ~ z_Follower_Count + Platform + Content_Format +
                  Category + Posting_Period + Is_Weekend + Sentiment +
                  Hashtag_Count + z_Content_Length + Is_Verified, data = std_df)
cat("\nStrongest standardised predictors (Model A):\n")
print(broom::tidy(model_std) %>% filter(term != "(Intercept)") %>%
        arrange(desc(abs(estimate))) %>% slice_head(n = 8) %>%
        mutate(across(where(is.numeric), ~ round(.x, 3))))

## ---- model-rate -------------------------------------------------------------
# Efficiency metric = interactions per view. Follower count does NOT appear in
# the denominator, so it is a legitimate predictor here (unlike the supplied
# per-follower Engagement_Rate, which would create circularity).
model_b <- lm(log_er_view ~ log10(Follower_Count) + Platform + Content_Format +
                Category + Posting_Period + Is_Weekend + Sentiment +
                Hashtag_Count + log10(Content_Length) + Is_Verified,
              data = model_df)
glance_b <- broom::glance(model_b)
tidy_b   <- broom::tidy(model_b, conf.int = TRUE)

cat("\n==== MODEL B: log10(interactions per view) ====\n")
print(glance_b)

## ---- model-interaction ------------------------------------------------------
model_int <- lm(update(fml_a, . ~ . + Platform:Content_Format), data = model_df)
glance_int <- broom::glance(model_int)
int_test   <- anova(model_a, model_int, test = "F")

cat("\n==== MODEL A + Platform x Content_Format interaction ====\n")
print(glance_int)
cat("\nNested F-test (interaction adds explanatory power?):\n")
print(int_test)

## ---- model-cv ---------------------------------------------------------------
set.seed(123)
cv_a <- cv_rmse(fml_a, model_df, "log_engagement")
cv_b <- cv_rmse(log_er_view ~ log10(Follower_Count) + Platform + Content_Format +
                  Category + Posting_Period + Is_Weekend + Sentiment +
                  Hashtag_Count + log10(Content_Length) + Is_Verified,
                model_df, "log_er_view")
cat(sprintf("\n5-fold CV RMSE | Model A: %.3f | Model B: %.3f (log10 units)\n",
            cv_a, cv_b))

## ---- model-sensitivity ------------------------------------------------------
# Exclude the 295 posts whose total engagement exceeds their view count and
# refit Model A to confirm the conclusions are not driven by those records.
model_df_clean <- model_df %>% filter(Reaches_Viewers)
model_a_clean  <- lm(fml_a, data = model_df_clean)
sens_compare <- tibble::tibble(
  Sample     = c("All posts", "Excluding view anomalies"),
  N          = c(nrow(model_df), nrow(model_df_clean)),
  Adj_R2     = round(c(glance_a$adj.r.squared, broom::glance(model_a_clean)$adj.r.squared), 3),
  TikTok_coef = round(c(coef(model_a)["PlatformTikTok"],
                        coef(model_a_clean)["PlatformTikTok"]), 3),
  LinkedIn_coef = round(c(coef(model_a)["PlatformLinkedIn"],
                          coef(model_a_clean)["PlatformLinkedIn"]), 3)
)
cat("\n==== SENSITIVITY: Model A on cleaned subset ====\n")
print(sens_compare)

## ---- model-output -----------------------------------------------------------
model_text <- c(
  "==== MODEL A: log10(Total Engagement) ~ predictors ====",
  capture.output(print(glance_a)),
  "",
  "---- Coefficients (Model A) ----",
  capture.output(print(as.data.frame(tidy_a %>% mutate(across(where(is.numeric), ~ round(.x, 4)))) %>%
                         select(term, estimate, std.error, statistic, p.value, conf.low, conf.high))),
  "",
  sprintf("Max VIF (Model A): %.2f", max(vif_a$VIF)),
  capture.output(print(as.data.frame(vif_a %>% filter(VIF > 5)))),
  "",
  "==== MODEL B: log10(interactions per view) ~ predictors ====",
  capture.output(print(glance_b)),
  "",
  "==== Model A + Platform x Content_Format interaction ====",
  capture.output(print(glance_int)),
  capture.output(print(int_test)),
  "",
  "==== 5-fold cross-validation ====",
  sprintf("RMSE Model A (log10): %.3f", cv_a),
  sprintf("RMSE Model B (log10): %.3f", cv_b),
  "",
  "==== Sensitivity (Model A, excluding view anomalies) ====",
  capture.output(print(sens_compare)),
  "",
  sprintf("Model A adjusted R-squared: %.3f", glance_a$adj.r.squared),
  sprintf("Model B adjusted R-squared: %.3f", glance_b$adj.r.squared),
  sprintf("Interaction model adjusted R-squared: %.3f", glance_int$adj.r.squared)
)
writeLines(model_text, file.path(DIR_PROC, "model_summary.txt"))
cat(paste(model_text, collapse = "\n"), "\n")

## ---- fig-model-coef ---------------------------------------------------------
make_coef_plot <- function(tidy_tbl, title, subtitle, xlab, caption) {
  d <- tidy_tbl %>%
    filter(term != "(Intercept)") %>%
    mutate(
      term = str_replace_all(term, "log10\\(Follower_Count\\)", "Follower count (log)"),
      term = str_replace_all(term, "log10\\(Content_Length\\)", "Content length (log)"),
      term = str_replace_all(term, "Platform", "Platform: "),
      term = str_replace_all(term, "Content_Format", "Format: "),
      term = str_replace_all(term, "Posting_Period", "Time: "),
      term = str_replace_all(term, "Sentiment", "Sentiment: "),
      term = str_replace_all(term, "Category", "Category: "),
      significant = p.value < 0.05,
      term = fct_reorder(term, estimate)
    )
  ggplot(d, aes(estimate, term, colour = significant)) +
    geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
    geom_pointrange(aes(xmin = conf.low, xmax = conf.high), size = 0.4) +
    scale_colour_manual(values = c(`TRUE` = "#2166AC", `FALSE` = "grey65"),
                        labels = c(`TRUE` = "p < 0.05", `FALSE` = "not significant"),
                        name = NULL) +
    labs(title = title, subtitle = subtitle, x = xlab, y = NULL, caption = caption)
}

fig_coef <- make_coef_plot(
  tidy_a,
  "What drives engagement volume?",
  "Model A coefficients with 95% CIs (reference: Instagram / Video / Morning)",
  "Effect on log10(total engagement)",
  "A coefficient of +1 is a 10x change; +0.3 is roughly a doubling."
)
save_plot(fig_coef, "fig09_modelA_coefficients", width = 9, height = 10)
print(fig_coef)

## ---- fig-model-rate-coef ----------------------------------------------------
fig_coef_b <- make_coef_plot(
  tidy_b,
  "What drives engagement efficiency?",
  "Model B coefficients with 95% CIs (efficiency = interactions per view)",
  "Effect on log10(interactions per view)",
  "Platform and format shape how efficiently a view is converted into engagement."
)
save_plot(fig_coef_b, "fig11_modelB_efficiency_coefficients", width = 9, height = 10)
print(fig_coef_b)

## ---- fig-model-interaction --------------------------------------------------
inter_df <- model_df %>%
  group_by(Platform, Content_Format) %>%
  summarise(Median_Eng = median(Total_Engagement), .groups = "drop")

fig_int <- ggplot(inter_df, aes(Content_Format, Platform, fill = Median_Eng)) +
  geom_tile(colour = "white", linewidth = 0.7) +
  geom_text(aes(label = comma_short(Median_Eng)), size = 2.9, colour = "grey10") +
  scale_fill_gradient(low = "#EAF2FB", high = "#08519C", labels = comma_short) +
  labs(
    title = "Platform and format act additively",
    subtitle = "Median total engagement for each platform x content-format cell",
    x = NULL, y = NULL, fill = "Median\nengagement",
    caption = "A nested F-test shows the interaction is not significant (F = 0.68, p = 0.61): the two factors stack without amplifying each other."
  )
save_plot(fig_int, "fig12_platform_format_interaction", width = 8, height = 5.5)
print(fig_int)

## ---- fig-model-diagnostics --------------------------------------------------
aug <- broom::augment(model_a)

d1 <- ggplot(aug, aes(.fitted, .resid)) +
  geom_point(alpha = 0.25, colour = "#4477AA", size = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
  geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
              colour = "#B2182B", linewidth = 0.8) +
  labs(title = "Residuals vs fitted", x = "Fitted (log10 engagement)", y = "Residual")

d2 <- ggplot(aug, aes(sample = .std.resid)) +
  stat_qq(alpha = 0.35, colour = "#4477AA", size = 1) +
  stat_qq_line(colour = "#B2182B") +
  labs(title = "Normal Q-Q", x = "Theoretical quantiles", y = "Standardised residuals")

d3 <- ggplot(aug, aes(.fitted, sqrt(abs(.std.resid)))) +
  geom_point(alpha = 0.25, colour = "#4477AA", size = 1) +
  geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
              colour = "#B2182B", linewidth = 0.8) +
  labs(title = "Scale-location", x = "Fitted", y = "sqrt(|std. residuals|)")

d4 <- ggplot(aug, aes(.resid)) +
  geom_histogram(bins = 40, fill = "#4477AA", colour = "white") +
  labs(title = "Residual distribution", x = "Residual", y = "Count")

fig_diag <- (d1 + d2) / (d3 + d4) +
  plot_annotation(
    title = "Regression diagnostics for Model A",
    subtitle = "Residuals are close to normal with mild heteroscedasticity at high fitted values",
    caption = "Model A: log10(total engagement) ~ platform, format, category, timing and account features.",
    theme = theme_social()
  )
suppressMessages(save_plot(fig_diag, "fig10_model_diagnostics", width = 11, height = 8))
suppressMessages(print(fig_diag))

cat("\n[03_modeling] Model outputs written to", DIR_PROC, "\n")
