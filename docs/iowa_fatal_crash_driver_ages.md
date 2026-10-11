# Reproducing the Iowa driver age ridgeline chart

How `output/iowa_fatal_crash_driver_ages.png` is made, how it maps onto the chart it copies, and how to check a
rebuild.

The model is Nicola Rennie's #30DayChartChallenge 2022 day 24 chart,
[day_24.R](https://github.com/nrennie/30DayChartChallenge/blob/main/2022/scripts/day_24.R): average annual working
hours across countries, one density curve per decade since 1870, in the style of the Financial Times.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_driver_ages.R")   # a few seconds; needs internet for the font
```

It writes `output/iowa_fatal_crash_driver_ages.png` (2400 x 3000 px, 8 x 10 in at 300 dpi) and a 500 px thumbnail.

## How the original maps onto this data

| Original | Here |
|---|---|
| Value: annual working hours of a country | Value: age of a driver in a fatal crash |
| One ridge per decade, newest at the bottom | One ridge per vehicle type, youngest median at the top |
| "Avg: 2,950 hrs" on each ridge | "Median: 35" on each ridge |
| `ggridges::geom_density_ridges()` | `density()` plus `geom_ribbon()` and `geom_line()`, stacked by hand |
| Black bar at the top left, added with `cowplot` | The same bar, drawn with `grid` on the PNG device |
| Colours `#fff1e5`, `#fea9a3`, `#990f3d`; font Roboto | The same |

`ggridges`, `cowplot` and `usefunc` are not installed. None was needed.

### Why vehicle type and not year

The obvious port is a ridge per year. It was looked at first and is flat: the median driver age is between 41 and
46 in every year from 2015 to 2026, with no direction. The original works because the curves move from ridge to
ridge, so the grouping here is the one where they do.

### Why the median and not the average

Ages in most groups are lopsided: many young drivers and a long tail to 90. The average of the passenger car
drivers is 41, but half of them are 35 or younger. The median describes "a typical driver" better.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crashes_2026-10-09.csv` (dataset 17 extract) | vehicle type and driver age, one row per vehicle | Yes |
| Font (Roboto) | text | No |
| R packages | | `renv.lock` |

The extract is described in [iowa_fatal_crashes.md](iowa_fatal_crashes.md). It runs from 2015 to early October
2026.

## What the script does

1. **Group** the 30 vehicle types of the source into nine. Seven are single types; "Single-unit truck" merges the
   2-axle and 3-axle types and "Farm machinery" merges "Farm tractor" and "Farm equipment". The other 21 types
   (234 vehicles, among them cargo vans, buses and trains) are left out because each has too few drivers for a
   curve.
2. **Drop unknown ages.** 290 of the remaining vehicles have no usable age: the field is blank on 127 vehicles,
   all in 2015, and the rest carry 200, the source's code for "not known". 5,602 drivers remain.
3. **Order** the groups by median age, then by average age where the medians tie.
4. **Density** per group with `density()`, the same bandwidth of 4 years for all, from age 0 to 100.
5. **Stack**: each curve is lifted to its row and drawn from the top row down, so every ridge overlaps the one
   above it. A density of 0.024 is one row high.
6. **Save** by printing the plot to a `png()` device and drawing the black bar on top.

## What the chart cannot say

- **It is not a risk by age.** It shows who was driving when a fatal crash happened, not how likely a driver of
  that age is to have one. Young people drive more passenger cars and fewer semi-trailer trucks to begin with.
- **Every driver involved is counted**, whether they died, were hurt or walked away, and whether or not they
  caused the crash. The file has no fault or injury field per driver.
- **The two small groups are rough.** ATV (96 drivers) and farm machinery (64) have bumpy curves, and the bumps
  are mostly chance. A bootstrap 95% interval for the median is 34 to 53 for ATVs and 49 to 63 for farm machinery,
  against 33 to 37 for passenger cars. That farm drivers are older than car drivers holds; the exact 58.5 does not
  deserve its decimal.
- **Eight drivers are recorded as 8 to 13 years old.** They are kept: most are on ATVs, where that is plausible.
- 2015 is thinner than the other years because of the blank ages.

## Hand-set values

| Value | Where | Chosen because |
|---|---|---|
| The nine groups | `case_when()` | each has at least 64 drivers with a known age; the next, cargo vans, has 46 |
| Bandwidth 4 years | `bandwidth` | smooth enough for 64 drivers, narrow enough to keep the peak of young car drivers |
| Ridge height 42 | `ridge_height` | the tallest curve reaches a little over one row |
| Title | `title` | written by hand; it names the top and bottom ridge, so check it if the order changes |

The subtitle's numbers are computed from the data.

## Checks

After a rebuild you should see:

- 6,126 vehicles in the file; 234 in other vehicle types; 290 without an age; 5,602 used.
- Medians, top to bottom: passenger car 35 (1,500 drivers), SUV 42 (1,124), single-unit truck 42 (260), ATV 44
  (96), pickup 45 (983), motorcycle 47 (607), minivan 47 (251), semi-trailer truck 48 (717), farm machinery 58.5
  (64).
- Under 25: passenger car 29%, ATV 27%, motorcycle 13%, semi-trailer truck 7%. 65 or over: farm machinery 33%,
  motorcycle 12%.
- Two runs in a row on the machine described in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo gave byte-identical
  PNGs: `shasum -a 256 output/iowa_fatal_crash_driver_ages.png` =
  `ed46c51afa0018d1db4e30a1e805b3964147f2e57860ee8d5a025e6db4a1b995`.

The checksum will differ on another machine or after a Google Fonts update. Compare the picture and the numbers
above in that case.
