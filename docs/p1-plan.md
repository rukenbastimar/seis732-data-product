# 1. Establish the question and check the source

NYC Citi Bike: Historical Ridership and Station Demand Analysis

## Audience and need

The audience is Citi Bikes operations planning team, who is responsible for understanding historical ridership demand. Demand may vary by station, time of day, or season, which makes it important to identify when and where bicycles are frequently used.

A data product analyzing trip patterns could help the team identify previous high-demand stations and peak usage periods. These insights could inform decisions about bicycle redistribution, station capacity, and operational planning, especially for stations that stayed the same since 2018. Since the available trip data ends in 2018, the serving objects and the final product would act as a reference rather than as a representation of current demand.

## One primary analytical question from P0

The proposed analytical product is a Tableau dashboard supporting a dimensional data warehouse developed in BigQuery. The dashboard will provide the identified stakeholders with a visual of historical ridership patterns across NYC. The dashboard will also allow the planning team to explore trip activity by station, time period and rider type to identify patterns that were in demand at the time.

The primary question: 
How does trip volume vary by month, season, year, day of week and hour of day?

## Source identifiers

- Source provider: Citi Bike New York / Google Cloud BigQuery Public Datasets
- Source project: bigquery-public-data
- Source dataset: new_york_citibike
- Source URL: [New York Citi Bike](https://console.cloud.google.com/bigquery?p=bigquery-public-data&d=new_york_citibike&page=dataset&project=seis-732-508001&ws=!1m5!1m4!3m2!1sbigquery-public-data!2snew_york_citibike!23sLEGACY_URL_PARAM)
- Primary source table: citibike_trips
- Data location: US
- Execution project: seis-732-508001

- Grain: One row represents one recorded Citi Bike trip event.
- Row count: 58,937,715
- Date range: July 1, 2013 to May 31, 2018 (based on recorded trip times).

- Candidate identifier: `bikeid` and `starttime`
- Rows with missing candidate identifier
    Expected: 0 for a valid identifier
    Observed: 5,828,994
- Repeated non-null identifier groups
    Expected: 0 for a unique identifier
    Observed: 12

The initial results indicated that the candidate identifiers are not ideal, since the dataset does not include a unique trip id or another surrogate key. Looking at the columns in the table, `bikeid` combined with the start time of a trip (`starttime`), should, in theory, reflect a unique trip event, since a bike can only be occupied once at a given time. 

To move forward with the dataset, I will likely exclude rows with a null `bikeid` or `starttime`. For the 12 rows with duplicated candidate identifiers, it is possible that those indicate bugs or glitches of the recording system, so I might write a curation rule to include only one of those rows, if it looks like they do represent the same trip taken, or handle those rows individually/separately since there are so few of them compared to the total number of rows. The grain states 'one recorded' trip, so while only one trip might have taken place, multiple recordings of that trip might have taken place (erroneously, perhaps), so I believe my grain is still appropriate after reviewing these results.

One additional finding: I wanted to check whether I could label the business process as recording a "completed" trip, and to test that, I counted the number of rows with a null 'stoptime', and got 5,828,994, which is the exact same result for missing `bikeid` or `starttime`. A few either smaller-scale queries and looking at the preview tab in BigQuery seem to support my suspicion that the dataset includes about 5.8 million fully blank rows. Running a query to validate this estimates about 8 GBs billed, so I haven't run that, but if this prediction is correct, it seems reasonable to leave all blank rows in Raw. Similarly, looking at rows with a non-null `starttime` and a null stoptime estimates about 7.5 GB processed so I will plan to test these during the curation stage.

# 2. Define the model and predict a history consequence

Business process: Recording completed Citi Bike trips
Fact-table type: Transaction fact table
Grain: One row represents one recorded Citi Bike trip event

A transaction fact table is appropriate because each source record represents an individual recorded trip rather than a periodic summary of activity. This grain supports analysis of historical trip volume, duration, station demand, and membership patterns.

Modeling choice: As mentioned above, the source does not contain a reliable unique trip identifier, and has about 5.8 million blank rows. My plan is to assign a warehouse-generated surrogate key to each retained trip record once all the missing and duplicate records are handled. 

Secondly, I will use the trip start date and time to assign each trip to a reporting period. This allows trip volume to reflect when riders initiate trips, which is useful for identifying ridership demand patterns. With this convention, trips spanning multiple hours or dates will be counted only in the period when they began, rather than across their entire duration.

My primary question was: How does trip volume vary by month, season, year, day of week and hour of day?

Table: **FACT_TRIP**
Key strategy: trip_key (a warehouse-generated surrogate primary key)
Attributes: start_date_key FK , start_time_key FK
Source identifiers: `bikeid`, `starttime`

Table: **DIM_DATE**
Key strategy: `date_key` uniquely identifies a calendar date
Attributes: `year`, `month`, `season`, `day_of_week`

Table: **DIM_TIME**
Key strategy: `time_key` uniquely identifies a time of day
Attributes: `hour`, `minute`

The primary question will be answered by counting rows in FACT_TRIP using COUNT(*), after applying data-quality rules to retain distinct trip events. FACT_TRIP will join to DIM_DATE through start_date_key and to DIM_TIME through start_time_key. Attributes such as year, month, season, and day of week will come from DIM_DATE and hour of day will come from DIM_TIME. The results can be grouped by these attributes and filtered by selected date ranges or time periods to identify historical ridership patterns.

The date and time dimensions used for my primary question contain fixed attributes. Since these attributes do not naturally change, I do not anticipate needing Type 2 history for these dimensions.

However, I noticed that some station IDs are associated with multiple station names in the historical trip data. Since station names contain location information (e.g., '123 North Ave', rather than 'Station A'), I found inconsistencies in naming as well differences indicating possible relocation.

For my secondary question on station demand (Which stations experience the highest departure and arrival volumes, and how does demand at these stations vary between weekdays and weekends?), I plan to introduce a DIM_STATION dimension. I would use Type 1 treatment to standardize minor naming differences, such as abbreviations, and Type 2 treatment for meaningful historical changes in station names or locations. The source station_id would identify a station across versions, while a warehouse-generated station_key would uniquely identify each historical version. Effective date ranges would determine which version applied when a trip occurred.

The Date dimension would be shared across the model, with the trip start date used for departure demand and the trip end date used for arrival demand.

Reporting consequence: Station history would not affect my primary question, since trip volume by year, month, season, day of week, and hour is calculated using trip start dates and times. However, it would affect station-level reporting by preserving the historical names and locations associated with trips rather than applying the latest station information to all historical records. Similarly, I might need to apply similar modeling to longitude and latitude, if they also change over time for station IDs.

Planned P3 test: I could simulate a station name change for one station ID and create two Type 2 dimension records with different warehouse keys and effective date ranges. Using a small sample of trips before and after the change, I would verify that each trip is associated with the appropriate station version.

# 3. Plan the build and its checks

## Planned Objects

| Layer | Planned Object | Purpose |
|---|---|---|
| Raw | `raw_citibike_trips` | Preserve the original trip records and source fields from the public BigQuery dataset without altering their values. Exclude blank rows.
| Curated | `curated_trips` | Apply data-quality rules, investigate potentially duplicated trips, and prepare eligible trip records for analysis. |
| Curated | `dim_date` | Provide calendar attributes derived from trip start dates, including year, month, season, and day of week. |
| Curated | `dim_time` | Provide time attributes derived from trip start times, including hour of day. |
| Curated | `fact_trip` | Store one row per retained trip event with a warehouse-generated `trip_key` and foreign keys to the Date and Time dimensions. |
| Serving | `serving_monthly_ridership` | Aggregate trip counts by year and month to analyze monthly and annual ridership trends. |
| Serving | `serving_seasonal_ridership` | Aggregate trip counts by year and season to compare seasonal ridership patterns. |
| Serving | `serving_daily_hourly_ridership` | Aggregate trip counts by calendar date and hour, supporting day-of-week, weekday/weekend, and hourly comparisons, including average daily demand. |

## Preliminary Run Order

1. Raw: Create raw_citibike_trips from the public BigQuery source.
2. Curated: Apply data-quality and trip-selection rules to create curated_trips.
3. Dimensions: Populate dim_date and dim_time using valid trip start timestamps.
4. Fact: Build fact_trip with generated surrogate keys and dimension foreign keys.
5. Validation: Check fact grain, row counts, and date/time relationships.
6. Serving: Create serving_ridership_trends with aggregated trip counts.
7. Visualization: Connect the Serving object to Tableau (or another visualization tool).

## Field Trace: citibike_trips.starttime

1. Raw - raw_citibike_trips: the original `starttime` values are preserved without modification.
2. Curated — curated_trips: `starttime` is validation and trip eligibility and duplicate-handling rules are applied.
3. Curated — dim_date: year, month, season, and day of week are derived from the date portion of `starttime`.
4. Curated — dim_time: hour of day is derived from the time portion of `starttime`.
5. Curated — fact_trip: each retained trip is assigned a warehouse-generated `trip_key` and foreign keys are assigned to the corresponding Date and Time dimension records.
6. Serving: trip volume is calculated using COUNT(*) and aggregated by the relevant Date and Time attributes in serving_monthly_ridership, serving_seasonal_ridership, and serving_daily_hourly_ridership.
7. Audience output: historical ridership trends are displayed in a visualization tool, allowing the Citi Bike operations planning team to compare trip volume by year, month, season, day of week, and hour.

## Project-Specific Risks and Planned Checks

**Risk 1: Missing or repeated trip identifiers (grain)**

The source does not have a unique trip ID. My P1 grain test identified 5,828,994 rows with a missing `bikeid` or `starttime`, and 12 repeated `(`bikeid`, `starttime`)` groups. I plan to exclude records missing either identifier field and investigate repeated combinations before retaining trips.

- **Planned check:** Verify that `curated_trips` contains no null `bikeid` or `starttime` values and no unintended repeated `(`bikeid`, `starttime`)` combinations. Reconcile retained trip counts between `curated_trips` and `fact_trip`.
- **Expected result:** All retained trips have complete identifiers, no unintended duplicates remain, and each retained trip corresponds to exactly one fact row.
- **Where:** BigQuery, after building `curated_trips` and `fact_trip` in P2/P3.

**Risk 2: Incorrect date/time aggregation (primary result)**

Incorrect date/time transformations or dimension joins could misrepresent ridership trends across different time periods.

- **Planned check:** Compare trip counts grouped directly from eligible trip start timestamps against counts produced by the Date and Time dimensions and Serving tables.
- **Expected result:** Counts match for equivalent periods, with no missing dimension relationships or unintended duplication.
- **Where:** BigQuery, after building `fact_trip` and the Serving tables in P2/P3.

## Access and Data Governance

The `starttime` field comes from the public BigQuery Citi Bike dataset and is low-risk for this project, so restricted access is not needed. The intended users of the final dashboard are the Citi Bike operations planning team and a designated data or analytics team member serving as the proposed data steward.

The original `starttime` field will not appear in the final dashboard at the individual trip level. Its derived attributes will be displayed alongside aggregated trip counts.

## Remaining Limitation and Next P2 Step

The largest remaining limitation is the historical coverage of the dataset, which ends in May 2018 and includes incomplete years at both ends of the reporting period. This limits the dashboard's usefulness for current operational planning and requires careful interpretation of annual and seasonal comparisons.

My first P2 build step will be to creat the `raw_citibike_trips` table to preserve the original source records before applying the planned selection and data-quality rules in `curated_trips`.

# 4. Diagnose and revise the plan

## Peer Feedback and Change Memo

During the M07 peer review, my partner and I discussed the intended audience for my data product. She brought up the possibility of urban transportation planners as an alternative audience rather than Citi Bike's operations planning team. This made me reconsider whether my proposed questions would be useful beyond Citi Bike's internal operations.

I decided to retain the operations planning team as my primary audience because my questions focus on identifying historical ridership patterns that could inform bicycle distribution and demand planning. I didn't expand the scope to urban transportation planning because that would likely require additional geographic analysis and potentially other data sources.

I also refined my Serving layer to include separate monthly, seasonal, and daily/hourly ridership summaries. The main uncertainty that remains is how to handle repeated trip identifiers during curation.

## AI Use

I used AI to help me identify gaps in my P1 plans and decisions by running them through it, and questioning its response. If it agreed with me, I asked it follow-up questions to poke it further and identify areas that I might have been overlooking. I also used it to create markdown style tables and review SQL syntax. Some of the SQL clauses were outside of my comfort zone so I had AI complete the query. 


