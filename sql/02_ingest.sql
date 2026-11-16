/*
Ingests data from the public Citibike trips dataset into a raw table in BigQuery.
Eliminates blank records at ingestion. 
Based on early profiling, a blank record can be a combination of null numeric columns and empty (non-null) string columns.
Preserves duplicate identifiers (bikeid + starttime) and partially populated records for the curated layer.
*/

-- Step 1: Create raw dataset in my BigQuery project (SUCCESS)
CREATE SCHEMA IF NOT EXISTS `seis-732-508001.raw`
  OPTIONS (
    location = 'US',
    description = 'Raw Citi Bike trip data with fully NULL records excluded during ingestion.');

-- Step 2: Create and populate raw table from Source (SUCCESS). Data types are inherited from the source schema.
CREATE OR REPLACE TABLE `seis-732-508001.raw.raw_citibike_trips`
AS
SELECT *
FROM `bigquery-public-data.new_york_citibike.citibike_trips`
WHERE
  tripduration IS NOT NULL
  OR starttime IS NOT NULL
  OR stoptime IS NOT NULL
  OR start_station_id IS NOT NULL
  OR NULLIF(TRIM(start_station_name), '') IS NOT NULL
  OR start_station_latitude IS NOT NULL
  OR start_station_longitude IS NOT NULL
  OR end_station_id IS NOT NULL
  OR NULLIF(TRIM(end_station_name), '') IS NOT NULL
  OR end_station_latitude IS NOT NULL
  OR end_station_longitude IS NOT NULL
  OR bikeid IS NOT NULL
  OR NULLIF(TRIM(usertype), '') IS NOT NULL
  OR birth_year IS NOT NULL
  OR NULLIF(TRIM(gender), '') IS NOT NULL
  OR NULLIF(TRIM(customer_plan), '') IS NOT NULL;

-- Step 3: Verify resulting row count (Result: 53,108,721)
SELECT COUNT(*) AS raw_row_count
FROM `seis-732-508001.raw.raw_citibike_trips`;