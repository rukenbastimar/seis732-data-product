
-- P0: Source Feasibility
-- Dataset: bigquery-public-data.new_york_citibike


-- 1. SCHEMA INSPECTION

-- 1.1 Inspect the schema of citibike_trips
SELECT
    column_name,
    data_type,
    is_nullable
FROM `bigquery-public-data.new_york_citibike.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'citibike_trips'
ORDER BY ordinal_position;


-- 1.2 Inspect the schema of citibike_stations
SELECT
    column_name,
    data_type,
    is_nullable
FROM `bigquery-public-data.new_york_citibike.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'citibike_stations'
ORDER BY ordinal_position;


-- 2. DATE COVERAGE

-- 2.1 Trip date coverage
SELECT
    MIN(starttime) AS earliest_date,
    MAX(starttime) AS latest_date
FROM `bigquery-public-data.new_york_citibike.citibike_trips`;

-- 2.2 Station reporting date coverage
SELECT
    MIN(last_reported) AS earliest_date,
    MAX(last_reported) AS latest_date
FROM `bigquery-public-data.new_york_citibike.citibike_stations`;


-- 3. DATE VALIDATION

-- 3.1 Count station records with timestamps predating Citi Bike's launch
SELECT
    COUNT(*) AS invalid_date_count
FROM `bigquery-public-data.new_york_citibike.citibike_stations`
WHERE last_reported <= '2013-07-01';


-- 4. CANDIDATE KEY VALIDATION

-- 4.1 Check for duplicate bike ID and start time combinations
-- Exclude records with NULL candidate key values
SELECT
    bikeid,
    starttime,
    COUNT(*) AS trip_count
FROM `bigquery-public-data.new_york_citibike.citibike_trips`
WHERE bikeid IS NOT NULL
    AND starttime IS NOT NULL
GROUP BY bikeid, starttime
HAVING COUNT(*) > 1;

-- 4.2 Check uniqueness and completeness of station IDs
SELECT
    COUNT(*) AS total_rows,
    COUNT(station_id) AS non_null_ids,
    COUNT(DISTINCT station_id) AS distinct_ids
FROM `bigquery-public-data.new_york_citibike.citibike_stations`;