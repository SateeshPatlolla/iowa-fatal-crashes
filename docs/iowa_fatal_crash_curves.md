# Reproducing the Iowa fatal crashes time-of-day curves

How `output/iowa_fatal_crash_curves.png` is made, how it differs from the chart it copies, and how to check a rebuild.

The model is Georgios Karamanis's TidyTuesday 2025 week 37 chart,
[passport_index.R](https://github.com/gkaramanis/tidytuesday/blob/master/2025/2025-week_37/passport_index.R): one
density curve per year of the number of visa-free destinations per passport, 2006 and 2025 in colour.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_curves.R")   # a few seconds; needs internet for the fonts only
```

It writes `output/iowa_fatal_crash_curves.png` (3000 x 2400 px, 10 x 8 in at 300 dpi) and a 500 px thumbnail.

## Input

`data/iowa_fatal_crash_dates_2026-10-10.csv`, the dataset 13 extract described in
[iowa_fatal_crash_days.md](iowa_fatal_crash_days.md): 3,390 fatal crashes, 2015 to 2025. The script uses the date
and the clock time (`timestr`). Every crash has a valid time.

## How the original maps onto this data

| Original | Here |
|---|---|
| Value: visa-free destinations of a passport | Value: time of day of a crash |
| One curve per year, 20 curves | One curve per weekday, 7 curves |
| 2006 and 2025 in colour | Sunday and Tuesday in colour |
| A note at the peak of each coloured curve | The same |

### Why weekdays and not years

The literal copy would be one curve per year with 2015 and 2025 in colour. I tried it: the yearly curves lie on top
of each other. The median crash time moves between 13:36 and 15:48 with no direction, and a Kolmogorov-Smirnov test
of 2015 against 2025 gives p = 0.80, so there is no shift to show. Driver age by year is the same story (p = 0.15).

The time of day does change with the weekday (Saturdays and Sundays against Tuesdays to Thursdays: p < 0.001), so
the weekday became the group. The two coloured days are picked by the script: the largest and the smallest share
of crashes before 5 am.

## What the script does

1. **Hour**: `timestr` ("14:05") becomes decimal hours; the weekday comes from the date.
2. **Density on a circle**: the clock has no ends, but `density()` treats 0 and 24 as walls and the curve sags
   there. The script adds a copy of the data shifted by -24 hours and one by +24, estimates the density over all
   three days, keeps 0 to 24 and multiplies by 3 so the kept day adds up to 1.
3. **Same bandwidth for every curve**: 1 hour. The original uses `adjust = 0.5`, which lets each group pick its own
   bandwidth from its own spread; with a fixed value the bumps of different days are comparable.
4. **Highlight**: grey lines are drawn first, the two coloured lines on top.
5. **Notes**: each points at the highest point of its curve within a window (Sunday 0 to 6 am, Tuesday noon to
   8 pm). Peak times are given to the nearest hour.

The y-axis is the density read as "share of the day's crashes per hour": 0.06 is shown as 6%.

## Changes from the original, and why

| Original | Here | Why |
|---|---|---|
| `geom_density()` | `density()` by hand, then `geom_line()` | `geom_density()` cannot wrap around midnight |
| `gghighlight` | two `geom_line()` layers | Not in `renv.lock` |
| `ggrepel` labels | `geom_text()` at set offsets | Two labels do not need a solver, and the result has no randomness |
| Hoefler Text and SF Pro | Libre Franklin and Fira Sans | The fonts the other charts in this repo use |

## Hand-set values

| Value | Where |
|---|---|
| Bandwidth of 1 hour | `bandwidth` |
| "Before 5 am" as the measure that picks the two days | `early` |
| Peak windows, note positions and line breaks | `peak()` calls, `notes` |
| Title | `title`; it names Sunday, so check `day_hi` after a data refresh |

Nothing is random, so there is no seed.

## Checks

After a rebuild the script prints the share of crashes before 5 am by weekday:

| Weekday | Crashes | Before 5 am |
|---|---|---|
| Sunday | 500 | 28.6% |
| Saturday | 595 | 19.7% |
| Friday | 534 | 10.5% |
| Monday | 475 | 9.9% |
| Thursday | 425 | 9.2% |
| Wednesday | 436 | 8.3% |
| Tuesday | 425 | 5.9% |

- Notes: Sunday 29%, peak about 2 am; Tuesday 6%, peak about 5 pm.
- On the same machine and package versions, `shasum -a 256 output/iowa_fatal_crash_curves.png` gives
  `bbee520aa83651f57c99f924fb3e0c0e03609a1f865998a2a95a3c83dc098a46`. Two runs in a row were byte-identical.

## Known limits

- Each curve shows how one day's crashes are spread over its hours, not how many there are. Saturday has 595
  crashes and Tuesday 425, and the curves hide that; the weekday chart shows it.
- A weekday is the calendar date, so Sunday's early hours are the end of Saturday night.
- A curve rests on 425 to 595 crashes. The large features (Sunday's night peak, Tuesday's 5 pm peak) are solid; the
  small wiggles depend on the bandwidth.
- Reported times bunch on round hours, a sign that some are estimates.
- The chart counts crashes, not traffic, and 2026 is not in dataset 13.
