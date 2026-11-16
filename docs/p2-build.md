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

| Decision | My choice | Why it fits this source |
|---|---|---|
| Source format and header row | Native BigQuery table; no header handling required | The source is an existing table in the BigQuery Public Datasets project. Since the column names and data types are already defined, header-row settings are not applicable. |
| Declared types for composite ID | bikeid: INTEGER; starttime: DATETIME | The combination of `bikeid` and `starttime` serves as the proposed composite trip identifier. These fields are preserved from the source and duplicate combinations will be addressed during curation. |
| Empty fields and invalid records | Allow NULL values and empty-string values in partially populated records; exclude fully blank records | Missing values in certain columns (such as gender) are not consequential to the primary analysis. Partially populated records are retained for downstream quality assessment. Records with no populated fields are excluded during ingestion because they provide no usable trip information. |
| Load into BigQuery or query the source in place | Load into a native BigQuery table | A native table provides a stable version of the source data, which supports reproducible curation and analysis without repeating querying the public source. |
| Append or replace on repeated loads | CREATE OR REPLACE TABLE | Replacing the raw table prevents duplicate records from being introduced when reloading the same source table. |
| Source-to-Raw filtering | CREATE OR REPLACE TABLE ... AS SELECT with a WHERE condition | The query excludes records where all fields are NULL or blank while preserving partially populated records and duplicate composite identifiers for the curated layer. |

[IngestionSQL](sql/02_ingest.sql#L1-L39)

Source row count: 58,937,715  
Raw row count: 53,108,721  
Total rows excluded: 5,828,994

The excluded row count matches my prediction in p2.
