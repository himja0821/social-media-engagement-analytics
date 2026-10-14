# =============================================================================
# 00_setup.R -- Packages, shared theme, palettes and helper functions
# Project: Social Media Engagement Analytics (R / ggplot2)
# -----------------------------------------------------------------------------
# Sourced by every other script and by the R Markdown report. Contains no
# analysis, only reusable infrastructure so that all figures share one look.
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(lubridate)
  library(forcats)
  library(ggplot2)
  library(scales)
  library(broom)
  library(patchwork)
})

options(scipen = 999, dplyr.summarise.inform = FALSE)

# --- Project root detection --------------------------------------------------
# Lets every script/report run regardless of whether the working directory is
# the project root or the reports/ sub-folder.
find_project_root <- function(start = getwd(), markers = c("data", "R")) {
  p <- normalizePath(start, mustWork = FALSE)
  for (i in 1:6) {
    if (all(dir.exists(file.path(p, markers)))) return(p)
    parent <- normalizePath(file.path(p, ".."), mustWork = FALSE)
    if (identical(parent, p)) break
    p <- parent
  }
  normalizePath(start, mustWork = FALSE)
}

PROJ_ROOT <- find_project_root()
DIR_RAW   <- file.path(PROJ_ROOT, "data", "raw")
DIR_PROC  <- file.path(PROJ_ROOT, "data", "processed")
DIR_FIG   <- file.path(PROJ_ROOT, "figures")
INVISIBLE <- dir.create(DIR_PROC, showWarnings = FALSE, recursive = TRUE)
INVISIBLE <- dir.create(DIR_FIG,  showWarnings = FALSE, recursive = TRUE)

# --- Colour palettes ---------------------------------------------------------
PAL_PLATFORM <- c(
  Instagram = "#E1306C",
  TikTok    = "#111111",
  Facebook  = "#1877F2",
  YouTube   = "#FF0000",
  Twitter   = "#1DA1F2",
  LinkedIn  = "#0A66C2"
)

PAL_FORMAT <- c(
  "Video"        = "#4477AA",
  "Image"        = "#EE6677",
  "Interactive"  = "#228833",
  "Text/Article" = "#CCBB44"
)

PAL_TIER <- c(
  Nano     = "#66CCEE",
  Micro    = "#228833",
  `Mid-tier` = "#CCBB44",
  Macro    = "#AA3377"
)

PAL_DIVERGING <- c("#B2182B", "#EF8A62", "#F7F7F7", "#67A9CF", "#2166AC")

# --- Shared ggplot theme -----------------------------------------------------
theme_social <- function(base_size = 12, base_family = "sans") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      plot.title       = element_text(face = "bold", size = base_size + 3,
                                      margin = margin(b = 4)),
      plot.subtitle    = element_text(colour = "grey35", lineheight = 1.15,
                                      margin = margin(b = 10)),
      plot.caption     = element_text(colour = "grey55", size = base_size - 2,
                                      hjust = 0, margin = margin(t = 8)),
      axis.title       = element_text(face = "bold", colour = "grey20"),
      axis.text        = element_text(colour = "grey30"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey91", linewidth = 0.3),
      legend.position  = "bottom",
      legend.title     = element_text(face = "bold"),
      legend.key       = element_blank(),
      strip.text       = element_text(face = "bold", colour = "grey15"),
      strip.background = element_rect(fill = "grey94", colour = NA),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      plot.margin      = margin(12, 16, 10, 12)
    )
}
theme_set(theme_social())

# --- Helper: save a figure consistently --------------------------------------
save_plot <- function(plot, name, width = 9, height = 5.5, dpi = 300) {
  path <- file.path(DIR_FIG, paste0(name, ".png"))
  ggsave(path, plot = plot, width = width, height = height, dpi = dpi,
         bg = "white")
  invisible(plot)
}

# --- Helper: number formatting ----------------------------------------------
comma_short <- function(x) label_number(scale_cut = cut_short_scale())(x)

# --- Helper: restore factor levels after reading the processed CSV -----------
relevel_analysis <- function(d) {
  d %>%
    mutate(
      Platform        = factor(Platform, levels = names(PAL_PLATFORM)),
      Content_Format  = factor(Content_Format, levels = names(PAL_FORMAT)),
      Posting_Period  = factor(Posting_Period,
                               levels = c("Morning", "Afternoon", "Evening", "Night")),
      Influencer_Tier = factor(Influencer_Tier, levels = names(PAL_TIER)),
      Sentiment       = factor(Sentiment, levels = c("Negative", "Neutral", "Positive")),
      Weekday         = factor(Weekday,
                               levels = c("Monday", "Tuesday", "Wednesday", "Thursday",
                                          "Friday", "Saturday", "Sunday")),
      Has_Media       = factor(Has_Media,   levels = c("With media", "Without media")),
      Is_Verified     = factor(Is_Verified, levels = c("Verified", "Not verified"))
    )
}

cat("\n[00_setup] Project root:", PROJ_ROOT, "\n")
