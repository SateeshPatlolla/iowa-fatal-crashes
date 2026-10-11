# Builds data/iowa_fatal_crash_dates_2026-10-10.csv, the small extract that R/iowa_fatal_crash_days.R reads
# Data: Vehicle Crashes in Iowa, Iowa Data Hub dataset 13
# Run from the project root: Rscript R/iowa_fatal_crash_dates_extract.R [path/to/downloaded.zip]
#
# Dataset 17 (drivers and vehicles), which the fatal crashes map uses, has empty date columns.
# Its sibling, dataset 13, is one row per crash and does carry the date. It is about 283 MB,
# so this keeps the fatal crashes and the columns a calendar chart needs. You only need to
# run it to refresh the data.

source("R/packages.R")

out_file <- "data/iowa_fatal_crash_dates_2026-10-10.csv"

# Pass the path of a zip you already downloaded to skip the download
args     <- commandArgs(trailingOnly = TRUE)
zip_file <- if (length(args) > 0) args[1] else tempfile(fileext = ".zip")
if (!file.exists(zip_file)) {
  options(timeout = 1800)
  download.file(
    "https://data.iowa.gov/api/dataset-download?path=datasets%2F13%2Frows.csv",
    zip_file, mode = "wb"
  )
}

keep <- c(
  "case_number", "crash_on", "crash_day", "timestr", "district", "county_name", "county_fips_code",
  "major_cause", "drug_or_alcohol", "light", "weather", "surface_conditions", "crash_severity", "fatalities"
)

# The zip holds the table in several CSV parts. Each part is unzipped, filtered and deleted
# in turn so the full table never sits on disk. Everything is read as text so no value is
# changed on the way through.
part_dir <- tempfile("crash_parts")
fatal <- purrr::map(sort(unzip(zip_file, list = TRUE)$Name), function(part) {
  path <- unzip(zip_file, files = part, exdir = part_dir)
  on.exit(unlink(path))
  read_csv(path, col_select = all_of(keep), col_types = cols(.default = col_character())) |>
    filter(crash_severity == "Fatal")
}) |>
  purrr::list_rbind() |>
  arrange(crash_on, case_number)

dir.create(dirname(out_file), showWarnings = FALSE)
write_csv(fatal, out_file, na = "")
message(nrow(fatal), " fatal crashes written to ", out_file)
