# Social Media Engagement Analytics

An end-to-end **R / tidyverse / ggplot2** analytics project that investigates what drives
engagement (likes, comments, shares, saves and views) across **5,000 posts** on **six social-media
platforms** over **2024–2025** — and then **independently replicates** the findings on a **real,
peer-reviewed dataset** (UCI *Facebook Metrics*, 500 posts).

The project contains a reproducible preprocessing pipeline, an exploratory analysis with
**fifteen publication-quality `ggplot2` figures**, and **log-linear regression models** that
quantify the drivers of engagement volume and engagement efficiency, plus an interaction test,
5-fold cross-validation and a robustness check. Everything is presented in a single self-contained
**R Markdown HTML report**.

---

## Highlights

| # | Figure | Question it answers |
|---|--------|---------------------|
| 1 | Engagement over time | Is engagement trending or seasonal? |
| 2 | Distribution of engagement rate | How skewed is engagement? |
| 3 | Engagement by content format | Do videos beat photos and text? |
| 4 | Engagement by platform | Which platform performs best? |
| 5 | Views vs likes (log–log) | How tightly linked are reach and likes? |
| 6 | Engagement by hour, faceted by platform | When should you post? |
| 7 | Correlation heat map | How do the metrics move together? |
| 8 | Engagement by influencer tier | Do small accounts win? |
| 9 | Model A coefficients | What drives engagement volume? |
| 10 | Model diagnostics | Is the regression trustworthy? |
| 11 | Model B coefficients | What drives engagement efficiency? |
| 12 | Platform × format interaction | Do platform and format amplify each other? |
| 13 | Replication: interactions by post type | Do the patterns hold on real data? |
| 14 | Replication: correlation heat map | Is reach–engagement structure real? |
| 15 | Replication: regression coefficients | Does format/timing matter in real data? |

### Headline results

- **Platform is the dominant lever — in two different ways.** TikTok wins on engagement *volume*
  (~5× Instagram, all else equal); Instagram is the most *efficient* platform per view, YouTube the
  least.
- **Reach drives engagement volume** (views and likes are strongly, positively related on every
  platform; Spearman ρ ≈ 0.65 between reach and interactions).
- **Engagement rate is heavily right-skewed** — a typical post earns ≈ 2% of followers, with a long
  viral tail.
- **Platform absorbs format:** once platform is controlled, content format/category are mostly
  non-significant for both volume and efficiency, and the platform × format interaction is **not**
  significant (in the real replication data, post type *is* significant — see §7).
- **Results are robust:** 5-fold CV RMSE = 0.24 (log₁₀) for Model A; removing the 295 view-anomaly
  posts leaves every coefficient essentially unchanged.
- Model **A** explains ≈ **68%** of the variation in engagement volume (adjusted R²); the
  non-circular efficiency model (**B**) explains ≈ **22%**.
- **The real-data replication reproduces the core patterns**, supporting external validity.

---

## Repository structure

```
social-media-engagement-analytics/
├── data/
│   ├── raw/                                   # source data (see SOURCES.md)
│   │   ├── social_media_engagement.csv        # primary (Kaggle)
│   │   ├── facebook_metrics.csv               # replication (UCI, real)
│   │   └── SOURCES.md
│   └── processed/                             # generated
│       ├── engagement_clean.csv               # analysis-ready table
│       ├── cleaning_log.txt                   # audit trail
│       ├── eda_summary.txt
│       ├── model_summary.txt
│       └── replication_summary.txt
├── R/
│   ├── 00_setup.R            # packages, theme, palettes, helpers
│   ├── 01_preprocess.R       # load, audit, clean, feature-engineer
│   ├── 02_eda.R              # summaries + 8 ggplot2 figures
│   ├── 03_modeling.R         # models, interaction, CV, robustness
│   ├── 04_replication.R      # independent replication on UCI data
│   └── 00_run_all.R          # run the whole pipeline
├── figures/                  # 15 exported PNG figures (300 dpi)
├── reports/
│   ├── social_media_engagement_report.Rmd     # the report source
│   └── social_media_engagement_report.html    # rendered report (self-contained)
├── social-media-engagement-analytics.Rproj
├── LICENSE
└── README.md
```

---

## Data

### Primary — Kaggle *Social Media Engagement Dataset*
* **Source:** <https://www.kaggle.com/datasets/aviral342/social-media-engagement-dataset>
* **Size:** 5,000 posts × 20 variables, 6 platforms, 12 categories, Jan 2024 – Dec 2025.
* The publisher states the figures are *platform-realistic and generated for educational use*, so
  the project focuses on **methodology** and adds an independent real-data check.

### Replication — UCI *Facebook Metrics* (real data)
* **Source:** Moro, S., Rita, P., & Vala, B. (2016). *Predicting social media performance metrics
  and the impact of the type of content.* Journal of Business Research, 69(9). UCI ID 368.
* **Size:** 500 real posts from a cosmetics brand's Facebook page (2014).

See [`data/raw/SOURCES.md`](data/raw/SOURCES.md) for full provenance, licences and re-download steps.

Primary variables: `Timestamp`, `Platform`, `Content_Type`, `Category`, `Views`, `Likes`,
`Comments`, `Shares`, `Saves`, `Follower_Count`, `Engagement_Rate`, `Hashtag_Count`,
`Content_Length`, `Sentiment`, `Influencer_Tier`, `Has_Media`, `Is_Verified`.

---

## How to reproduce

**Requirements:** R ≥ 4.2 and pandoc (or RStudio). Install the packages once:

```r
install.packages(c("tidyverse", "lubridate", "ggplot2", "scales",
                   "broom", "patchwork", "rmarkdown"))
```

Then, from the project root:

```r
# 1. Run the full analysis pipeline (writes data/processed + figures)
source("R/00_run_all.R")

# 2. Render the report
rmarkdown::render("reports/social_media_engagement_report.Rmd")
```

The report uses `knitr::read_chunk()` to execute the *same* code in `R/`, so the scripts and the
report can never drift apart.

To re-download the primary raw data instead of using the bundled CSV:

```r
# using the kagglehub R client (no credentials needed for this public dataset)
# install.packages("kagglehub")
kagglehub::dataset_download("aviral342/social-media-engagement-dataset")
```

---

## Methods at a glance

* **Cleaning:** timestamp parsing, internal-consistency checks (hour/day match the timestamp),
  re-derivation of the supplied `Engagement_Rate`, and flagging of 295 view-anomaly posts.
* **EDA:** distributions, platform/format/tier comparisons, log–log scatter, hour facets and a
  hierarchically ordered correlation heat map.
* **Modelling:** log-linear regressions; **Model A** = log₁₀(total engagement) volume, **Model B** =
  log₁₀(interactions per view) efficiency (chosen to avoid the circularity of a per-follower rate).
  Includes a Platform × Format interaction test, variance-inflation factors, 5-fold CV RMSE, and a
  sensitivity refit excluding anomalies.
* **Replication:** the same modelling logic re-run on the real UCI Facebook Metrics dataset.

---

## Deliverables checklist

- [x] Dataset description and source (two datasets)
- [x] R scripts / notebook (`R/`)
- [x] Reproducible preprocessing (cleaned dataset in `data/processed/`)
- [x] EDA summary (`data/processed/eda_summary.txt`)
- [x] Meaningful `ggplot2` visualisations (15 figures: trends, distributions, comparisons, scatter,
      facets, correlation heat maps, coefficient plots, diagnostics, replication)
- [x] Statistical models with diagnostics, interaction test, cross-validation and robustness
- [x] Interpretation of results (§8 of the report)
- [x] Independent replication on real data (§7 of the report)
- [x] Final R Markdown report (HTML)

---

## Author

**Himaja Vuchuru** — built as coursework for *Social Media Engagement Analytics*.

## Licence

Code released under the [MIT License](LICENSE). The datasets remain subject to the terms of their
respective listings (Kaggle and UCI).
