# When fatal crashes happen in Iowa: date against time of day, 2015 to 2025
# After Georgios Karamanis, TidyTuesday 2025 week 20 (vesuvius.R): every event as a point,
# time on x, a second measure running downwards on y, colour by point density, a shape behind
# the points for scale and two small maps
# Data: Vehicle Crashes in Iowa (dataset 13) for date and time, Drivers and Vehicles Involved
# in Iowa Crashes (dataset 17) for the position, both from the Iowa Data Hub
# Run from the project root: Rscript R/iowa_fatal_crash_hours.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
# Two extracts of the fatal crashes, built by the two *_extract.R scripts. The dated one has
# no position and the one with positions has no date, so they are joined on the crash key.
dates_file <- "data/iowa_fatal_crash_dates_2026-10-10.csv"
sites_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
if (!file.exists(dates_file)) stop("Extract not found. Run R/iowa_fatal_crash_dates_extract.R first.")
if (!file.exists(sites_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")

crashes <- read_csv(
  dates_file,
  col_select = c(crash = case_number, crash_on, time = timestr, impaired = drug_or_alcohol),
  col_types = cols(timestr = col_character())
)

# The second file has one row per vehicle; the position is the same on every vehicle of a crash
sites <- read_csv(sites_file, col_select = c(crash = vehicle_crash_key, location = crash_location)) |>
  distinct(crash, location)

# Wrangling ----

# Sunrise and sunset on the clock, in hours, from the standard textbook formulas. Good to a
# few minutes, which is plenty for a band behind the points.
sun_times <- function(date, lat, lon, tz, tz_meridian) {
  day    <- as.numeric(format(date, "%j"))
  # Equation of time: how many minutes the sun runs ahead of or behind the clock
  b      <- 2 * pi * (day - 81) / 364
  eot    <- 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)
  # Tilt of the earth towards the sun on that day
  tilt   <- -23.44 * cos(2 * pi * (day + 10) / 365) * pi / 180
  phi    <- lat * pi / 180
  # Half the length of the day in degrees; -0.833 allows for the sun's size and the bending of light
  half   <- acos((sin(-0.833 * pi / 180) - sin(phi) * sin(tilt)) / (cos(phi) * cos(tilt))) * 180 / pi
  # 1 during daylight saving time, which moves the clock an hour ahead of the sun
  summer <- as.POSIXlt(paste(date, "12:00"), tz = tz)$isdst
  noon   <- 12 - eot / 60 + (tz_meridian - lon) * 4 / 60 + summer
  tibble(date = date, sunrise = noon - half / 15, sunset = noon + half / 15)
}

# One sun for the whole state: Des Moines. Sunrise is about 20 minutes apart between the
# east and west borders, so the band is a guide, not a ruling on any single crash.
sun <- sun_times(
  seq(as.Date("2015-01-01"), as.Date("2025-12-31"), by = "day"),
  lat = 41.6, lon = -93.6, tz = "America/Chicago", tz_meridian = -90
)

crashes <- crashes |>
  mutate(
    # crash_on arrives as "2018-04-13 00:00:00 UTC"; the clock time is in its own column, "14:05"
    date = as.Date(substr(crash_on, 1, 10)),
    hour = as.numeric(substr(time, 1, 2)) + as.numeric(substr(time, 4, 5)) / 60,
    impaired = impaired != "None Indicated"
  ) |>
  left_join(sun, by = "date") |>
  left_join(sites, by = "crash") |>
  mutate(
    dark = hour < sunrise | hour > sunset,
    # The location arrives as text: "POINT(lon lat)"
    lon = as.numeric(str_match(location, "\\((-?[0-9.]+) ")[, 2]),
    lat = as.numeric(str_match(location, " (-?[0-9.]+)\\)")[, 2])
  )

# Colour by how crowded the neighbourhood of each point is (what ggpointdensity does):
# count the points within a radius, on axes that were first put on comparable scales
neighbours <- function(x, y, radius) rowSums(as.matrix(dist(cbind(x, y))) < radius)

crashes <- crashes |>
  mutate(
    # 11 years across, 24 hours down: scale both to 0 to 1 so the radius means the same both ways
    crowd_time = neighbours(as.numeric(date - min(date)) / as.numeric(max(date) - min(date)), hour / 24, 0.035)
  )

# Five crashes have no usable position (0, 0); they stay in the main chart
on_map <- crashes |>
  filter(lon < -85, lat > 35) |>
  # A degree of longitude is shorter than a degree of latitude here, by cos(latitude)
  mutate(crowd_map = neighbours(lon * cos(42 * pi / 180), lat, 0.15)) |>
  arrange(crowd_map)

crashes <- arrange(crashes, crowd_time)

# Base maps
sf_use_s2(FALSE)
states  <- ne_download(scale = 10, type = "admin_1_states_provinces", category = "cultural", returnclass = "sf", load = TRUE) |>
  filter(admin == "United States of America", !name %in% c("Alaska", "Hawaii"))
ia_poly <- filter(states, name == "Iowa")

# Numbers for the text
pct       <- function(x) round(100 * mean(x))
by_hour   <- count(crashes, h = floor(hour))
top_hour  <- by_hour$h[which.max(by_hour$n)]
afternoon <- pct(crashes$hour >= 15 & crashes$hour < 18)
by_month  <- count(crashes, m = as.integer(format(date, "%m")))

# Fonts and colours ----
main_font <- "Libre Franklin"
axis_font <- "Fira Sans"
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(axis_font)
showtext_auto()
showtext_opts(dpi = 300)

page  <- "#F5F5F5"
ink   <- "#1A1A1A"
muted <- "#6B6B6B"
night <- "#DCE1EA"
land  <- "#EED9C4"
edge  <- "#D9B99B"
# MetBrewer's Johnson palette, reversed as in the original: blue = sparse, red = crowded
johnson <- c("#132B69", "#0086A8", "#F6C200", "#D04E00", "#A00E00")

# Texts ----
title <- "Iowa's fatal crashes cluster in the late afternoon"

subtitle <- str_wrap(paste0(
  "Each point is one of the ", format(nrow(crashes), big.mark = ","), " fatal crashes in Iowa from 2015 to 2025, placed by date and by time of day. ",
  "Colour shows how many crashes share its part of the chart. The three hours from 3 pm to 6 pm hold ", afternoon,
  "% of them, and the crowded patches return every summer. ", pct(crashes$dark), "% happened in the dark; alcohol or drugs were indicated in ",
  pct(crashes$impaired[crashes$dark]), "% of those, against ", pct(crashes$impaired[!crashes$dark]), "% in daylight."
), 135)

caption <- "Source: Vehicle Crashes in Iowa and Drivers and Vehicles Involved in Iowa Crashes, Iowa DOT via Iowa Data Hub · After a chart by Georgios Karamanis"

hour_labels <- c("Midnight", "3 am", "6 am", "9 am", "Noon", "3 pm", "6 pm", "9 pm", "Midnight")

notes <- tribble(
  ~date,                 ~hour, ~label,
  as.Date("2016-10-15"),  1.6,  "Shaded: before sunrise and after sunset\nin Des Moines. The steps are the clock changes.",
  as.Date("2020-07-01"), 16.5,  paste0("More fatal crashes start between ", top_hour - 12, " and ", top_hour - 11, " pm\nthan in any other hour"),
  as.Date("2023-01-01"), 10.2,  paste0("August has the most crashes (", by_month$n[8], "),\nFebruary the fewest (", by_month$n[2], ")")
)

# Main chart ----
scatter <- ggplot() +
  # Night, the counterpart of the volcano's outline in the original: it gives the points a scale
  geom_ribbon(data = sun, aes(x = date, ymin = 0, ymax = sunrise), fill = night) +
  geom_ribbon(data = sun, aes(x = date, ymin = sunset, ymax = 24), fill = night) +
  geom_point(data = crashes, aes(x = date, y = hour, colour = crowd_time), size = 0.9) +
  geom_label(
    data = notes, aes(x = date, y = hour, label = label),
    family = axis_font, size = 3.4, lineheight = 0.95, colour = ink,
    fill = alpha("white", 0.85), linewidth = 0, label.padding = unit(0.25, "lines")
  ) +
  scale_colour_gradientn(colours = johnson) +
  scale_x_date(breaks = as.Date(paste0(2015:2025, "-01-01")), date_labels = "%Y", expand = c(0.01, 0), position = "top") +
  # Reversed, so the day runs downwards like the depths in the original
  scale_y_reverse(breaks = seq(0, 24, 3), labels = hour_labels, expand = c(0, 0), position = "right") +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_family = main_font) +
  theme(
    legend.position    = "none",
    panel.grid.major.y = element_line(colour = "darkgrey", linewidth = 0.1),
    panel.grid.minor.y = element_blank(),
    panel.grid.major.x = element_line(colour = "darkgrey", linewidth = 0.1),
    panel.grid.minor.x = element_blank(),
    axis.text          = element_text(family = axis_font, size = 10, colour = ink),
    # Year labels sit at 1 January; push them right so they read as the name of the column
    axis.text.x.top    = element_text(hjust = -0.35)
  )

# Maps ----
# Where the same crashes happened
iowa_map <- ggplot() +
  geom_sf(data = ia_poly, fill = "white", colour = edge, linewidth = 0.4) +
  geom_point(data = on_map, aes(x = lon, y = lat, colour = crowd_map), size = 0.15) +
  scale_colour_gradientn(colours = johnson) +
  labs(title = "Where they happened") +
  theme_void(base_family = main_font) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 10.5, colour = ink, margin = margin(b = 4))
  )

# Where Iowa is
locator <- ggplot() +
  geom_sf(data = states, fill = land, colour = "white", linewidth = 0.15) +
  geom_sf(data = ia_poly, fill = "#A00E00", colour = NA) +
  annotate("text", x = -93.4, y = 45.6, label = "IOWA", family = axis_font, fontface = "bold", size = 3, colour = ink) +
  coord_sf(crs = "ESRI:102003") +
  theme_void()

# Assemble ----
final <- (scatter | (iowa_map / locator / plot_spacer() + plot_layout(heights = c(1, 0.8, 1.1)))) +
  plot_layout(widths = c(1, 0.3)) +
  plot_annotation(
    title = title, subtitle = subtitle, caption = caption,
    theme = theme(
      plot.title    = element_text(family = main_font, size = 20, face = "bold", colour = ink),
      plot.subtitle = element_text(family = main_font, size = 11, lineheight = 1.15, colour = "#333333", margin = margin(0, 0, 12, 0)),
      plot.caption  = element_text(family = main_font, size = 8.5, colour = muted, margin = margin(10, 0, 0, 0)),
      plot.margin   = margin(12, 12, 10, 12)
    )
  ) &
  theme(plot.background = element_rect(fill = page, colour = NA))

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_hours.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_hours_thumb.png")

ggsave(out_png, final, width = 12, height = 8, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")
