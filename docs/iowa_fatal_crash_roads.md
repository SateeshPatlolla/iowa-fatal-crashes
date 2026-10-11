# Reproducing the Iowa fatal crashes on main roads map

How `output/iowa_fatal_crash_roads.png` is made, how it maps onto the map it copies, and how to check a rebuild.

The model is Nicola Rennie's #30DayMapChallenge 2022 day 11 map,
[day_11.R](https://github.com/nrennie/30DayMapChallenge/blob/main/2022/scripts/day_11.R): London's bus stops as
red dots over the larger streets in grey.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_roads.R")   # a few seconds; needs no internet
```

It writes `output/iowa_fatal_crash_roads.png` (2400 x 1920 px, 8 x 6.4 in at 300 dpi) and a 500 px thumbnail.

It runs offline: both inputs are in `data/` and the font is R's built-in "serif".

## How the original maps onto this data

| Original | Here |
|---|---|
| Red dots: 19,000 bus stops | Red dots: 3,581 fatal crashes, 2015 to early October 2026 |
| Grey lines: OpenStreetMap streets from motorway down to tertiary, via `osmdata` | Grey lines: the Census Bureau's primary and secondary roads for Iowa |
| One line width | Two: primary roads a little heavier |
| No outline, no labels; the streets give the shape | The same |
| Title and caption in red serif, `#fafafa` background | The same, plus a two-line subtitle |
| 6 x 6 in | 8 x 6.4 in, because Iowa is wider than tall |

### Why the roads are not from OpenStreetMap

`osmdata` is not installed. The OpenStreetMap server could be asked directly, but every road in Iowa down to
"tertiary" is a download of hundreds of megabytes that changes daily. The Census Bureau's TIGER/Line file is 3 MB,
dated, in the public domain, and `sf` reads it straight from the zip. It holds two classes:

- **Primary** (`MTFCC` S1100): interstates and other divided highways. 4,543 km of centre line.
- **Secondary** (`MTFCC` S1200): the other US and state highways and the main county highways. 24,312 km.

That is a coarser net than the original's: there are no minor county roads or city streets in it. The map says
so in its subtitle and uses the gap (see below).

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crashes_2026-10-09.csv` (dataset 17 extract) | position of each fatal crash | Yes |
| `data/iowa_primary_secondary_roads_tiger2024.zip` | the roads | Yes, the file is in the repo |
| R packages | | `renv.lock` |

The roads file is `tl_2024_19_prisecroads.zip` from
`https://www2.census.gov/geo/tiger/TIGER2024/PRISECROADS/`, downloaded on 2026-10-10 and saved under a clearer
name. SHA-256: `4d5bf9b614fab5414b9de5285a279b4cb4a76d80b7db5b161673f957dcd31088`. The script downloads it again
only if the file is missing.

## What the script does

1. **Crashes.** `distinct()` reduces the vehicle rows to 3,586 crashes. Five are recorded at `POINT(0 0)`
   ("position unknown") and are dropped. All other 3,581 are drawn; there is no state outline to clip to.
2. **Roads.** Read from the zip with the `/vsizip/` prefix and projected to UTM zone 15N, like the crashes.
3. **On a main road or not.** For each crash, `st_nearest_feature()` finds the nearest road line and
   `st_distance()` measures how far it is. Within 50 m counts as "on" that road.
4. **Draw** roads, then dots, with `theme_void()`.

## The 52%

| Where the crash was | Crashes | Share |
|---|---|---|
| On a primary road | 454 | 12.7% |
| On a secondary road | 1,394 | 38.9% |
| On neither: a minor county road or a city street | 1,733 | 48.4% |

- **The 50 m is a choice, and the result barely depends on it.** The share is 50.3% at 25 m, 51.6% at 50 m, 52.6%
  at 100 m and 55.4% at 250 m. A crash is either on a drawn road or clearly somewhere else.
- A crash at a junction of a main road and a side road counts as on the main road.
- On the map the "neither" dots are easy to see: the straight red rows with no grey under them are county roads
  on the one-mile grid, and the red clusters are the cities.

## What the map cannot say

- **It is not a map of dangerous roads.** A road with many dots may simply carry much traffic. Per kilometre of
  line the primary roads have about 0.10 fatal crashes and the secondary roads 0.06 over the period, but primary
  roads carry many times the traffic, and this project has no traffic counts.
- The road file is from 2024 and the crashes start in 2015. A crash on a road that was rebuilt or reclassified
  since may land in the wrong class.
- 2026 is a part year.

## Checks

After a rebuild you should see:

- 3,586 crashes in the file, 3,581 with a position.
- 4,464 road segments; 4,543 km primary and 24,312 km secondary.
- The table above, and the four shares by distance.
- Two runs in a row on the machine described in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo gave byte-identical
  PNGs: `shasum -a 256 output/iowa_fatal_crash_roads.png` =
  `6173c9ef4b517fc46a7eab759c42cdb1b229a6eb770426985c5ff42f71a97f65`.

The checksum will differ on another machine, because "serif" is whatever serif font that machine has. Compare the
picture and the numbers in that case.
