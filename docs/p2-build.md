# 1. Establish the input and run ingestion

## Audience and primary analytical question

| Field | Value |
|---|---|
| Audience | Citi Bike's operations planning team, who is responsible for understanding historical ridership demand |
| Primary analytical question | How does trip volume vary by month, season, year, day of week and hour of day? |

## Source identifiers

| Field | Value |
|---|---|
| Source provider | Citi Bike New York / Google Cloud BigQuery Public Datasets |
| Source project | `bigquery-public-data` |
| Source dataset | `new_york_citibike` |
| Source URL | [New York Citi Bike](https://console.cloud.google.com/bigquery?p=bigquery-public-data&d=new_york_citibike&page=dataset&project=seis-732-508001&ws=!1m5!1m4!3m2!1sbigquery-public-data!2snew_york_citibike!23sLEGACY_URL_PARAM) |
| Primary source table | `citibike_trips` |
| Data location | US |
| Execution project | `seis-732-508001` |

### Source table profile
| Attribute | Value |
|---|---|
| Grain | One row represents one recorded Citi Bike trip event. |
| Row count | 58,937,715 |
| Date range | July 1, 2013 to May 31, 2018 (based on recorded trip times). |
| Candidate identifier | `bikeid` and `starttime` |

## Load decisions
| Decision | My choice | Why it fits this source |
|---|---|---|
| Source format and header row | Native BigQuery table; no header handling required | The source is an existing table in the BigQuery Public Datasets project. Since the column names and data types are already defined, header-row settings are not applicable. |
| Declared types for composite ID | bikeid: INTEGER; starttime: DATETIME | The combination of `bikeid` and `starttime` serves as the proposed composite trip identifier. These fields are preserved from the source and duplicate combinations will be addressed during curation. |
| Empty fields and invalid records | Allow NULL values and empty-string values in partially populated records; exclude fully blank records | Missing values in certain columns (such as gender) are not consequential to the primary analysis. Partially populated records are retained for downstream quality assessment. Records with no populated fields are excluded during ingestion because they provide no usable trip information. |
| Load into BigQuery or query the source in place | Load into a native BigQuery table | A native table provides a stable version of the source data, which supports reproducible curation and analysis without repeating querying the public source. |
| Append or replace on repeated loads | CREATE OR REPLACE TABLE | Replacing the raw table prevents duplicate records from being introduced when reloading the same source table. |
| Source-to-Raw filtering | CREATE OR REPLACE TABLE ... AS SELECT with a WHERE condition | The query excludes records where all fields are NULL or blank while preserving partially populated records and duplicate composite identifiers for the curated layer. |

## Source-to-Raw reproducibility

[Ingestion SQL: 02_ingest.sql](../sql/02_ingest.sql)

Source: bigquery-public-data.new_york_citibike.citibike_trips  
Source row count: 58,937,715  
Raw row count: 53,108,721  
Rows excluded during ingestion: 5,828,994

### Raw row grain

One row represents one source record of a Citi Bike trip, including partially populated records and records with duplicate composite identifiers (`bikeid` + `starttime`). 
Each row retains the original source attributes without additional transformations.

### Reproducibility and Source limitations

I created an initial snapshot of the filtered Raw table (raw.raw_citibike_trips_initial_snapshot) to establish a fixed baseline of the 53,108,721 records retained during ingestion.

The active Raw table serves as the input for downstream curation. The snapshot is mainly for comparison and recovery.

Since the public source is externally maintained, future ingestion runs may produce different results. The snapshot preserves the initial Raw population.

Creation date: Nov 15, 2026, 10:21:33 PM UTC-6

### Raw objects
1. seis-732-508001.raw.raw_citibike_trips
2. seis-732-508001.raw.raw_citibike_trips_initial_snapshot

# 2. Build Curated at the intended grain

My curation rules will primarily focus on supporting my analytical question: **How does trip volume vary across dates and times?** With this in mind, the curation process needs to accomplish three key objectives:

1. **Ensure each trip is counted once** to avoid inflating trip volumes.
2. **Ensure trips are assigned to the correct date and time** for accurate temporal analysis.
3. **Preserve analytical integrity** by avoiding unnecessary exclusions based on missing values in less relevant fields, such as gender.

To address the first objective, I will investigate the 12 potentially duplicated trips identified during initial profiling and determine an appropriate deduplication rule.

I will also perform additional validation checks to identify potential data-quality issues, including:

- Comparing the reported `tripduration` against the elapsed time calculated from `starttime` and `stoptime`.
- Identifying unusually short or long trips that may indicate recording errors.
- Checking for chronological inconsistencies, such as `stoptime` occurring before `starttime`.

These investigations will inform my final curation rules, with the goal of preserving as many valid trip records as possible while ensuring reliable trip-volume analysis.

### 1. Investigating potential duplicate trips

First, I investigated whether there were any patterns among the potentially duplicated trips to determine whether records should be excluded individually or resolved through a consistent curation rule.

Of the 24 records (12 duplicate pairs), 11 pairs had different reported trip durations, with most differences ranging from a few seconds to a few minutes. One pair also had different end stations, which appeared to be a few blocks apart. Since there is no reliable way to determine which record is more accurate, I decided to apply a consistent tie-breaking rule rather than manually selecting records.

For records sharing the same bikeid and starttime, I will retain the record with the latest stoptime. If those values are identical, I will select the record with the longest tripduration. If a tie remains, I will use a deterministic hash of the complete row as the final tie-breaker.

This rule ensures that each composite trip identifier appears only once in Curated, which prevents potential double-counting in trip-volume analysis. However, selecting the latest stop time or longest duration does not necessarily mean the retained record is more accurate; these are deterministic resolution criteria rather than evidence of correctness.

Given the small number of affected records relative to the overall dataset, I consider this a reasonable approach.

[Curation SQL: 03_curate.sql](../sql/03_curate.sql)

### 2. Validating timestamps

Next, I investigated the timestamp columns to ensure that trips have plausible durations and to identify any chronological inconsistencies.

My initial profiling of the **53,108,721 Raw records** revealed:

| Validation Result | Record Count |
|---|---:|
| Missing `starttime` or `stoptime` | 0 |
| `stoptime` earlier than `starttime` | 119 |
| `stoptime` equal to `starttime` | 0 |
| `stoptime` later than `starttime` | 53,108,602 |

I also compared the reported `tripduration` against the elapsed time calculated from `starttime` and `stoptime`.

| Validation Result | Record Count |
|---|---:|
| Difference within 1 second | 51,429,907 |
| Difference greater than 1 second | 1,678,814 |
| Difference greater than 60 seconds | 799 |
| Largest observed discrepancy | 3,652 seconds (~61 minutes) |

Most records had relatively small discrepancies. However, further profiling revealed that many of the larger discrepancies clustered around March and November, which made me realize that daylight saving time transitions may explain some of these inconsistencies.

For example, the recorded start and stop times reflect local New York time, while the reported trip duration represent actual elapsed time. This could also explain some of the 119 records where `stoptime` appears earlier than `starttime`. However, without further verification, I cannot conclusively attribute these discrepancies to daylight saving time.

Additional profiling revealed:

| Metric | Result |
|---|---:|
| Minimum duration | 60 seconds |
| Maximum duration | 19,510,049 seconds (~226 days) |
| Average duration | 962.5 seconds (~16 minutes) |
| Median duration | 627 seconds (~10.5 minutes) |
| 95th percentile | 2,027 seconds (~34 minutes) |
| 99th percentile | 3,700 seconds (~62 minutes) |
| Nonpositive durations | 0 |
| Trips exceeding 24 hours | 11,513 |

While the maximum duration of approximately 226 days is unusual, an exceptionally long recorded trip does not necessarily indicate that the trip never occurred. It could reflect a bicycle that was not properly returned or another operational issue.

The minimum duration of 60 seconds is also consistent with Citi Bike's documented practice of excluding trips shorter than 60 seconds.

Since my primary analytical question focuses on **trip volume by date and time**, rather than trip duration, I decided to retain records with duration or chronological inconsistencies instead of automatically excluding them.

I will implement three data-quality flags in Curated:

- `duration_review_flag`: Reported and calculated durations differ by more than 60 seconds.
- `chronology_review_flag`: `stoptime` is earlier than `starttime`.
- `long_duration_review_flag`: Reported `tripduration` exceeds 24 hours.

These thresholds are intended to identify records for further review, not to establish that they are invalid. This approach preserves trip counts while making potentially problematic observations identifiable for future investigation.

[Curation SQL: 03_curate.sql](../sql/03_curate.sql)

## Curated objects

1. seis-732-508001.curated_trips_intermediate
2. seis-732-508001.curated_citibike_trips

**Note:** This is a modification from my P1 plan, where I originally intended to create the fact and dimension tables in Curated. I have decided to build the dimensional model in Serving.

## Curated row grain

One curated row represents one distinct Citibike trip observation, identified by warehouse-generated trip_id.

## Curation rules

I created the rules below based on my p2 profiling and subsequent investigations. They are intended to support my primary analytical question: **How does Citi Bike trip volume vary across dates and times?**

| Area | Observed Evidence | Curation Rule | Justification |
|---|---|---|---|
| **Grain and identifiers** | 12 duplicate pairs were identified using `bikeid` and `starttime`. | Define one Curated row as one distinct trip observation. Generate a deterministic `trip_id` from `bikeid` and `starttime`. | Provides a consistent trip identifier and prevents double-counting in trip-volume analysis. |
| **Duplicate records** | Of the 12 pairs, 11 had different durations, and one also had a different end station. | Retain the record with the latest `stoptime`, then longest `tripduration`, then highest deterministic full-row hash if needed. | Resolves repeated identifiers consistently without assuming the selected record is necessarily more accurate. |
| **Timestamp types** | `starttime` and `stoptime` are already stored as `DATETIME`, with varying fractional-second precision. | Preserve both fields and their existing data types. | BigQuery already supports the observed precision, so conversion or standardization is unnecessary. |
| **Missing timestamps** | No NULL values were identified in `starttime` or `stoptime` across 53,108,721 Raw records. | No missing-timestamp replacement or exclusion rule is required. | All Raw records have the timestamps needed for temporal analysis. |
| **Duration discrepancies** | 799 Raw records had differences greater than 60 seconds between reported and calculated duration. Some discrepancies may be related to daylight saving time. | Calculate the elapsed duration and flag differences greater than 60 seconds using `duration_review_flag`. | Identifies potentially inconsistent records without assuming every discrepancy is an error. |
| **Chronological inconsistencies** | 119 Raw records had `stoptime` earlier than `starttime`. Some discrepancies may be related to daylight saving time. | Flag these records using `chronology_review_flag`. | Identifies implausible timestamp sequences for review. |
| **Unusually long trips** | 11,513 Raw records had durations exceeding 24 hours; the maximum was approximately 226 days. | Flag trips exceeding 86,400 seconds using `long_duration_review_flag`. | Identifies unusually long rentals that may reflect operational or recording issues. |
| **Missing nonessential attributes** | Fields such as `gender` and `customer_plan` are not required to answer the primary question. | Preserve these attributes, including missing values, without using them as exclusion criteria. | Avoids unnecessarily reducing trip counts based on attributes unrelated to date/time analysis. |
| **Final Curated eligibility** | Some deduplicated records fail one or more duration or chronology checks. | Preserve all deduplicated records and their flags in the intermediate table. Exclude records with any of the three flags from the final Curated table. | Establishes a consistent quality-filtered analytical population while retaining excluded observations for review. |
| **Relationships and joins** | Curation is performed using a single Raw trip table. | No joins are performed in Curated. Fact and dimension relationships will be implemented in Serving. | Preserves the intended grain and avoids introducing row multiplication during curation. |

[Curation SQL: 03_curate.sql](../sql/03_curate.sql)

## Curated row count

53,096,704

## Curation vs. Raw

The difference in row counts between Raw and final Curated results from removing 12 duplicate records and excluding trips flagged for duration or chronological inconsistencies, while retaining those flagged records in the intermediate Curated table for further review.

## Field trace from P1

Field from p1: `starttime`

| Layer | Field / Rule | Purpose |
|---|---|---|
| **Source** | `citibike_trips.starttime` | Original trip start timestamp |
| **Raw** | `raw_citibike_trips.starttime` | Preserved without transformation |
| **Curated Intermediate** | `starttime` (DATETIME) | Preserved and used with `bikeid` for deduplication |
| **Final Curated** | `starttime` (DATETIME) | Retained for records passing quality checks |
| **Serving (planned)** | Date and time dimension keys derived from `starttime` | Supports grouping trips by date and hour |
| **Audience Output (planned)** | `COUNT(*) AS trip_volume` | Measures trip volume across dates and hours |

**Observed evidence:** All 53,108,721 Raw records contained a non-NULL `starttime`. The field was already stored as `DATETIME`, so no type conversion was necessary. The combination of `bikeid` and `starttime` identified 12 duplicate pairs, which are resolved during curation.

**Curation rule:** Preserve `starttime` in its original `DATETIME` type and use it as part of the composite identifier for deduplication. Records with duration or chronological inconsistencies are flagged in the intermediate Curated table, with flagged records excluded from the final Curated table. Date and hour attributes will be derived from `starttime` in Serving rather than Curated.

**Planned audience output:** A dashboard showing trip volume by date, along with an hourly ridership distribution to identify peak usage periods. These outputs will be built using the dimensional model in Serving, with trip volume calculated from records passing the Curated quality checks.

