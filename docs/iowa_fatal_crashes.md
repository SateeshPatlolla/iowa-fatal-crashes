# Reproducing the Iowa fatal crashes map

How `output/iowa_fatal_crashes.png` is made, what it depends on, and how to check that a rebuild matches.
The general notes on the environment, Natural Earth and fonts in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo apply
here too; this file covers what is different.

## Rebuild

From the project root:

```r
renv::restore()
source("R/iowa_fatal_crashes.R")   # about one minute; needs internet for Natural Earth and the fonts
```

It writes `output/iowa_fatal_crashes.png` (4800 x 4440 px, 16 x 14.8 in at 300 dpi) and a 500 px thumbnail.
This reads the extract in `data/`. You do not need the 717 MB download unless you want to refresh the data.

## Inputs

| Input | File | Pinned? |
|---|---|---|
| Fatal crash extract | `data/iowa_fatal_crashes_2026-10-09.csv` (0.9 MB), built by `R/iowa_fatal_crashes_extract.R` | Yes |
| Primary and secondary roads | `data/iowa_primary_secondary_roads_tiger2024.zip` (US Census Bureau TIGER/Line 2024; see [iowa_fatal_crash_roads.md](iowa_fatal_crash_roads.md)) | Yes |
| State outlines; fonts | Natural Earth 1:10m and Google Fonts, downloaded on each run | No |
| R packages | `renv.lock` (same packages as the other Iowa maps) | Yes |

### Where the extract comes from

[Iowa Data Hub dataset 17](https://data.iowa.gov/catalog/dataset/17), "Drivers and Vehicles Involved in Iowa
Crashes" (Iowa DOT, licence CC BY, updated weekly). It has one row per vehicle in every reported crash since 2015.

| | Full download, 2026-10-09 | Extract in the repo |
|---|---|---|
| Rows | 1,091,367 vehicles in 633,553 crashes | 6,126 vehicles in 3,586 fatal crashes |
| Columns | 52 | 12 |
| Size | 717 MB zip holding five CSV parts | 0.9 MB CSV |
| SHA-256 | `b52a17af5d2f8b86fa1b3379c00e4dc1c6d9dcaa5e1a5c83de75861aebafca63` | `95e9ee7e736cfb06bb52c6003abf935af43bd1b21d0f1f2ca9a3c3d40c5365fa` |

The extract script keeps rows with `crash_severity == "Fatal"` and these columns, unchanged and read as text:
`vehicle_crash_key`, `vehicle_unit_key`, `crash_year`, `crash_severity`, `fatalities`, `major_cause`,
`drug_or_alcohol_related`, `driver_age`, `driver_contributing_circumstances`, `vehicle_configuration`,
`speed_limit`, `crash_location`. Rows are sorted by crash and vehicle key.

To refresh:

```sh
Rscript R/iowa_fatal_crashes_extract.R                      # downloads the zip (717 MB) to a temp folder
Rscript R/iowa_fatal_crashes_extract.R path/to/rows.zip     # or reuse a zip you already have
```

Then change the date in `out_file` (extract script) and `csv_file` (map script), and update the numbers below.
The download URL is the one behind the site's "Download as CSV" button and is not documented, so it may change:
`https://data.iowa.gov/api/dataset-download?path=datasets%2F17%2Frows.csv`

## What the map script does, step by step

1. **Read** the extract.
2. **Group the cause.** `major_cause` has 61 values among fatal crashes. They are folded into five groups by
   pattern matching:

   | Group | `major_cause` values matched | Crashes |
   |---|---|---|
   | Ran off the road or lost control | "Ran off road - right / left / straight", "Lost Control" | 1,249 |
   | Failed to stop or yield | "Ran Stop Sign", "Ran Traffic Signal", every "FTYROW: ..." (failed to yield right of way), "Failed to yield to emergency vehicle" | 679 |
   | Speeding or reckless driving | "Exceeded authorized speed", "Driving too fast for conditions", "Operating vehicle in an reckless ... manner", "Aggressive driving/road rage" | 642 |
   | Wrong side or wrong lane | "Crossed centerline", "Crossed median", "Traveling wrong way ...", "Failed to keep in proper lane", every "Passing: ...", "Improper or erratic lane changing" | 345 |
   | Other or unknown | everything else, including "Unknown", "Other", following too close, animals and distraction | 671 |

3. **Parse the position** from text like `POINT(-93.6 41.6)` into longitude and latitude.
4. **Collapse to one row per crash.** Cause, deaths, position and the alcohol-or-drugs flag are identical on every
   vehicle of a crash (checked: no crash has more than one value), so the first is taken.
5. **Drop crashes that cannot be drawn.** Five have the position (0, 0). They still count in the subtitle's totals;
   3,581 crashes are drawn.
6. **Base map, loupe and layout**: the same as the city population map, except that this map draws roads where
   that one draws rivers and lakes (changed on 2026-10-10). The roads are the Census Bureau's primary and secondary
   roads for Iowa, read from the zip with `sf` and turned into longitude and latitude: primary roads (interstates
   and other divided highways) as a heavier line, secondary roads as a thin one, both under the dots. Inside the
   loupe the same roads are redrawn: they are cut at the ring with `st_intersection()`, taken apart into points
   with `st_coordinates()`, and each point is moved by the functions that move the crashes. The Des Moines loupe
   holds 472 crashes.
7. **Dots**: one per crash, coloured by cause group, drawn in random order (see below).
8. **Diamonds**: the 12 crashes with four or more deaths, labelled with deaths and year.
9. **Raincloud inset**: driver age by cause group. Only drivers whose own `driver_contributing_circumstances` is
   something other than "No improper action", "Not Reported" or "Unknown", and whose age is known: 3,455 drivers.
   Ages above 100 are the form's codes for unknown and are treated as missing (340 of the 6,126 vehicles have no
   usable age). The rain is a sample of up to 300 drivers per group.

## Reading the picture correctly

- **"Cause" is the reporting officer's judgement** on the crash form, one value per crash. It is not a court finding.
- **"Alcohol or drugs indicated"** means `drug_or_alcohol_related` is anything other than "None Indicated". That
  includes results below the legal limit, drug findings and refusals.
- **2026 is a part year.** The data runs to early October 2026 (213 deaths so far, against 259 in 2025 and
  319 to 402 in earlier years).
- **No time of day.** The `crash_at` columns are empty in the download, so nothing about hour or month can be shown.
- **Draw order.** Where dots pile up, the one on top hides the rest. Drawing a colour last would paint the cities
  in that colour, so the order is shuffled.
- **"Drivers recorded with an improper action"** is used in the inset so that the other driver in a two-car crash
  is not counted under a cause that was not theirs. It is still the officer's record, not proof of fault.

## Randomness

Three steps, all seeded with 35: the rain sample and its jitter (`set.seed(35)` before `slice_sample()`), the dot
draw order (`set.seed(35)` before `as_cause()`), and the label placement (`seed = 35`). Two runs in a row produced
byte-identical PNGs.

## Hand-set values

| Value | Where | Chosen because |
|---|---|---|
| Only fatal crashes | extract script | 633,553 crashes are too many to draw; 3,586 is readable |
| The five cause groups and their patterns | `case_when()` in the wrangling section | keeps the palette to five colours |
| Iowa bounding box for valid positions | `filter(between(lon, ...))` | removes the (0, 0) rows |
| Diamond rule: four or more deaths | `famous` | gives exactly 12 |
| Age cut-off at 100 | `mutate(age = ...)` | higher values are codes, not ages |
| Which drivers count in the inset | `age_dat` | see "Reading the picture correctly" |
| Map box, loupe position, label positions | as in the city population map | same layout |
| Title | `title` | written after looking at the numbers below |

## Checks

After a rebuild from the 2026-10-09 extract you should see:

- Subtitle: 3,586 fatal crashes, 3,953 people killed, 35% ran off the road or lost control, alcohol or drugs in
  35% of all fatal crashes and in 53% of the speeding or reckless group, 12 diamonds.
- Inset subtitle: half of the speeding drivers were 35 or younger; 24% of those who failed to yield were 65 or older.
- Deaths by year, from the extract: 2015: 321, 2016: 402, 2017: 331, 2018: 319, 2019: 337, 2020: 343, 2021: 356,
  2022: 336, 2023: 379, 2024: 357, 2025: 259, 2026: 213.
- Interstate 80 shows as a horizontal line of dots through Des Moines, now with its road drawn underneath. There
  are no rivers, lakes or river names on the map.
- On the same machine and package versions, `shasum -a 256 output/iowa_fatal_crashes.png` gives
  `b5fbb5828fa1b8a867a37fbf3a3a5c021231a132a285092ab04131a41d523adb`. On another machine compare the picture and
  the numbers above instead.
