# Reproducing the Iowa fatal crashes by vehicle type and weather chart

How `output/iowa_fatal_crash_vehicles.png` is made, how it differs from the chart it copies, and how to check a rebuild.

The model is Georgios Karamanis's TidyTuesday 2026 week 5 chart,
[brazilian_companies.R](https://github.com/gkaramanis/tidytuesday/blob/master/2026/2026-week_05/brazilian_companies.R):
one bar per owner qualification, filled to 100% and split by company size, with the bar thickness set by the log of
the number of companies.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_vehicles.R")   # a few seconds; needs internet for the fonts only
```

It writes `output/iowa_fatal_crash_vehicles.png` (3600 x 2400 px, 12 x 8 in at 300 dpi) and a 500 px thumbnail.

## Inputs

| Input | File | What the script takes |
|---|---|---|
| Vehicles in fatal crashes (dataset 17) | `data/iowa_fatal_crashes_2026-10-09.csv` | `vehicle_configuration`, one row per vehicle |
| Fatal crashes (dataset 13) | `data/iowa_fatal_crash_dates_2026-10-10.csv` | `weather`, one row per crash |

The two join on the crash number (`vehicle_crash_key` = `case_number`). The weather extract ends in 2025, so the
329 vehicles in 2026 crashes drop out: 5,797 vehicles in 3,390 crashes remain.

## How the original maps onto this data

| Original | Here |
|---|---|
| One bar per owner qualification | One bar per vehicle type |
| Split by company size, three groups | Split by weather, three groups |
| Counts companies | Counts crashes |
| Thickness: log10 of the number of companies | Thickness: log10 of the number of crashes |
| Ordered by the share of micro-enterprises | Ordered by the share in clear weather |
| Drops qualifications with one company | Folds types with fewer than 20 crashes into one bar |

## What the script does

1. **Weather groups**: "Clear" and "Cloudy" stay. Rain, snow, blowing snow, freezing rain, sleet, fog and severe
   winds become "Rain, snow, fog or wind". "Unknown" and "Other (explain in narrative)" are dropped (48 crashes).
2. **Unknown vehicle type** is dropped (11 vehicles). Three crashes lose their only vehicle this way, which leaves
   3,339 crashes.
3. **Crashes, not vehicles**: each crash counts once for every type of vehicle in it. See below.
4. **Small types**: the 13 types with at least 20 crashes get a bar. The other 16 types go into "All other types",
   which sits at the bottom and is not part of the ordering.
5. **Thickness**: `log10(crashes)`. Passenger cars (1,307) are about 2.3 times as thick as trucks with trailers
   (24), not 54 times.
6. **Labels**: a count is printed in every segment that is at least 3% of its bar. The share in clear weather is
   printed at the right end of each bar.

### Why crashes and not vehicles

The vehicle file has one row per vehicle, and the literal copy would count those rows. Five winter pile-ups have
44 to 96 vehicles each (the largest, in Grundy County on 4 February 2021, has 96). Counted by vehicle, 36.5% of
semi trucks are in rain, snow, fog or wind, and most of that is those five crashes. Counted by crash it is 15.4%.
A crash with a car and a semi is in both bars, so the bars add up to more than 3,339.

## Changes from the original, and why

| Original | Here | Why |
|---|---|---|
| `shadowtext` labels on every segment | `geom_text()`, white, only where the segment is wide enough | Not in `renv.lock`; small segments cannot hold a number |
| `MetBrewer` Juarez colours | Three hand-picked colours | Not in `renv.lock`; these were checked for colour-blind separation |
| Legend at the top right | Legend at the top left, in bar order | It reads in the same order as the segments |
| No share printed | Share in clear weather at the end of each bar | The order of the bars depends on it |
| DIN Condensed and Iosevka | Libre Franklin and Fira Sans | The fonts the other charts in this repo use |
| `camcorder` | `ggsave()` | Not in `renv.lock` |

## Hand-set values

| Value | Where |
|---|---|
| Which weather values count as bad, and which are dropped | `involved` |
| Minimum of 20 crashes for a type to get its own bar | `min_crashes` |
| Short names of the vehicle types | `type_names` |
| A segment needs 3% of its bar to get a label | `bars` |
| Colours | `weather_colours` |
| Title | `title`; it names motorcycles and semi trucks, so check the order after a data refresh |

Nothing is random, so there is no seed.

## Checks

After a rebuild the script prints this table:

| Type | Crashes | Clear | Cloudy | Rain, snow, fog or wind | Clear share | Bad-weather share |
|---|---|---|---|---|---|---|
| Train | 25 | 22 | 1 | 2 | 88.0% | 8.0% |
| Motorcycle | 547 | 461 | 76 | 10 | 84.3% | 1.8% |
| ATV | 91 | 75 | 9 | 7 | 82.4% | 7.7% |
| Farm tractor | 44 | 33 | 10 | 1 | 75.0% | 2.3% |
| All other types | 112 | 82 | 16 | 14 | 73.2% | 12.5% |
| SUV | 909 | 657 | 162 | 90 | 72.3% | 9.9% |
| Passenger car | 1,307 | 941 | 235 | 131 | 72.0% | 10.0% |
| Truck with trailer | 24 | 17 | 5 | 2 | 70.8% | 8.3% |
| Passenger van | 236 | 165 | 43 | 28 | 69.9% | 11.9% |
| Single-unit truck, 3+ axles | 88 | 61 | 18 | 9 | 69.3% | 10.2% |
| Single-unit truck, 2 axles | 131 | 90 | 28 | 13 | 68.7% | 9.9% |
| Pickup truck | 891 | 600 | 186 | 105 | 67.3% | 11.8% |
| Cargo van | 36 | 24 | 7 | 5 | 66.7% | 13.9% |
| Semi truck | 423 | 271 | 87 | 65 | 64.1% | 15.4% |

- All crashes, each counted once: 2,429 clear (72.7%), 603 cloudy (18.1%), 307 rain, snow, fog or wind (9.2%).
- On the same machine and package versions, `shasum -a 256 output/iowa_fatal_crash_vehicles.png` gives
  `c4a2a94d2ba6d98d2156d9b7603f0c537ca6a0f77c8286958a5bc84c6b8b592d`. Two runs in a row were byte-identical.

## Known limits

- The chart shows the weather when crashes happened, not how dangerous each weather is. Few motorcycles are on the
  road in snow, so few crash in it. There is no count of traffic by weather to turn this into a risk.
- Weather is what the officer recorded for the crash, one value per crash. "Clear" at night and "Clear" by day are
  the same value.
- Small bars are uncertain: trains rest on 25 crashes and trucks with trailers on 24, so one or two crashes move
  their share by several points.
- The gaps between most types are small. Cars, SUVs, vans and pickups all sit between 67% and 72% clear.
- The thickness is a log scale. It ranks the types by size but does not show how much larger one is.
- 2026 is not in dataset 13, so the chart stops at 2025.
