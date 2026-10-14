# =============================================================================
# 02_eda.R -- Exploratory data analysis and ggplot2 visualisations
# -----------------------------------------------------------------------------
# Input : data/processed/engagement_clean.csv
# Output: figures/*.png  (8 figures), data/processed/eda_summary.txt
#
# Run after 01_preprocess.R:  source("R/02_eda.R")
# =============================================================================

if (!exists("theme_social")) source("R/00_setup.R")

## ---- load-clean -------------------------------------------------------------
eda <- readr::read_csv(file.path(DIR_PROC, "engagement_clean.csv"),
                       show_col_types = FALSE) %>%
  relevel_analysis()

## ---- eda-summary ------------------------------------------------------------
overview <- tibble::tibble(
  Metric = c("Posts analysed", "Platforms", "Content formats",
             "Content categories", "Date range", "Total likes",
             "Total comments", "Total shares", "Total saves"),
  Value = c(format(nrow(eda), big.mark = ","),
            as.character(n_distinct(eda$Platform)),
            as.character(n_distinct(eda$Content_Format)),
            as.character(n_distinct(eda$Category)),
            paste(min(eda$Date), "to", max(eda$Date)),
            format(sum(eda$Likes), big.mark = ","),
            format(sum(eda$Comments), big.mark = ","),
            format(sum(eda$Shares), big.mark = ","),
            format(sum(eda$Saves), big.mark = ","))
)

numeric_vars <- c("Likes", "Comments", "Shares", "Saves", "Views",
                  "Follower_Count", "Total_Engagement",
                  "Engagement_Rate", "Hashtag_Count", "Content_Length")

summary_stats <- eda %>%
  select(all_of(numeric_vars)) %>%
  tidyr::pivot_longer(everything(), names_to = "Variable", values_to = "value") %>%
  group_by(Variable) %>%
  summarise(
    Mean   = mean(value),
    Median = median(value),
    SD     = sd(value),
    Min    = min(value),
    Q1     = quantile(value, .25),
    Q3     = quantile(value, .75),
    Max    = max(value),
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))

platform_summary <- eda %>%
  group_by(Platform) %>%
  summarise(
    Posts        = n(),
    Median_Likes = median(Likes),
    Median_Views = median(Views),
    Mean_ER      = round(mean(Engagement_Rate), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(Mean_ER))

format_summary <- eda %>%
  group_by(Content_Format) %>%
  summarise(
    Posts    = n(),
    Mean_ER  = round(mean(Engagement_Rate), 2),
    Median_ER = round(median(Engagement_Rate), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(Mean_ER))

eda_text <- c(
  "==== OVERVIEW ====",
  capture.output(print(overview)),
  "",
  "==== SUMMARY STATISTICS ====",
  capture.output(print(summary_stats)),
  "",
  "==== ENGAGEMENT BY PLATFORM ====",
  capture.output(print(platform_summary)),
  "",
  "==== ENGAGEMENT BY CONTENT FORMAT ====",
  capture.output(print(format_summary)),
  "",
  sprintf("Overall mean engagement rate (by followers): %.2f%%", mean(eda$Engagement_Rate)),
  sprintf("Overall median engagement rate (by followers): %.2f%%", median(eda$Engagement_Rate)),
  sprintf("Skewness of Total_Engagement: %.2f", {
    z <- (eda$Total_Engagement - mean(eda$Total_Engagement)) / sd(eda$Total_Engagement)
    mean(z^3)
  })
)
writeLines(eda_text, file.path(DIR_PROC, "eda_summary.txt"))
cat(paste(eda_text, collapse = "\n"), "\n")

## ---- eda-missing ------------------------------------------------------------
missing_tbl <- eda %>%
  summarise(across(everything(), ~ sum(is.na(.x)))) %>%
  tidyr::pivot_longer(everything(), names_to = "Variable", values_to = "N_missing")
cat("\nTotal missing cells in analysis dataset:", sum(missing_tbl$N_missing), "\n")

## ---- eda-correlation --------------------------------------------------------
cor_vars <- c("Likes", "Comments", "Shares", "Saves", "Views",
              "Follower_Count", "Hashtag_Count", "Content_Length")
cor_mat <- eda %>%
  select(all_of(cor_vars)) %>%
  mutate(across(everything(), ~ log10(.x + 1))) %>%
  cor(method = "spearman") %>%
  round(2)
cat("\nSpearman correlations (log10 scale):\n")
print(cor_mat)

## ---- fig-trend --------------------------------------------------------------
trend_df <- eda %>%
  group_by(Year_Month = as.Date(Year_Month)) %>%
  summarise(Mean_ER = mean(Engagement_Rate), .groups = "drop")

peak <- trend_df %>% slice_max(Mean_ER, n = 1)

fig_trend <- ggplot(trend_df, aes(Year_Month, Mean_ER)) +
  geom_line(colour = "#2166AC", linewidth = 0.9) +
  geom_point(colour = "#2166AC", size = 2) +
  geom_smooth(method = "loess", span = 0.6, se = FALSE,
              colour = "#B2182B", linetype = "dashed", linewidth = 0.8) +
  geom_hline(yintercept = mean(trend_df$Mean_ER), colour = "grey50",
             linetype = "dotted") +
  annotate("label", x = peak$Year_Month, y = peak$Mean_ER,
           label = paste0("Peak: ", format(peak$Year_Month, "%b %Y"),
                          "\n", round(peak$Mean_ER, 1), "%"),
           hjust = 0.5, vjust = -0.4, size = 3.4, fill = "#FFF3CD") +
  scale_x_date(date_labels = "%b\n%Y", date_breaks = "3 months") +
  labs(
    title = "Engagement held steady through 2024-2025",
    subtitle = "Monthly mean engagement rate (interactions per follower) across all 5,000 posts",
    x = NULL, y = "Mean engagement rate (%)",
    caption = "Dashed red = LOESS trend; dotted grey = overall mean."
  )
save_plot(fig_trend, "fig01_trend_engagement_over_time", width = 10, height = 5.5)
print(fig_trend)

## ---- fig-distribution -------------------------------------------------------
med_log <- median(log10(eda$Engagement_Rate))
mean_log <- mean(log10(eda$Engagement_Rate))

fig_dist <- ggplot(eda, aes(log10(Engagement_Rate))) +
  geom_histogram(aes(y = after_stat(density)), bins = 40,
                 fill = "#4477AA", colour = "white", alpha = 0.85) +
  geom_density(colour = "#B2182B", linewidth = 1) +
  geom_vline(xintercept = med_log, linetype = "dashed", colour = "grey20") +
  annotate("label", x = med_log, y = Inf,
           label = paste0("median = ", round(10^med_log, 2), "%"),
           vjust = 1.4, hjust = -0.05, size = 3.3, fill = "white") +
  scale_x_continuous(
    breaks = log10(c(0.05, 0.5, 2, 10, 50, 500, 3500)),
    labels = c("0.05%", "0.5%", "2%", "10%", "50%", "500%", "3500%")) +
  labs(
    title = "Engagement rate is strongly right-skewed",
    subtitle = "Most posts sit near 2%, but a long tail of viral posts reaches into the thousands",
    x = "Engagement rate (interactions / followers, log scale)",
    y = "Density",
    caption = "Histogram of log10(engagement rate); red curve = kernel density."
  )
save_plot(fig_dist, "fig02_distribution_engagement_rate")
print(fig_dist)

## ---- fig-contenttype --------------------------------------------------------
fig_format <- eda %>%
  mutate(Content_Format = fct_reorder(Content_Format, Engagement_Rate, median)) %>%
  ggplot(aes(Content_Format, Engagement_Rate, fill = Content_Format)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.85, width = 0.65) +
  geom_jitter(width = 0.12, alpha = 0.08, size = 0.7, colour = "grey20") +
  stat_summary(fun = median, geom = "point", shape = 23, size = 3,
               fill = "white", colour = "grey10") +
  coord_cartesian(ylim = c(0, 12)) +
  scale_fill_manual(values = PAL_FORMAT, guide = "none") +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    title = "Video posts draw the strongest engagement",
    subtitle = "Boxes ordered by median; white diamonds mark medians (outliers hidden)",
    x = NULL, y = "Engagement rate (%)",
    caption = "Y-axis zoomed to 0-12% with coord_cartesian(); values above are clipped for readability."
  )
save_plot(fig_format, "fig03_comparison_engagement_by_content")
print(fig_format)

## ---- fig-platform -----------------------------------------------------------
platform_plot <- eda %>%
  group_by(Platform) %>%
  summarise(Mean_ER = mean(Engagement_Rate),
            SE = sd(Engagement_Rate) / sqrt(n()), .groups = "drop")

fig_platform <- ggplot(platform_plot, aes(fct_reorder(Platform, Mean_ER), Mean_ER,
                                          fill = Platform)) +
  geom_col(alpha = 0.9, width = 0.7) +
  geom_errorbar(aes(ymin = Mean_ER - SE, ymax = Mean_ER + SE),
                width = 0.2, colour = "grey30") +
  scale_fill_manual(values = PAL_PLATFORM, guide = "none") +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    title = "Average engagement rate differs sharply by platform",
    subtitle = "Bars show mean engagement rate; whiskers show +/- 1 standard error",
    x = NULL, y = "Mean engagement rate (%)",
    caption = "Mean is sensitive to viral outliers -- medians are compared in fig03 and fig08."
  )
save_plot(fig_platform, "fig04_comparison_engagement_by_platform")
print(fig_platform)

## ---- fig-scatter ------------------------------------------------------------
rho <- cor(log10(eda$Views), log10(eda$Likes), method = "spearman")

fig_scatter <- ggplot(eda, aes(Views, Likes, colour = Platform)) +
  geom_point(alpha = 0.45, size = 1.3) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.8, formula = y ~ x) +
  scale_x_log10(labels = comma_short) +
  scale_y_log10(labels = comma_short) +
  scale_colour_manual(values = PAL_PLATFORM) +
  annotate("label", x = min(eda$Views) * 1.6, y = max(eda$Likes) * 0.9,
           label = paste0("Spearman rho = ", round(rho, 2)),
           hjust = 0, size = 3.6, fill = "white") +
  labs(
    title = "More views almost always means more likes",
    subtitle = "Likes rise with reach on every platform, but the slope differs by platform",
    x = "Views (log scale)", y = "Likes (log scale)",
    caption = "Each line = ordinary least-squares fit for that platform on log-log axes."
  )
suppressMessages(save_plot(fig_scatter, "fig05_scatter_views_vs_likes"))
suppressMessages(print(fig_scatter))

## ---- fig-facet-time ---------------------------------------------------------
hour_df <- eda %>%
  group_by(Platform, Hour) %>%
  summarise(Median_ER = median(Engagement_Rate), .groups = "drop")

fig_facet <- ggplot(hour_df, aes(Hour, Median_ER, colour = Platform)) +
  geom_line(linewidth = 0.7, alpha = 0.8) +
  geom_point(size = 1.4) +
  facet_wrap(~Platform, ncol = 3, scales = "free_y") +
  scale_colour_manual(values = PAL_PLATFORM, guide = "none") +
  scale_x_continuous(breaks = seq(0, 23, 6)) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    title = "Best posting hours vary by platform",
    subtitle = "Median engagement rate by hour of day, one panel per platform",
    x = "Hour of day (0-23)", y = "Median engagement rate (%)",
    caption = "Free y-axes let each platform's shape be read; compare heights with caution."
  )
save_plot(fig_facet, "fig06_facet_engagement_by_hour", width = 10, height = 6)
print(fig_facet)

## ---- fig-heatmap ------------------------------------------------------------
ordered_vars <- cor_mat %>%
  as.data.frame() %>%
  dist() %>%
  hclust() %>%
  { .$order } %>%
  rownames(cor_mat)[.]

cor_long <- as.data.frame(cor_mat) %>%
  tibble::rownames_to_column("Var1") %>%
  pivot_longer(-Var1, names_to = "Var2", values_to = "rho") %>%
  mutate(
    Var1 = factor(Var1, levels = rev(ordered_vars)),
    Var2 = factor(Var2, levels = ordered_vars)
  )

fig_heat <- ggplot(cor_long, aes(Var2, Var1, fill = rho)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 3, colour = "grey15") +
  scale_fill_gradientn(colours = PAL_DIVERGING, limits = c(-1, 1),
                       breaks = seq(-1, 1, 0.5)) +
  coord_fixed() +
  labs(
    title = "Engagement metrics move together",
    subtitle = "Spearman rank correlations (log10 scale), hierarchically ordered",
    x = NULL, y = NULL, fill = "rho",
    caption = "Reach (views) and follower count track likes tightly; shares are the most independent signal."
  ) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))
save_plot(fig_heat, "fig07_correlation_heatmap", width = 8, height = 7)
print(fig_heat)

## ---- fig-tiers --------------------------------------------------------------
fig_tiers <- ggplot(eda, aes(Influencer_Tier, Engagement_Rate, fill = Influencer_Tier)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.85, width = 0.65) +
  stat_summary(fun = median, geom = "text", aes(label = sprintf("%.1f%%", after_stat(y))),
               vjust = -0.6, size = 3.2, colour = "grey15") +
  coord_cartesian(ylim = c(0, 12)) +
  scale_fill_manual(values = PAL_TIER, guide = "none") +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    title = "Smaller accounts earn higher engagement rates",
    subtitle = "Engagement rate by influencer tier (labels show medians)",
    x = NULL, y = "Engagement rate (%)",
    caption = "Nano/Micro accounts convert followers into interactions far more efficiently than Macro accounts."
  )
save_plot(fig_tiers, "fig08_engagement_by_influencer_tier")
print(fig_tiers)

cat("\n[02_eda] Figures written to", DIR_FIG, "\n")
