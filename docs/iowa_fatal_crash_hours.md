# Reproducing the Iowa fatal crashes by date and time of day chart

How `output/iowa_fatal_crash_hours.png` is made, how it maps onto the chart it copies, and how to check a rebuild.

The model is Georgios Karamanis's TidyTuesday 2025 week 20 chart,
[vesuvius.R](https://github.com/gkaramanis/tidytuesday/blob/master/2025/2025-week_20/vesuvius.R): earthquakes under
Mount Vesuvius, 2011 to 2024.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_hours.R")   # under a minute; needs internet for Natural Earth and the fonts
```

It writes `output/iowa_fatal_crash_hours.png` (3600 x 2400 px, 12 x 8 in at 300 dpi) and a 500 px thumbnail.

## How the original maps onto this data

| Original | Here |
|---|---|
| One point per earthquake | One point per fatal crash (3,390) |
| x: date and time of the quake | x: date of the crash |
| y: depth, running downwards | y: time of day, midnight at the top running down to midnight |
| Colour: point density | The same, see "Colour" below |
| Outline of the volcano behind the points, for scale | Hours of darkness behind the points |
| Contour map with the quake positions | Iowa outline with the crash positions |
| Map of Italy with a dot | Map of the lower 48 states with Iowa filled |

The volcano has no counterpart in crash data. What it does in the original is give the depths something familiar to
be read against, and night does that for the time of day.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crash_dates_2026-10-10.csv` (dataset 13 extract) | date, clock time, alcohol or drug flag | Yes |
| `data/iowa_fatal_crashes_2026-10-09.csv` (dataset 17 extract) | position of each crash | Yes |
| Natural Earth 1:10m states | both maps | No, downloaded on each run |
| Fonts (Libre Franklin, Fira Sans) | text | No |
| R packages | | `renv.lock` |

The extracts are described in [iowa_fatal_crash_days.md](iowa_fatal_crash_days.md) and
[iowa_fatal_crashes.md](iowa_fatal_crashes.md). Neither has both the date and the position, so the script joins
them on the crash key (`case_number` = `vehicle_crash_key`). All 3,390 dated crashes find a position.

## What the script does

1. **Time of day**: `timestr` ("14:05") becomes decimal hours. Every crash has a valid time.
2. **Sun**: `sun_times()` computes sunrise and sunset on the clock for Des Moines (41.6 N, 93.6 W) for each day,
   from the equation of time and the sun's declination, with one hour added while daylight saving time is on.
   Spot checks: 21 June 05:40 and 20:53, 21 December 07:38 and 16:48, which agree with published tables to a few
   minutes.
3. **Dark**: a crash is "in the dark" if its time is before sunrise or after sunset that day.
4. **Colour**: number of crashes within a radius of each point. In the main chart both axes are scaled to 0 to 1
   and the radius is 0.035. On the map longitude is multiplied by cos(42 degrees) and the radius is 0.15 degrees.
   Crowded points are drawn last.
5. **Maps**: five crashes at (0, 0) are left off the Iowa map and kept in the main chart. The locator uses the
   Albers projection `ESRI:102003`.
6. **Assemble** with patchwork: chart on the left, the two maps in a column on the right.

## Changes from the original, and why

| Original | Here | Why |
|---|---|---|
| `ggpointdensity` | `dist()` and a count | Not in `renv.lock` |
| `MetBrewer` Johnson | the five hex codes typed in | Not installed |
| `shadowtext` notes | `geom_label()` with a see-through white fill | Not installed |
| `elevatr`, `marmap`, `terra` | not needed | There is no terrain here |
| Maps inset in the lower left of the chart | Maps in a column beside the chart | The quakes leave the lower left empty; crashes fill the whole day |
| Charter and Asap fonts | Libre Franklin and Fira Sans | The fonts the other charts in this repo use |

## Hand-set values

| Value | Where |
|---|---|
| Des Moines as the place the sun is computed for | `sun_times()` call |
| Density radii 0.035 and 0.15 | `neighbours()` calls |
| Position and wording of the three notes | `notes` |
| Title | `title`; check it against `by_hour` after a data refresh |
| Layout widths and heights | `plot_layout()` |

Nothing is random, so there is no seed.

## Checks

After a rebuild from the two extracts:

- Subtitle: 3,390 crashes; 19% between 3 pm and 6 pm; 43% in the dark; alcohol or drugs indicated in 47% of crashes
  in the dark and 27% in daylight.
- Notes: the hour from 5 pm has the most crashes (238); August 401 crashes, February 184.
- On the same machine and package versions, `shasum -a 256 output/iowa_fatal_crash_hours.png` gives
  `0bdcb5b7f71fc01d9406954d1868640739503c6ffd405ac0d0ca28fb2597fa68`. Two runs in a row were byte-identical.

## Known limits

- The chart counts crashes, not traffic. More crashes at 5 pm partly reflects more cars on the road at 5 pm; the
  data has no traffic volumes to turn counts into risk.
- One sunrise is used for the whole state. It differs by about 20 minutes between the east and west borders, and
  dusk is not dark. The officer's own `light` entry agrees with the computed band for 99% of crashes recorded as
  daylight or dark.
- "Alcohol or drugs indicated" is every value of `drug_or_alcohol` other than "None Indicated", which includes
  alcohol below the legal limit, drugs and refusals.
- Reported times bunch on round hours (02:00, 03:00), a sign that some are estimates.
- 2026 is not in dataset 13. The thinner cloud of points in late 2025 is real: it was Iowa's lowest year on record
  (see [iowa_fatal_crash_eras.md](iowa_fatal_crash_eras.md)).
