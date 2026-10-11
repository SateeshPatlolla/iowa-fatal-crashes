# Builds data/iowa_fatal_crashes_2026-10-09.csv, the small extract that R/iowa_fatal_crashes.R reads
# Data: Drivers and Vehicles Involved in Iowa Crashes, Iowa Data Hub dataset 17
# Run from the project root: Rscript R/iowa_fatal_crashes_extract.R [path/to/downloaded.zip]
#
# The full dataset is one row per vehicle in every reported crash since 2015: about 1.1 million
# rows and 717 MB, too big to keep in the repo. This keeps the vehicles in fatal crashes and
# the twelve columns the map needs. You only need to run it to refresh the data.

source("R/packages.R")

out_file <- "data/iowa_fatal_crashes_2026-10-09.csv"

# Pass the path of a zip you already downloaded to skip the download
args     <- commandArgs(trailingOnly = TRUE)
zip_file <- if (length(args) > 0) args[1] else tempfile(fileext = ".zip")
if (!file.exists(zip_file)) {
  options(timeout = 1800)
  download.file(
    "https://data.iowa.gov/api/dataset-download?path=datasets%2F17%2Frows.csv",
    zip_file, mode = "wb"
  )
}

# The zip holds the table in several CSV parts
part_dir <- tempfile("crash_parts")
parts    <- unzip(zip_file, exdir = part_dir)

keep <- c(
  "vehicle_crash_key", "vehicle_unit_key", "crash_year", "crash_severity", "fatalities",
  "major_cause", "drug_or_alcohol_related", "driver_age", "driver_contributing_circumstances",
  "vehicle_configuration", "speed_limit", "crash_location"
)

# Everything is read as text so no value is changed on the way through
fatal <- purrr::map(sort(parts), function(part) {
  read_csv(part, col_select = all_of(keep), col_types = cols(.default = col_character())) |>
    filter(crash_severity == "Fatal")
}) |>
  purrr::list_rbind() |>
  arrange(vehicle_crash_key, vehicle_unit_key)

dir.create(dirname(out_file), showWarnings = FALSE)
write_csv(fatal, out_file, na = "")
message(nrow(fatal), " vehicles in ", n_distinct(fatal$vehicle_crash_key), " fatal crashes written to ", out_file)
