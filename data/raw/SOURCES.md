# Data sources

## Primary dataset — `social_media_engagement.csv`

| Field | Value |
|---|---|
| Title | Social Media Engagement Dataset |
| Publisher | Kaggle (user `aviral342`) |
| URL | https://www.kaggle.com/datasets/aviral342/social-media-engagement-dataset |
| File | `social_media_engagement.csv` |
| Size | 5,000 rows × 20 columns |
| Period | 1 January 2024 – 31 December 2025 |
| Platforms | Instagram, TikTok, Facebook, YouTube, Twitter, LinkedIn |

### Columns

`Post_ID`, `Timestamp`, `Platform`, `Content_Type`, `Category`, `Likes`, `Comments`, `Shares`,
`Views`, `Saves`, `Follower_Count`, `Engagement_Rate`, `Hour_of_Day`, `Day_of_Week`,
`Hashtag_Count`, `Content_Length`, `Sentiment`, `Influencer_Tier`, `Has_Media`, `Is_Verified`.

### Provenance note

The Kaggle listing describes the engagement figures as *platform-realistic and generated for
educational and research use*. The dataset is used here to demonstrate a reproducible analytics
workflow; findings are interpreted as properties of this dataset and should not be read as
universal facts about live social platforms.

### How it was obtained

Downloaded with the `kagglehub` client, which retrieves the public archive without credentials:

```r
# R
kagglehub::dataset_download("aviral342/social-media-engagement-dataset")
```

```python
# Python
import kagglehub
kagglehub.dataset_download("aviral342/social-media-engagement-dataset")
```

The downloaded CSV was copied verbatim to `data/raw/social_media_engagement.csv`.

### Validation performed during preprocessing

* 0 missing values, 0 duplicate `Post_ID`s.
* `hour(Timestamp)` matches `Hour_of_Day` for all 5,000 rows.
* `weekday(Timestamp)` matches `Day_of_Week` for all 5,000 rows.
* Supplied `Engagement_Rate` equals `100 * (Likes + Comments + Shares) / Follower_Count`
  (maximum absolute difference 0.005, i.e. rounding error).
* 295 posts flagged where total engagement exceeds `Views` (implausible but retained and flagged).

## Replication dataset — `facebook_metrics.csv`

| Field | Value |
|---|---|
| Title | Facebook Metrics |
| Source | UCI Machine Learning Repository (ID 368) |
| Study | Moro, S., Rita, P., & Vala, B. (2016). *Predicting social media performance metrics and the impact of the type of content: A case study in the banking sector.* Journal of Business Research, 69(9), 3341–3349. |
| URL | https://archive.ics.uci.edu/dataset/368/facebook+metrics |
| Mirror used | http://murraylax.org/datasets/facebook.csv |
| File | `facebook_metrics.csv` |
| Size | 500 rows × 14 columns |
| Period | 2014 (one cosmetics brand's Facebook page) |

### Columns

`Type`, `Month`, `Weekday`, `Hour`, `Paid`, `Reach`, `Impressions`, `EngagedUsers`, `Comments`,
`Likes`, `Shares`, `Interactions`, `Weekday.Int`, `Month.Int`.

### Why it is used

The primary Kaggle dataset is published as simulated/platform-realistic data. This **real,
externally collected** dataset is used in `R/04_replication.R` and §7 of the report to confirm
that the core patterns (reach drives engagement; format and timing matter) are not artefacts of
the synthetic data.

### Validation performed during preprocessing

* 500 posts, 0 duplicate rows.
* Missing values: `Likes` 1, `Shares` 4, `Interactions` 0 — handled with `na.rm`/pairwise deletion.
* Some posts have zero interactions; a `log1p` scale is used when visualising.
