# P0 Feasibility Results

## 1. Date Coverage

### 1.1 Trip Date Coverage — `citibike_trips`

| Metric | Result |
|---|---|
| Earliest date | 2013-07-01 00:00:00 |
| Latest date | 2018-05-31 23:59:59.606 |

The trip data covers approximately five years, from July 2013 through May 2018.

### 1.2 Station Reporting Date Coverage — `citibike_stations`

| Metric | Result |
|---|---|
| Earliest date | 1970-01-02 00:00:00 UTC |
| Latest date | 2026-10-14 00:06:09 UTC |

The earliest reported timestamp predates Citi Bike's launch, suggesting invalid or placeholder dates.

## 2. Date Validation

### 2.1 Station Records Predating Citi Bike's Launch

| Metric | Result |
|---|---:|
| Records with suspicious timestamps | 54 |

I identified 54 station records with `last_reported` timestamps before the specified cutoff. These dates may require exclusion or further investigation before analysis.

## 3. Candidate Key Validation

### 3.1 Composite Key Check — `citibike_trips`

| Metric | Result |
|---|---:|
| Duplicate combinations returned | 10 |
| Trip count per combination | 2 |
| NULL candidate key values | Excluded |

After excluding NULL values, the query returned 10 duplicated combinations of `bikeid` and `starttime`, each appearing twice. Since the query was limited to 10 results, additional duplicated combinations may exist. This combination cannot currently be treated as a reliable unique trip identifier.

### 3.2 Station ID Validation — `citibike_stations`

| Metric | Result |
|---|---:|
| Total rows | 2,519 |
| Non-null station IDs | 2,519 |
| Distinct station IDs | 2,519 |

All station IDs are non-null and unique, confirming that `station_id` can serve as the primary key for the station table.