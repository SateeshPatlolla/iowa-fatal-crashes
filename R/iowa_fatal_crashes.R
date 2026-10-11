# Iowa's fatal crashes 2015 to 2026 by cause, in the style of the week 35 castles map (R/week_35.R in the mice-algorithm repo)
# Data: Drivers and Vehicles Involved in Iowa Crashes, Iowa Data Hub dataset 17
# Run from the project root: Rscript R/iowa_fatal_crashes.R

# Packages ----
source("R/packages.R")

out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Data ----
# The full dataset is 717 MB, so the repo keeps an extract: every vehicle in a fatal crash,
# twelve columns. R/iowa_fatal_crashes_extract.R rebuilds it from the Data Hub download.
csv_file <- "data/iowa_fatal_crashes_2026-10-09.csv"
if (!file.exists(csv_file)) stop("Extract not found. Run R/iowa_fatal_crashes_extract.R first.")

vehicles <- read_csv(
  csv_file,
  col_select = c(crash = vehicle_crash_key, year = crash_year, deaths = fatalities, major_cause,
                 impaired = drug_or_alcohol_related, age = driver_age,
                 action = driver_contributing_circumstances, location = crash_location)
)

# Wrangling ----

# Map bbox: Iowa has no sea, so the loupe sits over Missouri and the raincloud over Nebraska and Kansas
xmin_ia <- -99.9
xmax_ia <- -89.7
ymin_ia <- 38.1
ymax_ia <- 44.0

# Planar geometry is fine at this scale
sf_use_s2(FALSE)

crop_wide <- function(x) {
  st_crop(x, xmin = xmin_ia - 1, xmax = xmax_ia + 1, ymin = ymin_ia - 1, ymax = ymax_ia + 1)
}

states_crop <- crop_wide(ne_download(scale = 10, type = "admin_1_states_provinces", category = "cultural", returnclass = "sf", load = TRUE))
ia_poly     <- states_crop |> filter(name == "Iowa", admin == "United States of America")

# Fold the 61 "major cause" values into five groups so the palette stays readable
cause_order  <- c("offroad", "yield", "speed", "lane", "other")
cause_labels <- c(
  offroad = "Ran off the road or lost control",
  yield   = "Failed to stop or yield",
  speed   = "Speeding or reckless driving",
  lane    = "Wrong side or wrong lane",
  other   = "Other or unknown"
)

vehicles <- vehicles |>
  mutate(
    cause = case_when(
      str_detect(major_cause, "^Ran off road|^Lost Control") ~ "offroad",
      str_detect(major_cause, "^Exceeded|too fast|reckless|Aggressive") ~ "speed",
      str_detect(major_cause, "^FTYROW|^Ran Stop|^Ran Traffic|Failed to yield") ~ "yield",
      str_detect(major_cause, "Crossed|wrong way|proper lane|^Passing|lane changing") ~ "lane",
      .default = "other"
    ),
    # The location arrives as text: "POINT(lon lat)"
    lon = as.numeric(str_match(location, "\\((-?[0-9.]+) ")[, 2]),
    lat = as.numeric(str_match(location, " (-?[0-9.]+)\\)")[, 2]),
    # Ages above 110 are the form's codes for "unknown"
    age = if_else(age <= 100, age, NA_real_)
  )

# The data has one row per vehicle. The map needs one row per crash; everything used here
# (cause, deaths, location, alcohol or drugs) is the same on every vehicle of a crash.
crashes_all <- vehicles |>
  summarise(
    year = first(year), deaths = first(deaths), cause = first(cause),
    impaired = first(impaired) != "None Indicated",
    lon = first(lon), lat = first(lat),
    .by = crash
  )

# A few crashes have no usable position (0, 0). They count in the totals but cannot be drawn.
crashes <- crashes_all |>
  filter(between(lon, -96.7, -90.1), between(lat, 40.3, 43.6))

# Iowa's primary and secondary roads, the same Census Bureau file as in R/iowa_fatal_crash_roads.R.
# "/vsizip/" lets sf read the shapefile inside the zip without unpacking it.
roads_file <- "data/iowa_primary_secondary_roads_tiger2024.zip"
roads_url  <- "https://www2.census.gov/geo/tiger/TIGER2024/PRISECROADS/tl_2024_19_prisecroads.zip"
# The roads file is in the repo; this only runs if it has been deleted
if (!file.exists(roads_file)) download.file(roads_url, roads_file, mode = "wb")
roads <- st_read(paste0("/vsizip/", roads_file), quiet = TRUE) |>
  # The file is in NAD83; the rest of this map is in WGS84 longitude and latitude
  st_transform(st_crs(states_crop)) |>
  transmute(
    # MTFCC is the Census Bureau's road class: S1100 primary (interstates and other
    # divided highways), S1200 secondary (the other US, state and main county highways)
    class = ifelse(MTFCC == "S1100", "primary", "secondary")
  )

# Des Moines loupe. The metro is far too dense to read at state scale
dm_lon   <- -93.68
dm_lat   <- 41.62
dm_r_deg <- 0.33
dm_rx    <- dm_r_deg / cos(dm_lat * pi / 180)

lon_scale <- cos(mean(c(ymin_ia, ymax_ia)) * pi / 180)
loupe_x   <- -93.7
loupe_y   <- 39.38
loupe_r   <- 0.9
mag       <- loupe_r / dm_r_deg

to_loupe_x <- function(lon) loupe_x + mag * (lon - dm_lon) * cos(dm_lat * pi / 180) / lon_scale
to_loupe_y <- function(lat) loupe_y + mag * (lat - dm_lat)

in_dm <- function(lon, lat) ((lon - dm_lon) / dm_rx)^2 + ((lat - dm_lat) / dm_r_deg)^2 <= 1

circle <- function(cx, cy, rx, ry, n = 240) {
  t <- seq(0, 2 * pi, length.out = n)
  tibble(x = cx + rx * cos(t), y = cy + ry * sin(t))
}

dm_ring    <- circle(dm_lon, dm_lat, dm_rx, dm_r_deg)
loupe_disc <- circle(loupe_x, loupe_y, loupe_r / lon_scale, loupe_r)

crashes <- crashes |> mutate(dm = in_dm(lon, lat))

# The roads inside the ring, redrawn in the loupe: cut them at the ring, take the lines
# apart into their points, and move every point the way the crashes are moved
ring_poly <- st_sfc(st_polygon(list(as.matrix(dm_ring))), crs = st_crs(roads))
roads_cut <- st_intersection(roads, ring_poly) |>
  st_cast("MULTILINESTRING") |>
  st_cast("LINESTRING", warn = FALSE)
roads_dm <- as_tibble(st_coordinates(roads_cut)) |>
  transmute(
    x = to_loupe_x(X), y = to_loupe_y(Y),
    line = L1, class = roads_cut$class[L1]
  )

crashes_dm <- crashes |>
  filter(dm) |>
  mutate(x = to_loupe_x(lon), y = to_loupe_y(lat))

# The deadliest crashes get a diamond and a label
famous <- crashes |>
  filter(deaths >= 4) |>
  mutate(label = str_glue("{deaths} killed, {year}"))
famous_dm <- crashes_dm |>
  filter(deaths >= 4) |>
  mutate(label = str_glue("{deaths} killed, {year}"))

# Short leader from the ring down to the loupe
loupe_link <- tibble(
  x = dm_lon, y = dm_lat - dm_r_deg,
  xend = loupe_x, yend = loupe_y + loupe_r
)

# Driver ages for the raincloud chart. Only drivers the officer recorded as doing something
# wrong, so the other party in a two-car crash does not blur the picture.
age_dat <- vehicles |>
  filter(!is.na(age), !action %in% c("No improper action", "Not Reported", "Unknown")) |>
  mutate(cause = stats::reorder(cause, age, FUN = median))

set.seed(35)
rain_dat <- age_dat |>
  slice_sample(n = 300, by = cause) |>
  mutate(x_jitter = as.numeric(cause) - 0.18 + stats::runif(n(), -0.09, 0.09))

# Numbers for the subtitle
pct          <- function(x) round(100 * mean(x))
by_cause     <- function(k) crashes_all |> filter(cause %in% k)
speed_ages   <- age_dat |> filter(cause == "speed")
yield_ages   <- age_dat |> filter(cause == "yield")

# Map annotations: neighbours in capitals
state_names <- tribble(
  ~label,          ~lon,    ~lat,
  "SOUTH DAKOTA",  -97.45,  43.6,
  "NEBRASKA",      -98.2,   41.9,
  "MINNESOTA",     -93.5,   43.8,
  "WISCONSIN",     -90.45,  43.7,
  "ILLINOIS",      -90.1,   41.0,
  "MISSOURI",      -91.4,   39.6
)

# Plot ----

# Fonts
main_font <- 'Libre Franklin'
map_font  <- 'Fira Sans'
sysfonts::font_add_google(main_font)
sysfonts::font_add_google(map_font)
showtext_auto()
showtext_opts(dpi = 300)

# Atlas palette:
page      <- '#FBF8F1'
ink       <- '#1A1A1A'
muted     <- '#6B6B6B'
neighbour <- '#EEE6D6'
home      <- '#FFFEFA'
border    <- '#C4B7A0'
road      <- '#B3A995'
red       <- '#E3120B'

# Red goes to speed: the group the inset is about
cause_palette <- c(
  offroad = '#C46A1F',
  yield   = '#0F3B63',
  speed   = red,
  lane    = '#2E7D6B',
  other   = '#CFC6B4'
)

title <- "One in three fatal crashes in Iowa starts with a driver leaving the road"
subtitle <- str_glue(
  "Iowa recorded **{format(nrow(crashes_all), big.mark = ',')} fatal crashes** from 2015 to early October 2026, killing ",
  "{format(sum(crashes_all$deaths), big.mark = ',')} people. In {pct(crashes_all$cause == 'offroad')}% the main cause was a vehicle running off ",
  "the road or a driver losing control. Alcohol or drugs were indicated in {pct(crashes_all$impaired)}% of all fatal crashes, ",
  "and in {pct(by_cause('speed')$impaired)}% of those put down to speeding or reckless driving. ",
  "Diamonds mark the {nrow(famous)} crashes that killed four or more people"
)

caption <- paste(
  'Source: Drivers and Vehicles Involved in Iowa Crashes (Iowa DOT), Iowa Data Hub, data.iowa.gov/catalog/dataset/17, as of 9 October 2026; roads: US Census Bureau, TIGER/Line 2024',
  'Layout after Guillaume Noblet\'s #TidyTuesday 2026 week 35 castles map',
  sep = '<br>'
)

# Dots are drawn in random order. Drawing one colour last would paint the cities in that colour,
# because whichever group is on top hides the rest where crashes pile up.
set.seed(35)
as_cause <- function(d) d |> mutate(cause = factor(cause, cause_order)) |> slice_sample(prop = 1)

p_map <- ggplot() +
  # Land
  geom_sf(data = states_crop, fill = neighbour, colour = border, linewidth = 0.3) +
  geom_sf(data = ia_poly, fill = home, colour = '#8C8170', linewidth = 0.5) +
  # Roads
  geom_sf(data = roads |> filter(class == 'secondary'), colour = road, linewidth = 0.2) +
  geom_sf(data = roads |> filter(class == 'primary'), colour = road, linewidth = 0.55) +
  # State labels
  geom_text(
    data = state_names, aes(lon, lat, label = label),
    family = map_font, colour = '#948A78', size = 4
  ) +
  # Crashes
  geom_point(
    data = as_cause(crashes),
    aes(lon, lat, fill = cause),
    shape = 21, size = 2, colour = 'white', stroke = 0.25
  ) +
  # Deadliest crashes
  geom_point(
    data = famous, aes(lon, lat),
    shape = 23, size = 3.6, fill = ink, colour = 'white', stroke = 0.5
  ) +
  # Keep the state-scale labels off the ring
  geom_text_repel(
    data = bind_rows(
      famous |> filter(!dm) |> select(lon, lat, label),
      dm_ring |> slice(seq(1, n(), by = 12)) |> mutate(lon = x, lat = y, label = '', .keep = 'none')
    ),
    aes(lon, lat, label = label),
    family = map_font, size = 3.8, colour = ink,
    box.padding = 0.6, point.padding = 0.3, segment.colour = ink, segment.size = 0.3,
    min.segment.length = 0, max.overlaps = Inf, seed = 35,
    bg.color = 'white', bg.r = 0.15
  ) +
  # Des Moines ring, leader and loupe
  geom_path(data = dm_ring, aes(x, y), colour = ink, linewidth = 0.5) +
  geom_segment(
    data = loupe_link, aes(x = x, y = y, xend = xend, yend = yend),
    colour = ink, linewidth = 0.35, linetype = '22'
  ) +
  geom_polygon(data = loupe_disc, aes(x, y), fill = home, colour = ink, linewidth = 0.7) +
  geom_path(data = roads_dm |> filter(class == 'secondary'), aes(x, y, group = line), colour = road, linewidth = 0.3) +
  geom_path(data = roads_dm |> filter(class == 'primary'), aes(x, y, group = line), colour = road, linewidth = 0.8) +
  geom_point(
    data = as_cause(crashes_dm),
    aes(x, y, fill = cause),
    shape = 21, size = 2.6, colour = 'white', stroke = 0.3
  ) +
  geom_point(
    data = famous_dm, aes(x, y),
    shape = 23, size = 3.6, fill = ink, colour = 'white', stroke = 0.5
  ) +
  geom_text_repel(
    data = famous_dm, aes(x, y, label = label),
    family = map_font, size = 3.6, colour = ink,
    box.padding = 0.55, point.padding = 0.3, force = 3, segment.colour = ink, segment.size = 0.25,
    min.segment.length = 0, max.overlaps = Inf, seed = 35,
    bg.color = 'white', bg.r = 0.15,
    xlim = loupe_x + c(-1, 1) * 0.92 * loupe_r / lon_scale,
    ylim = loupe_y + c(-1, 1) * 0.92 * loupe_r
  ) +
  annotate(
    'text', x = loupe_x, y = loupe_y - loupe_r - 0.14, label = 'DES MOINES AREA',
    family = map_font, fontface = 'bold', size = 4.2, colour = ink
  ) +
  # Legend
  scale_fill_manual(
    values = cause_palette, breaks = cause_order,
    labels = cause_labels, name = NULL
  ) +
  guides(fill = guide_legend(nrow = 1, override.aes = list(size = 5))) +
  # Labels
  labs(title = title, subtitle = subtitle, caption = caption) +
  coord_sf(xlim = c(xmin_ia, xmax_ia), ylim = c(ymin_ia, ymax_ia), expand = FALSE) +
  # Theme
  theme_void(base_family = main_font) +
  theme(
    plot.background       = element_rect(fill = page, colour = NA),
    panel.background      = element_rect(fill = neighbour, colour = NA),
    plot.margin           = margin(40, 35, 15, 35),
    plot.title.position   = 'plot',
    plot.caption.position = 'plot',
    plot.title = element_textbox_simple(
      family = main_font, face = 'bold', size = 32, colour = ink,
      lineheight = 1.1, margin = margin(b = 10)
    ),
    plot.subtitle = element_textbox_simple(
      family = main_font, size = 16, colour = '#333333', lineheight = 1.35, margin = margin(b = 12)
    ),
    plot.caption = element_textbox_simple(
      family = main_font, size = 13, colour = muted, halign = 0, lineheight = 1.4, margin = margin(t = 10)
    ),
    legend.position      = 'top',
    legend.justification = 'left',
    legend.text          = element_text(family = main_font, size = 14, colour = ink, margin = margin(r = 14)),
    legend.key           = element_rect(fill = NA, colour = NA),
    legend.margin        = margin(b = 6)
  )

# Raincloud chart: half-violins with a narrow boxplot, and the raw ages as rain underneath.
# "Other" is too pale to read as text, so its label uses the muted grey
label_palette <- replace(cause_palette, "other", muted)
short_labels  <- c(
  offroad = "Ran off road", yield = "Failed to yield", speed = "Speeding",
  lane = "Wrong side", other = "Other"
)
cause_label <- function(x) sprintf("<span style='color:%s'>**%s**</span>", label_palette[x], short_labels[x])

p_inset <- ggplot(age_dat, aes(x = cause, y = age)) +
  geom_violin(
    aes(fill = cause), trim = TRUE, scale = 'width', alpha = 0.6, colour = NA,
    position = position_nudge(x = 0.15), width = 0.9
  ) +
  geom_boxplot(
    width = 0.1, outlier.shape = NA, linewidth = 0.4, fill = 'white', colour = ink,
    position = position_nudge(x = 0.15)
  ) +
  geom_point(
    data = rain_dat, aes(x = x_jitter, y = age, colour = cause),
    inherit.aes = FALSE, size = 0.9, alpha = 0.55
  ) +
  scale_fill_manual(values = cause_palette, guide = 'none') +
  scale_colour_manual(values = cause_palette, guide = 'none') +
  scale_x_discrete(labels = cause_label) +
  scale_y_continuous(breaks = seq(20, 100, by = 20)) +
  coord_flip() +
  labs(
    title = 'Speeding drivers are the youngest',
    subtitle = str_glue(
      "Age of drivers recorded with an improper action. Half of\n",
      "the speeding drivers were {median(speed_ages$age)} or younger; {pct(yield_ages$age >= 65)}% of those\n",
      "who failed to yield were 65 or older"
    ),
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 13, base_family = main_font) +
  theme(
    plot.background    = element_rect(fill = 'white', colour = '#D8D4CC', linewidth = 0.4),
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_line(colour = '#E6E2DA', linewidth = 0.3),
    # coord_flip draws the category axis with axis.text.y.left, which is
    # plain text in the base theme, so the markdown element goes there
    axis.text.y.left   = element_markdown(size = 13, hjust = 0),
    axis.text.x        = element_text(colour = muted, size = 11),
    plot.title         = element_text(face = 'bold', size = 15, colour = ink),
    plot.subtitle      = element_text(size = 11.5, colour = muted, lineheight = 1.15, margin = margin(b = 8)),
    plot.title.position = 'plot',
    plot.margin        = margin(10, 14, 8, 10)
  )

# Red tab at the top-left
red_tab <- ggplot() +
  annotate('rect', xmin = 0, xmax = 1, ymin = 0, ymax = 1, fill = red) +
  theme_void()

p <- p_map +
  inset_element(p_inset, left = 0.012, right = 0.335, bottom = 0.02, top = 0.5, align_to = 'panel') +
  inset_element(red_tab, left = 0, right = 0.07, bottom = 0.993, top = 1, align_to = 'full') +
  plot_annotation(theme = theme(plot.background = element_rect(fill = page, colour = NA)))

# Save ----
out_png   <- file.path(out_dir, 'iowa_fatal_crashes.png')
out_thumb <- file.path(out_dir, 'iowa_fatal_crashes_thumb.png')

ggsave(
  out_png,
  plot   = p,
  width  = 16,
  height = 14.8,
  dpi    = 300,
  bg     = page
)

image <- image_read(out_png)
image <- image_scale(image, geometry_size_pixels(width = 500, preserve_aspect = TRUE))
image_write(image, out_thumb, format = 'png')
