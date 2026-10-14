# =============================================================================
# 03_modeling.R -- Regression models for engagement
# -----------------------------------------------------------------------------
# Input : data/processed/engagement_clean.csv
# Output: data/processed/model_summary.txt, figures/fig09*, fig10*
#
# Model A : drivers of engagement VOLUME   log10(Total_Engagement)
# Model B : drivers of engagement EFFICIENCY log10(Engagement_Rate)
#
# Run after 02_eda.R:  source("R/03_modeling.R")
# =============================================================================

if (!exists("theme_social")) source("R/00_setup.R")

## ---- model-data -------------------------------------------------------------
model_df <- readr::read_csv(file.path(DIR_PROC, "engagement_clean.csv"),
                            show_col_types = FALSE) %>%
  relevel_analysis()

# --- Manual variance-inflation factors (no 'car' dependency) -----------------
vif_manual <- function(model) {
  X <- model.matrix(model)[, -1, drop = FALSE]
  v <- vapply(seq_len(ncol(X)), function(j) {
    y <- X[, j]
    r2 <- summary(stats::lm(y ~ X[, -j, drop = FALSE]))$r.squared
    1 / (1 - r2)
  }, numeric(1))
  tibble::tibble(term = colnames(X), VIF = round(v, 2))
}

## ---- model-vol --------------------------------------------------------------
model_a <- lm(
  log10(Total_Engagement) ~ log10(Follower_Count) + Platform + Content_Format +
    Category + Posting_Period + Is_Weekend + Sentiment +
    Hashtag_Count + log10(Content_Length) + Is_Verified,
  data = model_df
)

glance_a <- broom::glance(model_a)
tidy_a   <- broom::tidy(model_a, conf.int = TRUE)
vif_a    <- vif_manual(model_a)

cat("==== MODEL A: log10(Total_Engagement) ====\n")
print(glance_a)
cat("\nTop predictors (standardised so effects are comparable):\n")
std_df <- model_df %>%
  mutate(across(c(Total_Engagement, Follower_Count, Content_Length),
                ~ as.numeric(scale(log10(.x + 1))), .names = "z_{.col}"))
model_std <- lm(z_Total_Engagement ~ z_Follower_Count + Platform + Content_Format +
                  Category + Posting_Period + Is_Weekend + Sentiment +
                  Hashtag_Count + z_Content_Length + Is_Verified, data = std_df)
print(broom::tidy(model_std) %>% filter(term != "(Intercept)") %>%
        arrange(desc(abs(estimate))) %>% slice_head(n = 10))

## ---- model-rate -------------------------------------------------------------
model_b <- lm(
  log10(Engagement_Rate) ~ log10(Follower_Count) + Platform + Content_Format +
    Category + Posting_Period + Is_Weekend + Sentiment +
    Hashtag_Count + log10(Content_Length) + Is_Verified,
  data = model_df
)
glance_b <- broom::glance(model_b)
tidy_b   <- broom::tidy(model_b, conf.int = TRUE)

cat("\n==== MODEL B: log10(Engagement_Rate) ====\n")
print(glance_b)

## ---- model-output -----------------------------------------------------------
model_text <- c(
  "==== MODEL A: log10(Total Engagement) ~ predictors ====",
  capture.output(print(glance_a)),
  "",
  "---- Coefficients (Model A) ----",
  capture.output(print(as.data.frame(tidy_a %>% mutate(across(where(is.numeric), ~ round(.x, 4)))) %>%
                         select(term, estimate, std.error, statistic, p.value, conf.low, conf.high))),
  "",
  sprintf("Max VIF (Model A): %.2f  (terms with VIF > 5 are flagged below)", max(vif_a$VIF)),
  capture.output(print(as.data.frame(vif_a %>% filter(VIF > 5)))),
  "",
  "==== MODEL B: log10(Engagement_Rate) ~ predictors ====",
  capture.output(print(glance_b)),
  "",
  "---- Coefficients (Model B) ----",
  capture.output(print(as.data.frame(tidy_b %>% mutate(across(where(is.numeric), ~ round(.x, 4)))) %>%
                         select(term, estimate, std.error, statistic, p.value, conf.low, conf.high))),
  "",
  sprintf("Model A adjusted R-squared: %.3f", glance_a$adj.r.squared),
  sprintf("Model B adjusted R-squared: %.3f", glance_b$adj.r.squared),
  sprintf("Model A residual standard error: %.3f (log10 units)", glance_a$sigma)
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
  "Model B coefficients with 95% CIs (reference: Instagram / Video / Morning)",
  "Effect on log10(engagement rate)",
  "Format and platform both shape how efficiently followers engage."
)
save_plot(fig_coef_b, "fig11_modelB_rate_coefficients", width = 9, height = 10)
print(fig_coef_b)

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
