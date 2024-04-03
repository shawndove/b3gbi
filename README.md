
<!-- README.md is generated from README.Rmd. Please edit that file -->

# b3gbi <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/b3gbi)](https://CRAN.R-project.org/package=b3gbi)
[![R-CMD-check](https://github.com/shawndove/b3gbi/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/shawndove/b3gbi/actions/workflows/R-CMD-check.yaml)
[![codecov](https://codecov.io/gh/shawndove/b3gbi/branch/main/graph/badge.svg)](https://app.codecov.io/gh/shawndove/b3gbi/)
[![repo
status](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
<!-- badges: end -->

Analyze biodiversity trends and spatial patterns from GBIF data cubes,
using flexible indicators like richness, evenness, and more.

## Overview

Biodiversity researchers need robust and standardized tools to analyze
the vast amounts of data available on platforms like GBIF. The b3gbi
package leverages the power of data cubes to streamline biodiversity
assessments. It helps researchers gain insights into:

- **Changes Over Time:** How biodiversity metrics shift throughout the
  years.
- **Spatial Variations:** Differences in biodiversity across regions,
  identifying hotspots or areas of concern.
- **The Impact of Factors:** How different environmental variables or
  human activities might affect biodiversity patterns.

## Key Features

b3gbi empowers biodiversity analysis with:

- **Standardized Workflows:** Simplify the process of calculating common
  biodiversity indicators from GBIF data cubes.
- **Flexibility:** Calculate richness, evenness, rarity, taxonomic
  distinctness, Shannon-Hill diversity, Simpson-Hill diversity, and
  more.
- **Analysis Options:** Explore temporal trends or create spatial maps.
- **Visualization Tools:** Generate publication-ready plots of your
  biodiversity metrics.

## Installation

You can install the development version of b3gbi from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
# devtools::install_github("shawndove/b3gbi")
```

## Example

This is a basic example which shows you how to calculate and plot a map
of species richness for a data cube containing GBIF occurrence data on
amphibians in Europe:

``` r
# Load package
library(b3gbi)

# Load GBIF data cube
cube_name <- "data/europe_species_cube.csv"

# Load taxonomic info for cube
tax_info <- "data/europe_species_info.csv"

# Prepare cube
insect_data <- process_cube(cube_name, tax_info)

# Calculate diversity metric
map_obs_rich_insects <- obs_richness_map(insect_data)

# Plot diversity metric
plot(map_obs_rich_insects, title = "Observed Species Richness: Insects in Europe") 
```

<img src="man/figures/README-example-1.png" width="100%" />
