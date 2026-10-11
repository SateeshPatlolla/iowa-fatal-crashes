# Where fatal crashes are densest in Iowa, drawn as a contour map, 2015 to 2025
# After Nicola Rennie, forest-of-bowland.R (data-viz-projects): filled contours of a surface
# with the contour lines on top, title and palette swatches inside a pale box
# The original surface is the height of the land. Here it is the number of fatal crashes
# per 1,000 square kilometres.
# Data: Vehicle Crashes in Iowa, vehicle level (Iowa Data Hub dataset 17)
# Run from the project root: Rscript R/iowa_fatal_crash_contours.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Parameters ----
# The same list as in the original, with the bandwidth and cell size added
# Contour lines, in crashes per 1,000 km2. The original uses equal steps of 50 m. Equal steps
# do not work here: nine tenths of Iowa lie under 40 and the top of Des Moines is over 300,
# so the lines would all crowd round the cities. Each step here is about 1.4 times the last.
break_vals  <- c(0, 10, 15, 20, 30, 40, 60, 80, 120, 160, 240, 320)
bandwidth   <- 12        # how far each crash is spread, in km (standard deviation)
cell        <- 2         # grid cell, in km
# "Morgenstern" from MetBrewer, typed in because the package is not installed
col_palette <- c("#7c668c", "#b08ba5", "#dfbbc8", "#ffc680", "#ffb178", "#db8872", "#a56457")
text_family <- "Commissioner"
bg_col      <- "#ffc680"
box_col     <- "#FFE5AD"
text_col    <- "#574156"
title       <- "Iowa fatal crashes"

# Data ----
sites_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
if (!file.exists(sites_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")

# One row per vehicle in the file; the position is the same on every vehicle of a crash
crashes <- read_csv(sites_file, col_select = c(crash = vehicle_crash_key, year = crash_year, location = crash_location)) |>
  distinct(crash, year, location)
n_all <- nrow(crashes)

# Wrangling ----
utm <- 26915   # UTM zone 15N: metres, and Iowa sits in the middle of the zone

crashes <- crashes |>
  filter(!is.na(location)) |>
  mutate(
    # The location arrives as text: "POINT(lon lat)"
    lon = as.numeric(str_match(location, "\\(([-0-9.]+) ")[, 2]),
    lat = as.numeric(str_match(location, " ([-0-9.]+)\\)")[, 2])
  ) |>
  # Five crashes are recorded at "POINT(0 0)", which means "position unknown"
  filter(lon != 0, lat != 0) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  st_transform(utm)

sf_use_s2(FALSE)
iowa <- ne_download(scale = 10, type = "admin_2_counties", category = "cultural", returnclass = "sf", load = TRUE) |>
  filter(REGION == "IA") |>
  st_transform(utm) |>
  st_union()

# The outline is a simplified one, so some crashes on border roads and bridges fall up to
# 2.4 km outside it. They are Iowa crashes and are kept: anything within 3 km of the outline
# counts.
crashes <- crashes[st_is_within_distance(crashes, iowa, dist = 3000, sparse = FALSE)[, 1], ]
n_used <- nrow(crashes)

# The surface ----
# Everything in kilometres from here, so that the density comes out per square kilometre
xy   <- st_coordinates(crashes) / 1000
box  <- st_bbox(iowa) / 1000
pad  <- 4 * bandwidth
grid_x <- seq(box["xmin"] - pad, box["xmax"] + pad, by = cell)
grid_y <- seq(box["ymin"] - pad, box["ymax"] + pad, by = cell)

# A kernel density estimate: every crash becomes a small hill 12 km wide, and the hills are
# added up. KernSmooth ships with R. The result sums to 1 over the map, so it is multiplied
# by the number of crashes and by 1,000 to read as crashes per 1,000 km2.
smooth <- function(points) {
  KernSmooth::bkde2D(
    points, bandwidth = c(bandwidth, bandwidth),
    gridsize = c(length(grid_x), length(grid_y)),
    range.x  = list(range(grid_x), range(grid_y))
  )$fhat
}
surface <- smooth(xy) * n_used * 1000

# Near the border part of each hill falls outside Iowa, where there are no crashes in the
# data to fill it back in, so the edge would look emptier than it is. The fix: smooth Iowa
# itself (a point in every grid cell inside the state) the same way. That gives, for every
# cell, the share of its neighbourhood that lies inside Iowa. Dividing by it corrects the edge.
cells <- expand.grid(x = grid_x, y = grid_y)
inside <- st_intersects(
  st_as_sf(cells * 1000, coords = c("x", "y"), crs = utm), iowa, sparse = FALSE
)[, 1]
share_inside <- smooth(as.matrix(cells[inside, ])) * sum(inside) * cell^2
# Outside the state the share goes to zero; the floor keeps the division finite there.
# Those cells are covered by the mask below.
surface <- surface / pmax(share_inside, 0.25)

# expand.grid() runs through x fastest, which is also how as.vector() unrolls the matrix
cells$z <- as.vector(surface)

stopifnot(max(cells$z[inside]) < max(break_vals))
cols <- grDevices::colorRampPalette(col_palette)(length(break_vals) - 1)

# The summit, and the cities to name. Positions typed in as longitude and latitude.
peak <- cells[inside, ][which.max(cells$z[inside]), ]
cities <- tibble::tribble(
  ~city,            ~lon,    ~lat,
  "Des Moines",     -93.62,  41.59,
  "Cedar Rapids",   -91.67,  41.98,
  "Davenport",      -90.58,  41.54,
  "Sioux City",     -96.40,  42.50,
  "Council Bluffs", -95.86,  41.26,
  "Waterloo",       -92.34,  42.49,
  "Dubuque",        -90.66,  42.50,
  "Iowa City",      -91.53,  41.66
) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  st_transform(utm)
cities <- bind_cols(st_drop_geometry(cities), as.data.frame(st_coordinates(cities) / 1000))
# Height of the surface at each city: the nearest grid cell
cities$z <- sapply(seq_len(nrow(cities)), function(i) {
  surface[which.min(abs(grid_x - cities$X[i])), which.min(abs(grid_y - cities$Y[i]))]
})
peak_city <- cities$city[which.min((cities$X - peak$x)^2 + (cities$Y - peak$y)^2)]

# Everything outside Iowa is painted over in the colour of the box
# (the frame is larger than the grid so that its own edge falls outside the picture)
frame <- st_as_sfc(st_bbox(c(
  xmin = min(grid_x) - 500, xmax = max(grid_x) + 500, ymin = min(grid_y) - 500, ymax = max(grid_y) + 500
)))
mask <- st_difference(frame, st_geometry(iowa) / 1000)
outline <- st_geometry(iowa) / 1000

# Fonts ----
sysfonts::font_add_google(text_family)
showtext_auto()
showtext_opts(dpi = 300)

# Texts ----
state_mean <- n_used / as.numeric(st_area(iowa)) * 1e6 * 1000
subtitle <- paste0("Highest point: ", peak_city, ", ", round(peak$z), " fatal crashes per 1,000 km\u00b2")
note <- paste0(
  "Fatal crashes from ", min(crashes$year), " to early October ", max(crashes$year), ", smoothed over ", bandwidth, " km. Iowa as a whole: ", round(state_mean),
  " per 1,000 km\u00b2.\nLines at ", paste(break_vals[-1], collapse = ", "),
  ". The surface counts crashes, not risk: it rises where people live."
)
caption <- "Data: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 17) · Graphic: after a map by Nicola Rennie"

# Plot ----
left   <- box[["xmin"]]
top    <- box[["ymax"]]
bottom <- box[["ymin"]]
swatch <- 14   # km

final <- ggplot() +
  geom_contour_filled(data = cells, aes(x = x, y = y, z = z), breaks = break_vals) +
  geom_contour(data = cells, aes(x = x, y = y, z = z), breaks = break_vals, colour = text_col, linewidth = 0.25) +
  scale_fill_manual(values = cols, drop = FALSE) +
  geom_sf(data = mask, fill = box_col, colour = NA) +
  geom_sf(data = outline, fill = NA, colour = text_col, linewidth = 0.4) +
  geom_point(data = cities, aes(x = X, y = Y), colour = text_col, size = 0.9) +
  geom_label(
    data = cities, aes(x = X, y = Y + 9, label = city),
    family = text_family, colour = text_col, fill = alpha(box_col, 0.8), size = 2.7, fontface = "bold",
    label.size = 0, label.padding = unit(0.12, "lines")
  ) +
  # The palette as a row of squares, as in the original
  annotate(
    "rect",
    xmin = left + (seq_along(col_palette) - 1) * swatch * 1.25, xmax = left + (seq_along(col_palette) - 1) * swatch * 1.25 + swatch,
    ymin = top + 96, ymax = top + 96 + swatch * 0.5, fill = col_palette
  ) +
  annotate(
    "text", x = left + length(col_palette) * swatch * 1.25 + 2, y = top + 96 + swatch * 0.25,
    label = paste0("0 to ", max(break_vals), " fatal crashes per 1,000 km²"),
    hjust = 0, family = text_family, colour = text_col, size = 3.2
  ) +
  annotate("text", x = left, y = top + 68, label = toupper(title), hjust = 0, fontface = "bold", family = text_family, colour = text_col, size = 13) +
  annotate("text", x = left, y = top + 40, label = subtitle, hjust = 0, family = text_family, colour = text_col, size = 5) +
  annotate("text", x = left, y = top + 16, label = note, hjust = 0, lineheight = 1.15, family = text_family, colour = text_col, size = 3.6) +
  annotate("text", x = left, y = bottom - 16, label = caption, hjust = 0, family = text_family, colour = text_col, size = 3.2) +
  coord_sf(
    xlim = c(box[["xmin"]] - 14, box[["xmax"]] + 14), ylim = c(bottom - 28, top + 112),
    expand = FALSE, datum = NA
  ) +
  theme_void(base_family = text_family) +
  theme(
    legend.position  = "none",
    plot.margin      = margin(20, 20, 20, 20),
    plot.background  = element_rect(fill = bg_col, colour = bg_col),
    panel.background = element_rect(fill = box_col, colour = box_col)
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_contours.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_contours_thumb.png")

# The original is an upright A4 page. Iowa is wider than tall, so the page keeps A4's long
# side as its width and takes the height the map needs.
ggsave(out_png, final, width = 297, height = 268, units = "mm", dpi = 300, bg = bg_col)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_contours.md
cat("Crashes in file:", n_all, " with a usable position:", n_used, "\n")
cat("Years:", min(crashes$year), "to", max(crashes$year), "\n")
cat("Peak:", round(peak$z, 1), "near", peak_city, " State mean:", round(state_mean, 1), " Top break:", max(break_vals), "\n")
cat("Share of Iowa below the state mean:", round(100 * mean(cells$z[inside] < state_mean)), "%  below 40:", round(100 * mean(cells$z[inside] < 40)), "%\n")
print(table(crashes$year))
print(arrange(cities[, c("city", "z")], desc(z)))
