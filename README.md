# Social Media Engagement Analytics

An end-to-end **R / tidyverse / ggplot2** analytics project that investigates what drives
engagement (likes, comments, shares, saves and views) across **5,000 posts** on **six social-media
platforms** over **2024–2025** — and then **independently validates** the findings on a second,
**real Kaggle dataset** (23k+ genuinely observed VK posts).

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
| 13 | Validation: interactions by content format | Do the patterns hold on real data? |
| 14 | Validation: correlation heat map | Do engagement actions co-move for real? |
| 15 | Validation: regression coefficients | Does format/timing matter in real data? |

### Headline results

- **Platform is the dominant lever — in two different ways.** TikTok wins on engagement *volume*
  (~5× Instagram, all else equal); Instagram is the most *efficient* platform per view, YouTube the
  least.
- **Reach drives engagement volume** (views and likes are positively related on every platform;
  Spearman ρ ≈ 0.4–0.5 on a log scale).
- **Engagement rate is heavily right-skewed** — a typical post earns ≈ 2% of followers, with a long
  viral tail.
- **Platform absorbs format (in the primary data):** once platform is controlled, content
  format/category are mostly non-significant for both volume and efficiency, and the platform ×
  format interaction is **not** significant. On the real VK validation data, content format *is*
  significant (see §7).
- **Results are robust:** 5-fold CV RMSE = 0.24 (log₁₀) for Model A; removing the 295 view-anomaly
  posts leaves every coefficient essentially unchanged.
- Model **A** explains ≈ **68%** of the variation in engagement volume (adjusted R²); the
  non-circular efficiency model (**B**) explains ≈ **22%**.
- **The real-data validation reproduces the core patterns**, supporting external validity.

---

## Repository structure

```
social-media-engagement-analytics/
├── data/
│   ├── raw/                                   # source data (see SOURCES.md)
│   │   ├── social_media_engagement.csv        # primary (Kaggle)
│   │   ├── vk_posts_metadata.csv              # validation (Kaggle, real)
│   │   └── SOURCES.md
│   └── processed/                             # generated
│       ├── engagement_clean.csv               # analysis-ready table
│       ├── vk_clean.csv                       # cleaned validation table
│       ├── cleaning_log.txt                   # audit trail
│       ├── eda_summary.txt
│       ├── model_summary.txt
│       └── replication_summary.txt
├── R/
│   ├── 00_setup.R            # packages, theme, palettes, helpers
│   ├── 01_preprocess.R       # load, audit, clean, feature-engineer
│   ├── 02_eda.R              # summaries + 8 ggplot2 figures
│   ├── 03_modeling.R         # models, interaction, CV, robustness
│   ├── 04_replication.R      # independent validation on real Kaggle data
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

### Validation — Kaggle *VK Filtered Social Posts with Engagement Metadata* (real data)
* **Source:** <https://www.kaggle.com/datasets/nooruzbekt/vk-social-media-posts-metadata>
* **Size:** 23,453 genuinely observed VK posts (2011–2024) with likes, comments, reposts, content
  format, text length, hashtags and posting time.

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

To re-download the raw data instead of using the bundled CSVs (both are public Kaggle datasets,
no credentials required):

```python
# Python
import kagglehub
kagglehub.dataset_download("aviral342/social-media-engagement-dataset")   # primary
kagglehub.dataset_download("nooruzbekt/vk-social-media-posts-metadata")   # validation
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
* **Validation:** the same core modelling logic re-run on a second, **real Kaggle** dataset
  (23k+ observed VK posts) to confirm the patterns generalise beyond the simulated primary data.

---

## Deliverables checklist

- [x] Dataset description and source (two **Kaggle** datasets)
- [x] R scripts / notebook (`R/`)
- [x] Reproducible preprocessing (cleaned datasets in `data/processed/`)
- [x] EDA summary (`data/processed/eda_summary.txt`)
- [x] Meaningful `ggplot2` visualisations (15 figures: trends, distributions, comparisons, scatter,
      facets, correlation heat maps, coefficient plots, diagnostics, validation)
- [x] Statistical models with diagnostics, interaction test, cross-validation and robustness
- [x] Interpretation of results (§8 of the report)
- [x] Independent validation on real Kaggle data (§7 of the report)
- [x] Final R Markdown report (HTML)

---

## Author

**Himaja Vuchuru** — built as coursework for *Social Media Engagement Analytics*.

## Licence

Code released under the [MIT License](LICENSE). Both datasets remain subject to the terms of their
respective Kaggle listings.
