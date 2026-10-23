# 1. Establish the question and check the source

NYC Citi Bike: Historical Ridership and Station Demand Analysis

## Audience and need

The audience is Citi Bikes operations planning team, which is responsible for understanding ridership demand and planning bicycle distribution across stations. Demand may vary by station, time of day and season which makes it important to identify when and where bicycles are frequently used.

A data product analyzing trip patterns could help the team identify high-demand stations and peak usage periods. These insights could inform decisions about bicycle redistribution, station capacity and operational planning. Since the available trip data ends in 2018 I would use the findings as a reference rather than as a representation of current demand.

## One primary analytical question from P0

The proposed analytical product is a Tableau dashboard supporting a dimensional data warehouse developed in BigQuery. The dashboard will provide the identified stakeholders with a visual of ridership patterns across NYC. The dashboard will also allow the planning team to explore trip activity by station, time period and rider type to identify patterns in demand.

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

The results indicate that the candidate identifiers are not ideal, but since the dataset does not include a unique trip id or another surrogate key, I think that bikeid combined with the start of a trip, should, in theory, reflect a unique trip event, since a bike can only be occupied once at a given time. 

To move forward with the dataset, I will likely exclude rows with a null bikeid or starttime, but I might need to perform more quality checks on those rows to see if there would be a different way to identify them as unique trips taken. For the 12 rows with duplicated candidate identifiers, it is possible that those indicate bugs or glitches, so I might write a curation rule to include only one of those rows, if it looks like they do represent the same trip taken. The grain states 'one recorded' trip, so while only one trip might have taken place, multiple recordings of that trip might have taken place (erroneously, perhaps), so I believe my grain is still appropriate after reviewing these results.

# 2. Define the model and predict a history consequence

# 3. Plan the build and its checks

# 4. Diagnose and revise the plan