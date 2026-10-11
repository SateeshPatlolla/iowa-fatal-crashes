# Reproducing the Iowa fatal crash hexagon map

How `output/iowa_fatal_crash_hexes.png` is made, how it maps onto the map it copies, and how to check a rebuild.

The model is Nicola Rennie's #30DayMapChallenge 2022 day 21 map,
[day_21.R](https://github.com/nrennie/30DayMapChallenge/blob/main/2022/scripts/day_21.R): Germany drawn as a
honeycomb of small hexagons coloured by population, under the single word "Deutschland".

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_hexes.R")   # under a minute; needs internet for Natural Earth and the font
```

It writes `output/iowa_fatal_crash_hexes.png` (2400 x 1860 px, 8 x 6.2 in at 300 dpi) and a 500 px thumbnail.

## How the original maps onto this data

The original script is short because its data arrives finished: the Kontur dataset is a file of hexagons with the
population already in each. Here both halves are made: the hexagons, and the count inside them.

| Original | Here |
|---|---|
| Hexagons 400 m across, downloaded | Hexagons 10 km across, made with `sf::st_make_grid(square = FALSE)` |
| Value: people living in the hexagon | Value: fatal crashes in the hexagon, 2015 to early October 2026 |
| Only hexagons with people in them exist | Every hexagon that touches Iowa is drawn; 34% have no crash |
| `scico` palette "lajolla", pale to dark | Nine colours along the same palette, typed in |
| `trans = "pseudo_log"` on fill and outline | The same |
| Title "Deutschland" in MedievalSharp; no legend, no caption | Title "Iowa" in the same font; a two-line caption |
| 6 x 6 in | 8 x 6.2 in, because Iowa is wider than tall |

`scico` and `R.utils` are not installed. The palette's colours were read from the published table of the colour
map (Fabio Crameri's "lajolla") and nine of them, evenly spaced, are in the script.

### Why 10 km

The original's hexagons are 400 m across because there are 83 million people to put in them. There are 3,581
fatal crashes. At 10 km a hexagon covers 86.6 km² and holds two crashes on average, so the map fills in and the
roads show as chains of darker cells. At 5 km most cells would be empty; at 20 km the roads disappear into
blocks. It is one number at the top of the script (`hex_width`).

### Why pseudo-log

Counts run from 0 to 86 and half the hexagons have 0 or 1. On a straight scale almost everything would be the
palest colour. A log scale would spread them out but cannot take zero. `pseudo_log` behaves like a straight line
near zero and like a logarithm further out, so it does both. The original uses it for the same reason.

### Why a caption

The original has no legend and no words besides the title; a reader is expected to recognise a population map.
A map of crash counts cannot be recognised that way, so two lines under the map say what a hexagon is and what
the palest and darkest colours stand for.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crashes_2026-10-09.csv` (dataset 17 extract) | position of each fatal crash | Yes |
| Natural Earth 1:10m US counties | the outline of Iowa, used only to choose the hexagons | No, downloaded on each run |
| Font (MedievalSharp) | the title | No |
| R packages | | `renv.lock` |

The caption is in R's default sans-serif font, as nothing is set for it.

## What the script does

1. **Crashes.** `distinct()` reduces the vehicle rows to 3,586 crashes; five at `POINT(0 0)` are dropped.
2. **Honeycomb.** `st_make_grid()` lays hexagons over Iowa's bounding box in UTM zone 15N. The 1,789 that touch
   Iowa are kept whole.
3. **Count.** `st_join(crashes, hexes, join = st_within)` gives each crash the number of its hexagon, and
   `count()` adds them up. Hexagons without a crash are set to 0.
4. **Draw** with fill and outline in the same colour, so there are no seams.

## What the map cannot say

- **It counts crashes, not risk.** The dark cells are the cities and the busy roads, as on the contour map
  ([iowa_fatal_crash_contours.md](iowa_fatal_crash_contours.md)), which shows the same crashes smoothed.
- **Border hexagons are partly outside Iowa** and look paler than they would if they were all land in the state.
  The contour map corrects for that; this one does not.
- **The picture depends on where the grid happens to sit.** Shift the honeycomb by 5 km and a cluster that is one
  dark cell here becomes two medium ones. The count of 86 for the darkest cell is a property of this grid, not of
  Des Moines.
- 2026 is a part year.

## Checks

After a rebuild you should see:

- 3,581 crashes with a position, all 3,581 counted into a hexagon.
- 1,789 hexagons of 86.6 km².
- Hexagons by count: 609 with none, 500 with one, 261 with two, 300 with three to five, 85 with six to ten, 19
  with 11 to 20, 12 with 21 to 50, three with more.
- The ten highest counts: 86, 83, 54, 50, 48, 38, 35, 32, 27, 26.
- The script stops if the darkest hexagon is no longer within 15 km of the State Capitol, because the caption
  names Des Moines.
- Two runs in a row on the machine described in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo gave byte-identical
  PNGs: `shasum -a 256 output/iowa_fatal_crash_hexes.png` =
  `7642df41106afc40bf7acc65e5b540729aaa3a8f465143122d57d4b43d9f9ac8`.

The checksum will differ on another machine or after a Natural Earth or Google Fonts update. Compare the picture
and the numbers above in that case.
