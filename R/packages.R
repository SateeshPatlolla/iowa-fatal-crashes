# Packages for every script in R/. Each script starts with source("R/packages.R"),
# so run them from the project root. Versions are pinned in renv.lock; renv::restore() installs them.

# data ----
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)

# charts ----
library(ggplot2)
library(ggtext)
library(ggrepel)
library(patchwork)

# fonts ----
library(sysfonts)
library(showtext)

# maps ----
library(sf)
library(rnaturalearth)

# images ----
library(magick)
library(grid)

# smoothing ----
library(KernSmooth)
