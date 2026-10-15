# 1. Working title
NYC Citi Bike: Historical Ridership and Station Demand Analysis

# 2. Audience and need

The audience is Citi Bikes operations planning team, which is responsible for understanding ridership demand and planning bicycle distribution across stations. Demand may vary by station, time of day and season which makes it important to identify when and where bicycles are frequently used.

A data product analyzing trip patterns could help the team identify high-demand stations and peak usage periods. These insights could inform decisions about bicycle redistribution, station capacity and operational planning. Since the available trip data ends in 2018 I would use the findings as a reference rather than as a representation of current demand.

# 3. Proposed analytical product and questions

The proposed analytical product is a Tableau dashboard supporting a dimensional data warehouse developed in BigQuery. The dashboard will provide the identified stakeholders with a visual of ridership patterns across NYC. The dashboard will also allow the planning team to explore trip activity by station, time period and rider type to identify patterns in demand.

The dashboard will aim to address the analytical questions:

Question 1. Ridership trends: How does trip volume vary by month, season, year, day of week and hour of day?

Question 2. Station demand: Which stations experience the highest departure and arrival volumes, and how does demand at these stations vary between weekdays and weekends?

Question 3. Trip duration: How do average trip duration differ by membership type, time of day and weekday versus weekend usage?

Question 4. Membership patterns: How do trip volume and usage patterns differ between subscribers and short-term customers and how has the proportion of trips taken by each group changed over time?

# 4. Source identification and access

- Source provider: Citi Bike New York / Google Cloud BigQuery Public Datasets
- Source project: bigquery-public-data
- Source dataset: new_york_citibike
- Source URL: [New York Citi Bike](https://console.cloud.google.com/bigquery?p=bigquery-public-data&d=new_york_citibike&page=dataset&project=seis-732-508001&ws=!1m5!1m4!3m2!1sbigquery-public-data!2snew_york_citibike!23sLEGACY_URL_PARAM)
- Primary source table: citibike_trips
- Supporting table: citibike_stations
- Data location: US
- Execution project: seis-732-508001

The NYC Citi Bike Trips dataset is publicly available through Google BigQuery. 

I confirmed that the dataset is currently accessible through my Google Cloud environment and that I am able to run SQL queries against the source tables from my execution project.

I did not find any visible restrictions on data use, attribution or redistribution in the BigQuery dataset information.

# 5. Quick source profile

## Grain

### citibike_trips
One row represents one recorded Citi Bike trip. The table does not contain an explicit trip ID, and I did not yet establish a reliable unique identifier.

### citibike_stations
 One row represents the latest recorded status of one Citi Bike station. Station information is updated in place so historical station status is not retained.

 ## Current row count (verified through schema)

 ### citibike_trips
 58,937,715
 ### citibike_stations
 2519

 ## Relevant date/time coverage

 ### citibike_trips
 Trip start times range from July 1, 2013 to May 31, 2018.

 ### citibike_stations
The last_reported timestamps range from January 2, 1970 to October 14, 2026.

## Possible IDs or keys

### citibike_trips
The table does not contain an explicit trip ID. The combination of bikeid and starttime was evaluated as a candidate key, but a full-table query identified 12 duplicated combinations, even after excluding null values. A preliminary sampling also revealed missing key values. Therefore, no reliable unique trip identifier has been established. If the duplicated combinations represent repeated records of the same trips, deduplication could make this combination a viable composite key. However further investigation would be needed to confirm its uniqueness.

### citibike_stations
The station_id field uniquely identifies each station. All 2,519 records have a non-null distinct station ID, which confirms that station_id is a valid key for the table.

## Important null, duplicate, type, or semi-structured characteristics

### citibike_trips
All 15 fields are nullable according to the schema. I identified missing values in bikeid and/or starttime, as well as duplicated combinations of these fields.

### citibike_stations
 The station_id field contains no null or duplicate values. However, 54 records have last_reported timestamps predating Citi Bike's launch, so they appear to be invalid or placeholder dates.

## Known refresh behavior

### citibike_trips
Appears to be a historical dataset. Last modified on September 10, 2018.

### citibike_stations
Last modified on October 13, 2026. This table is updated daily, but the station attributes appear to be overwritten, so the table does not retain historical changes.

## Sensitivity, aggregation, or interpretation concerns

### citibike_trips
Missing and potentially duplicated trip records could affect aggregate trip counts. Since data ends in 2018, I would limit my conclusions to historical patterns. 

### citibike_stations
Although it is possible to join the two tables using the station IDs, I would not be able to use current station capacity or availability to interpret historical trip activity.

## Fields likely to support the proposed questions

For time-based questions, I identified starttime as the primary field, so that ridership trends can be analyzed by year, month, season, day of week, time of day, and weekday vs. weekend.

The start_station_id and end_station_id fields in the trips table would be used to identify high-demand stations by comparing arrival and departure volumes per the aggregated time.

The tripduration column would be used to calculate average trip lengths across different time periods and membership groups, and usertype would allow me to compare similar patterns such as trips taken by subscribers and customers.

The station_id column in the stations table could be used to identify the address of each station, but since station attributes gets overwritten into the same row with each update, I would have to avoid using station capacity or availability to interpret historical ridership patterns.

# 6. Need-to-source fit

| Proposed Question | Needed Fields or Concepts | Candidate Source Object(s) | Why the Source Appears Sufficient | Gap or Assumption to Test in P1 |
|---|---|---|---|---|
| **Q1 — Ridership Trends:** How does trip volume vary by month, season, year, day of week, and hour of day? | `starttime`; trip count; year, month, season, day of week, and hour derived from `starttime` | `citibike_trips` | Each row represents one recorded trip, and `starttime` can be used to derive the date/time components needed to analyze ridership patterns. | I will investigate missing timestamps and potential duplicate records that could affect trip counts. I will also account for incomplete calendar years (2013 and 2018). |
| **Q2 — Station Demand:** Which stations experience the highest departure and arrival volumes, and how does demand at these stations vary between weekdays and weekends? | `start_station_id`, `end_station_id`, `starttime`; trip count | `citibike_trips` | Start and end station IDs identify trip origins and destinations, while `starttime` allows weekday and weekend comparisons. Trip counts can be aggregated by station to identify high-demand locations. | I will check for missing station IDs and whether station identifiers remain consistent over time. |
| **Q3 — Trip Duration:** How does average trip duration differ by membership type, time of day, and weekday versus weekend usage? | `tripduration`, `usertype`, `starttime`; average trip duration | `citibike_trips` | The table contains trip duration in seconds, membership classification, and trip start times, allowing average durations to be calculated and compared across rider groups and time periods. | I will check for missing, zero, negative, or unusually long trip durations that could distort averages, and verify that membership classifications are consistent. |
| **Q4 — Membership Patterns:** How do trip volume and usage patterns differ between annual subscribers and short-term customers, and how has each group's share of total trips changed over time? | `usertype`, `starttime`; trip count; percentage of trips by membership type | `citibike_trips` | The `usertype` field distinguishes annual subscribers from short-term customers, while `starttime` allows trip volumes and membership shares to be compared across time periods. | I will check for missing or inconsistent membership classifications and whether their definitions remained consistent over time. Since `usertype` classifies trips rather than unique riders, membership shares will represent percentages of trips, not percentages of individual Citi Bike users. |

# 7. Feasibility risks and response

## Risk 1

Evidence: My preliminary profiling identified missing values in the trip data, and a full-table query found 12 duplicated combinations of bikeid and starttime. The table also lacks an explicit trip ID.

In P1, I will investigate whether these combinations represent true duplicate trips and determine how missing or duplicated records should be handled to avoid inaccurate trip counts.

## Risk 2

Evidence: The citibike_trips table contains records from July 2013 through May 2018 and appears to be no longer updated. The citibike_stations table is updated regularly, but historical station attributes appear to be overwritten.

I will limit the dashboard to historical ridership analysis and avoid comparing current station attributes with historical trips.

## Risk 3

Evidence: The trips table contains approximately 58 million records, meaning that the processing costs might be something to be cautious about.

I will monitor estimated query processing costs, select only necessary columns, and use sampling or bounded queries for exploratory analysis. I may also create aggregated tables to reduce repeated scans. 

## Fallback

If further profiling in P1 reveals that missing or potentially duplicated trip records substantially affect the reliability of the proposed analyses, I will narrow the dashboard to a validated subset of the historical trip data. I could restrict the analysis to complete calendar years and records meeting established data quality criteria to preserve the core analytical questions.

# 8. First P1 decision

My first priority in P1 will be to determine whether duplicated candidate keys represent repeated trip records or distinct trips. Based on these findings, I will establish appropriate deduplication and missing-value handling rules while preserving a clearly defined trip-level fact grain.

# 9. AI/tool accountability

I used ChatGPT to brainstorm potential analytical questions and evaluate the suitability of the Citi Bike dataset. I also asked it to clarify some of the concepts included and to review my written responses. Lastly, when I was close to being done, I asked it to format each file nicely using markdown syntax for a consistent design between all deliverables.



