# Reproducing the Iowa road deaths calendar

How `output/iowa_fatal_crash_calendar.png` is made, how it maps onto the chart it copies, and how to check a rebuild.

The model is Georgios Karamanis's TidyTuesday 2025 week 40 chart,
[cranes.R](https://github.com/gkaramanis/tidytuesday/blob/master/2025/2025-week_40/cranes.R): crane counts at Lake
Hornborga in Sweden, 2002 to 2024.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_calendar.R")   # under a minute; needs internet for Natural Earth and the fonts
```

It writes `output/iowa_fatal_crash_calendar.png` (5100 x 2850 px, 17 x 9.5 in at 300 dpi) and a 500 px thumbnail.

## How the original maps onto this data

| Original | Here |
|---|---|
| Rows: years 2002 to 2024 | Rows: years 2015 to 2025 |
| Columns: months | The same |
| Bar: cranes counted that day | Bar: people killed that day |
| Left block: March and April, the spring peak | Left block: July and August, the two months with the most deaths per day |
| Right block: August to October | Right block: the other ten months |
| Middle: map of the lake, locator map of Sweden, a paragraph | Middle: crash positions in Iowa, locator map of the US, a paragraph |
| Missing bar: no count that day | Missing bar: nobody died that day |

The script picks the two peak months from the data, so the left block follows the data after a refresh.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crash_dates_2026-10-10.csv` (dataset 13 extract) | date and deaths of each crash | Yes |
| `data/iowa_fatal_crashes_2026-10-09.csv` (dataset 17 extract) | position of each crash | Yes |
| Natural Earth 1:10m states | both maps | No, downloaded on each run |
| Fonts (Libre Franklin, Fira Sans) | text | No |
| R packages | | `renv.lock` |

The extracts are described in [iowa_fatal_crash_days.md](iowa_fatal_crash_days.md) and
[iowa_fatal_crashes.md](iowa_fatal_crashes.md).

## What the script does

1. **Calendar**: every date from 2015-01-01 to 2025-12-31 (4,018 days), with deaths and crashes summed per day and
   zero where there were none.
2. **Peak months**: mean deaths per day by month; the top two go to the left block.
3. **`calendar()`**: one function draws both blocks, so they share the y scale (0 to 9) and the colour scale. Only
   days with at least one death get a bar. `facet_grid(vars(year), vars(month), switch = "y")` makes the grid and
   puts the year labels on the left; the right block hides them.
4. **Worst day**: labelled inside its panel.
5. **Middle column**: a US locator, the Iowa outline with one dot per crash (peak-month crashes in red, drawn
   last), and the text in a `ggtext::geom_textbox()`, which wraps to the column width.
6. **Assemble** with patchwork at widths 2 : 2 : 10, so a month is the same width in both blocks, with one shared
   legend on top.

## Changes from the original, and why

| Original | Here | Why |
|---|---|---|
| `MetBrewer` OKeeffe2 | the seven hex codes typed in | Not in `renv.lock` |
| `marquee::geom_marquee()` for the paragraph | `ggtext::geom_textbox()` | `marquee` needs a newer R than 4.2 |
| `shadowtext` labels on the maps | none | Not installed; the maps need no labels |
| `lubridate` for year, month, day | `format()` on the date | Not installed |
| Colour scale starts at 0 with white for missing | Colour scale runs 0 to 9, bars start at 1 | A one-death bar in the palest colour was nearly invisible on the panel |
| 11 x 8.5 in | 17 x 9.5 in | Twelve month columns, not five |

## Hand-set values

| Value | Where |
|---|---|
| Date range | `seq()` in the calendar step; must cover the whole years in the extract |
| "January to March" as the winter comparison | `winter` |
| Wording of the paragraph, title and subtitle | `story`, `title`, `subtitle`; the numbers in them are computed |
| Column widths, heights of the middle column, page size | `plot_layout()`, `ggsave()` |

Nothing is random, so there is no seed.

## Checks

After a rebuild the script prints deaths per day by month:

| Month | Deaths per day | Days without a death | Deaths |
|---|---|---|---|
| January | 0.67 | 56% | 227 |
| February | 0.67 | 55% | 209 |
| March | 0.68 | 55% | 231 |
| April | 0.82 | 49% | 272 |
| May | 0.97 | 44% | 330 |
| June | 1.04 | 38% | 343 |
| July | 1.16 | 36% | 397 |
| August | 1.29 | 31% | 441 |
| September | 1.12 | 38% | 371 |
| October | 0.95 | 42% | 325 |
| November | 0.87 | 45% | 286 |
| December | 0.90 | 47% | 308 |

- Text: 3,740 deaths in 3,390 crashes; no death on 45% of days; worst day 14 August 2015 with 9 deaths in 6
  crashes; longest spell without a death 11 days (11 to 21 January 2024); longest run with at least one, 15 days
  (18 September to 2 October 2020).
- On the same machine and package versions, `shasum -a 256 output/iowa_fatal_crash_calendar.png` gives
  `0cfa60067a06b42767c13408488de165c87ffc00ad83a4144b61c2ca09e431d1`. Two runs in a row were byte-identical.

## Known limits

- The bottom row thins out towards December (11 deaths against 36 in December 2024). An earlier version of this
  chart said the data might be incomplete. It is not: 2025 was Iowa's lowest year on record (see
  [iowa_fatal_crash_eras.md](iowa_fatal_crash_eras.md)), and the subtitle now says so. August's lead does not
  depend on it.
- A gap means "no death", but days that do not exist (30 February, 31 April) are also blank.
- These are counts, not rates. There is more driving in summer, and the data has no traffic volumes.
- A death is counted on the day of the crash.
- Five crashes have no usable position and are missing from the map only. 2026 is not in dataset 13.
