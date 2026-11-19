/* 1. Trip deduplication */

/* profiling */

WITH duplicate_keys AS (
    SELECT bikeid, starttime
    FROM `seis-732-508001.raw.raw_citibike_trips`
    GROUP BY bikeid, starttime
    HAVING COUNT(*) > 1
)
SELECT r.*
FROM `seis-732-508001.raw.raw_citibike_trips` AS r
INNER JOIN duplicate_keys AS d
    ON r.bikeid = d.bikeid
    AND r.starttime = d.starttime
ORDER BY r.bikeid, r.starttime;

/* results showed a total of 24 records (12 pairs) that
mostly differed very slightly in duration. As a deterministic
rule, curation will retain records with the longest trip duration. */

/* curation rule (example) */

SELECT *
FROM `seis-732-508001.raw.raw_citibike_trips` AS r
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY bikeid, starttime
    ORDER BY
        stoptime DESC NULLS LAST,
        tripduration DESC NULLS LAST,
        FARM_FINGERPRINT(TO_JSON_STRING(r)) DESC
) = 1;




/* 2. Timestamp validation */

/* profiling */

SELECT
  COUNT(*) AS total_rows,
  COUNTIF(starttime IS NULL) AS missing_starttime,
  COUNTIF(stoptime IS NULL) AS missing_stoptime,
  COUNTIF(stoptime < starttime) AS stop_before_start,
  COUNTIF(stoptime = starttime) AS stop_equals_start,
  COUNTIF(stoptime > starttime) AS valid_sequence
FROM `seis-732-508001.raw.raw_citibike_trips`;

/* results showed a total of 53,108,721 rows, 0 missing starttime or stoptime,
119 record having an earlier stoptime than starttime,
0 records where stop and starttimes were equal, which left
53,108,602 with a valid sequence of events. */

/* additional profiling */

SELECT
  COUNT(*) AS total_rows,
  MIN(tripduration) AS min_duration_seconds,
  MAX(tripduration) AS max_duration_seconds,
  ROUND(AVG(tripduration), 1) AS avg_duration_seconds,
  APPROX_QUANTILES(tripduration, 100)[OFFSET(50)] AS median_seconds,
  APPROX_QUANTILES(tripduration, 100)[OFFSET(95)] AS p95_seconds,
  APPROX_QUANTILES(tripduration, 100)[OFFSET(99)] AS p99_seconds,
  COUNTIF(tripduration <= 0) AS nonpositive_duration,
  COUNTIF(tripduration > 86400) AS over_24_hours
FROM `seis-732-508001.raw.raw_citibike_trips`;

/* additional profiling revealed the following:

total rows: 53,108,721
min_duration_seconds: 60
max_duration_seconds: 19,510,049 (about 226 days)
avg_duration_seconds: 962.5
median_seconds: 627
p95_seconds: 2027
p99_seconds: 3700
nonpositive_duration: 0
over_24_hours: 11,513
*/

/* comparing dataset's tripduration to actual recorded stop and starttime */

WITH duration_check AS (
    SELECT
        tripduration,
        DATETIME_DIFF(
            stoptime,
            starttime,
            MICROSECOND
        ) / 1000000.0 AS calculated_seconds
    FROM `seis-732-508001.raw.raw_citibike_trips`
    WHERE starttime IS NOT NULL
        AND stoptime IS NOT NULL
        AND tripduration IS NOT NULL
)
SELECT
    COUNT(*) AS compared_rows,
    COUNTIF(ABS(tripduration - calculated_seconds) <= 1)
        AS within_1_second,
    COUNTIF(ABS(tripduration - calculated_seconds) > 1)
        AS mismatch_over_1_second,
    COUNTIF(ABS(tripduration - calculated_seconds) > 60)
        AS mismatch_over_60_seconds,
    MAX(ABS(tripduration - calculated_seconds))
        AS largest_difference_seconds
FROM duration_check;

/* results:

compared_rows: 53,108,721
within_1_second: 51,429,907
mismatch_over_1_second: 1,678,814
mismatch_over_60_seconds: 799
largest_difference_seconds: 3652.0

These findings suggest some inconsistencies between
the reported duration and the recorded timestamps. 
Since most discrepancies are relatively small, 
I will investigate the records exceeding 60 seconds
before determining whether they require exclusion 
or additional curation. */

/* local nyc time vs UTC */

/* The difference observed above helped me realize that
the reported trip durations might be using UTC, as opposed to local time,
which would explain why some records have a positive tripduration value
but a negative calculation of stoptime - starttime.

To confirm this, I ran the following query to invetigate records where
the observed discrepancy was around 3600 seconds (1 hour) since that's
the expected difference due to timezone conversion. */

WITH duration_check AS (
    SELECT
        DATE(starttime) AS trip_date,
        tripduration,
        DATETIME_DIFF(
            stoptime,
            starttime,
            SECOND
        ) AS calculated_seconds
    FROM `seis-732-508001.raw.raw_citibike_trips`
)
SELECT
    trip_date,
    COUNT(*) AS affected_trips,
    COUNTIF(tripduration - calculated_seconds > 0)
        AS reported_duration_longer,
    COUNTIF(tripduration - calculated_seconds < 0)
        AS reported_duration_shorter
FROM duration_check
WHERE ABS(
    ABS(tripduration - calculated_seconds) - 3600
) <= 60
GROUP BY trip_date
ORDER BY affected_trips DESC, trip_date;

/* The results showed that many of these records clustered
around March and November, which is in line with my suspicion that
daylight saving time transitions may explain some of the inconsistencies.

Since the discrepancies do not necessarily indicate invalid trips, 
I will retain these records in Curated and flag those with a duration
difference greater than 60 seconds for further review. Records where 
stoptime precedes starttime will also be flagged. */

/* full curation SQL */

CREATE SCHEMA IF NOT EXISTS `seis-732-508001.curated`;

-- STEP 1: Intermediate Curated table
-- Deduplicate trips and apply data-quality flags

CREATE OR REPLACE TABLE `seis-732-508001.curated.citibike_trips_intermediate`
AS
WITH
  deduplicated AS (
    SELECT *
    FROM `seis-732-508001.raw.raw_citibike_trips` AS r
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY bikeid, starttime
          ORDER BY
            stoptime DESC,
            tripduration DESC,
            FARM_FINGERPRINT(TO_JSON_STRING(r)) DESC
        )
      = 1
  ),
  validated AS (
    SELECT
      *,
      DATETIME_DIFF(
        stoptime,
        starttime,
        MICROSECOND)
        / 1000000.0 AS calculated_duration_seconds
    FROM deduplicated
  )
SELECT
  -- Stable trip identifier
  TO_HEX(SHA256(TO_JSON_STRING(STRUCT(bikeid, starttime)))) AS trip_id,

  -- Original source attributes
  tripduration,
  starttime,
  stoptime,
  start_station_id,
  start_station_name,
  start_station_latitude,
  start_station_longitude,
  end_station_id,
  end_station_name,
  end_station_latitude,
  end_station_longitude,
  bikeid,
  usertype,
  birth_year,
  gender,
  customer_plan,

  -- Duration validation
  calculated_duration_seconds,
  ROUND(
    tripduration - calculated_duration_seconds, 2)
    AS duration_difference_seconds,

  -- Data-quality flags
  ABS(
    tripduration - calculated_duration_seconds)
    > 60 AS duration_review_flag,
  stoptime < starttime AS chronology_review_flag,
  tripduration > 86400 AS long_duration_review_flag
FROM validated;

-- STEP 2: Final Curated table
-- Retain only trips passing all quality checks

CREATE OR REPLACE TABLE `seis-732-508001.curated.curated_citibike_trips`
AS
SELECT *
FROM `seis-732-508001.curated.citibike_trips_intermediate`
WHERE
  NOT duration_review_flag
  AND NOT chronology_review_flag
  AND NOT long_duration_review_flag;
