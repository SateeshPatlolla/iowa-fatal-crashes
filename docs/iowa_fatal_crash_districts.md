# Reproducing the Iowa road death rates by district and county chart

How `output/iowa_fatal_crash_districts.png` is made, how it maps onto the chart it copies, and how to check a rebuild.

The model is Georgios Karamanis's TidyTuesday 2025 week 48 chart,
[spi_indicators.R](https://github.com/gkaramanis/tidytuesday/blob/master/2025/2025-week_48/spi_indicators.R): the
World Bank's statistical performance score by world region, then by country inside one region.

## Rebuild

```r
renv::restore()
source("R/iowa_fatal_crash_districts.R")   # under a minute; needs internet for Natural Earth and the fonts
```

It writes `output/iowa_fatal_crash_districts.png` (4200 x 2400 px, 14 x 8 in at 300 dpi) and a 500 px thumbnail.

## How the original maps onto this data

| Original | Here |
|---|---|
| Groups: seven world regions | Groups: Iowa DOT's six districts |
| Members: the countries of Europe & Central Asia | Members: the 17 counties of the Southwest district |
| Value: a score from 0 to 100 | Value: road deaths per 100,000 residents a year |
| Left: a smoothed line per region, one highlighted, named along the line | Left: a line per district, one highlighted, named at its right-hand end |
| Right: one panel per country, drawn over all the others in faint lines | The same, per county |
| Arrows after the name for the income class | Arrows after the name for the size of the county |

The script picks the district with the highest whole-period rate, so the highlight follows the data.

## Inputs

| Input | Used for | Pinned? |
|---|---|---|
| `data/iowa_fatal_crash_dates_2026-10-10.csv` (dataset 13 extract) | year, county, district and deaths of each crash | Yes |
| `data/iowa_county_population_2015_2024.csv` | residents per county and year | Yes |
| Natural Earth 1:10m US counties | the small map | No, downloaded on each run |
| Fonts (Libre Franklin, Fira Sans) | text | No |
| R packages | | `renv.lock` |

### The crash extract gained two columns

`district` and `county_fips_code` were added to `R/iowa_fatal_crash_dates_extract.R` for this chart. The download
used was byte-identical to the first one (same SHA-256), the twelve earlier columns did not change, and the four
earlier charts rebuild to the same checksums. The extract's own checksum is now
`f5c59946a0ca48259e7da8bfd52628f317b96432d6ea380844ee12182c7b5bec`.

### County population

`R/iowa_county_population_extract.R` builds the table from two Census Bureau files (the county rows, `SUMLEV` 050):

- 2015 to 2019: `https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/cities/SUB-EST2020_19.csv`
- 2020 to 2024: `https://www2.census.gov/programs-surveys/popest/datasets/2020-2024/cities/totals/sub-est2024_19.csv`

Result: 99 counties x 10 years = 990 rows, SHA-256
`2c56da08b1be5f2c49318f50ad4f332816cef462a7193dd23039fd3edb88473a`. The script was run on 2026-10-10 and reproduced
the file exactly. The state totals in it match the Census figures (3,122,541 in 2015; 3,241,488 in 2024).

## Definitions

- **Years**: 2015 to 2024. 2025 is left out because there is no county population estimate for it yet. (It was
  also an unusual year, the lowest on record; see [iowa_fatal_crash_eras.md](iowa_fatal_crash_eras.md).)
- **County of a crash**: `county_name`. Seven fatal crashes have none and are dropped (3,137 remain, 3,474 deaths).
  Names are matched to the Census names after removing everything but letters and spaces, which pairs "OBRIEN" with
  "O'Brien". The county code is not used because it is empty on 27 rows.
- **District of a county**: the data records the district per crash, and it is not constant within a county: 96
  crashes (3%) carry another district than most crashes of their county, and Madison, Emmet and Humboldt are split
  nearly in half. Each county is assigned to the district it is most often recorded under, and all its crashes
  count there. A tie goes to the lower district number; Madison is the one tie (15 crashes each under Southwest
  and Southeast) and lands in the Southwest. The result is 12 Central, 19 Northeast, 19 Northwest, 17 Southwest, 20 Southeast and 12 East Central
  counties.
- **Rate**: deaths in a year and the two before it, divided by the residents of the same three years, times
  100,000. The first point is 2017. A single year is too jumpy for small counties.
- **Whole-period rate** (the numbers in the subtitle and the order of the panels): deaths 2015 to 2024 divided by
  the sum of the yearly residents.
- **Arrows**: residents in 2024; up for 50,000 or more, right for 10,000 to 50,000, down for fewer.

## Changes from the original, and why

| Original | Here | Why |
|---|---|---|
| `geom_smooth()` ribbons | three-year pooled rate, plain lines | A stated window is easier to check than a loess fit, and the pooling is needed for the counties anyway |
| `geomtextpath` labels along the lines | names at the line ends | Not in `renv.lock` |
| `gghighlight` in the panels | a background layer built with `crossing()` | Not installed |
| Same y-axis left and right | 0 to 16 on the left, 0 to 80 on the right | Small counties reach five times the district rates |
| No map | small map of the district | Few readers know where the DOT districts are |
| Panels in alphabetical order | from the highest rate to the lowest | The order then carries information |

## Hand-set values

| Value | Where |
|---|---|
| Last year used (2024) | `filter(year <= 2024)` |
| Three-year window | `pooled_rate()` |
| Size classes for the arrows | `county_all` |
| Label spacing at the line ends, map position, facet columns | `ends`, `inset_element()`, `facet_wrap()` |
| Title wording ("a few small counties") and "next to Des Moines" in the subtitle | `title`, `subtitle`; check after a data refresh |

Nothing is random, so there is no seed.

## Checks

After a rebuild the script prints both tables. Whole-period rates per 100,000 residents a year:

| District | Deaths | Rate |
|---|---|---|
| Southwest | 488 | 14.2 |
| Southeast | 551 | 13.5 |
| Northwest | 452 | 12.5 |
| Northeast | 492 | 12.1 |
| East Central | 764 | 9.1 |
| Central | 727 | 8.9 |

Iowa: 10.9. Southwest counties, highest first: Fremont 49.1, Adair 41.3, Cass 30.5, Ringgold 29.2, Audubon 23.3,
Harrison 22.3, Mills 21.6, Madison 18.2, Adams 16.5, Shelby 16.2, Montgomery 13.8, Taylor 13.3, Union 13.1,
Pottawattamie 12.2, Guthrie 10.3, Page 9.2, Dallas 6.4.

On the same machine and package versions, `shasum -a 256 output/iowa_fatal_crash_districts.png` gives
`565014319ad55a863e2d4a78fe5203cd0cca52ba13339954b272c6396c15382e`. Two runs in a row were byte-identical.

## Known limits

- **Per resident is not per mile driven.** A death is counted in the county where the crash happened, whoever
  died. Interstate 29 runs through Fremont and Interstate 80 through Adair and Cass, so much of the traffic there
  is not local. The rate says where deaths happen relative to how few people live there, not how dangerous the
  roads are for a driver.
- **Small numbers.** Adams County had 6 deaths in ten years and Fremont 33. One crash moves a small county's line a
  long way, even pooled over three years.
- **Break in the population series.** 2019 and 2020 come from estimates built on different censuses; Iowa's total
  steps up by about 1% between them. That lowers rates slightly from 2020.
- **District assignment** is the rule described above, not an official list of district boundaries. The headline
  does not depend on it. Southwest and Southeast rates under three versions of the rule:

  | Rule | Southwest | Southeast |
  |---|---|---|
  | Madison in the Southwest (the chart) | 14.2 | 13.5 |
  | Madison in the Southeast | 14.0 | 13.7 |
  | Each crash under its own recorded district, residents split in proportion | 14.4 | 13.6 |

  The gap between the two is small under every version; the gap to the Central and East Central districts (about
  9) is the solid finding.
