# The weather at Iowa's fatal crashes by the type of vehicle involved, 2015 to 2025
# After Georgios Karamanis, TidyTuesday 2026 week 5 (brazilian_companies.R): one bar per group,
# every bar filled to 100% and split by a second category, bar thickness from the log of the
# group's size, bars ordered by the share of the first category
# Data: Drivers and Vehicles Involved in Iowa Crashes (dataset 17) for the vehicle type,
# Vehicle Crashes in Iowa (dataset 13) for the weather, both from the Iowa Data Hub
# Run from the project root: Rscript R/iowa_fatal_crash_vehicles.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
vehicles_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
weather_file  <- "data/iowa_fatal_crash_dates_2026-10-10.csv"
if (!file.exists(vehicles_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")
if (!file.exists(weather_file)) stop("Extract not found. Run R/iowa_fatal_crash_dates_extract.R first.")

# One row per vehicle
vehicles <- read_csv(
  vehicles_file,
  col_select = c(crash = vehicle_crash_key, type = vehicle_configuration),
  col_types = cols(vehicle_crash_key = col_double())
)

# One row per crash. This extract ends in 2025, so the join below drops the 2026 crashes.
weather <- read_csv(
  weather_file,
  col_select = c(crash = case_number, weather),
  col_types = cols(case_number = col_double())
)

# Wrangling ----
weather_levels <- c("Clear", "Cloudy", "Rain, snow, fog or wind")

# Shorter names for the types that get their own bar
type_names <- c(
  "Sport utility vehicle"              = "SUV",
  "Four-tire truck (pick-up)"          = "Pickup truck",
  "Tractor/semi-trailer"               = "Semi truck",
  "Passenger van (seats < 9)"          = "Passenger van",
  "Single-unit truck (2-axle, 6-tire)" = "Single-unit truck, 2 axles",
  "Single-unit truck (>= 3 axles)"     = "Single-unit truck, 3+ axles",
  "All-terrain vehicle (ATV)"          = "ATV",
  "Cargo/panel van"                    = "Cargo van",
  "Truck/trailer"                      = "Truck with trailer"
)

involved <- vehicles |>
  inner_join(weather, by = "crash") |>
  mutate(
    weather = case_when(
      weather %in% c("Clear", "Cloudy")                         ~ weather,
      weather %in% c("Unknown", "Other (explain in narrative)") ~ NA,
      TRUE                                                      ~ weather_levels[3]
    )
  ) |>
  filter(!is.na(weather), type != "Unknown")

# The unit is the crash, not the vehicle. Five winter pile-ups have 44 to 96 vehicles each;
# counted by vehicle, they alone would decide the bad-weather share of semi trucks. A crash
# counts once for every type of vehicle in it, so a car hitting a semi is in both bars.
# Types with fewer than `min_crashes` crashes go into one bar: their shares rest on too few
# crashes to compare.
min_crashes <- 20
other_name  <- "All other types"

big_types <- involved |>
  distinct(crash, type) |>
  count(type) |>
  filter(n >= min_crashes) |>
  pull(type)

involved <- involved |>
  mutate(
    type = if_else(type %in% big_types, type, other_name),
    type = coalesce(type_names[type], type)
  ) |>
  distinct(crash, type, weather)

bars <- involved |>
  count(type, weather) |>
  complete(type, weather, fill = list(n = 0)) |>
  group_by(type) |>
  mutate(total = sum(n), ratio = n / total, clear_share = ratio[weather == "Clear"]) |>
  ungroup() |>
  mutate(weather = factor(weather, levels = weather_levels))

# Bars from the bottom up: the catch-all bar first, then by rising share of clear weather.
# The thickness is the log of the number of crashes, as in the original: a type with ten
# times the crashes is one unit thicker, so rare types stay readable.
positions <- bars |>
  distinct(type, total, clear_share) |>
  arrange(type != other_name, clear_share) |>
  mutate(
    width = log10(total),
    x     = cumsum(width) - width / 2,
    share_label = paste0(round(100 * clear_share), "%")
  )

bars <- bars |>
  left_join(select(positions, type, width, x), by = "type") |>
  # A count is printed where its segment is wide enough to hold it
  mutate(label = if_else(ratio >= 0.03, format(n, big.mark = ",", trim = TRUE), ""))

# All crashes with known weather, each counted once, for the subtitle
all_crashes <- involved |>
  distinct(crash, weather) |>
  count(weather) |>
  mutate(share = n / sum(n))

# Fonts and colours ----
main_font <- "Libre Franklin"
axis_font <- "Fira Sans"
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(axis_font)
showtext_auto()
showtext_opts(dpi = 300)

page  <- "#FDF9F3"
ink   <- "#2C2C2C"
muted <- "#666666"
# Checked for colour-blind separation and for contrast against the page
weather_colours <- setNames(c("#C4820E", "#12998A", "#3D52B8"), weather_levels)

# Texts ----
title <- "Motorcycles crash in clear weather, semi trucks get the worst of it"

pct_all <- function(w) round(100 * all_crashes$share[all_crashes$weather == w])

subtitle <- str_wrap(paste0(
  "The weather at the ", format(sum(all_crashes$n), big.mark = ","), " fatal crashes in Iowa from 2015 to 2025, by the type of vehicle involved. ",
  "A crash counts once for every type of vehicle in it. Of all crashes, ", pct_all("Clear"), "% were in clear weather and ",
  pct_all(weather_levels[3]), "% in rain, snow, fog or wind. Numbers are crashes; thicker bars are types with more crashes (log scale). ",
  "Types are ordered by their share in clear weather."
), 118)

caption <- paste0(
  "Source: Drivers and Vehicles Involved in Iowa Crashes and Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub ",
  "(datasets 17 and 13) · After a chart by Georgios Karamanis"
)

# Plot ----
top_edge <- sum(positions$width)

plot <- ggplot(bars, aes(x = x, y = n, fill = weather, width = width)) +
  # reverse = TRUE puts the first level, clear weather, on the left
  geom_col(position = position_fill(reverse = TRUE), colour = page, linewidth = 0.7) +
  geom_text(
    aes(label = label),
    position = position_fill(vjust = 0.5, reverse = TRUE),
    family = axis_font, fontface = "bold", colour = "white", size = 3.4
  ) +
  geom_text(
    data = positions, aes(x = x, y = -0.012, label = type), inherit.aes = FALSE,
    hjust = 1, family = main_font, size = 3.9,
    colour = if_else(positions$type == other_name, muted, ink)
  ) +
  geom_text(
    data = positions, aes(x = x, y = 1.012, label = share_label), inherit.aes = FALSE,
    hjust = 0, family = axis_font, size = 3.6, colour = ink
  ) +
  annotate(
    "text", x = top_edge + 0.55, y = 1.012, label = "in clear\nweather", hjust = 0, vjust = 0,
    family = axis_font, size = 3.1, colour = muted, lineheight = 0.9
  ) +
  scale_fill_manual(values = weather_colours, name = NULL) +
  coord_flip(clip = "off") +
  labs(title = title, subtitle = subtitle, caption = caption) +
  theme_void(base_size = 14, base_family = axis_font) +
  theme(
    legend.position      = "top",
    legend.justification = "left",
    legend.text          = element_text(size = 11, colour = ink, family = main_font),
    legend.key.size      = unit(0.42, "cm"),
    legend.margin        = margin(0, 0, 6, -188),
    plot.background      = element_rect(fill = page, colour = NA),
    plot.title           = element_text(face = "bold", size = 21, family = main_font, colour = ink, margin = margin(0, 0, 6, -190)),
    plot.subtitle        = element_text(size = 11.5, family = main_font, colour = ink, lineheight = 1.15, margin = margin(0, 0, 14, -190)),
    plot.caption         = element_text(colour = muted, size = 9, hjust = 1, margin = margin(12, 0, 0, 0)),
    plot.margin          = margin(20, 60, 14, 210)
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_vehicles.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_vehicles_thumb.png")

ggsave(out_png, plot, width = 12, height = 8, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_vehicles.md
bars |>
  select(type, weather, n, total) |>
  pivot_wider(names_from = weather, values_from = n) |>
  mutate(clear = round(100 * Clear / total, 1), bad = round(100 * .data[[weather_levels[3]]] / total, 1)) |>
  arrange(desc(clear)) |>
  print(n = Inf)
print(all_crashes)
