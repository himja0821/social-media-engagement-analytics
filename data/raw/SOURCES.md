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

## Validation dataset — `vk_posts_metadata.csv`

| Field | Value |
|---|---|
| Title | VK Filtered Social Posts with Engagement Metadata |
| Source | Kaggle (publisher `nooruzbekt`) |
| URL | https://www.kaggle.com/datasets/nooruzbekt/vk-social-media-posts-metadata |
| File | `vk_posts_metadata.csv` |
| Size | 23,453 rows × 12 columns |
| Period | Nov 2011 – Dec 2024 |
| Nature | **Real, observed** posts scraped from public VK pages |

### Columns

`Post ID`, `Post Link`, `Text`, `Date & Time`, `Author ID`, `Likes`, `Comments`, `Reposts`,
`Hashtags`, `Content Type`, `Text Length`, `Time of Day`.

### Why it is used

The primary Kaggle dataset is published as simulated/platform-realistic data. This second,
**genuinely observed Kaggle dataset** is used in `R/04_replication.R` and §7 of the report to
confirm that the core patterns (format and timing matter; engagement actions co-move) are not
artefacts of the simulated data.

### How it was obtained

```python
import kagglehub
kagglehub.dataset_download("nooruzbekt/vk-social-media-posts-metadata")
```

### Validation / cleaning performed

* 23,453 posts; duplicates removed on `Post ID`.
* `Content Type` (43 raw attachment strings) harmonised into `Photo`, `Video`, `Link`, `Text`,
  `Other` (priority Video > Photo > Link > Text).
* `Time of Day` translated from Russian (Утро/День/Вечер/Ночь) → Morning/Afternoon/Evening/Night.
* `Text` has 6,906 blanks (not needed for the numeric analysis); `Text Length` is used instead.
* `Hashtags` is `"Нет"` (“No”) for 98.2% of posts, so it is treated as a binary flag.
* Engagement outcome = `Likes + Comments + Reposts`; several posts have zero, so a `log1p` scale
  is used when visualising.
