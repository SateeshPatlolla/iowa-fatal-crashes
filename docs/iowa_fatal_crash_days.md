# Reproducing the Iowa fatal crashes by weekday chart

How `output/iowa_fatal_crash_days.png` is made, how it differs from the chart it copies, and how to check a rebuild.

The model is Georgios Karamanis's TidyTuesday 2025 week 17 chart,
[daily_accidents.R](https://github.com/gkaramanis/tidytuesday/blob/master/2025/2025-week_17/daily_accidents.R):
US road deaths per day, 1992 to 2016, one panel per weekday.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_days.R")   # a few seconds; needs internet for the fonts only
```

It writes `output/iowa_fatal_crash_days.png` (3300 x 2100 px, 11 x 7 in at 300 dpi) and a 500 px thumbnail.

## Inputs

| Input | Where it comes from | Pinned? |
|---|---|---|
| Fatal crashes with dates | `data/iowa_fatal_crash_dates_2026-10-10.csv`, extracted from [Iowa Data Hub dataset 13](https://data.iowa.gov/catalog/dataset/13) (Vehicle Crashes in Iowa, Iowa DOT) | Yes, the extract is in the repo |
| Fonts (Libre Franklin, Fira Sans) | Google Fonts, downloaded on each run | No |
| R packages | `renv.lock` | Yes |

### Why a second dataset

The fatal crashes map uses dataset 17 (drivers and vehicles). Its date columns (`crash_at` and the two next to it)
are empty in the download, so it cannot say on which day a crash happened. Dataset 13 is the crash-level table the
vehicle rows belong to, and it has `crash_on`.

The two agree: for every year from 2015 to 2025 they hold the same number of fatal crashes and deaths, every crash
in dataset 13 is in dataset 17 under the same key, and the death counts match crash by crash. Dataset 13 stops at
the end of 2025, so the 196 fatal crashes of 2026 that the map shows are not in this chart.

### The extract

- Download on 2026-10-10: a 283 MB zip of three CSV parts, SHA-256
  `d31fdcff5680a38d78cb2dab71236f4a709b815c753ad421b91e4ef81278137d`. Not kept in the repo.
- `R/iowa_fatal_crash_dates_extract.R` keeps rows with `crash_severity == "Fatal"` and 14 columns, all as text.
  Pass the path of a zip you already have as the first argument to skip the download.
- Result: 3,390 crashes, 3,740 deaths, SHA-256
  `f5c59946a0ca48259e7da8bfd52628f317b96432d6ea380844ee12182c7b5bec`. (The district and county code columns
  were added later on 2026-10-10 from an identical download; the other twelve columns did not change.)
- The chart uses three columns (key, date, deaths). Time of day, light, weather, surface, district, county, cause and the
  alcohol flag are kept for later charts.

## What the script does

1. **Calendar**: build every date from 2015-01-01 to 2025-12-31 (4,018 days) and join the deaths onto it. Days
   without a fatal crash are absent from the data and become zero.
2. **Rolling mean**: a centred 61-day mean of daily deaths (the day plus 30 either side), as in the original.
3. **Group**: sum deaths and the rolling mean by month and weekday. January 2015 and December 2025 have no complete
   window and drop out, leaving 130 months x 7 weekdays = 910 points.
4. **Axes**: x is deaths divided by the number of such weekdays in the month (four or five); y is deaths divided by
   the summed rolling mean, so 1 means "as deadly as the days around it".
5. **Colour**: for each point, the number of points in the same panel within 0.08 of it after both axes are scaled
   to 0 to 1. Crowded points are drawn last.
6. **Bar chart**: mean deaths per day by weekday over all 4,018 days, placed in the empty eighth slot of the grid.

## Changes from the original, and why

| Original | Here | Why |
|---|---|---|
| One point per day | One point per weekday within a month | The US has about 100 road deaths a day. Iowa has 0.93, and 45% of days have none. Daily points would pile up on 0, 1 and 2. |
| Log scale for the ratio | Linear scale | 38 of the 910 points are zero (a month whose Tuesdays, say, saw no deaths), and zero has no place on a log scale. Dropping them would bias the picture. They sit on top of each other at the origin. |
| `slider::slide_dbl()` | `stats::filter()` | Same centred mean; `slider` is not in `renv.lock`. |
| `lubridate::wday()` | `format(date, "%u")` | `lubridate` is not installed; `%u` also does not depend on the system language. |
| `ggpointdensity::geom_pointdensity()` | neighbour count with `dist()` | Not installed; with 130 points a panel the count is four lines. |
| `MetBrewer` Hokusai1 | the seven hex codes typed in | Not installed. |
| Fixel Display and Borel fonts | Libre Franklin and Fira Sans | The fonts the other charts in this repo use. |
| Holiday and daylight-saving flags | left out | The original computes them but does not draw them. |
| Empty eighth facet slot | bar chart of deaths per day | States the answer in one number per weekday. |

## Hand-set values

| Value | Where | Note |
|---|---|---|
| Date range | `seq()` in the calendar step | must cover whole years present in the extract |
| Neighbour radius 0.08 | `neighbours` | only changes the colouring |
| Position of the bar chart | `inset_element()` | placed by eye for an 11 x 7 in page |
| Title, and the two highlighted bars | `title`, `geom_col()` | check against the bar values after a data refresh |

Nothing is random, so there is no seed.

## Checks

After a rebuild from the 2026-10-10 extract:

- Deaths per day: Monday 0.91, Tuesday 0.79, Wednesday 0.81, Thursday 0.82, Friday 1.07, Saturday 1.14, Sunday 0.97;
  all days 0.93.
- Subtitle: Saturdays above their 61-day average in 64% of months, Tuesdays in 32%.
- On the same machine and package versions, `shasum -a 256 output/iowa_fatal_crash_days.png` gives
  `f3e7b65cd0fc593603b4ef28379d29ae29118604e5479a02c1c1fb5eadddfb17`. Two runs in a row were byte-identical.

## Known limits

- 2025 is much lower than the other years: 259 deaths against 357 in 2024, and 11 in December against 36. An earlier
  version of this note took that for missing data. It is not: Iowa DOT reports 260 road deaths for the year, the
  fewest on record (see [iowa_fatal_crash_eras.md](iowa_fatal_crash_eras.md)). The chart compares each weekday with
  the days around it, so a lower year does not distort it.
- Each weekday's ratio is measured against an average that includes that weekday, which pulls all ratios slightly
  towards 1.
- A point is four or five days, so single bad crashes move it a lot: the Monday point at 4.5x is one month.
- The date is the calendar date of the crash. A crash at 1 a.m. on Sunday counts as Sunday, although it belongs to
  Saturday night.
