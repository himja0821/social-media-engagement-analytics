# =============================================================================
# 04_replication.R -- Independent validation on a second, REAL Kaggle dataset
# -----------------------------------------------------------------------------
# Input : data/raw/vk_posts_metadata.csv
#         (Kaggle: "VK Filtered Social Posts with Engagement Metadata" --
#          23,453 real posts scraped from public VK pages, 2011-2024)
# Output: figures/fig13..fig15, data/processed/replication_summary.txt
#
# Purpose: the primary dataset is published as platform-realistic/simulated
#          data. This script re-tests the core story -- that content format and
#          posting timing drive engagement -- on genuinely real, observed posts,
#          so the conclusions are not an artefact of one synthetic source.
# =============================================================================

if (!exists("theme_social")) source("R/00_setup.R")

## ---- repl-load --------------------------------------------------------------
vk_raw <- readr::read_csv(
  file.path(DIR_RAW, "vk_posts_metadata.csv"),
  col_types = readr::cols(`Date & Time` = readr::col_character(),
                          .default = readr::col_guess()),
  show_col_types = FALSE
)

vk <- vk_raw %>%
  rename(
    post_id      = `Post ID`,
    datetime     = `Date & Time`,
    author_id    = `Author ID`,
    likes        = `Likes`,
    comments     = `Comments`,
    reposts      = `Reposts`,
    hashtags     = `Hashtags`,
    content_type = `Content Type`,
    text_length  = `Text Length`,
    time_of_day  = `Time of Day`
  ) %>%
  mutate(
    datetime  = lubridate::ymd_hms(datetime),
    # Real observed engagements: likes + comments + reposts
    engagement = likes + comments + reposts,
    has_hashtags = !is.na(hashtags) & trimws(hashtags) != "\u041d\u0435\u0442" &
      nzchar(trimws(hashtags)),
    format = dplyr::case_when(
      stringr::str_detect(content_type, "video") ~ "Video",
      stringr::str_detect(content_type, "photo") ~ "Photo",
      stringr::str_detect(content_type, "link")  ~ "Link",
      stringr::str_detect(content_type, "text")  ~ "Text",
      TRUE                                       ~ "Other"
    ),
    time_of_day = dplyr::recode(time_of_day,
      "\u0423\u0442\u0440\u043e"  = "Morning",
      "\u0414\u0435\u043d\u044c"  = "Afternoon",
      "\u0412\u0435\u0447\u0435\u0440" = "Evening",
      "\u041d\u043e\u0447\u044c"  = "Night"
    ),
    year   = lubridate::year(datetime)
  ) %>%
  filter(!is.na(datetime), !is.na(format)) %>%
  distinct(post_id, .keep_all = TRUE) %>%
  mutate(
    format      = factor(format, levels = c("Photo", "Video", "Link", "Text", "Other")),
    time_of_day = factor(time_of_day,
                         levels = c("Morning", "Afternoon", "Evening", "Night"))
  )

## ---- repl-summary -----------------------------------------------------------
repl_overview <- tibble::tibble(
  Metric = c("Posts (real, observed)", "Date coverage", "Distinct posting days",
             "Total likes", "Total comments", "Total reposts",
             "Median engagements / post", "Share with hashtags"),
  Value = c(format(nrow(vk), big.mark = ","),
            paste(format(min(vk$datetime), "%b %Y"), "\u2013",
                  format(max(vk$datetime), "%b %Y")),
            format(dplyr::n_distinct(as.Date(vk$datetime)), big.mark = ","),
            format(sum(vk$likes), big.mark = ","),
            format(sum(vk$comments), big.mark = ","),
            format(sum(vk$reposts), big.mark = ","),
            format(median(vk$engagement), big.mark = ","),
            sprintf("%.1f%%", 100 * mean(vk$has_hashtags)))
)

format_summary <- vk %>%
  group_by(format) %>%
  summarise(Posts = n(),
            Median_Engagement = median(engagement),
            Mean_Engagement = round(mean(engagement)),
            Median_Text_Length = median(text_length, na.rm = TRUE),
            .groups = "drop") %>%
  arrange(desc(Median_Engagement))

time_summary <- vk %>%
  group_by(time_of_day) %>%
  summarise(Posts = n(), Median_Engagement = median(engagement),
            .groups = "drop")

cor_vars_vk <- c("likes", "comments", "reposts", "engagement", "text_length")
cor_vk <- vk %>% select(all_of(cor_vars_vk)) %>%
  cor(method = "spearman", use = "pairwise.complete.obs") %>% round(2)

repl_text <- c(
  "==== VALIDATION: real Kaggle VK posts (23k+ observed posts) ====",
  capture.output(print(repl_overview)),
  "",
  "---- Engagement by content format (real data) ----",
  capture.output(print(format_summary)),
  "",
  "---- Engagement by time of day (real data) ----",
  capture.output(print(time_summary)),
  "",
  "---- Spearman correlations ----",
  capture.output(print(cor_vk))
)
cat(paste(repl_text, collapse = "\n"), "\n")

## ---- fig-repl-type ----------------------------------------------------------
fig_repl_type <- ggplot(vk, aes(format, engagement, fill = format)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.85, width = 0.65) +
  geom_jitter(width = 0.12, alpha = 0.08, size = 0.6, colour = "grey20") +
  stat_summary(fun = median, geom = "point", shape = 23, size = 3,
               fill = "white", colour = "grey10") +
  scale_y_continuous(trans = "log1p", labels = comma_short) +
  scale_fill_viridis_d(guide = "none", option = "D", end = 0.85) +
  labs(
    title = "Real observed data confirms format matters",
    subtitle = "Kaggle VK posts: total engagements (likes + comments + reposts) by content format",
    x = NULL, y = "Total engagements (log scale)",
    caption = "Real data (n = 23k+ posts); white diamonds mark medians. A log1p axis keeps zero-engagement posts visible."
  )
save_plot(fig_repl_type, "fig13_replication_interactions_by_type", width = 8, height = 5.5)
print(fig_repl_type)

## ---- fig-repl-corr ----------------------------------------------------------
cor_order <- cor_vk %>% dist() %>% hclust() %>% { .$order } %>% rownames(cor_vk)[.]
cor_long <- as.data.frame(cor_vk) %>%
  tibble::rownames_to_column("Var1") %>%
  pivot_longer(-Var1, names_to = "Var2", values_to = "rho") %>%
  mutate(Var1 = factor(Var1, levels = rev(cor_order)),
         Var2 = factor(Var2, levels = cor_order),
         Var1 = stringr::str_replace_all(Var1, "_", " "),
         Var2 = stringr::str_replace_all(Var2, "_", " "))

fig_repl_corr <- ggplot(cor_long, aes(Var2, Var1, fill = rho)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 3, colour = "grey15") +
  scale_fill_gradientn(colours = PAL_DIVERGING, limits = c(-1, 1)) +
  coord_fixed() +
  labs(
    title = "Likes, comments and reposts co-move in real data too",
    subtitle = "Kaggle VK posts: Spearman correlations, hierarchically ordered",
    x = NULL, y = NULL, fill = "rho",
    caption = "The positive coupling of engagement actions mirrors the primary dataset."
  ) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))
save_plot(fig_repl_corr, "fig14_replication_correlation_heatmap", width = 8, height = 6.5)
print(fig_repl_corr)

## ---- fig-repl-model ---------------------------------------------------------
# Replicate the core regression: do format and timing still matter on real data?
vk_model <- lm(log10(engagement + 1) ~ format + log1p(text_length) +
                 has_hashtags + time_of_day + year, data = vk)
vk_glance <- broom::glance(vk_model)
vk_tidy   <- broom::tidy(vk_model, conf.int = TRUE)

cat("\n==== Validation regression: log10(engagements + 1) ====\n")
print(vk_glance)

repl_coef <- vk_tidy %>%
  filter(term != "(Intercept)") %>%
  mutate(
    term = stringr::str_replace_all(term, "^format", "Format: "),
    term = stringr::str_replace_all(term, "^time_of_day", "Time: "),
    term = stringr::str_replace_all(term, "log1p\\(text_length\\)", "Text length (log)"),
    term = stringr::str_replace_all(term, "has_hashtagsTRUE", "Has hashtags"),
    term = stringr::str_replace_all(term, "^year", "Year (trend)"),
    significant = p.value < 0.05,
    term = fct_reorder(term, estimate)
  )

fig_repl_model <- ggplot(repl_coef, aes(estimate, term, colour = significant)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high), size = 0.4) +
  scale_colour_manual(values = c(`TRUE` = "#2166AC", `FALSE` = "grey65"),
                      labels = c(`TRUE` = "p < 0.05", `FALSE` = "not significant"),
                      name = NULL) +
  labs(
    title = "Format and length drive real engagement",
    subtitle = "Kaggle VK posts regression coefficients with 95% CIs",
    x = "Effect on log10(engagements)", y = NULL,
    caption = "On genuinely observed posts, video format is a significant positive driver while link/text formats trail photos; longer captions and evening/night posting are slightly negative."
  )
save_plot(fig_repl_model, "fig15_replication_model_coefficients", width = 9, height = 8)
print(fig_repl_model)

repl_text <- c(
  repl_text,
  "",
  "==== Validation regression ====",
  capture.output(print(vk_glance)),
  "",
  sprintf("Validation adjusted R-squared: %.3f", vk_glance$adj.r.squared),
  sprintf("Validation sample: %s real posts", format(nrow(vk), big.mark = ","))
)
writeLines(repl_text, file.path(DIR_PROC, "replication_summary.txt"))
readr::write_csv(vk %>%
                   select(post_id, datetime, format, time_of_day, text_length,
                          has_hashtags, likes, comments, reposts, engagement),
                 file.path(DIR_PROC, "vk_clean.csv"))

cat("\n[04_replication] Validation outputs written.\n")
