# P0 Feasibility Results

## 1. Schema Inspection

### 1.1 Trip Table Schema — `citibike_trips`

The table contains 16 columns, including trip timestamps, duration, station identifiers, bicycle identifiers, and rider classifications. The schema identifies all columns as nullable. 

| Column Name | Data Type | Nullable |
|---|---|---|
| `tripduration` | INT64 | YES |
| `starttime` | DATETIME | YES |
| `stoptime` | DATETIME | YES |
| `start_station_id` | INT64 | YES |
| `start_station_name` | STRING | YES |
| `start_station_latitude` | FLOAT64 | YES |
| `start_station_longitude` | FLOAT64 | YES |
| `end_station_id` | INT64 | YES |
| `end_station_name` | STRING | YES |
| `end_station_latitude` | FLOAT64 | YES |
| `end_station_longitude` | FLOAT64 | YES |
| `bikeid` | INT64 | YES |
| `usertype` | STRING | YES |
| `birth_year` | INT64 | YES |
| `gender` | STRING | YES |
| `customer_plan` | STRING | YES |

### 1.2 Station Table Schema — `citibike_stations`

The table contains station identifiers and attributes describing station location, capacity and availability. Station_ID is the only non-nullable field. Combined with the later uniqueness check, this supports this column's use as the primary key of the stations table.

| Column Name | Data Type | Nullable |
|---|---|---|
| `station_id` | STRING | NO |
| `name` | STRING | YES |
| `short_name` | STRING | YES |
| `latitude` | FLOAT64 | YES |
| `longitude` | FLOAT64 | YES |
| `region_id` | INT64 | YES |
| `rental_methods` | STRING | YES |
| `capacity` | INT64 | YES |
| `eightd_has_key_dispenser` | BOOL | YES |
| `num_bikes_available` | INT64 | YES |
| `num_bikes_disabled` | INT64 | YES |
| `num_docks_available` | INT64 | YES |
| `num_docks_disabled` | INT64 | YES |
| `is_installed` | BOOL | YES |
| `is_renting` | BOOL | YES |
| `is_returning` | BOOL | YES |
| `eightd_has_available_keys` | BOOL | YES |
| `last_reported` | TIMESTAMP | YES |


## 2. Date Coverage

### 2.1 Trip Date Coverage — `citibike_trips`

| Metric | Result |
|---|---|
| Earliest date | 2013-07-01 00:00:00 |
| Latest date | 2018-05-31 23:59:59.606 |

The trip data covers approximately five years, from July 2013 through May 2018.

### 2.2 Station Reporting Date Coverage — `citibike_stations`

| Metric | Result |
|---|---|
| Earliest date | 1970-01-02 00:00:00 UTC |
| Latest date | 2026-10-14 00:06:09 UTC |

The earliest reported timestamp predates Citi Bike's launch, suggesting invalid or placeholder dates.

## 3. Date Validation

### 3.1 Station Records Predating Citi Bike's Launch

| Metric | Result |
|---|---:|
| Records with suspicious timestamps | 54 |

I identified 54 station records with `last_reported` timestamps before the specified cutoff. These dates may require exclusion or further investigation before analysis.

## 4. Candidate Key Validation

### 4.1 Composite Key Check — `citibike_trips`

| Metric | Result |
|---|---:|
| Duplicate combinations returned | 12 |
| Trip count per combination | 2 |
| NULL candidate key values | Excluded |

After excluding NULL values, the query returned 12 duplicated combinations of `bikeid` and `starttime`, each appearing twice. This combination cannot currently be treated as a reliable unique trip identifier.

### 4.2 Station ID Validation — `citibike_stations`

| Metric | Result |
|---|---:|
| Total rows | 2,519 |
| Non-null station IDs | 2,519 |
| Distinct station IDs | 2,519 |

All station IDs are non-null and unique, confirming that `station_id` can serve as the primary key for the station table.