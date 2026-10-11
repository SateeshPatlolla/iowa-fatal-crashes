# Reproducing the Iowa road deaths by period chart

How `output/iowa_fatal_crash_eras.png` is made, how it maps onto the chart it copies, and how to check a rebuild.

The model is Nicola Rennie's #30DayChartChallenge 2025 day 23 chart,
[day_23.R](https://github.com/nrennie/30DayChartChallenge/blob/main/2025/scripts/day_23.R): the share of world
income going to the richest 1%, cut into one panel per century.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_eras.R")   # a few seconds; needs internet for the fonts
```

It writes `output/iowa_fatal_crash_eras.png` (2100 x 1500 px, 7 x 5 in at 300 dpi, the size of the original) and a
500 px thumbnail.

## How the original maps onto this data

| Original | Here |
|---|---|
| A dot per year | A dot per month, 132 in all |
| Value: income share of the richest 1% | Value: road deaths in the month, adjusted for the season |
| Three panels: 1800s, 1900s, 2000s | Three panels: 2015 to 2019, 2020 to 2024, 2025 |
| Panels edge to edge, each with its own x axis (`facet_wrap(scales = "free_x")`, zero spacing) | The same |
| A loess line with a band per panel (`geom_smooth()`) | The same |
| A heading inside each panel: "A century of change" | "Five level years", "Five more of the same", "The lowest year on record" |
| The 1800s panel has dots but no line: too little data | Every panel has a line; the 2025 panel has only 12 dots |
| Colours 1, 2, 4 of `PrettyCols` "Dark" | The same three, typed in |
| Fonts Poetsen One and Nunito Sans | The same |
| | A dashed line at 1 July 2025, when the hands-free law took effect |

`PrettyCols` and `nrBrand` are not installed. Neither was needed.

In the original the three panels have the same width although the first century has a handful of points. That is
kept: 2025 gets a third of the width for one year, so it is stretched five times compared with the other two.
Read the slope of its line with that in mind.

## The seasonal adjustment

Road deaths follow the calendar: August has about twice as many as February. Plotted raw, that swing would be
most of what the eye sees, and in a one-year panel the smoothed line would simply draw the summer.

So each month is divided by an index for its calendar month:

1. For each calendar month, the average deaths over 2015 to 2024 (January 21.0, August 40.5).
2. Divide by the average of those twelve numbers. January gets 0.72, August 1.40.
3. Adjusted value = deaths in the month / index of its calendar month.

A dot at 30 is a month running at about 360 deaths a year. The index is built from 2015 to 2024 only, so 2025 is
measured against the years before it and not against itself.

| Month | Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Index | 0.72 | 0.66 | 0.74 | 0.87 | 1.05 | 1.09 | 1.27 | 1.40 | 1.20 | 1.04 | 0.93 | 1.02 |

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crash_dates_2026-10-10.csv` (dataset 13 extract) | date and deaths of each fatal crash | Yes |
| Fonts (Poetsen One, Nunito Sans) | text | No |
| R packages | | `renv.lock` |

## 2025 is complete, and an earlier note here was wrong

2025 has 259 deaths in this data against 357 in 2024, and December has 11 against 36. The docs of the earlier
charts in this project said the last months of 2025 "may be incomplete". That was a guess, and checking it for
this chart showed it was wrong. Iowa DOT reports 260 traffic deaths for 2025, the first year under 300 in a
century and the lowest on record, and names July (down 33%), September (down 48%) and December (down 72%) as the
largest falls against 2024. This data gives 259 for the year and, for those three months, 39 to 28, 39 to 23 and
36 to 11: down 28%, 41% and 69%. The year is complete to within one death.

Sources: [Iowa DOT, 12 March 2026](https://iowadot.gov/transportation-matters/2026-03-12/can-iowa-repeat-low-traffic-fatalities-2026-what-dot-doing-keep-safety-momentum-rolling);
[The Gazette](https://www.thegazette.com/news/iowa-sees-lowest-annual-traffic-death-toll-in-100-years/article_3dfab295-c3c6-5c78-866c-ddc5ad731124.html);
[KCRG, 14 March 2026](https://www.kcrg.com/2026/03/14/statistics-indicate-traffic-deaths-decline-iowa/).

What changed because of this:

- The notes in the docs for the weekday, hours, calendar, districts, counties and contour charts were corrected.
- The calendar chart's subtitle said "may be incomplete". It now says 2025 was the lowest year on record, and the
  PNG was rebuilt (new checksum in [iowa_fatal_crash_calendar.md](iowa_fatal_crash_calendar.md)).
- The rate charts still stop at 2024, for the reason that remains true: there is no county population estimate
  for 2025 yet.

## What the chart cannot say

- **It does not show that the law caused the fall.** State officials credit the hands-free law, and the second
  half of 2025 was 37% below the second half of 2024. But the first half, before the law, was already 12% below,
  and the adjusted dots sit at 23 to 26 from January on, against about 30 before. The steep part of the line is
  November and December. One year, one state and no comparison group cannot separate a law from weather, traffic
  volume or chance.
- **"Lowest on record" is Iowa DOT's statement.** This data starts in 2015 and can only say "lowest of eleven
  years".
- **The bands are loess's own.** They treat the months as independent and say how well the curve is pinned down,
  not where a future month will fall. With 12 points the 2025 band is wide, and loess curves bend most at the ends
  of a panel: the dip at the start of 2015 and of 2020 is partly that.
- **The periods are a choice.** Two blocks of five years and then 2025 on its own. 2020 to 2024 averaged 354
  deaths a year against 342 before, a difference of 3.6% that is well inside the year-to-year swings (319 to 402),
  hence "more of the same".
- These are counts, not rates per mile driven.

## Checks

After a rebuild you should see:

- Deaths per year: 321, 402, 331, 319, 337, 343, 356, 336, 379, 357, 259.
- Per period: 1,710 deaths (342 a year), 1,771 (354 a year), 259.
- Halves: January to June 138 in 2024 and 121 in 2025 (down 12%); July to December 219 and 138 (down 37%).
- Adjusted values run from 10.7 (December 2025) to 41.7.
- Two runs in a row on the machine described in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo gave byte-identical
  PNGs: `shasum -a 256 output/iowa_fatal_crash_eras.png` =
  `49e4e7ff296dff7de11f4c42f35951d2da2675e52e0ab89620aceb0888afe7f6`.

The checksum will differ on another machine or after a Google Fonts update. Compare the picture and the numbers
above in that case.
