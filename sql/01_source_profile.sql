-- P1: Source Profile

-- Test proposed trip fact grain
-- Candidate identifier: bikeid + starttime

WITH grain_groups AS (
    SELECT
        bikeid,
        starttime,
        COUNT(*) AS rows_per_id
    FROM `bigquery-public-data.new_york_citibike.citibike_trips`
    GROUP BY bikeid, starttime
)

SELECT
    COALESCE(SUM(rows_per_id), 0) AS source_rows,

    COALESCE(
        SUM(
            IF(
                bikeid IS NULL OR starttime IS NULL,
                rows_per_id,
                0
            )
        ),
        0
    ) AS rows_with_null_id,

    COUNTIF(
        bikeid IS NOT NULL
        AND starttime IS NOT NULL
        AND rows_per_id > 1
    ) AS repeated_id_groups

FROM grain_groups;

-- Check number of null values for stoptime (to check for whether the business process includes incomplete trips)

SELECT
    COUNT(*)
FROM `bigquery-public-data.new_york_citibike.citibike_trips`
WHERE stoptime IS NULL;

-- Check whether station IDs are associated with multiple names across historical trips.

WITH station_observations AS (
    SELECT
        start_station_id AS station_id,
        start_station_name AS station_name
    FROM `bigquery-public-data.new_york_citibike.citibike_trips`

    UNION ALL

    SELECT
        end_station_id AS station_id,
        end_station_name AS station_name
    FROM `bigquery-public-data.new_york_citibike.citibike_trips`
)

SELECT
    station_id,
    COUNT(DISTINCT station_name) AS distinct_names,
    ARRAY_AGG(
        DISTINCT station_name IGNORE NULLS
        ORDER BY station_name
    ) AS observed_names
FROM station_observations
WHERE station_id IS NOT NULL
GROUP BY station_id
HAVING COUNT(DISTINCT station_name) > 1
ORDER BY distinct_names DESC, station_id;