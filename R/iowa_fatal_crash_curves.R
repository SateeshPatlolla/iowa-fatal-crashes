# Time of day of Iowa's fatal crashes, one curve per weekday, 2015 to 2025
# After Georgios Karamanis, TidyTuesday 2025 week 37 (passport_index.R): one density curve per
# group, all in grey except the two that differ most, each with a note at its peak
# Data: Vehicle Crashes in Iowa, Iowa Data Hub dataset 13
# Run from the project root: Rscript R/iowa_fatal_crash_curves.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
csv_file <- "data/iowa_fatal_crash_dates_2026-10-10.csv"
if (!file.exists(csv_file)) stop("Extract not found. Run R/iowa_fatal_crash_dates_extract.R first.")

crashes <- read_csv(
  csv_file,
  col_select = c(crash = case_number, crash_on, time = timestr),
  col_types = cols(timestr = col_character())
)

# Wrangling ----
day_names <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")

crashes <- crashes |>
  mutate(
    date    = as.Date(substr(crash_on, 1, 10)),
    hour    = as.numeric(substr(time, 1, 2)) + as.numeric(substr(time, 4, 5)) / 60,
    # "%u" is the ISO weekday number, 1 = Monday
    weekday = factor(format(date, "%u"), levels = as.character(1:7), labels = day_names)
  )

# The original draws one curve per year. Here the years lie on top of each other (the time of
# day of fatal crashes did not move between 2015 and 2025), so the curves are the weekdays,
# where the shape does change.

# The clock is a circle: 23:50 and 00:10 are neighbours. A plain density treats 0 and 24 as
# walls and sags at both ends. The fix is to lay a copy of the data on either side (one day
# earlier, one day later), estimate over all three, and keep the middle day. The curve then
# covers three days, so it is multiplied by 3 to make the middle day add up to 1 again.
# Every weekday gets the same bandwidth so that the curves are comparable.
bandwidth <- 1  # hours

day_curve <- function(hour) {
  d <- density(c(hour - 24, hour, hour + 24), bw = bandwidth, from = 0, to = 24, n = 481)
  tibble(hour = d$x, density = d$y * 3)
}

curves <- crashes |>
  group_by(weekday) |>
  summarise(curve = list(day_curve(hour)), n = n()) |>
  unnest(curve)

# The two weekdays to highlight: the largest and smallest share of crashes before 5 am
early <- crashes |>
  group_by(weekday) |>
  summarise(n = n(), share = mean(hour < 5)) |>
  arrange(desc(share))

day_hi <- as.character(early$weekday[1])
day_lo <- as.character(early$weekday[nrow(early)])
pct    <- function(d) round(100 * early$share[early$weekday == d])

# Where each note points: the highest point of the curve inside a window of hours
peak <- function(day, from, to) {
  curves |>
    filter(weekday == day, hour >= from, hour <= to) |>
    slice_max(density, n = 1)
}

# A smoothed curve cannot place its peak to the minute, so the notes give the nearest hour
clock <- function(h) {
  hh <- round(h) %% 24
  paste0(ifelse(hh %% 12 == 0, 12, hh %% 12), ifelse(hh < 12, " am", " pm"))
}

peak_hi <- peak(day_hi, 0, 6)
peak_lo <- peak(day_lo, 12, 20)

notes <- bind_rows(
  peak_hi |> mutate(
    label = str_wrap(paste0(
      "On ", day_hi, "s, ", pct(day_hi), "% of fatal crashes happen before 5 am, the end of Saturday night. The curve peaks at about ",
      clock(peak_hi$hour), "."), 34),
    x = 3.6, y = density + 0.012, hjust = 0
  ),
  peak_lo |> mutate(
    label = str_wrap(paste0(
      "On ", day_lo, "s only ", pct(day_lo), "% happen before 5 am. The curve follows the working day and peaks at about ",
      clock(peak_lo$hour), "."), 30),
    x = 19.3, y = density + 0.009, hjust = 0
  )
)

# The curves are close together where they end, so the two names go next to the peaks
names_at <- bind_rows(
  peak_hi |> mutate(x = hour - 0.25, y = density + 0.004, hjust = 1),
  peak_lo |> mutate(x = hour - 0.3, y = density + 0.004, hjust = 1)
)

# Fonts and colours ----
main_font <- "Libre Franklin"
axis_font <- "Fira Sans"
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(axis_font)
showtext_auto()
showtext_opts(dpi = 300)

page    <- "#FDF9F3"
ink     <- "#2C2C2C"
muted   <- "#666666"
grey    <- "#DDD4C7"
col_hi  <- "#7C2D12"
col_lo  <- "#1E40AF"
col_txt <- "#9A7209"
day_colours <- setNames(c(col_hi, col_lo), c(day_hi, day_lo))

# Texts ----
title <- "Sunday's fatal crashes come before dawn"

subtitle <- str_wrap(paste0(
  "Time of day of the ", format(nrow(crashes), big.mark = ","), " fatal crashes in Iowa from 2015 to 2025, one curve per day of the week. ",
  "The higher the curve, the larger the share of that day's crashes at that hour. Five days are in grey; ",
  "the two that differ most are in colour. The area under every curve is the same."
), 112)

caption <- "Source: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 13) · After a chart by Georgios Karamanis"

# Plot ----
highlighted <- filter(curves, weekday %in% c(day_hi, day_lo))

plot <- ggplot(mapping = aes(x = hour, y = density, group = weekday)) +
  # Grey first, colour on top: this is what gghighlight does in the original
  geom_line(data = filter(curves, !weekday %in% c(day_hi, day_lo)), colour = grey, linewidth = 0.5) +
  geom_line(data = highlighted, aes(colour = weekday), linewidth = 1.1) +
  geom_segment(
    data = notes, aes(x = hour, xend = x - 0.15, y = density, yend = y - 0.001, group = NULL),
    colour = col_txt, linewidth = 0.3
  ) +
  geom_point(data = notes, aes(colour = weekday), size = 2.2) +
  geom_text(
    data = notes, aes(x = x, y = y, label = label, hjust = hjust),
    vjust = 0.5, family = main_font, fontface = "bold", colour = col_txt, size = 4, lineheight = 1
  ) +
  geom_text(
    data = names_at, aes(x = x, y = y, label = weekday, colour = weekday, hjust = hjust),
    family = main_font, fontface = "bold", size = 4.2
  ) +
  scale_colour_manual(values = day_colours) +
  scale_x_continuous(
    breaks = seq(0, 24, 3), expand = c(0.01, 0),
    labels = c("Midnight", "3 am", "6 am", "9 am", "Noon", "3 pm", "6 pm", "9 pm", "Midnight")
  ) +
  # Density is "share per hour": 0.06 means 6% of the day's crashes fall in each hour around there
  scale_y_continuous(
    breaks = seq(0, 0.1, 0.02), labels = function(y) paste0(round(100 * y), "%"), position = "right",
    limits = c(0, NA), expand = expansion(mult = c(0, 0.12))
  ) +
  coord_cartesian(clip = "off") +
  labs(
    title = title, subtitle = subtitle, caption = caption,
    x = "Time of the crash", y = "Share of the day's fatal crashes per hour"
  ) +
  theme_minimal(base_size = 14, base_family = axis_font) +
  theme(
    legend.position    = "none",
    plot.background    = element_rect(fill = page, colour = NA),
    plot.title         = element_text(face = "bold", size = 22, family = main_font, colour = ink),
    plot.subtitle      = element_text(size = 12, family = main_font, colour = ink, lineheight = 1.15, margin = margin(4, 0, 14, 0)),
    plot.caption       = element_text(colour = muted, size = 9.5, margin = margin(12, 0, 0, 0)),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.text.y.right  = element_text(size = 9, colour = muted),
    axis.text.x        = element_text(colour = ink),
    axis.title         = element_text(colour = ink, size = 12),
    plot.margin        = margin(20, 20, 16, 20)
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_curves.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_curves_thumb.png")

ggsave(out_png, plot, width = 10, height = 8, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_curves.md
print(early)
