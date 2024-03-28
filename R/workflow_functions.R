#' Create a Spatial Grid for Mapping
#'
#' Generates a grid of polygons covering a specified geographic area,
#' suitable for mapping data retrieved with the rnaturalearth package.
#'
#' @param map_data A spatial object (e.g., an sf object) representing the
#'   geographic area of interest.  Obtained from rnaturalearth.
#' @param cell_size Cell length in kilometers.
#' @return An sf object containing the grid polygons, with attributes:
#'   * `cellid`: A unique ID for each grid cell.
#'   * `area_km2`: Area of each grid cell in square kilometers.
#'
#' @examples
#' # Get some map data
#' germany_map <- rnaturalearth::ne_countries(country = "Germany", scale = "medium", returnclass = "sf")
#' # Change projection to EPSG:3035 (works well with metric grid size)
#' germany_map <- sf::st_transform(germany_map, crs = "EPSG:3035")
#' # Calculate a 100km x 100km grid and plot it
#' germany_grid <- create_grid(germany_map, cell_size = 10)
#' plot(germany_grid)
#' @noRd
create_grid <- function(map_data,
                        level,
                        cell_size = NULL) {

  if (!is.null(cell_size)) {

    cell_size <- round(cell_size)

  } else {

    cell_size <- ifelse(level == "world", 100,
                        ifelse(level == "continent", 100,
                               ifelse(level == "country", 10)))

  }

  # Make a grid across the map area
  grid <- map_data %>%
    sf::st_make_grid(cellsize = c(cell_size * 1000, cell_size * 1000)) %>%
    sf::st_intersection(map_data) %>%
    sf::st_cast("MULTIPOLYGON") %>%
    sf::st_sf() %>%
    dplyr::mutate(cellid = dplyr::row_number())

  # Add area column to grid
  grid$area_km2 <-
    grid %>%
    sf::st_area() %>%
    units::set_units("km^2")

  return(grid)

}

#' Retrieve Map Data from rnaturalearth
#'
#' Downloads and prepares map data from the rnaturalearth package at
#' different geographic scales (country, continent, or world).
#'
#' @param level  The desired geographic scale: "country", "continent", or "world".
#' @param region  The specific region to retrieve data for (required when
#'  `level = "country"` or `level = "continent"`).
#' @return An sf object containing the map data, transformed to the
#'   appropriate projection.
#'
#' @examples
#' # Download country-level data for France
#' france_map <- get_NE_data(level = "country", region = "France")
#'
#' # Get continent-level data for Africa
#' africa_map <- get_NE_data(level = "continent", region = "Africa")
#'
#' # Retrieve a map of the entire world
#' world_map <- get_NE_data(level = "world")
#' @noRd
get_NE_data <- function(level, region, cube_crs) {

  # Download and prepare Natural Earth map data
  if (level == "country") {

    map_data <- rnaturalearth::ne_countries(scale = "medium",
                                            country = region,
                                            returnclass = "sf")

  } else if (level == "continent") {

    map_data <- rnaturalearth::ne_countries(scale = "medium",
                                            continent = region,
                                            returnclass = "sf")

  } else if (level == "world") {

    map_data <- rnaturalearth::ne_countries(scale = "medium",
                                            returnclass = "sf")

  }

    map_data <- map_data %>%
      sf::st_as_sf() %>%
     # sf::st_transform(crs = "EPSG:3035")
      sf::st_transform(crs = cube_crs)

  return(map_data)

}


#' @noRd
prepare_spatial_data <- function(data, grid, cube_crs) {

  # Set map limits
  # map_lims <- sf::st_buffer(grid, dist = 1000) %>%
  #   sf::st_bbox()

  # Scale coordinates of occurrences so the number of digits matches map
  data <-
    data %>%
    dplyr::mutate(xcoord = xcoord * 1000,
                  ycoord = ycoord * 1000)

  # data[, xcoord := xcoord * 1000][, ycoord := ycoord * 1000]

  # Convert the x and y columns to the correct format for plotting with sf
  occ_sf <- sf::st_as_sf(data,
                         coords = c("xcoord", "ycoord"),
                       #  crs = "EPSG:3035")
                       crs = cube_crs)

  # Set attributes as spatially constant to avoid warnings
  sf::st_agr(grid) <- "constant"
  sf::st_agr(occ_sf) <- "constant"

  # Calculate intersection between occurrences and grid cells
  occ_grid_int <- sf::st_intersection(occ_sf, grid, left = TRUE)

  # Add cell numbers to occurrence data
  # data <-
  #   data_scaled %>%
  #   dplyr::inner_join(occ_grid_int) %>%
  #   suppressMessages() %>%
  #   dplyr::arrange(cellid)

  data <-
    data %>%
    dplyr::inner_join(occ_grid_int) %>%
    suppressMessages() %>%
    dplyr::arrange(cellid)

  #
  # # Remove grid cells with areas smaller than 20% of the largest one
  # grid <-
  #   grid %>%
  #   filter(area_km2 > 0.2 * max(area_km2))
  #
  # # Remove same grid cells from data
  # data <-
  #   data %>%
  #   filter(cellid %in% grid$cellid)

  return(data)

}

#' @title Calculate Biodiversity Indicators Over Space or Time
#'
#' @description This function provides a flexible framework for calculating various biodiversity
#' indicators on a spatial grid or as a time series. It prepares the data, creates a grid, calculates indicators,
#' and formats the output into an appropriate S3 object ('indicator_map' or 'indicator_ts').
#'
#' @param x A data cube object ('processed_cube').
#' @param type The indicator to calculate. Supported options include:
#'   * 'hill0', 'hill1', 'hill2': Hill numbers (order 0, 1, and 2).
#'   * 'obs_richness': Observed species richness.
#'   * 'total_occ': Total number of occurrences.
#'   * 'newness': Mean year of occurrence.
#'   * 'density': Density of occurrences.
#'   * 'williams_evenness', 'pielou_evenness': Evenness measures.
#'   * 'ab_rarity', 'area_rarity':  Abundance-based and area-based rarity scores.
#'   * 'spec_occ': Species occurrences.
#'   * 'tax_distinct': Taxonomic distinctness.
#' @param cell_size Length of grid cell sides, in km. (Default: 10 for country, 100 for continent or world)
#' @param level Spatial level: 'continent', 'country', or 'world'. (Default: 'continent')
#' @param region The region of interest (e.g., "Europe"). (Default: "Europe")
#' @param ... Additional arguments passed to specific indicator calculation functions.
#'
#' @return An S3 object of the appropriate class containing the calculated indicator values and metadata:
#'   * 'indicator_map' for real-world observational data calculated over a grid (map)
#'   * 'indicator_ts' for real-world observational data calculated over time (time series)
#'   * 'virtual_indicator_map' for virtual species data calculated over a grid (map).
#'
#' @examples
#' diversity_map <- compute_indicator_workflow(example_cube_2, type = "obs_richness_map", level = "continent", region = "Europe")
#' diversity_map
#'
#' @noRd
compute_indicator_workflow <- function(x,
                                       type,
                                       dim_type = c("map", "ts"),
                                       cell_size = NULL,
                                       level = c("continent", "country", "world"),
                                       region = "Europe",
                                       cube_crs = NULL,
                                       first_year = NULL,
                                       last_year = NULL,
                                       ...) {

  stopifnot_error("Object class not recognized.",
                  inherits(x, "processed_cube") |
                    inherits(x, "processed_cube_dsinfo") |
                    inherits(x, "virtual_cube"))

  type <- match.arg(type,
                    names(available_indicators))
  dim_type <- match.arg(dim_type)
  level <- match.arg(level)

  if (!is.null(first_year)) {
    first_year <- ifelse(first_year > x$first_year, first_year, x$first_year)
  } else {
    first_year <- x$first_year
   }

  if (!is.null(final_year)) {
    last_year <- ifelse(last_year < x$last_year, last_year, x$last_year)
  } else {
    last_year <- x$last_year
  }

  data <- x$data[(x$data$year >= first_year) & (x$data$year <= final_year),]

  # Collect information to add to final object
  num_species <- x$num_species
  num_years <- length(unique(data$year))
  num_families <- x$num_families

  if (dim_type == "ts") {

    year_names <- unique(data$year)
    map_lims <- unlist(list("xmin" = min(data$xcoord),
                            "xmax" = max(data$xcoord),
                            "ymin" = min(data$ycoord),
                            "ymax" = max(data$ycoord)))

  }

  if (!inherits(x, "virtual_cube")) {

    kingdoms <- x$kingdoms
    species_names <- unique(data$scientificName)
    years_with_obs <- unique(data$year)

  }

  if (is.null(cube_crs)) {

    cube_crs <- "EPSG:3035"

  }


  if (dim_type == "map" | (!is.null(level) & !is.null(region))) {

    # Download Natural Earth data
    map_data <- get_NE_data(level, region, cube_crs)

    # Create grid from Natural Earth data
    grid <- create_grid(map_data, level, cell_size)

    # Format spatial data and merge with grid
    data <- prepare_spatial_data(data, grid, cube_crs)

  } else {

    level <- "unknown"
    region <- "unknown"

  }

  # Assign classess to send data to correct calculator function
  subtype <- paste0(type, "_", dim_type)
  class(data) <- append(type, class(data))
  class(data) <- append(subtype, class(data))

  if (dim_type == "map") {

    # Calculate indicator
    indicator <- calc_map(data, ...)

    # Add indicator values to grid
    diversity_grid <-
      grid %>%
      dplyr::left_join(indicator, by = "cellid")

  } else {

    # Calculate indicator
    indicator <- calc_ts(data, ...)

  }

  # Create indicator object
  if (!inherits(x, "virtual_cube")) {

    if (dim_type == "map") {

      diversity_obj <- new_indicator_map(diversity_grid,
                                         div_type = type,
                                         cell_size = cell_size,
                                         map_level = level,
                                         map_region = region,
                                         kingdoms = kingdoms,
                                         num_families = num_families,
                                         num_species = num_species,
                                         first_year = first_year,
                                         last_year = last_year,
                                         num_years = num_years,
                                         species_names = species_names,
                                         years_with_obs = years_with_obs)

    } else {

      diversity_obj <- new_indicator_ts(as_tibble(indicator),
                                        div_type = type,
                                        map_level = level,
                                        map_region = region,
                                        kingdoms = kingdoms,
                                        num_families = num_families,
                                        num_species = num_species,
                                        num_years = num_years,
                                        species_names = species_names,
                                        coord_range = map_lims)

    }

  } else {

    diversity_obj <- new_virtual_indicator_map(diversity_grid,
                                               div_type = type,
                                               cell_size = cell_size,
                                               map_level = level,
                                               map_region = region,
                                               num_species = num_species,
                                               first_year = first_year,
                                               last_year = last_year,
                                               num_years = num_years)

  }

  return(diversity_obj)

}

