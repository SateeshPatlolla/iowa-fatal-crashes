# How old the drivers in Iowa's fatal crashes are, by the kind of vehicle they drove
# After Nicola Rennie, #30DayChartChallenge 2022 day 24 (day_24.R): one density curve per
# group, stacked as ridges, with the group's average written on each, in Financial Times colours
# The original has a ridge per decade. Here it is a ridge per vehicle type.
# Data: Vehicle Crashes in Iowa, vehicle level (Iowa Data Hub dataset 17)
# Run from the project root: Rscript R/iowa_fatal_crash_driver_ages.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
crash_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
if (!file.exists(crash_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")

# One row per vehicle in a fatal crash, so one row per driver
drivers <- read_csv(crash_file, col_select = c(year = crash_year, vehicle = vehicle_configuration, age = driver_age))
n_all <- nrow(drivers)

# Wrangling ----
drivers <- drivers |>
  mutate(
    # The 30 vehicle types of the source, reduced to the nine with enough drivers for a curve
    # (the next one down, cargo vans, has 46 drivers with a known age)
    group = case_when(
      vehicle == "Passenger car"                  ~ "Passenger car",
      vehicle == "Sport utility vehicle"          ~ "SUV",
      vehicle == "Four-tire truck (pick-up)"      ~ "Pickup",
      vehicle == "Tractor/semi-trailer"           ~ "Semi-trailer truck",
      vehicle == "Motorcycle"                     ~ "Motorcycle",
      vehicle == "Passenger van (seats < 9)"      ~ "Minivan",
      str_starts(vehicle, "Single-unit truck")    ~ "Single-unit truck",
      vehicle == "All-terrain vehicle (ATV)"      ~ "ATV",
      vehicle %in% c("Farm tractor", "Farm equipment") ~ "Farm machinery"
    )
  )
n_other <- sum(is.na(drivers$group))

# Age 200 is the source's code for "not known" (every train has it). Ages are blank in part
# of 2015. Eight drivers are recorded as younger than 14; they stay in.
drivers <- filter(drivers, !is.na(group))
n_no_age <- sum(is.na(drivers$age) | drivers$age > 110)
drivers <- filter(drivers, !is.na(age), age <= 110)

summary_data <- drivers |>
  group_by(group) |>
  summarise(
    n = n(), median = median(age), mean = mean(age),
    under25 = mean(age < 25), over65 = mean(age >= 65)
  ) |>
  # Youngest at the top, oldest at the bottom
  arrange(median, mean) |>
  mutate(row = rev(row_number()))

# One density curve per group. ggridges would do this in one line; it is not installed, so
# the curves are computed with density() and stacked by hand. The bandwidth is fixed at
# 4 years for every group so that the curves can be compared.
bandwidth <- 4
ages <- seq(0, 100, by = 0.25)
ridge_height <- 42   # a density of 0.024 becomes one row

ridges <- drivers |>
  group_by(group) |>
  reframe({
    d <- density(age, bw = bandwidth, from = min(ages), to = max(ages), n = length(ages))
    tibble(age = d$x, density = d$y)
  }) |>
  left_join(select(summary_data, group, row), by = "group") |>
  mutate(top = row + density * ridge_height)

# Fonts and colours ----
main_font <- "Roboto"
sysfonts::font_add_google(main_font)
showtext_auto()
showtext_opts(dpi = 300)

# The colours of the original, which are the Financial Times's
paper <- "#fff1e5"
fill  <- "#fea9a3"
line  <- "#990f3d"

# Texts ----
youngest <- summary_data[1, ]
oldest   <- summary_data[nrow(summary_data), ]
bike     <- filter(summary_data, group == "Motorcycle")
pct      <- function(x) paste0(round(100 * x), "%")

title <- "Car drivers in Iowa's fatal crashes skew young, farm drivers old"

subtitle <- str_wrap(paste0(
  "Age of the driver of every vehicle in a fatal crash, 2015 to early October 2026, by the kind of vehicle. ",
  "Half of the ", tolower(youngest$group), " drivers were ", youngest$median, " or younger and ", pct(youngest$under25),
  " were under 25. On ", tolower(oldest$group), ", half were ", oldest$median, " or older. ",
  "Motorcycle riders are the group in the middle of life: only ", pct(bike$under25), " were under 25 and ", pct(bike$over65), " were 65 or over. ",
  "These are all drivers involved, not only those who died or were at fault."
), 104)

caption <- "After a chart by N. Rennie | Data: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 17)"

# Plot ----
p <- ggplot() +
  theme(
    plot.background  = element_rect(fill = paper, colour = paper),
    panel.background = element_rect(fill = paper, colour = paper),
    axis.ticks       = element_blank(),
    panel.grid       = element_blank(),
    plot.margin      = margin(18, 20, 8, 10),
    text             = element_text(family = main_font, colour = "black"),
    axis.text.y      = element_text(size = 11, colour = "black", vjust = 0, lineheight = 1.05, margin = margin(r = 5)),
    axis.text.x      = element_text(size = 11, colour = "black", margin = margin(t = 5)),
    axis.title.x     = element_text(size = 11, margin = margin(8, 0, 5, 0)),
    plot.title       = element_text(size = 16, face = "bold", margin = margin(10, 0, 10, 0)),
    plot.subtitle    = element_text(size = 11, lineheight = 1.2, margin = margin(0, 0, 14, 0)),
    plot.caption     = element_text(size = 9, hjust = 0, margin = margin(5, 0, 0, 0)),
    plot.title.position   = "plot",
    plot.caption.position = "plot"
  )

# The ridges are drawn from the top row down, so that each one overlaps the one above it
for (r in sort(summary_data$row, decreasing = TRUE)) {
  p <- p +
    geom_ribbon(data = filter(ridges, row == r), aes(x = age, ymin = row, ymax = top), fill = fill) +
    geom_line(data = filter(ridges, row == r), aes(x = age, y = top), colour = line, linewidth = 0.8) +
    geom_line(data = filter(ridges, row == r), aes(x = age, y = row), colour = line, linewidth = 0.8)
}

p <- p +
  # geom_label() and not geom_text(): the pale box keeps the words readable where a ridge
  # runs behind them
  geom_label(
    data = summary_data, aes(x = 99.3, y = row + 0.36, label = paste0("Median: ", median)),
    hjust = 1, family = main_font, colour = line, fill = alpha(paper, 0.75), size = 3.8,
    label.size = 0, label.padding = unit(0.12, "lines")
  ) +
  scale_x_continuous(breaks = seq(0, 100, 10), limits = range(ages), expand = c(0, 0)) +
  scale_y_continuous(
    breaks = summary_data$row,
    labels = paste0(summary_data$group, "\n", format(summary_data$n, big.mark = ","), " drivers"),
    expand = expansion(add = c(0.15, 0.25))
  ) +
  labs(title = title, subtitle = subtitle, caption = caption, x = "Age of the driver", y = NULL)

# The black bar at the top left, the Financial Times's mark. The original adds it with
# cowplot; here the plot is printed to a PNG device and the bar is drawn on top with grid.
bar <- rectGrob(
  x = unit(0.14, "in"), y = unit(1, "npc"), width = unit(1, "in"), height = unit(0.07, "in"),
  hjust = 0, vjust = 1, gp = gpar(col = "black", fill = "black")
)

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_driver_ages.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_driver_ages_thumb.png")

png(out_png, width = 8, height = 10, units = "in", res = 300)
print(p)
grid.draw(bar)
dev.off()

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_driver_ages.md
cat("Vehicles in file:", n_all, " other vehicle types:", n_other, " no age:", n_no_age, " used:", nrow(drivers), "\n")
print(summary_data)
