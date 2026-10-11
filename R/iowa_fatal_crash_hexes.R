# Fatal crashes in Iowa counted in hexagons, 2015 to early October 2026
# After Nicola Rennie, #30DayMapChallenge 2022 day 21 (day_21.R): Germany as a honeycomb of
# small hexagons, each coloured by the people living in it, under a one-word title
# The original downloads its hexagons ready-made, with the population already in them
# (the Kontur dataset). Here the hexagons are made with sf and the crashes are counted
# into them.
# Data: Vehicle Crashes in Iowa, vehicle level (Iowa Data Hub dataset 17)
# Run from the project root: Rscript R/iowa_fatal_crash_hexes.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
sites_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
if (!file.exists(sites_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")

# One row per vehicle in the file; the position is the same on every vehicle of a crash
crashes <- read_csv(sites_file, col_select = c(crash = vehicle_crash_key, location = crash_location)) |>
  distinct(crash, location)

# Wrangling ----
utm <- 26915   # UTM zone 15N: metres, so the hexagons have a real size

crashes <- crashes |>
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

# The honeycomb. cellsize is the distance between the centres of two neighbouring hexagons,
# which is also the width of a hexagon from flat side to flat side: 10 km.
hex_width <- 10000
hexes <- st_make_grid(iowa, cellsize = hex_width, square = FALSE) |>
  st_as_sf() |>
  rename(geometry = x) |>
  mutate(hex = row_number())
# Keep the hexagons that touch Iowa, whole. Along the border they stick out a little, as
# the hexagons of the original do along the coast.
hexes <- hexes[st_intersects(hexes, iowa, sparse = FALSE)[, 1], ]

# Which hexagon is each crash in? st_join() adds the hexagon's number to every crash.
counted <- st_join(crashes, hexes, join = st_within) |>
  st_drop_geometry() |>
  filter(!is.na(hex)) |>
  count(hex, name = "crashes")

kontur <- hexes |>
  left_join(counted, by = "hex") |>
  # A hexagon no crash fell into has no row in the count: that is a zero, not a gap
  mutate(crashes = coalesce(crashes, 0L))

# Fonts and colours ----
title_font <- "MedievalSharp"
sysfonts::font_add_google(title_font)
showtext_auto()
showtext_opts(dpi = 300)

bg   <- "#fafafa"
navy <- "#0B0B45"
# Nine colours along "lajolla", one of Fabio Crameri's scientific colour maps, from its
# pale end to its dark end. The original gets it from the scico package, which is not
# installed.
lajolla <- c("#FFFECB", "#F7D971", "#ECAC54", "#E58751", "#D85F4D", "#A44544", "#653329", "#362411", "#191900")

# Texts ----
hex_area <- as.numeric(st_area(kontur[1, ])) / 1e6
top <- max(kontur$crashes)
# The caption names Des Moines as the darkest hexagon. Stop if a rebuild from newer data
# moves the maximum somewhere else (the State Capitol is at 93.60 W, 41.59 N).
capitol <- st_transform(st_sfc(st_point(c(-93.60, 41.59)), crs = 4326), utm)
stopifnot(as.numeric(st_distance(st_centroid(kontur[which.max(kontur$crashes), ]), capitol)) < 15000)
caption <- paste0(
  "Fatal crashes from 2015 to early October 2026 in hexagons ", hex_width / 1000, " km across. ",
  "Palest: none (", round(100 * mean(kontur$crashes == 0)), "% of the hexagons). Darkest: ", top, ", in Des Moines.\n",
  "After a map by N. Rennie | Data: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 17)"
)

# Plot ----
final <- ggplot() +
  # Fill and outline get the same colour, so the hexagons close up without seams
  geom_sf(data = kontur, aes(fill = crashes, colour = crashes), linewidth = 0.1) +
  # pseudo_log is a log scale that can take zero: it runs like a straight line near 0 and
  # like a logarithm further out. With a plain log scale the empty hexagons would vanish.
  scale_fill_gradientn(colours = lajolla, trans = "pseudo_log") +
  scale_colour_gradientn(colours = lajolla, trans = "pseudo_log") +
  labs(title = "Iowa", caption = caption) +
  theme_void() +
  theme(
    legend.position  = "none",
    plot.title       = element_text(colour = navy, family = title_font, size = 44, hjust = 0.5),
    plot.caption     = element_text(colour = navy, size = 7.5, hjust = 0.5, lineheight = 1.2, margin = margin(t = 6)),
    plot.margin      = margin(10, 10, 10, 10),
    plot.background  = element_rect(fill = bg, colour = bg),
    panel.background = element_rect(fill = bg, colour = bg)
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_hexes.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_hexes_thumb.png")

# The original is 6 x 6 in for Germany. Iowa is half as wide again as it is tall.
ggsave(out_png, final, width = 8, height = 6.2, units = "in", dpi = 300, bg = bg)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_hexes.md
cat("Crashes with a position:", nrow(crashes), " counted into a hexagon:", sum(kontur$crashes), "\n")
cat("Hexagons:", nrow(kontur), " area of one:", round(hex_area, 1), "km2\n")
print(summary(kontur$crashes))
print(table(cut(kontur$crashes, c(-1, 0, 1, 2, 5, 10, 20, 50, Inf), labels = c("0", "1", "2", "3-5", "6-10", "11-20", "21-50", "51+"))))
print(sort(kontur$crashes, decreasing = TRUE)[1:10])
