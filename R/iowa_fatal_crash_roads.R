# Every fatal crash in Iowa as a red dot on the state's main roads, 2015 to early October 2026
# After Nicola Rennie, #30DayMapChallenge 2022 day 11 (day_11.R): London's bus stops as red
# dots over the larger streets in grey, and nothing else
# The original takes its streets from OpenStreetMap with the osmdata package. That package
# is not installed; the roads here are the US Census Bureau's file of primary and secondary
# roads, which sf reads directly.
# Data: Vehicle Crashes in Iowa, vehicle level (Iowa Data Hub dataset 17); TIGER/Line 2024
# Run from the project root: Rscript R/iowa_fatal_crash_roads.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
sites_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
roads_file <- "data/iowa_primary_secondary_roads_tiger2024.zip"
roads_url  <- "https://www2.census.gov/geo/tiger/TIGER2024/PRISECROADS/tl_2024_19_prisecroads.zip"
if (!file.exists(sites_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")
# The roads file is in the repo; this only runs if it has been deleted
if (!file.exists(roads_file)) download.file(roads_url, roads_file, mode = "wb")

# One row per vehicle in the file; the position is the same on every vehicle of a crash
crashes <- read_csv(sites_file, col_select = c(crash = vehicle_crash_key, location = crash_location)) |>
  distinct(crash, location)
n_all <- nrow(crashes)

# "/vsizip/" lets sf read the shapefile inside the zip without unpacking it
roads <- st_read(paste0("/vsizip/", roads_file), quiet = TRUE)

# Wrangling ----
utm <- 26915   # UTM zone 15N: metres, so distances can be measured

plot_data <- crashes |>
  mutate(
    # The location arrives as text: "POINT(lon lat)"
    lon = as.numeric(str_match(location, "\\(([-0-9.]+) ")[, 2]),
    lat = as.numeric(str_match(location, " ([-0-9.]+)\\)")[, 2])
  ) |>
  # Five crashes are recorded at "POINT(0 0)", which means "position unknown"
  filter(lon != 0, lat != 0) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  st_transform(utm)

roads <- roads |>
  st_transform(utm) |>
  mutate(
    # MTFCC is the Census Bureau's road class: S1100 primary (interstates and other
    # divided highways), S1200 secondary (the other US, state and main county highways)
    class = ifelse(MTFCC == "S1100", "primary", "secondary")
  )

# How many crashes happened on one of the roads drawn? A crash counts as "on" a road when
# it lies within 50 m of it: the roads are centre lines and a divided highway is wide.
nearest <- st_nearest_feature(plot_data, roads)
plot_data$distance <- as.numeric(st_distance(plot_data, roads[nearest, ], by_element = TRUE))
plot_data$on_class <- ifelse(plot_data$distance <= 50, roads$class[nearest], "other road")
on_main <- mean(plot_data$distance <= 50)

# Plot ----
# The original uses R's built-in "serif" font, so no font is downloaded here
red  <- "#C41E3A"
grey <- "#A9A9A9"
bg   <- "#fafafa"

final <- ggplot() +
  geom_sf(data = roads, aes(linewidth = class), colour = grey) +
  scale_linewidth_manual(values = c(primary = 0.35, secondary = 0.15), guide = "none") +
  geom_sf(data = plot_data, colour = red, size = 0.25) +
  labs(
    title    = "Iowa Fatal Crashes",
    subtitle = paste0(
      format(nrow(plot_data), big.mark = ","), " crashes, 2015 to early October 2026. ",
      round(100 * on_main), "% happened on the main roads drawn here;\nthe other dots trace the county roads and city streets that are not."
    ),
    caption  = "After a map by N. Rennie | Data: Iowa DOT via Iowa Data Hub (dataset 17); roads: US Census Bureau, TIGER/Line 2024"
  ) +
  theme_void() +
  theme(
    plot.title       = element_text(family = "serif", colour = red, size = 24, hjust = 0.5, margin = margin(t = 20)),
    plot.subtitle    = element_text(family = "serif", colour = red, size = 10, hjust = 0.5, lineheight = 1.1, margin = margin(t = 6, b = 4)),
    plot.caption     = element_text(family = "serif", colour = red, size = 8, hjust = 0.5, margin = margin(b = 10)),
    plot.background  = element_rect(colour = bg, fill = bg),
    panel.background = element_rect(colour = bg, fill = bg)
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_roads.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_roads_thumb.png")

# The original is 6 x 6 in for London. Iowa is half as wide again as it is tall.
ggsave(out_png, final, width = 8, height = 6.4, units = "in", dpi = 300, bg = bg)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_roads.md
cat("Crashes in file:", n_all, " with a position:", nrow(plot_data), "\n")
cat("Road segments:", nrow(roads), " km:", round(tapply(as.numeric(st_length(roads)) / 1000, roads$class, sum)), "\n")
print(round(100 * prop.table(table(plot_data$on_class)), 1))
cat("Within 25 / 50 / 100 / 250 m of a drawn road:", round(100 * sapply(c(25, 50, 100, 250), \(d) mean(plot_data$distance <= d)), 1), "\n")
