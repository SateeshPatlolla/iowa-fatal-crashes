# Which weekdays are deadliest on Iowa roads, 2015 to 2025
# After Georgios Karamanis, TidyTuesday 2025 week 17 (daily_accidents.R): one panel per weekday,
# deaths per day on x, the same figure against its 61-day average on y, colour by point density
# Data: Vehicle Crashes in Iowa, Iowa Data Hub dataset 13
# Run from the project root: Rscript R/iowa_fatal_crash_days.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
# The crash dates live in dataset 13, not in dataset 17 that the map uses. The repo keeps an
# extract of the fatal crashes; R/iowa_fatal_crash_dates_extract.R rebuilds it.
csv_file <- "data/iowa_fatal_crash_dates_2026-10-10.csv"
if (!file.exists(csv_file)) stop("Extract not found. Run R/iowa_fatal_crash_dates_extract.R first.")

crashes <- read_csv(csv_file, col_select = c(crash = case_number, crash_on, deaths = fatalities)) |>
  # crash_on arrives as "2018-04-13 00:00:00 UTC"; the time part is always midnight
  mutate(date = as.Date(substr(crash_on, 1, 10)))

# Wrangling ----

# One row per calendar day. A day with no fatal crash is missing from the data, so build the
# full calendar first and fill the gaps with zero.
days <- tibble(date = seq(as.Date("2015-01-01"), as.Date("2025-12-31"), by = "day")) |>
  left_join(count(crashes, date, wt = deaths, name = "deaths"), by = "date") |>
  mutate(
    deaths = coalesce(deaths, 0L),
    # Centred 61-day mean: the day itself plus 30 days either side, as in the original.
    # stats::filter() returns NA where the window runs off either end of the series.
    rolling = as.numeric(stats::filter(deaths, rep(1 / 61, 61), sides = 2)),
    # "%u" is the ISO weekday number, 1 = Monday. It does not depend on the system language.
    weekday = factor(
      format(date, "%u"), levels = as.character(1:7),
      labels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    ),
    month = format(date, "%Y-%m")
  )

# The original plots one point per day, which works for the whole United States (about 100
# deaths a day). Iowa has fewer than one, and 45% of days have none, so a daily point would
# sit on 0, 1 or 2 and a ratio of zero cannot go on a log scale. One point here is therefore
# one weekday within one month: "the Saturdays of July 2019".
points <- days |>
  group_by(month, weekday) |>
  summarise(n_days = n(), deaths = sum(deaths), expected = sum(rolling), .groups = "drop") |>
  # January 2015 and December 2025 have no complete 61-day window
  filter(!is.na(expected)) |>
  mutate(
    per_day = deaths / n_days,
    ratio   = deaths / expected
  )

# Colour by how crowded the neighbourhood of each point is (what ggpointdensity does):
# put both axes on a 0 to 1 scale, then count the points of the same panel within a small radius
rescale01 <- function(x) (x - min(x)) / (max(x) - min(x))

points <- points |>
  mutate(x01 = rescale01(per_day), y01 = rescale01(ratio)) |>
  group_by(weekday) |>
  mutate(neighbours = rowSums(as.matrix(dist(cbind(x01, y01))) < 0.08)) |>
  ungroup() |>
  # Draw the crowded points last so they sit on top
  arrange(neighbours)

# Numbers for the text
all_days  <- mean(days$deaths)
by_day    <- days |> group_by(weekday) |> summarise(per_day = mean(deaths))
above     <- points |> group_by(weekday) |> summarise(share = mean(ratio > 1))
rate      <- function(d) by_day$per_day[by_day$weekday == d]
share     <- function(d) round(100 * above$share[above$weekday == d])
zero_days <- round(100 * mean(days$deaths == 0))

# Fonts and colours ----
main_font <- "Libre Franklin"
axis_font <- "Fira Sans"
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(axis_font)
showtext_auto()
showtext_opts(dpi = 300)

ink   <- "#1A1A1A"
muted <- "#6B6B6B"
# MetBrewer's Hokusai1 palette, reversed as in the original: blue = sparse, brown = crowded
hokusai <- c("#224B5E", "#94B594", "#EDC775", "#E09351", "#DF7E66", "#B75347", "#6D2F20")

# Texts ----
title <- "Fridays and Saturdays are the deadliest days on Iowa roads"

subtitle <- str_wrap(paste0(
  "Each point is one weekday within one month, for example the Saturdays of July 2019, from 2015 to 2025. ",
  "Left to right is deaths per day. Up and down compares that with the 61-day average around the same dates: ",
  "above the solid line the weekday was deadlier than the days around it. The Saturdays of a month beat that average ",
  share("Saturday"), "% of the time, the Tuesdays ", share("Tuesday"), "%. ",
  "The dashed line is the average for all days, ", format(round(all_days, 2), nsmall = 2), " deaths."
), 150)

caption <- "Source: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 13) · After a chart by Georgios Karamanis"

# Plot ----
scatter <- ggplot(points, aes(x = per_day, y = ratio)) +
  geom_hline(yintercept = 1, linewidth = 0.4) +
  geom_vline(xintercept = all_days, linetype = "dashed", linewidth = 0.4) +
  geom_point(aes(colour = neighbours), size = 1.5) +
  scale_colour_gradientn(colours = hokusai) +
  scale_x_continuous(breaks = 0:4) +
  # A month's weekdays can have no deaths at all, so the ratio axis is linear: a log scale
  # (the original's choice) has no place for zero
  scale_y_continuous(breaks = 0:4, labels = function(x) paste0(x, "x")) +
  # With seven panels the last slot of the 2 x 4 grid stays empty; the bar chart goes there
  facet_wrap(vars(weekday), nrow = 2) +
  labs(
    title = title, subtitle = subtitle, caption = caption,
    x = "Deaths per day", y = "Deaths compared with the 61-day average"
  ) +
  coord_cartesian(clip = "off") +
  theme_bw(base_family = main_font) +
  theme(
    legend.position  = "none",
    plot.background  = element_rect(fill = "grey97", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    panel.grid       = element_blank(),
    strip.background = element_rect(fill = "#D1E3F3", colour = "black"),
    strip.text       = element_text(face = "bold", colour = "grey10", size = 11),
    axis.text        = element_text(family = axis_font, colour = ink),
    axis.title       = element_text(colour = ink),
    plot.title       = element_text(size = 20, face = "bold", colour = ink),
    plot.subtitle    = element_text(size = 10.5, lineheight = 1.15, colour = "#333333", margin = margin(0, 0, 16, 0)),
    plot.caption     = element_text(size = 8.5, colour = muted, margin = margin(10, 0, 0, 0)),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    plot.margin      = margin(12, 12, 10, 12)
  )

# The plain answer, for the empty eighth slot
bars <- ggplot(by_day, aes(x = per_day, y = reorder(weekday, desc(weekday)))) +
  geom_col(aes(fill = weekday %in% c("Friday", "Saturday")), width = 0.7) +
  geom_text(
    aes(label = format(round(per_day, 2), nsmall = 2)),
    hjust = 1.15, family = axis_font, size = 3.1, colour = "white"
  ) +
  scale_fill_manual(values = c(`TRUE` = "#B75347", `FALSE` = "#224B5E"), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Deaths per day, all 11 years", x = NULL, y = NULL) +
  theme_minimal(base_family = main_font) +
  theme(
    panel.grid    = element_blank(),
    axis.text.x   = element_blank(),
    axis.text.y   = element_text(colour = ink, size = 9),
    plot.title    = element_text(face = "bold", size = 10.5, colour = ink),
    plot.title.position = "plot",
    plot.background = element_rect(fill = "grey97", colour = NA)
  )

final <- scatter +
  inset_element(bars, left = 0.765, right = 0.995, bottom = 0.075, top = 0.44, align_to = "full")

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_days.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_days_thumb.png")

ggsave(out_png, final, width = 11, height = 7, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")
