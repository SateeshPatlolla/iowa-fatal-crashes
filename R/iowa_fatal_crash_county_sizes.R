# Road death rates of Iowa's counties, grouped by how many people live in them, 2015 to 2024
# After Nicola Rennie, #30DayChartChallenge 2024 day 6 (day_06.R): a "raincloud" per group,
# with the density curve above the line, one dot per observation below it, and the median
# with two intervals on the line
# The original has a dot per country and a row per level of schooling. Here it is a dot per
# county and a row per county size.
# Data: Vehicle Crashes in Iowa (Iowa Data Hub dataset 13) and US Census Bureau county
# population estimates
# Run from the project root: Rscript R/iowa_fatal_crash_county_sizes.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
crash_file <- "data/iowa_fatal_crash_dates_2026-10-10.csv"
pop_file   <- "data/iowa_county_population_2015_2024.csv"
if (!file.exists(crash_file)) stop("Extract not found. Run R/iowa_fatal_crash_dates_extract.R first.")

crashes <- read_csv(crash_file, col_select = c(crash_on, county_name, deaths = fatalities))
population <- read_csv(pop_file)

# Wrangling ----

# The same rate as in R/iowa_fatal_crash_counties.R: all road deaths of 2015 to 2024 in the
# county over the sum of its ten yearly population estimates
name_key <- function(x) str_remove_all(toupper(x), "[^A-Z ]")

county_deaths <- crashes |>
  mutate(year = as.integer(substr(crash_on, 1, 4)), key = name_key(county_name)) |>
  filter(year <= 2024, !is.na(county_name)) |>
  group_by(key) |>
  summarise(deaths = sum(deaths))

size_levels <- c("Under 10,000 residents", "10,000 to 20,000", "20,000 to 50,000", "50,000 or more")

counties <- population |>
  mutate(key = name_key(county)) |>
  group_by(key, county) |>
  summarise(resident_years = sum(population), residents = last(population), .groups = "drop") |>
  left_join(county_deaths, by = "key") |>
  mutate(
    deaths = coalesce(deaths, 0),
    rate   = 1e5 * deaths / resident_years,
    # Residents in 2024. The four classes are a choice; see docs/iowa_fatal_crash_county_sizes.md
    size   = cut(residents, breaks = c(0, 10000, 20000, 50000, Inf), labels = size_levels, right = FALSE),
    row    = as.integer(size)
  )

# ggdist draws all three parts of the original in two lines. It is not installed, so each
# part is built here.

# 1. The slab: a density curve per group, above the line. Its height is scaled so that the
# tallest curve takes 0.45 of a row.
bandwidth <- 2
grid <- seq(0, 55, by = 0.1)
slabs <- counties |>
  group_by(size, row) |>
  reframe({
    d <- density(rate, bw = bandwidth, from = min(grid), to = max(grid), n = length(grid))
    tibble(rate = d$x, density = d$y)
  }) |>
  # Cut each curve where it has run out, so that it does not trail along the whole row
  filter(density > 0.0005)
slab_scale <- 0.45 / max(slabs$density)
slabs <- mutate(slabs, top = row + density * slab_scale)

# 2. The dots: one per county, below the line. Counties are put into bins one rate unit
# wide and stacked downwards inside their bin.
bin_width <- 1
dot_step  <- 0.058   # distance between two stacked dots, in rows
dots <- counties |>
  mutate(bin = floor(rate / bin_width) * bin_width + bin_width / 2) |>
  group_by(size, bin) |>
  arrange(rate, .by_group = TRUE) |>
  mutate(y = row - 0.075 - (row_number() - 1) * dot_step) |>
  ungroup()

# 3. The interval: the median, the middle 66% (thick) and the middle 95% (thin) of the
# counties in the group. These are ggdist's defaults.
intervals <- counties |>
  group_by(size, row) |>
  summarise(
    n = n(), median = median(rate),
    lo66 = quantile(rate, 0.17), hi66 = quantile(rate, 0.83),
    lo95 = quantile(rate, 0.025), hi95 = quantile(rate, 0.975),
    # The group as one place: all its deaths over all its residents
    pooled = 1e5 * sum(deaths) / sum(resident_years),
    .groups = "drop"
  )

# The county with the highest rate in each group, named next to its dot
named <- dots |>
  group_by(size) |>
  slice_max(rate, n = 1) |>
  ungroup()

# Fonts and colours ----
body_font  <- "Roboto"
title_font <- "Roboto Slab"
sysfonts::font_add_google(body_font)
sysfonts::font_add_google(title_font)
showtext_auto()
showtext_opts(dpi = 300)

bg_col   <- "grey95"
text_col <- "black"
# The first four colours of CARTO's "Bold" (rcartocolor is not installed)
cols_vec <- setNames(c("#7F3C8D", "#11A579", "#3969AC", "#F2B701"), size_levels)

# Texts ----
r1 <- function(x) format(round(x, 1), nsmall = 1)
small <- intervals[1, ]
large <- intervals[nrow(intervals), ]

title <- "Iowa's road death rates fall with county size"
st <- paste0(
  "Each dot is one of Iowa's 99 counties, placed by its road deaths per 100,000 residents a year from 2015 to 2024. ",
  "The curve shows where the dots pile up. The black dot is the middle county of its group, the thick line the middle two thirds, the thin line nearly all. ",
  "The middle county with under 10,000 residents had ", r1(small$median), "; the middle county with 50,000 or more had ", r1(large$median),
  ". Small counties also differ far more from each other."
)
cap <- "**Data**: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 13); US Census Bureau<br>**Graphic**: after a chart by Nicola Rennie"

# Plot ----
ticks <- data.frame(x = seq(10, 50, 10))

final <- ggplot() +
  # Grid lines and their labels are drawn by hand, as in the original, so that the labels
  # can sit inside the panel under the lowest row
  geom_segment(data = ticks, aes(x = x, xend = x, y = 0.42, yend = 4.6), colour = alpha(text_col, 0.2), linewidth = 0.3) +
  geom_text(data = ticks, aes(x = x, y = 0.33, label = x), family = body_font, size = 3.1) +
  geom_ribbon(data = slabs, aes(x = rate, ymin = row, ymax = top, fill = size, group = size), alpha = 0.5) +
  geom_line(data = slabs, aes(x = rate, y = top, colour = size, group = size), linewidth = 0.4) +
  geom_point(data = dots, aes(x = bin, y = y, fill = size), shape = 21, colour = bg_col, stroke = 0.25, size = 1.75) +
  geom_segment(data = intervals, aes(x = lo95, xend = hi95, y = row, yend = row), linewidth = 0.45, colour = text_col) +
  geom_segment(data = intervals, aes(x = lo66, xend = hi66, y = row, yend = row), linewidth = 1.3, colour = text_col) +
  geom_point(data = intervals, aes(x = median, y = row), size = 2.2, colour = text_col) +
  geom_text(
    # To the right of the dot, or to the left where the right would leave the panel
    data = named, aes(x = bin + ifelse(bin > 45, -0.9, 0.9), y = y, label = county, hjust = ifelse(bin > 45, 1, 0)),
    family = body_font, size = 2.6, colour = text_col
  ) +
  scale_fill_manual(values = cols_vec) +
  scale_colour_manual(values = cols_vec) +
  scale_x_continuous(limits = c(0, 55), expand = c(0, 0)) +
  scale_y_continuous(
    breaks = intervals$row,
    labels = paste0(str_wrap(intervals$size, 12), "\n(", intervals$n, " counties)"),
    limits = c(0.25, 4.6), expand = c(0, 0)
  ) +
  labs(x = "Road deaths per 100,000 residents a year", y = NULL, title = title, subtitle = st, caption = cap) +
  theme_minimal(base_size = 9, base_family = body_font) +
  theme(
    plot.margin      = margin(8, 12, 6, 10),
    plot.background  = element_rect(fill = bg_col, colour = bg_col),
    panel.background = element_rect(fill = bg_col, colour = bg_col),
    plot.title       = element_textbox_simple(colour = text_col, family = title_font, face = "bold", size = rel(1.55), lineheight = 1.05, margin = margin(b = 8, t = 6)),
    plot.subtitle    = element_textbox_simple(colour = text_col, lineheight = 1.25, margin = margin(b = 4)),
    plot.caption     = element_textbox_simple(colour = text_col, size = rel(0.8), lineheight = 1.25, margin = margin(t = 6, b = 2)),
    axis.text.x      = element_blank(),
    axis.title.x     = element_text(colour = text_col, size = rel(0.95), margin = margin(t = 0)),
    axis.text.y      = element_text(colour = text_col, lineheight = 1.05, size = rel(1), margin = margin(r = 2)),
    panel.grid       = element_blank(),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    legend.position  = "none"
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_county_sizes.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_county_sizes_thumb.png")

ggsave(out_png, final, width = 5, height = 7, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_county_sizes.md
print(as.data.frame(intervals), digits = 3)
print(select(named, size, county, rate))
cat("Largest dot stack:", max(count(dots, size, bin)$n), "\n")
cat("Rank correlation of rate with residents:", round(cor(counties$rate, counties$residents, method = "spearman"), 2), "\n")
