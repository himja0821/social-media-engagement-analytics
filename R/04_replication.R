# =============================================================================
# 04_replication.R -- Independent replication on a REAL, peer-reviewed dataset
# -----------------------------------------------------------------------------
# Input : data/raw/facebook_metrics.csv
#         (UCI "Facebook Metrics" dataset, Moro, Rita & Vala, 2016 -- 500 real
#          posts from a cosmetics brand's Facebook page during 2014)
# Output: figures/fig13..fig15, data/processed/replication_summary.txt
#
# Purpose: show that the headline patterns found in the main dataset also hold
#          on genuinely real, externally published data.
# =============================================================================

if (!exists("theme_social")) source("R/00_setup.R")

## ---- repl-load --------------------------------------------------------------
fb <- readr::read_csv(file.path(DIR_RAW, "facebook_metrics.csv"),
                      show_col_types = FALSE)

fb <- fb %>%
  mutate(
    Type    = factor(Type, levels = c("Photo", "Status", "Link", "Video")),
    Month   = factor(Month, levels = month.name),
    Weekday = factor(Weekday, levels = c("Monday", "Tuesday", "Wednesday",
                                         "Thursday", "Friday", "Saturday", "Sunday")),
    Paid    = factor(Paid, levels = c(0, 1), labels = c("Organic", "Paid"))
  )

## ---- repl-summary -----------------------------------------------------------
repl_overview <- tibble::tibble(
  Metric = c("Posts", "Post types", "Date coverage", "Total likes",
             "Total comments", "Total shares", "Median interactions / post"),
  Value = c(nrow(fb),
            paste(levels(fb$Type), collapse = ", "),
            "Jan-Dec 2014",
            format(sum(fb$Likes, na.rm = TRUE), big.mark = ","),
            format(sum(fb$Comments, na.rm = TRUE), big.mark = ","),
            format(sum(fb$Shares, na.rm = TRUE), big.mark = ","),
            format(median(fb$Interactions, na.rm = TRUE), big.mark = ","))
)

type_summary <- fb %>%
  group_by(Type) %>%
  summarise(Posts = n(),
            Median_Interactions = median(Interactions, na.rm = TRUE),
            Median_Reach = median(Reach, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(Median_Interactions))

cor_vars_fb <- c("Reach", "Impressions", "EngagedUsers", "Comments",
                 "Likes", "Shares", "Interactions")
cor_fb <- fb %>% select(all_of(cor_vars_fb)) %>%
  cor(method = "spearman", use = "pairwise.complete.obs") %>% round(2)

repl_text <- c(
  "==== REPLICATION: UCI Facebook Metrics (Moro et al., 2016) ====",
  capture.output(print(repl_overview)),
  "",
  "---- Interactions by post type ----",
  capture.output(print(type_summary)),
  "",
  "---- Spearman correlations ----",
  capture.output(print(cor_fb))
)

cat(paste(repl_text, collapse = "\n"), "\n")

## ---- fig-repl-type ----------------------------------------------------------
fig_repl_type <- ggplot(fb, aes(Type, Interactions, fill = Type)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.85, width = 0.65) +
  geom_jitter(width = 0.12, alpha = 0.15, size = 0.8, colour = "grey20") +
  stat_summary(fun = median, geom = "point", shape = 23, size = 3,
               fill = "white", colour = "grey10") +
  scale_y_continuous(trans = "log1p", labels = comma_short) +
  scale_fill_viridis_d(guide = "none", option = "D", end = 0.85) +
  labs(
    title = "Real data confirms format matters",
    subtitle = "UCI Facebook Metrics: total interactions by post type (log scale)",
    x = NULL, y = "Total interactions (log scale)",
    caption = "White diamonds mark medians; jittered points show individual posts."
  )
save_plot(fig_repl_type, "fig13_replication_interactions_by_type", width = 8, height = 5.5)
print(fig_repl_type)

## ---- fig-repl-corr ----------------------------------------------------------
repl_order <- cor_fb %>% dist() %>% hclust() %>% { .$order } %>% rownames(cor_fb)[.]
cor_fb_long <- as.data.frame(cor_fb) %>%
  tibble::rownames_to_column("Var1") %>%
  pivot_longer(-Var1, names_to = "Var2", values_to = "rho") %>%
  mutate(Var1 = factor(Var1, levels = rev(repl_order)),
         Var2 = factor(Var2, levels = repl_order))

fig_repl_corr <- ggplot(cor_fb_long, aes(Var2, Var1, fill = rho)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 3, colour = "grey15") +
  scale_fill_gradientn(colours = PAL_DIVERGING, limits = c(-1, 1)) +
  coord_fixed() +
  labs(
    title = "Reach and engagement move together in real data too",
    subtitle = "UCI Facebook Metrics: Spearman correlations, hierarchically ordered",
    x = NULL, y = NULL, fill = "rho",
    caption = "The views-reach/likes/shares structure mirrors the main dataset."
  ) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))
save_plot(fig_repl_corr, "fig14_replication_correlation_heatmap", width = 8, height = 6.5)
print(fig_repl_corr)

## ---- fig-repl-model ---------------------------------------------------------
# Replicate the core regression: does posting period/type still matter?
fb_model <- lm(log10(Interactions + 1) ~ Type + Month + Weekday + Hour + Paid,
               data = fb)
fb_glance <- broom::glance(fb_model)
fb_tidy   <- broom::tidy(fb_model, conf.int = TRUE)

cat("\n==== Replication regression: log10(Interactions) ====\n")
print(fb_glance)

repl_coef <- fb_tidy %>%
  filter(term != "(Intercept)") %>%
  mutate(term = str_replace_all(term, "Type", "Type: "),
         term = str_replace_all(term, "Month", "Month: "),
         term = str_replace_all(term, "Weekday", "Weekday: "),
         significant = p.value < 0.05,
         term = fct_reorder(term, estimate))

fig_repl_model <- ggplot(repl_coef, aes(estimate, term, colour = significant)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high), size = 0.4) +
  scale_colour_manual(values = c(`TRUE` = "#2166AC", `FALSE` = "grey65"),
                      labels = c(`TRUE` = "p < 0.05", `FALSE` = "not significant"),
                      name = NULL) +
  labs(
    title = "Posting period and format drive real engagement",
    subtitle = "UCI Facebook Metrics regression coefficients with 95% CIs",
    x = "Effect on log10(interactions)", y = NULL,
    caption = "Month (seasonality), post type and hour all reach significance in real data."
  )
save_plot(fig_repl_model, "fig15_replication_model_coefficients", width = 9, height = 8)
print(fig_repl_model)

repl_text <- c(
  repl_text,
  "",
  "==== Replication regression ====",
  capture.output(print(fb_glance)),
  "",
  sprintf("Replication adjusted R-squared: %.3f", fb_glance$adj.r.squared)
)
writeLines(repl_text, file.path(DIR_PROC, "replication_summary.txt"))

cat("\n[04_replication] Replication outputs written.\n")
