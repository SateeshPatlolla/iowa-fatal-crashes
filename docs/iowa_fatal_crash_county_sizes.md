# Reproducing the Iowa road death rate by county size chart

How `output/iowa_fatal_crash_county_sizes.png` is made, how it maps onto the chart it copies, and how to check a
rebuild.

The model is Nicola Rennie's #30DayChartChallenge 2024 day 6 chart,
[day_06.R](https://github.com/nrennie/30DayChartChallenge/blob/main/2024/scripts/day_06.R): teachers' salaries in
OECD countries by level of schooling, drawn as "rainclouds".

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_county_sizes.R")   # a few seconds; needs internet for the fonts
```

It writes `output/iowa_fatal_crash_county_sizes.png` (1500 x 2100 px, 5 x 7 in at 300 dpi, the size of the
original) and a 500 px thumbnail.

## How the original maps onto this data

| Original | Here |
|---|---|
| A dot per country | A dot per county (99) |
| Value: teachers' salary in dollars | Value: road deaths per 100,000 residents a year, 2015 to 2024 |
| Four rows: level of schooling, lowest at the bottom | Four rows: county size, smallest at the bottom |
| `ggdist::geom_slab()`: density curve above the line | `density()` and `geom_ribbon()` |
| `ggdist::stat_dotsinterval()`: dots below, median and intervals on the line | bins and stacks computed with `dplyr`, drawn with `geom_point()` and `geom_segment()` |
| Palette: first four of CARTO "Bold" | The same four colours, typed in |
| Grid lines and their labels drawn by hand inside the panel | The same |
| No names | The highest county of each group is named |
| Fonts Roboto and Roboto Slab, `grey95` background | The same |

`ggdist`, `rcartocolor`, `camcorder` and `nrBrand` are not installed. None was needed.

## Reading a raincloud

Each row shows the same counties three times:

- **Dots** (the rain): one per county. Counties are put into bins one rate unit wide and stacked downwards, so a
  dot sits at the middle of its bin, up to 0.5 away from its true value. Fremont (49.1) is drawn at 49.5.
- **Curve** (the cloud): a density estimate of the same values, bandwidth 2. All four curves share one height
  scale, so a taller curve means the group is more tightly packed.
- **Line**: the black dot is the median county; the thick line runs from the 17th to the 83rd percentile (the
  middle 66%) and the thin line from the 2.5th to the 97.5th (the middle 95%). These are `ggdist`'s defaults.
  They describe the spread of the counties in the group. They are not confidence intervals.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crash_dates_2026-10-10.csv` (dataset 13 extract) | year, county and deaths of each fatal crash | Yes |
| `data/iowa_county_population_2015_2024.csv` | residents per county and year | Yes |
| Fonts (Roboto, Roboto Slab) | text | No |
| R packages | | `renv.lock` |

The rate is the one on the county map; its definition is in
[iowa_fatal_crash_counties.md](iowa_fatal_crash_counties.md). No map files are needed here.

## The size classes are a choice

Counties are grouped by their 2024 residents at 10,000, 20,000 and 50,000. Those are round numbers, the first
and last match the arrows on the districts chart, and they give 26, 41, 21 and 11 counties. Other cuts would move
a few dots between rows. The trend does not depend on them: across all 99 counties the rank correlation between
rate and residents is -0.58.

## What the chart cannot say

- **It is not a risk for residents**, for the reason given on the county map: deaths are counted where the crash
  happened and divided by the people who live there. A small county with an interstate carries traffic that is not
  its own.
- **Part of the wider spread among small counties is chance.** With 6,000 residents, ten years give 15 to 30
  deaths, and a handful more or fewer moves the rate a lot. Large counties cannot scatter that way. So "small
  counties differ more" is true of the numbers, but not all of it is a real difference between places.
- **The median county is not the group's rate.** The 26 smallest counties taken together had 21.2, their median
  county 19.6. For the 11 largest it is 7.4 and 6.9.
- The top row has 11 dots. Its curve and intervals are the roughest.

## Checks

After a rebuild you should see:

| Group | Counties | Median | Middle 66% | Middle 95% | Group as a whole | Highest |
|---|---|---|---|---|---|---|
| Under 10,000 | 26 | 19.6 | 14.0 to 28.4 | 10.6 to 44.2 | 21.2 | Fremont 49.1 |
| 10,000 to 20,000 | 41 | 14.3 | 11.5 to 18.5 | 9.2 to 29.4 | 15.6 | Cass 30.5 |
| 20,000 to 50,000 | 21 | 11.7 | 10.5 to 16.0 | 8.0 to 21.0 | 12.9 | Benton 23.0 |
| 50,000 or more | 11 | 6.9 | 6.0 to 9.7 | 4.8 to 11.8 | 7.4 | Pottawattamie 12.2 |

- The tallest stack of dots is six.
- Two runs in a row on the machine described in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo gave byte-identical
  PNGs: `shasum -a 256 output/iowa_fatal_crash_county_sizes.png` =
  `0aa7ec9cb798b2758c0d3bb77be1519febe8d835126a71b6bb57610cea1118c5`.

The checksum will differ on another machine or after a Google Fonts update. Compare the picture and the table in
that case.
