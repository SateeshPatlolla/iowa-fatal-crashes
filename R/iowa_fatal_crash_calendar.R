# Road deaths in Iowa day by day, 2015 to 2025: one row per year, one column per month
# After Georgios Karamanis, TidyTuesday 2025 week 40 (cranes.R): daily bars in a grid of
# years and months, the peak season in a block on the left, the rest on the right, and a map
# with a short text between them
# Data: Vehicle Crashes in Iowa (dataset 13) for the dates, Drivers and Vehicles Involved in
# Iowa Crashes (dataset 17) for the positions, both from the Iowa Data Hub
# Run from the project root: Rscript R/iowa_fatal_crash_calendar.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
dates_file <- "data/iowa_fatal_crash_dates_2026-10-10.csv"
sites_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
if (!file.exists(dates_file)) stop("Extract not found. Run R/iowa_fatal_crash_dates_extract.R first.")
if (!file.exists(sites_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")

crashes <- read_csv(dates_file, col_select = c(crash = case_number, crash_on, deaths = fatalities)) |>
  mutate(date = as.Date(substr(crash_on, 1, 10)))

# One row per vehicle in this file; the position is the same on every vehicle of a crash
sites <- read_csv(sites_file, col_select = c(crash = vehicle_crash_key, location = crash_location)) |>
  distinct(crash, location)

# Wrangling ----

# One row per calendar day, including the days on which nobody died
days <- tibble(date = seq(as.Date("2015-01-01"), as.Date("2025-12-31"), by = "day")) |>
  left_join(
    crashes |> group_by(date) |> summarise(deaths = sum(deaths), crashes = n()),
    by = "date"
  ) |>
  mutate(
    deaths  = coalesce(deaths, 0),
    crashes = coalesce(crashes, 0L),
    year    = as.integer(format(date, "%Y")),
    month   = factor(month.name[as.integer(format(date, "%m"))], levels = month.name),
    day     = as.integer(format(date, "%d"))
  )

# The block on the left holds the peak season: the two months with the most deaths per day
by_month <- days |>
  group_by(month) |>
  summarise(per_day = mean(deaths), quiet = mean(deaths == 0), total = sum(deaths))

peak_months <- by_month |> slice_max(per_day, n = 2) |> arrange(month) |> pull(month) |> as.character()

# Numbers for the text
worst      <- slice_max(days, deaths, n = 1)
peak_rate  <- max(by_month$per_day)
peak_name  <- as.character(by_month$month[which.max(by_month$per_day)])
winter     <- mean(days$deaths[days$month %in% c("January", "February", "March")])
quiet_all  <- round(100 * mean(days$deaths == 0))
quiet_peak <- round(100 * by_month$quiet[which.max(by_month$per_day)])

# Longest unbroken runs of days without and with a death. rle() ("run length encoding")
# turns TRUE TRUE FALSE TRUE into lengths 2, 1, 1 and values TRUE, FALSE, TRUE.
runs       <- rle(days$deaths == 0)
run_quiet  <- max(runs$lengths[runs$values])
run_deadly <- max(runs$lengths[!runs$values])

# Crash positions for the map. The location arrives as text: "POINT(lon lat)".
on_map <- crashes |>
  left_join(sites, by = "crash") |>
  mutate(
    lon  = as.numeric(str_match(location, "\\((-?[0-9.]+) ")[, 2]),
    lat  = as.numeric(str_match(location, " (-?[0-9.]+)\\)")[, 2]),
    peak = month.name[as.integer(format(date, "%m"))] %in% peak_months
  ) |>
  # Five crashes have no usable position (0, 0)
  filter(lon < -85, lat > 35) |>
  # Peak-season crashes are drawn last, on top
  arrange(peak)

sf_use_s2(FALSE)
states  <- ne_download(scale = 10, type = "admin_1_states_provinces", category = "cultural", returnclass = "sf", load = TRUE) |>
  filter(admin == "United States of America", !name %in% c("Alaska", "Hawaii"))
ia_poly <- filter(states, name == "Iowa")

# Fonts and colours ----
main_font <- "Libre Franklin"
axis_font <- "Fira Sans"
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(axis_font)
showtext_auto()
showtext_opts(dpi = 300)

page  <- "grey99"
ink   <- "#1A1A1A"
muted <- "#6B6B6B"
sky   <- "#E3F2FD"
# MetBrewer's OKeeffe2 palette, as in the original: pale = few, dark = many
okeeffe <- c("#FBE3C2", "#F2C88F", "#ECB27D", "#E69C6B", "#D37750", "#B9563F", "#92351E")

# Texts ----
title <- paste(peak_name, "is the deadliest month on Iowa roads")

subtitle <- str_wrap(paste0(
  "Each bar is one day from 2015 to 2025; its height and colour show how many people died in crashes that day. A gap is a day without a death. ",
  peak_months[1], " and ", peak_months[2], ", the two months with the most deaths per day, are on the left, the other ten on the right. The bottom row is thinner: 2025 was Iowa's lowest year on record."
), 190)

caption <- "Source: Vehicle Crashes in Iowa and Drivers and Vehicles Involved in Iowa Crashes, Iowa DOT via Iowa Data Hub · After a chart by Georgios Karamanis"

story <- paste0(
  "**", format(sum(days$deaths), big.mark = ","), " people died** in ", format(nrow(crashes), big.mark = ","),
  " crashes in these 11 years, about one a day. The toll rises through spring and peaks in ", peak_name, " at ",
  format(round(peak_rate, 2), nsmall = 2), " deaths a day, nearly twice the ", format(round(winter, 2), nsmall = 2),
  " of January to March.<br><br>Nobody died on ", quiet_all, "% of all days, but on only ", quiet_peak, "% of days in ", peak_name,
  ". The worst day was ", as.integer(format(worst$date, "%d")), " ", format(worst$date, "%B %Y"), ": ", worst$deaths, " deaths in ", worst$crashes,
  " separate crashes.<br><br>The longest spell without a death lasted ", run_quiet, " days; the longest run of days with at least one, ", run_deadly,
  ".<br><br><span style='color:#B9563F'>**Red**</span> points on the map are the crashes of ", peak_months[1], " and ", peak_months[2], "."
)

# Calendar blocks ----
# The same plot is needed twice, for the peak months and for the rest, so it is a function.
# Both blocks must share the y scale and the colour scale, or bars could not be compared across.
calendar <- function(data, year_labels) {
  ggplot(filter(data, deaths > 0)) +
    geom_col(aes(x = day, y = deaths, fill = deaths), width = 0.9) +
    scale_fill_gradientn(colours = okeeffe, limits = c(0, max(days$deaths)), breaks = c(1, 3, 5, 7, 9), name = "Deaths that day") +
    scale_x_continuous(limits = c(0.5, 31.5), breaks = c(1, 10, 20, 30)) +
    scale_y_continuous(limits = c(0, max(days$deaths))) +
    # switch = "y" moves the year strips from the right to the left
    facet_grid(vars(year), vars(month), switch = "y") +
    coord_cartesian(expand = FALSE, clip = "off") +
    theme_minimal(base_family = main_font) +
    theme(
      plot.background   = element_rect(fill = page, colour = NA),
      panel.background  = element_rect(fill = sky, colour = NA),
      panel.grid        = element_blank(),
      panel.spacing     = unit(3, "pt"),
      strip.text.x      = element_text(face = "bold", size = 10, colour = ink),
      strip.text.y.left = if (year_labels) element_text(angle = 0, size = 10, colour = ink) else element_blank(),
      axis.title        = element_blank(),
      axis.text.y       = element_blank(),
      axis.text.x       = element_text(family = axis_font, size = 7, colour = muted)
    )
}

left  <- calendar(filter(days, month %in% peak_months), year_labels = TRUE) +
  # Name the worst day inside its panel. The data frame carries year and month so that
  # facet_grid() knows which panel the label belongs to.
  geom_text(
    data = mutate(worst, label = paste0(day, " ", substr(month, 1, 3), ": ", deaths, " deaths")),
    aes(x = day - 1.2, y = deaths - 1.2, label = label),
    hjust = 1, family = axis_font, size = 2.6, colour = ink
  )
right <- calendar(filter(days, !month %in% peak_months), year_labels = FALSE)

# Middle column ----
iowa_map <- ggplot() +
  geom_sf(data = ia_poly, fill = "#F7F4EA", colour = "#B9AE9A", linewidth = 0.3) +
  geom_point(data = on_map, aes(x = lon, y = lat, colour = peak), size = 0.2) +
  scale_colour_manual(values = c(`FALSE` = "#C9C2B4", `TRUE` = "#B9563F"), guide = "none") +
  coord_sf(clip = "off") +
  theme_void()

locator <- ggplot() +
  geom_sf(data = states, fill = "#F7F4EA", colour = "#B9AE9A", linewidth = 0.1) +
  geom_sf(data = ia_poly, fill = "#B9563F", colour = NA) +
  coord_sf(crs = "ESRI:102003") +
  theme_void()

# geom_textbox() wraps the text to the width of the panel and understands **bold** and <br>
story_box <- ggplot() +
  geom_textbox(
    aes(x = 0, y = 1, label = story),
    hjust = 0, vjust = 1, width = unit(1, "npc"), box.colour = NA, fill = NA,
    box.padding = unit(c(0, 0, 0, 0), "pt"),
    family = main_font, size = 3.3, lineheight = 1.25, colour = ink
  ) +
  scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
  theme_void()

middle <- locator / iowa_map / story_box + plot_layout(heights = c(0.55, 1, 2.6))

# Assemble ----
final <- (left | middle | right) +
  plot_layout(widths = c(2, 2, 10), guides = "collect") +
  plot_annotation(
    title = title, subtitle = subtitle, caption = caption,
    theme = theme(plot.margin = margin(14, 14, 10, 14))
  ) &
  theme(
    legend.position      = "top",
    legend.key.width     = unit(3, "lines"),
    legend.key.height    = unit(0.5, "lines"),
    legend.title         = element_text(family = main_font, size = 9, colour = ink, vjust = 0.2),
    legend.text          = element_text(family = axis_font, size = 8, colour = ink),
    legend.margin        = margin(0, 0, 0, 0),
    plot.background      = element_rect(fill = page, colour = NA),
    plot.title           = element_text(family = main_font, face = "bold", size = 20, colour = ink),
    plot.subtitle        = element_text(family = main_font, size = 11, colour = "#333333", lineheight = 1.15),
    plot.caption         = element_text(family = main_font, size = 8.5, colour = muted)
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_calendar.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_calendar_thumb.png")

ggsave(out_png, final, width = 17, height = 9.5, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_calendar.md
print(by_month)
