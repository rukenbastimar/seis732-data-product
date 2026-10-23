-- P1: Source Profile

-- 1. Test proposed trip fact grain
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
