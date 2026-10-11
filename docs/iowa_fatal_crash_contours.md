# Reproducing the Iowa fatal crash contour map

How `output/iowa_fatal_crash_contours.png` is made, how it maps onto the map it copies, and how to check a rebuild.

The model is Nicola Rennie's
[forest-of-bowland.R](https://github.com/nrennie/data-viz-projects/blob/main/forest-of-bowland/forest-of-bowland.R):
a contour map of the hills of the Forest of Bowland in Lancashire.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_contours.R")   # under a minute; needs internet for Natural Earth and the font
```

It writes `output/iowa_fatal_crash_contours.png` (3507 x 3165 px, 297 x 268 mm at 300 dpi) and a 500 px thumbnail.

## How the original maps onto this data

The original draws a surface that already exists: the height of the land, downloaded as a grid. Crashes are
points, so the surface has to be made first. That is the one real change; the drawing is the same.

| Original | Here |
|---|---|
| Surface: elevation in metres, from `elevatr` | Surface: fatal crashes per 1,000 km², a kernel density estimate of the crash positions |
| Filled contours, then contour lines on top (`tidyterra`) | The same, with `ggplot2::geom_contour_filled()` and `geom_contour()` |
| Lines every 50 m | Lines at 10, 15, 20, 30, 40, 60, 80, 120, 160, 240, 320 |
| Palette "Morgenstern" from `MetBrewer` | The same seven colours, typed in |
| A rectangle of land | Iowa; everything outside is painted over in the box colour |
| Title, "Maximum Elevation: 560m", palette swatches, all inside the pale box | Title, "Highest point: Des Moines, 308 ...", swatches, in the same places |
| No place names | Eight cities named, so the peaks can be read |
| Upright A4 | 297 mm wide, 268 mm tall, because Iowa is wider than tall |
| Font: Commissioner | The same |

`elevatr`, `tidyterra`, `ggnewscale` and `MetBrewer` are not installed and none was needed. `KernSmooth`, which
makes the surface, ships with R.

## Making the surface

1. **Positions.** The vehicle-level extract (`data/iowa_fatal_crashes_2026-10-09.csv`) has one row per vehicle;
   `distinct()` reduces it to 3,586 crashes. Five are recorded at `POINT(0 0)`, which means the position is
   unknown, and are dropped; 3,581 are used. Of those, 38 fall up to 2.4 km outside the outline, which is a
   simplified one: they are crashes on border roads and bridges. The script keeps anything within 3 km of the
   outline. Leaving them out was tried first and lowered Sioux City from 143 to 99.
2. **Projection.** Longitude and latitude are turned into UTM zone 15N and divided by 1,000, so distances are in
   kilometres.
3. **Kernel density.** `KernSmooth::bkde2D()` replaces every crash by a small round hill with a standard deviation
   of 12 km and adds the hills up on a grid of 2 km cells. The result is multiplied by the number of crashes and
   by 1,000, so it reads as fatal crashes per 1,000 km² over the whole period.
4. **Edge correction.** Near the border part of each hill falls outside Iowa, and the data has no crashes there to
   fill it back in, so the edge would look emptier than it is. The script smooths Iowa itself the same way, which
   gives for each cell the share of its neighbourhood that is Iowa (1.00 in Des Moines, 0.58 in Davenport), and
   divides by it. The share is floored at 0.25; that touches three cells, in the south-east tip.

### Why 12 km

It is a choice, not a result. With 3,581 crashes over 145,000 km², a 12 km hill covers about 44 crashes in an
average spot, enough for the rural ups and downs to be more than single crashes. A smaller value turns the map
into dots; a larger one merges Cedar Rapids and Iowa City. The number in the subtitle depends on it: the top of
Des Moines is 308 at 12 km and would be higher with a narrower hill. Change `bandwidth` at the top of the script
to see.

### Why the contour steps are not equal

The original has a line every 50 m. Equal steps of 10 were tried first: 90% of Iowa is below 40 and the top is
over 300, so thirty lines crowded round the cities and the rest of the state was one colour. Each step is now
about 1.4 times the one before, and the lines are listed on the map.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crashes_2026-10-09.csv` (dataset 17 extract) | position and year of each fatal crash | Yes |
| Natural Earth 1:10m US counties | the outline of Iowa (the 99 counties merged) | No, downloaded on each run |
| Font (Commissioner) | text | No |
| R packages | | `renv.lock` |

The extract is described in [iowa_fatal_crashes.md](iowa_fatal_crashes.md). This is the file with positions; it
runs from 2015 to early October 2026, so this map covers a longer period than the charts built on dataset 13.

## What the map cannot say

- **It is a map of where crashes are, which is mostly a map of where people and traffic are.** It says nothing
  about how dangerous a road or a county is. The county map
  ([iowa_fatal_crash_counties.md](iowa_fatal_crash_counties.md)) divides by residents and gives the opposite
  picture: Polk County, the summit here, has one of the lowest rates in the state.
- **Border cities are estimates.** In Davenport, Council Bluffs, Sioux City and Dubuque about 40% of the
  neighbourhood is another state or a river, and the height there is "crashes per 1,000 km² of Iowa nearby".
- **2026 is a part year** (196 crashes so far) and 2025 was an unusually low year (246, against about 310 in
  other years). Both are in the surface.
- The outline has a small spur in the north-west corner that comes from the Natural Earth county shapes.

## Hand-set values

| Value | Where | Chosen because |
|---|---|---|
| Bandwidth 12 km, cell 2 km | parameters | see "Why 12 km" |
| Contour lines | `break_vals` | see "Why the contour steps are not equal"; the script stops if the surface rises above the last one |
| Eight cities and their positions | `cities` | the largest places; typed in, there is no city file with coordinates in the project |
| Positions of title, subtitle, note, swatches, caption | `annotate()` calls, in km from the corners of Iowa | placed by eye |

The peak's name is the typed-in city nearest to the highest cell, so it follows the data as long as the summit
stays near one of the eight.

## Checks

After a rebuild you should see:

- 3,586 crashes in the file, 3,581 used, years 2015 to 2026.
- Peak 308.4 near Des Moines; Iowa as a whole 24.6; 74% of Iowa below the state figure and 89% below 40.
- Surface at the cities: Des Moines 307, Davenport 240, Council Bluffs 151, Sioux City 143, Cedar Rapids 119,
  Waterloo 95, Dubuque 73, Iowa City 63.
- A plain count agrees with the order: fatal crashes within 15 km, per 1,000 km² of Iowa land in that circle, are
  Des Moines 434, Davenport 294, Council Bluffs 190, Sioux City 182, Cedar Rapids 153, Waterloo 126, Dubuque 90,
  Iowa City 72. The surface is lower everywhere because it spreads each crash over a wider area.
- Two runs in a row on the machine described in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo gave byte-identical
  PNGs: `shasum -a 256 output/iowa_fatal_crash_contours.png` =
  `e6f4cc7e9dbdff39cc96ef1e29d0b455a84235415c0aaf72f4ffe7230a29a916`.

The checksum will differ on another machine or after a Natural Earth or Google Fonts update. Compare the picture
and the numbers above in that case.
