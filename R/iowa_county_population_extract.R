# Builds data/iowa_county_population_2015_2024.csv, which R/iowa_fatal_crash_districts.R reads
# Data: US Census Bureau population estimates (the Iowa files of the subcounty series, which
# also carry one total row per county)
# Run from the project root: Rscript R/iowa_county_population_extract.R
# You only need to run it to rebuild the table.

source("R/packages.R")

out_file <- "data/iowa_county_population_2015_2024.csv"

base <- "https://www2.census.gov/programs-surveys/popest/datasets"
urls <- c(
  # Estimates for 2010 to 2020, built on the 2010 census
  old = paste0(base, "/2010-2020/cities/SUB-EST2020_19.csv"),
  # Estimates for 2020 to 2024, built on the 2020 census
  new = paste0(base, "/2020-2024/cities/totals/sub-est2024_19.csv")
)

# SUMLEV 050 marks the county rows. The yearly figures sit in columns POPESTIMATE2015,
# POPESTIMATE2016, ...; pivot_longer() turns them into one row per county and year.
read_counties <- function(url) {
  read_csv(url, col_types = cols(.default = col_character())) |>
    filter(SUMLEV == "050") |>
    select(COUNTY, NAME, matches("^POPESTIMATE20[0-9]{2}$")) |>
    pivot_longer(starts_with("POPESTIMATE"), names_to = "year", values_to = "population") |>
    mutate(year = as.integer(str_remove(year, "POPESTIMATE")), population = as.integer(population))
}

# 2020 exists in both files; the newer series is used from 2020 on
population <- bind_rows(
  read_counties(urls["old"]) |> filter(year >= 2015, year <= 2019),
  read_counties(urls["new"])
) |>
  transmute(county_fips_code = paste0("19", COUNTY), county = str_remove(NAME, " County$"), year, population) |>
  arrange(county_fips_code, year)

stopifnot(nrow(population) == 99 * 10)

write_csv(population, out_file)
message(nrow(population), " rows written to ", out_file)
