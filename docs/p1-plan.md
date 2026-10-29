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

- Candidate identifier: bikeid and starttime
- Rows with missing candidate identifier
    Expected: 0 for a valid identifier
    Observed: 5,828,994
- Repeated non-null identifier groups
    Expected: 0 for a unique identifier
    Observed: 12

The initial results indicated that the candidate identifiers are not ideal, since the dataset does not include a unique trip id or another surrogate key. Looking at the columns in the table, bikeid combined with the start time of a trip (starttime), should, in theory, reflect a unique trip event, since a bike can only be occupied once at a given time. 

To move forward with the dataset, I will likely exclude rows with a null bikeid or starttime. For the 12 rows with duplicated candidate identifiers, it is possible that those indicate bugs or glitches of the recording system, so I might write a curation rule to include only one of those rows, if it looks like they do represent the same trip taken, or handle those rows individually/separately since there are so few of them compared to the total number of rows. The grain states 'one recorded' trip, so while only one trip might have taken place, multiple recordings of that trip might have taken place (erroneously, perhaps), so I believe my grain is still appropriate after reviewing these results.

One additional finding: I wanted to check whether I could label the business process as recording a "completed" trip, and to test that, I counted the number of rows with a null 'stoptime', and got 5,828,994, which is the exact same result for missing bikeid or starttime. A few either smaller-scale queries and looking at the preview tab in BigQuery seem to support my suspicion that the dataset includes about 5.8 million fully blank rows. Running a query to validate this estimates about 8 GBs billed, so I haven't run that, but if this prediction is correct, it seems reasonable to leave all blank rows in Raw. Similarly, looking at rows with a non-null starttime and a null stoptime estimates about 7.5 GB processed so I will plan to test these during the curation stage.

# 2. Define the model and predict a history consequence

Business process: Recording completed Citi Bike trips
Fact-table type: Transaction fact table
Grain: One row represents one recorded Citi Bike trip event

A transaction fact table is appropriate because each source record represents an individual recorded trip rather than a periodic summary of activity. This grain supports analysis of historical trip volume, duration, station demand, and membership patterns.

Modeling choice: As mentioned above, the source does not contain a reliable unique trip identifier, and has about 5.8 million blank rows. My plan is to assign a warehouse-generated surrogate key to each retained trip record once all the missing and duplicate records are handled. 

Secondly, I will use the trip start date and time to assign each trip to a reporting period. This allows trip volume to reflect when riders initiate trips, which is useful for identifying ridership demand patterns. With this convention, trips spanning multiple hours or dates will be counted only in the period when they began, rather than across their entire duration.

My primary question was: How does trip volume vary by month, season, year, day of week and hour of day?

Table: FACT_TRIP
Key strategy: trip_key (a warehouse-generated surrogate primary key)
Attributes: start_date_key FK , start_time_key FK
Source identifiers: bikeid, starttime

Table: DIM_DATE
Key strategy: date_key uniquely identifies a calendar date
Attributes: year, month, season, day of week

Table: DIM_TIME
Key strategy: time_key uniquely identifies a time of day
Attributes: hour, minute

The primary question will be answered by counting rows in FACT_TRIP using COUNT(*), after applying data-quality rules to retain distinct trip events. FACT_TRIP will join to DIM_DATE through start_date_key and to DIM_TIME through start_time_key. Attributes such as year, month, season, and day of week will come from DIM_DATE and hour of day will come from DIM_TIME. The results can be grouped by these attributes and filtered by selected date ranges or time periods to identify historical ridership patterns.

The date and time dimensions used for my primary question contain fixed attributes. Since these attributes do not naturally change, I do not anticipate needing Type 2 history for these dimensions.

However, I noticed that some station IDs are associated with multiple station names in the historical trip data. Since station names contain location information (e.g., '123 North Ave', rather than 'Station A'), I found inconsistencies in naming as well differences indicating possible relocation.

For my secondary question on station demand (Which stations experience the highest departure and arrival volumes, and how does demand at these stations vary between weekdays and weekends?), I plan to introduce a DIM_STATION dimension. I would use Type 1 treatment to standardize minor naming differences, such as abbreviations, and Type 2 treatment for meaningful historical changes in station names or locations. The source station_id would identify a station across versions, while a warehouse-generated station_key would uniquely identify each historical version. Effective date ranges would determine which version applied when a trip occurred.

The Date dimension would be shared across the model, with the trip start date used for departure demand and the trip end date used for arrival demand.

Reporting consequence: Station history would not affect my primary question, since trip volume by year, month, season, day of week, and hour is calculated using trip start dates and times. However, it would affect station-level reporting by preserving the historical names and locations associated with trips rather than applying the latest station information to all historical records. Similarly, I might need to apply similar modeling to longitude and latitude, if they also change over time for station IDs.

Planned P3 test: I could simulate a station name change for one station ID and create two Type 2 dimension records with different warehouse keys and effective date ranges. Using a small sample of trips before and after the change, I would verify that each trip is associated with the appropriate station version.

# 3. Plan the build and its checks

# 4. Diagnose and revise the plan