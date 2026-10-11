# Road deaths per 100,000 residents in each Iowa county, 2015 to 2024
# After Nicola Rennie, general-health-2021-census.R (data-viz-projects): one map, every area
# filled by one rate, the explanation in the subtitle and the colour bar underneath
# Data: Vehicle Crashes in Iowa (Iowa Data Hub dataset 13) and US Census Bureau county
# population estimates
# Run from the project root: Rscript R/iowa_fatal_crash_counties.R

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

# County names are the join key, as in R/iowa_fatal_crash_districts.R: "OBRIEN" in the crash
# data against "O'Brien" in the Census file.
name_key <- function(x) str_remove_all(toupper(x), "[^A-Z ]")

county_deaths <- crashes |>
  mutate(year = as.integer(substr(crash_on, 1, 4)), key = name_key(county_name)) |>
  # 2025 is left out: there is no county population estimate for it yet.
  # Seven crashes have no county.
  filter(year <= 2024, !is.na(county_name)) |>
  group_by(key) |>
  summarise(deaths = sum(deaths))

# One rate per county for the whole ten years: all deaths over all resident-years. Ten years
# because the smallest county has under 5,000 residents and a single year there is 0 or 1 death.
rates <- population |>
  mutate(key = name_key(county)) |>
  group_by(key, county) |>
  summarise(resident_years = sum(population), residents = last(population), .groups = "drop") |>
  left_join(county_deaths, by = "key") |>
  mutate(deaths = coalesce(deaths, 0), rate = 1e5 * deaths / resident_years) |>
  arrange(desc(rate))

state_rate <- 1e5 * sum(rates$deaths) / sum(rates$resident_years)
highest <- rates[1, ]
lowest  <- rates[nrow(rates), ]
big     <- filter(rates, residents >= 50000)
small   <- filter(rates, residents < 10000)
group_rate <- function(data) 1e5 * sum(data$deaths) / sum(data$resident_years)

# County outlines
sf_use_s2(FALSE)
map_data <- ne_download(scale = 10, type = "admin_2_counties", category = "cultural", returnclass = "sf", load = TRUE) |>
  filter(REGION == "IA") |>
  mutate(key = name_key(NAME)) |>
  left_join(rates, by = "key") |>
  # UTM zone 15N, which runs through the middle of Iowa
  st_transform(26915)
stopifnot(nrow(map_data) == 99, !anyNA(map_data$rate))

# Roads, from Natural Earth too: interstates and the other federal ("US") highways, cut at
# the state line
roads <- ne_download(scale = 10, type = "roads", category = "cultural", returnclass = "sf", load = TRUE) |>
  filter(level %in% c("Interstate", "Federal")) |>
  select(level, name) |>
  st_transform(26915) |>
  st_intersection(st_union(map_data))
interstates <- filter(roads, level == "Interstate")
us_highways <- filter(roads, level == "Federal")

# A shield for each of the four long interstates. The positions are typed in as longitude
# and latitude, then moved onto the nearest point of that road.
shields <- tibble::tribble(
  ~name, ~lon,   ~lat,
  "80",  -92.10, 41.69,
  "80",  -94.75, 41.50,
  "35",  -93.35, 42.90,
  "35",  -93.78, 40.95,
  "29",  -96.05, 42.05,
  "380", -91.90, 42.25
) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  st_transform(26915)
for (i in seq_len(nrow(shields))) {
  road <- st_union(filter(interstates, name == shields$name[i]))
  link <- st_nearest_points(shields$geometry[i], road)
  shields$geometry[i] <- st_cast(link, "POINT")[2]
}
shields$label <- paste0("I-", shields$name)

# The two counties named in the subtitle get a label so that they can be found
named <- map_data |>
  filter(key %in% c(highest$key, lowest$key)) |>
  mutate(label = paste0(county, "\n", format(round(rate, 1), nsmall = 1))) |>
  st_centroid()
# Moved east of the county's centre, off the interstate that runs through both counties:
# 7 km in Story, 4 km in Fremont, which is narrower. Adding to an sfc drops its CRS.
shift <- ifelse(named$key == highest$key, 4000, 7000)
st_geometry(named) <- st_sfc(
  lapply(seq_len(nrow(named)), function(i) st_geometry(named)[[i]] + c(shift[i], 0)),
  crs = st_crs(named)
)

# Fonts and colours ----
main_font  <- "Roboto"
title_font <- "Roboto Slab"
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(title_font)
showtext_auto()
showtext_opts(dpi = 300)

# CARTO's "BurgYl", the palette of the original (rcartocolor is not installed here)
burg_yl <- c("#fbe6c5", "#f5ba98", "#ee8a82", "#dc7176", "#c8586c", "#9c3f5d", "#70284a")

# Texts ----
r1 <- function(x) format(round(x, 1), nsmall = 1)

title <- "Road deaths per 100,000 residents a year in Iowa's counties, 2015 to 2024"

subtitle <- paste0(
  "Each county is coloured by the number of people killed in crashes on its roads over the ten years, divided by its residents. ",
  highest$county, " County, in the south-west corner, had the highest rate at ", r1(highest$rate), "; ",
  lowest$county, " County the lowest at ", r1(lowest$rate), ". Iowa as a whole had ", r1(state_rate), ". ",
  "The ", nrow(big), " counties with 50,000 residents or more had ", r1(group_rate(big)), " between them, the ",
  nrow(small), " with fewer than 10,000 had ", r1(group_rate(small)),
  ". Deaths are counted where the crash happened, whoever died, so a small county crossed by an interstate carries its through traffic. ",
  "Dark lines are interstates, thin white lines the other US highways. The colour bar is stretched so that each doubling of the rate takes the same length."
)

caption <- "**Data**: Vehicle Crashes in Iowa, Iowa DOT via Iowa Data Hub (dataset 13); US Census Bureau population estimates. Roads: Natural Earth.<br>**Graphic**: after a map by Nicola Rennie."

# Plot ----
final <- ggplot() +
  geom_sf(data = map_data, mapping = aes(fill = rate), colour = "black", linewidth = 0.1) +
  geom_sf(data = us_highways, colour = "white", linewidth = 0.25, alpha = 0.55) +
  # A dark line inside a white one, so that the interstates show on pale and on dark counties
  geom_sf(data = interstates, colour = "white", linewidth = 1.1, lineend = "round") +
  geom_sf(data = interstates, colour = "#2B2B2B", linewidth = 0.4, lineend = "round") +
  geom_sf_label(
    data = shields, aes(label = label),
    family = main_font, size = 1.9, fontface = "bold", colour = "#2B2B2B", fill = "white",
    label.size = 0, label.padding = unit(0.1, "lines"), label.r = unit(0.08, "lines")
  ) +
  geom_sf_text(
    data = named, aes(label = label, colour = rate > 15),
    family = main_font, size = 2.3, lineheight = 0.9, fontface = "bold"
  ) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "black"), guide = "none") +
  # A log scale: the rates run from under 5 to almost 50 and most counties sit between 10 and
  # 20, so a linear bar would spend most of its colours on four counties
  scale_fill_gradientn(
    colours = burg_yl, trans = "log", limits = c(4, 50), breaks = c(5, 10, 20, 40)
  ) +
  guides(fill = guide_colourbar(
    title = "Road deaths per 100,000 residents a year",
    theme = theme(
      legend.title.position = "top",
      legend.key.width  = unit(3.2, "in"),
      legend.key.height = unit(0.12, "in")
    )
  )) +
  labs(title = title, subtitle = subtitle, caption = caption) +
  theme_void(base_family = main_font, base_size = 11) +
  theme(
    legend.position  = "bottom",
    legend.title     = element_text(hjust = 0.5),
    plot.title       = element_textbox_simple(family = title_font, face = "bold", size = 15),
    plot.subtitle    = element_textbox_simple(lineheight = 1.25, margin = margin(t = 10, b = 6)),
    plot.caption     = element_textbox_simple(size = 8, lineheight = 1.25, margin = margin(t = 10)),
    plot.background  = element_rect(fill = "white", colour = "white"),
    panel.background = element_rect(fill = "white", colour = "white"),
    plot.margin      = margin(15, 15, 15, 15)
  )

# Save ----
out_png   <- file.path(out_dir, "iowa_fatal_crash_counties.png")
out_thumb <- file.path(out_dir, "iowa_fatal_crash_counties_thumb.png")

ggsave(out_png, final, width = 8, height = 8.2, units = "in", dpi = 300)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = "png")

# Printed for the checks in docs/iowa_fatal_crash_counties.md
print(rates, n = 99)
cat("Iowa:", r1(state_rate), " 50,000 or more:", nrow(big), r1(group_rate(big)), " under 10,000:", nrow(small), r1(group_rate(small)), "\n")
