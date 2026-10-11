# Road death rates by Iowa DOT district and, inside the worst district, by county, 2015 to 2024
# After Georgios Karamanis, TidyTuesday 2025 week 48 (spi_indicators.R): on the left one line
# per group with one group highlighted, on the right a small panel for every member of that
# group, drawn against all the other members
# Data: Vehicle Crashes in Iowa (Iowa Data Hub dataset 13) and US Census Bureau county
# population estimates
# Run from the project root: Rscript R/iowa_fatal_crash_districts.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
crash_file <- "data/iowa_fatal_crash_dates_2026-10-10.csv"
pop_file   <- "data/iowa_county_population_2015_2024.csv"
if (!file.exists(crash_file)) stop("Extract not found. Run R/iowa_fatal_crash_dates_extract.R first.")

crashes <- read_csv(
  crash_file,
  col_select = c(crash = case_number, crash_on, district, county_name, deaths = fatalities)
)
population <- read_csv(pop_file)

# Wrangling ----

# County names are the join key: "BUENA VISTA" in the crash data, "Buena Vista" in the Census
# file, and "OBRIEN" against "O'Brien". The county code would be safer, but it is missing on
# 27 crash rows where the name is present.
name_key <- function(x) str_remove_all(toupper(x), "[^A-Z ]")

crashes <- crashes |>
  mutate(year = as.integer(substr(crash_on, 1, 4)), key = name_key(county_name)) |>
  # 2025 is left out: there is no county population estimate for it yet.
  # Seven crashes have no county.
  filter(year <= 2024, !is.na(county_name))

# The district is recorded per crash, and 3% of crashes carry a different district from most
# crashes of their county. Each county goes to the district it is most often recorded under.
# count() sorts by district, so a tie goes to the lower district number. There is one tie:
# Madison, 15 crashes each under Southwest (4) and Southeast (5). The ranking of the districts
# is the same whichever way it goes (see docs/iowa_fatal_crash_districts.md).
home_district <- crashes |>
  count(key, district) |>
  group_by(key) |>
  slice_max(n, n = 1, with_ties = FALSE) |>
  ungroup() |>
  # "District 4 (Southwest)" -> "Southwest"
  transmute(key, district = str_match(district, "\\((.+)\\)")[, 2])

# One row per county and year, with zero where nobody died
county_years <- population |>
  mutate(key = name_key(county)) |>
  left_join(home_district, by = "key") |>
  left_join(
    crashes |> group_by(key, year) |> summarise(deaths = sum(deaths), .groups = "drop"),
    by = c("key", "year")
  ) |>
  mutate(deaths = coalesce(deaths, 0))

# A single year is too jumpy: a county of 6,000 people goes from 0 to 50 per 100,000 with
# three deaths. Each point is therefore three years pooled: the deaths of that year and the
# two before it, over the residents of the same three years. The first point is 2017.
pooled_rate <- function(data) {
  data |>
    arrange(year) |>
    mutate(
      deaths3 = deaths + lag(deaths) + lag(deaths, 2),
      people3 = population + lag(population) + lag(population, 2),
      rate    = 1e5 * deaths3 / people3
    ) |>
    filter(!is.na(rate))
}

districts <- county_years |>
  group_by(district, year) |>
  summarise(deaths = sum(deaths), population = sum(population), .groups = "drop") |>
  group_by(district) |>
  pooled_rate() |>
  ungroup()

# Whole-period rate, used to pick the district to highlight and to order the county panels
overall <- function(data) summarise(data, deaths = sum(deaths), rate = 1e5 * sum(deaths) / sum(population), residents = last(population))

district_all <- county_years |>
  group_by(district, year) |>
  summarise(deaths = sum(deaths), population = sum(population), .groups = "drop") |>
  group_by(district) |>
  overall() |>
  arrange(desc(rate))

worst <- district_all$district[1]
best  <- district_all$district[nrow(district_all)]

county_all <- county_years |>
  filter(district == worst) |>
  group_by(county) |>
  arrange(year) |>
  overall() |>
  arrange(desc(rate)) |>
  mutate(
    # The arrows play the part of the income classes in the original: they say how big the county is
    size  = case_when(residents >= 50000 ~ "↑", residents >= 10000 ~ "→", .default = "↓"),
    label = paste(county, size)
  )

counties <- county_years |>
  filter(district == worst) |>
  group_by(county) |>
  pooled_rate() |>
  ungroup() |>
  left_join(select(county_all, county, label), by = "county") |>
  # Panels run from the highest whole-period rate to the lowest
  mutate(label = factor(label, levels = county_all$label))

# Every county again in every panel, as the faint background lines. Dropping the facet
# variable and crossing with all labels gives each panel the full set.
backdrop <- counties |>
  select(county, year, rate) |>
  crossing(label = factor(levels(counties$label), levels = levels(counties$label)))

state_rate <- 1e5 * sum(county_years$deaths) / sum(county_years$population)
r1 <- function(x) format(round(x, 1), nsmall = 1)

# County outlines for the small map
sf_use_s2(FALSE)
county_shapes <- ne_download(scale = 10, type = "admin_2_counties", category = "cultural", returnclass = "sf", load = TRUE) |>
  filter(REGION == "IA") |>
  mutate(key = name_key(NAME)) |>
  left_join(home_district, by = "key")

# Fonts and colours ----
main_font <- "Libre Franklin"
axis_font <- "Fira Sans"
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(axis_font)
showtext_auto()
showtext_opts(dpi = 300)

page       <- "grey99"
ink        <- "#1A1A1A"
muted      <- "#7A7A7A"
highlight  <- "#2C7FB8"
dark       <- "#0B4C6B"
pale       <- "#D5D9DD"

theme_set(
  theme_bw(base_family = main_font) +
    theme(
      plot.background = element_rect(fill = page, colour = NA),
      panel.grid      = element_blank(),
      axis.ticks.y    = element_blank(),
      axis.text       = element_text(size = 10, family = axis_font, colour = ink),
      axis.title      = element_blank(),
      # Fira Sans has the arrow characters; Libre Franklin does not
      strip.text      = element_text(size = 10.5, family = axis_font, face = "bold", hjust = 0, vjust = 0, colour = ink)
    )
)

# Texts ----
top3 <- county_all$county[1:3]
low  <- county_all[nrow(county_all), ]

title <- paste0("Road deaths: the ", worst, " district has Iowa's highest rate, driven by a few small counties")

subtitle <- str_wrap(paste0(
  "Road deaths per 100,000 residents a year, pooled over three years (the point at 2024 covers 2022 to 2024). Left: Iowa DOT's six districts; over the whole period the ",
  worst, " had ", r1(district_all$rate[1]), ", the ", best, " ", r1(district_all$rate[nrow(district_all)]), ", Iowa ", r1(state_rate),
  ". Right: the ", nrow(county_all), " counties of the ", worst, " district, each drawn against the others, from the highest rate to the lowest. ",
  top3[1], ", ", top3[2], " and ", top3[3], " lead; ", low$county, ", next to Des Moines, has ", r1(low$rate),
  ". Arrows show county size: ↑ 50,000 residents or more, → 10,000 to 50,000, ↓ fewer. ",
  "Deaths are counted where the crash happened, whoever died, so through traffic on the interstates counts too."
), 190)

caption <- "Source: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 13); US Census Bureau population estimates · After a chart by Georgios Karamanis"

# Left: the districts ----
ends <- districts |>
  filter(year == max(year)) |>
  # Labels sit at the right-hand end of each line; nudge the ones that would collide
  arrange(rate) |>
  mutate(label_y = rate)
for (i in 2:nrow(ends)) ends$label_y[i] <- max(ends$label_y[i], ends$label_y[i - 1] + 0.55)

p_districts <- ggplot(districts, aes(x = year, y = rate, group = district)) +
  geom_hline(yintercept = state_rate, linetype = "dashed", linewidth = 0.3, colour = muted) +
  annotate("text", x = 2017.05, y = state_rate + 0.3, label = "Iowa, whole period", hjust = 0, family = axis_font, size = 3.2, colour = muted) +
  geom_line(data = filter(districts, district != worst), colour = pale, linewidth = 1.6, lineend = "round") +
  geom_line(data = filter(districts, district == worst), colour = highlight, linewidth = 2.4, lineend = "round") +
  geom_text(
    data = ends, aes(x = year + 0.12, y = label_y, label = district, colour = district == worst, fontface = ifelse(district == worst, "bold", "plain")),
    hjust = 0, family = main_font, size = 3.8
  ) +
  scale_colour_manual(values = c(`TRUE` = dark, `FALSE` = muted), guide = "none") +
  scale_x_continuous(breaks = range(districts$year), expand = expansion(mult = c(0.02, 0.24))) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.06))) +
  theme(panel.background = element_rect(colour = "black", linewidth = 1))

# Where the highlighted district is
p_map <- ggplot(county_shapes) +
  geom_sf(aes(fill = district == worst), colour = "white", linewidth = 0.15) +
  scale_fill_manual(values = c(`TRUE` = highlight, `FALSE` = pale), guide = "none") +
  theme_void()

p_left <- p_districts + inset_element(p_map, left = 0.03, right = 0.42, bottom = 0.03, top = 0.36)

# Right: the counties of the highlighted district ----
p_counties <- ggplot(counties, aes(x = year, y = rate)) +
  geom_line(data = backdrop, aes(group = county), colour = highlight, linewidth = 0.15, alpha = 0.35) +
  geom_line(colour = dark, linewidth = 0.8) +
  scale_x_continuous(breaks = range(counties$year)) +
  scale_y_continuous(limits = c(0, NA), breaks = c(0, 40, 80), expand = expansion(mult = c(0, 0.05))) +
  facet_wrap(vars(label), ncol = 6) +
  theme(
    # Two labels per panel: the first is pushed right and the second left so that neighbours
    # do not collide. ggplot2 warns that a vector here is "not officially supported"; it works.
    axis.text.x      = element_text(hjust = c(0, 1), size = 8),
    axis.text.y      = element_text(size = 8),
    strip.background = element_rect(fill = NA, colour = NA)
  )

# Assemble ----
final <- (p_left | p_counties) +
  plot_layout(widths = c(1, 1.45)) +
  plot_annotation(
    title = title, subtitle = subtitle, caption = caption,
    theme = theme(
      plot.title    = element_text(size = 19, face = "bold", colour = ink),
      # Fira Sans again, for the arrows
      plot.subtitle = element_text(family = axis_font, size = 11, lineheight = 1.15, colour = "#333333", margin = margin(2, 0, 10, 0)),
      plot.caption  = element_text(hjust = 0, size = 8.5, colour = muted),
      plot.margin   = margin(12, 14, 10, 14)
    )
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_districts.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_districts_thumb.png")

ggsave(out_png, final, width = 14, height = 8, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_districts.md
print(district_all)
print(county_all, n = 30)
