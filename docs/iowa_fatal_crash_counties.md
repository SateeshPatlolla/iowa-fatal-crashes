# Reproducing the Iowa road death rate map by county

How `output/iowa_fatal_crash_counties.png` is made, how it maps onto the map it copies, and how to check a rebuild.

The model is Nicola Rennie's
[general-health-2021-census.R](https://github.com/nrennie/data-viz-projects/blob/main/general-health/general-health-2021-census.R):
the share of people in each local authority of England and Wales who reported bad health in the 2021 Census.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_counties.R")   # under a minute; needs internet for Natural Earth and the fonts
```

It writes `output/iowa_fatal_crash_counties.png` (2400 x 2460 px, 8 x 8.2 in at 300 dpi) and a 500 px thumbnail.

## How the original maps onto this data

| Original | Here |
|---|---|
| Areas: 331 local authorities of England and Wales | Areas: Iowa's 99 counties |
| Value: age-standardised % reporting bad or very bad health | Value: road deaths per 100,000 residents a year, 2015 to 2024 |
| Subtitle names the highest area and the average | Subtitle names the highest and lowest county and the state rate |
| Palette: CARTO "BurgYl" from `rcartocolor` | The same seven colours, typed into the script (`rcartocolor` is not installed) |
| Linear colour bar, 2% to 10% | Log colour bar, 4 to 50 |
| No labels on the map | Two labels, for the counties the subtitle names |
| Portrait, 4 x 6 in | Near-square, 8 x 8.2 in, because Iowa is wider than tall |
| No roads | Interstates and US highways drawn over the counties |
| Fonts: Roboto and Roboto Slab | The same |

### Why the colour bar is on a log scale

The rates run from 4.7 to 49.1, and 80 of the 99 counties fall between 8.5 and 24.4. On a linear bar the top half
of the colours would go to four counties and the rest of the state would look alike. On a log bar each doubling
takes the same length, so 5 to 10 is as visible as 20 to 40.

### Why "the state rate" and not "the average"

The original gives the plain average of the areas. Here that would be 15.7, well above Iowa's rate of 10.9,
because 26 small counties with high rates count as much as Polk County with half a million residents. The state
rate (all deaths over all residents) is the figure a reader would expect, so the subtitle uses that.

### The roads

The subtitle says that a small county crossed by an interstate carries its through traffic, so the map shows where
the interstates are. They come from Natural Earth's 1:10m `roads` layer, through the same
`rnaturalearth::ne_download()` call as the county outlines, so no new package was needed. (`tigris` and `osmdata`
would give every road, but neither is installed and county roads would bury the colours.)

- Kept: `level == "Interstate"` (about 1,220 km inside Iowa) and `level == "Federal"`, the US highways (about
  4,860 km). State highways are left out.
- The lines are cut at the state border with `st_intersection()`, after projecting both layers.
- Interstates are a dark line inside a wider white one, so they show on pale and on dark counties. US highways
  are thin and half-transparent so the county colour stays the main thing.
- Six labels (I-29, I-35 twice, I-80 twice, I-380) are placed by typing a longitude and latitude and moving the
  point onto the nearest spot of that road with `st_nearest_points()`.
- Natural Earth is a small-scale map: the lines are simplified and can be a kilometre or two off. They are good
  for "which counties does I-80 cross", not for placing a crash.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crash_dates_2026-10-10.csv` (dataset 13 extract) | year, county and deaths of each fatal crash | Yes |
| `data/iowa_county_population_2015_2024.csv` | residents per county and year | Yes |
| Natural Earth 1:10m US counties | county outlines | No, downloaded on each run |
| Natural Earth 1:10m roads (8.7 MB) | interstates and US highways | No, downloaded on each run |
| Fonts (Roboto, Roboto Slab) | text | No |
| R packages | | `renv.lock` |

Both data files are described in [iowa_fatal_crash_districts.md](iowa_fatal_crash_districts.md). No new data was
downloaded for this map.

## Definitions

- **Rate**: deaths in the county from 2015 to 2024, divided by the sum of its ten yearly population estimates,
  times 100,000. It reads as deaths per 100,000 residents per year.
- **Deaths** are counted in the county where the crash happened, whoever died.
- **2025 is left out**: there is no county population estimate for it yet.
- **Seven crashes (seven deaths) have no county** and are not on the map. The state rate is the sum over the 99
  counties: 3,474 deaths.
- The map is drawn in UTM zone 15N (EPSG:26915).

## What the map cannot say

- **It is not a risk for residents.** The divisor is the people who live in a county, not the people who drive
  through it. Fremont County (6,500 residents) has Interstate 29 running its whole length, and Adair and Cass sit
  on Interstate 80. A rate per mile driven would be the fairer measure; this project has no traffic counts.
- **Small counties are still uncertain after ten years.** Fremont's 49.1 rests on 33 deaths; an exact Poisson 95%
  interval is 34 to 69. Ringgold's 29.2 rests on 14 deaths (16 to 49). Story's 4.7 rests on 46 (3.4 to 6.2). The
  broad pattern (large counties low, small counties high) is solid; the exact order of neighbouring small counties
  is not.
- Unlike the original, the rate is **not age-standardised**.

## Checks

After a rebuild you should see:

- Highest: Fremont 49.1, Adair 41.3, Monona 33.6, Cass 30.5, Iowa County 29.4.
- Lowest: Story 4.7, Johnson 5.2, Dallas 6.4, Dubuque 6.6, Linn 6.8, Polk 6.9.
- Iowa 10.9. The 11 counties with 50,000 residents or more (2024): 7.4. The 26 with fewer than 10,000: 21.2.
- All 99 counties have a colour; the script stops if one does not join.
- Two runs in a row on the machine described in [iowa_place_names.md](https://github.com/SateeshPatlolla/mice-algorithm/blob/main/docs/iowa_place_names.md) in the mice-algorithm repo gave byte-identical
  PNGs: `shasum -a 256 output/iowa_fatal_crash_counties.png` =
  `54ab25c6d255f2993d71e859617067593b5c144e4f56e73d2ab339d0db71ed22`.

The checksum will differ on another machine or after a Natural Earth or Google Fonts update. Compare the picture
and the numbers above in that case.
