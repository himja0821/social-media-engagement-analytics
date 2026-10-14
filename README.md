# Social Media Engagement Analytics

An end-to-end **R / tidyverse / ggplot2** analytics project that investigates what drives
engagement (likes, comments, shares, saves and views) across **5,000 posts** on **six social-media
platforms** over **2024–2025**.

The project contains a reproducible preprocessing pipeline, an exploratory analysis with
**eight publication-quality `ggplot2` figures**, and **two log-linear regression models** that
quantify the drivers of engagement volume and engagement efficiency. Everything is presented in a
single self-contained **R Markdown HTML report**.

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

### Headline results

- **Reach is the dominant driver of engagement volume** (views and likes are strongly, positively
  related on every platform).
- **Platform is the strongest predictor** of both engagement volume and rate.
- **Engagement rate is heavily right-skewed** — a typical post earns ≈ 2% of followers, with a long
  viral tail.
- **Smaller accounts are more efficient:** the engagement *rate* falls as follower counts rise.
- **Content format affects the rate, not the raw volume:** video/interactive posts convert better
  than text.
- Model **A** explains ≈ **68%** and Model **B** ≈ **80%** of the variation (adjusted R²).

---

## Repository structure

```
social-media-engagement-analytics/
├── data/
│   ├── raw/                                   # source data (see SOURCES.md)
│   │   ├── social_media_engagement.csv
│   │   └── SOURCES.md
│   └── processed/                             # generated
│       ├── engagement_clean.csv               # analysis-ready table
│       ├── cleaning_log.txt                   # audit trail
│       ├── eda_summary.txt
│       └── model_summary.txt
├── R/
│   ├── 00_setup.R            # packages, theme, palettes, helpers
│   ├── 01_preprocess.R       # load, audit, clean, feature-engineer
│   ├── 02_eda.R              # summaries + 8 ggplot2 figures
│   ├── 03_modeling.R         # two log-linear models + diagnostics
│   └── 00_run_all.R          # run the whole pipeline
├── figures/                  # 11 exported PNG figures (300 dpi)
├── reports/
│   ├── social_media_engagement_report.Rmd     # the report source
│   └── social_media_engagement_report.html    # rendered report (self-contained)
├── social-media-engagement-analytics.Rproj
├── LICENSE
└── README.md
```

---

## Data

* **Source:** Kaggle — *Social Media Engagement Dataset*
  (<https://www.kaggle.com/datasets/aviral342/social-media-engagement-dataset>).
* **Size:** 5,000 posts × 20 variables, 6 platforms, 12 categories, Jan 2024 – Dec 2025.
* See [`data/raw/SOURCES.md`](data/raw/SOURCES.md) for provenance, licence and re-download steps.

Key variables: `Timestamp`, `Platform`, `Content_Type`, `Category`, `Views`, `Likes`, `Comments`,
`Shares`, `Saves`, `Follower_Count`, `Engagement_Rate`, `Hashtag_Count`, `Content_Length`,
`Sentiment`, `Influencer_Tier`, `Has_Media`, `Is_Verified`.

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

To re-download the raw data instead of using the bundled CSV:

```r
# using the kagglehub R client (no credentials needed for this public dataset)
# install.packages("kagglehub")
kagglehub::dataset_download("aviral342/social-media-engagement-dataset")
```

---

## Deliverables checklist

- [x] Dataset description and source
- [x] R scripts / notebook (`R/`)
- [x] Reproducible preprocessing (cleaned dataset in `data/processed/`)
- [x] EDA summary (`data/processed/eda_summary.txt`)
- [x] Eight meaningful `ggplot2` visualisations (trends, distributions, comparisons, scatter,
      facets, correlation heat map)
- [x] Statistical model / analysis (two regressions with diagnostics)
- [x] Interpretation of results (§7 of the report)
- [x] Final R Markdown report (HTML)

---

## Author

**Himaja Vuchuru** — built as coursework for *Social Media Engagement Analytics*.

## Licence

Code released under the [MIT License](LICENSE). The dataset remains subject to the terms of its
Kaggle listing.
