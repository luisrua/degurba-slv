## Analisis de tendencias de clasificacion DEGURBA para El Salvador ##
# Luis de la Rua ## May 2026

# SETTINGS =====================================================================
# Clean workspace
rm(list = ls())
gc()

# libraries loaded from the script below
source("setup.R")

# paths 
folder <- "C:/GIS/UNFPA GIS/DEGURBA/SLV_degurba/" 

# 1. GHS BUILT SURFACE TRENDS =================================================

# Layer Municipios, it does not change from 2007 to 2024
ab <- vect(paste0(folder, "layers/LIM_MUNICIPAL.shp"))
head(ab)
plot(ab)

# GHSP Built_S Estima area urbanizada por pixel.
# Vamos a calcular la tendencia de desarrollo urbanistico basado en esta estimacion 
# para detectar el crecimiento de suelo urbano por municipio y así poder descartar
# reduccion % población urbana que serían causa del cambio de metodologia de clasificacion
# urbano rural y no de un exodo rural o desplazamiento de la población a otras areas.

# GHSL population grid from https://human-settlement.emergency.copernicus.eu/download.php?ds=pop
# For 2005 to 2020
ghs_pop_2005 <- rast(paste0(folder, "layers/ghs/GHS_POP_E2005_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))
ghs_pop_2010 <- rast(paste0(folder, "layers/ghs/GHS_POP_E2010_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))
ghs_pop_2015 <- rast(paste0(folder, "layers/ghs/GHS_POP_E2015_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))
ghs_pop_2020 <- rast(paste0(folder, "layers/ghs/GHS_POP_E2020_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))

# Projection to Mollewide
ab_mol <- project(ab, crs(ghs_pop_2005))
ab_mol

# 2. WHAT DEGURBA WOULD LOOK LIKE IN 2005,2010,2015 and 2020 ======================================

# 2 Categories Urban Clusters (Towns and Suburbs) are merged into the Urban category.
# According to the official United Nations and Eurostat guidelines for the Degree of Urbanisation,
# the translation from the 3-class system to a dichotomous 2-class system works exactly like this:
# URBAN: Cities (Centers) + Towns & Suburbs (Clusters)
# RURAL: Rural Areas

ghs_list <- list("2005" = ghs_pop_2005,
                 "2010" = ghs_pop_2010,
                 "2015" = ghs_pop_2015,
                 "2020" = ghs_pop_2020
)

# Empty list for the results
results_list <- list()
table_results_list <- list()

for(yr in names(ghs_list)) {
  
  cat("\n========================================\n")
  cat("PROCESSING 2-CLASS DEGURBA FOR YEAR:", yr, "\n")
  cat("========================================\n")
  
  # 1. Grab, Crop, and Mask the raster to save memory
  current_raster <- ghs_list[[yr]]
  pop_grid_100m <- crop(current_raster, ext(ab_mol))
  pop_grid_100m <- mask(pop_grid_100m, ab_mol)
  
  # 2. Calculate Density
  pop_density_100m <- pop_grid_100m / 0.01
  
  # 3. Identify Urban Centers (>1500 density, 4-way, >50k pop)
  high_density <- ifel(pop_density_100m >= 1500, pop_grid_100m, NA)
  center_patches <- patches(high_density, directions = 4)
  center_pop <- zonal(pop_grid_100m, center_patches, fun = "sum", na.rm = TRUE)
  colnames(center_pop) <- c("patch_id", "total_pop")
  valid_center_ids <- center_pop$patch_id[center_pop$total_pop >= 50000]
  urban_centers <- ifel(center_patches %in% valid_center_ids, 1, NA)
  
  # 4. Identify Urban Clusters (>300 density, 8-way, >5k pop)
  mod_density <- ifel(pop_density_100m >= 300, pop_grid_100m, NA)
  cluster_patches <- patches(mod_density, directions = 8)
  cluster_pop <- zonal(pop_grid_100m, cluster_patches, fun = "sum", na.rm = TRUE)
  colnames(cluster_pop) <- c("patch_id", "total_pop")
  valid_cluster_ids <- cluster_pop$patch_id[cluster_pop$total_pop >= 5000]
  urban_clusters <- ifel(cluster_patches %in% valid_cluster_ids, 1, NA)
  
  # 5. Separate Population into Urban vs Rural (Same as before)
  pop_urban <- ifel(!is.na(urban_centers) | !is.na(urban_clusters), pop_grid_100m, 0)
  pop_rural <- ifel(is.na(urban_centers) & is.na(urban_clusters), pop_grid_100m, 0)
  
  pop_stack_2class <- c(pop_urban, pop_rural, pop_grid_100m)
  names(pop_stack_2class) <- c("pop_urban", "pop_rural", "pop_total")
  
  # 6. BLAZING FAST EXTRACTION WITH EXACTEXTRACTR
  cat("Extracting population statistics via exactextractr...\n")
  
  # Convert ab_mol to sf since exact_extract requires sf or st objects
  ab_sf_internal <- st_as_sf(ab_mol)
  
  # exact_extract automatically calculates the fraction of coverage and multiplies it 
  # by the cell value when you use fun = "sum".
  # It returns a clean dataframe matching the row order of your polygons.
  ext_data <- exact_extract(pop_stack_2class, ab_sf_internal, fun = "sum", progress = FALSE)
  
  # Handle any missing values safely
  ext_data[is.na(ext_data)] <- 0
  
  # 7. Build the Statistical Table for the current year
  # Safely extract names from the sf object
  district_names <- as.character(ab_sf_internal[["NA3"]]) 
  
  year_table <- data.frame(
    Year        = as.numeric(yr),
    District    = district_names, 
    # exactextract appends 'sum.' to the front of the layer names
    Pop_Total   = round(ext_data$sum.pop_total, 0),
    Pop_Urban   = round(ext_data$sum.pop_urban, 0),
    Pop_Rural   = round(ext_data$sum.pop_rural, 0)
  )
  
  # Calculate percentages and designations
  year_table <- year_table %>%
    mutate(
      Pct_Urban = ifelse(Pop_Total > 0, round((Pop_Urban / Pop_Total) * 100, 2), 0),
      Pct_Rural = ifelse(Pop_Total > 0, round((Pop_Rural / Pop_Total) * 100, 2), 0),
      Designation = ifelse(Pct_Urban >= 50.00, "Urban", "Rural"),
      Designation = ifelse(Pop_Total == 0, "Rural", Designation)
    )
  
  table_results_list[[yr]] <- year_table
}

# Combine all 4 years into one Master Table
master_degurba_table <- do.call(rbind, table_results_list)

# 2. Reshape the long table into a wide table
master_degurba_wide <- master_degurba_table %>%
  pivot_wider(
    id_cols     = District,
    names_from  = Year,
    values_from = c(Pop_Total, Pop_Urban, Pop_Rural, Pct_Urban, Pct_Rural, Designation),
    names_glue  = "{.value}_{Year}" # Appends the year cleanly to the end of each column
  )

# 2. Export the clean data frame safely to CSV
write.csv(master_degurba_wide, 
          paste0(folder, "results/El_Salvador_DEGURBA_Wide_2005_2020.csv"), 
          row.names = FALSE)




# 3. MAPPING RESULTS ========================
library(leaflet)
library(sf)
library(dplyr)

cat("Preparing data for the Leaflet Time-Series Map...\n")

# 1. Attach the clean wide data back to the spatial polygons
# Since we know the rows match perfectly 1-to-1 from the exactextract loop, 
# we can just bind the dataframes together directly.
map_data_sf <- st_as_sf(ab_mol)
map_data_sf <- bind_cols(map_data_sf, master_degurba_wide)

# 2. Transform to WGS84 (EPSG:4326) which Leaflet absolutely requires
map_data_wgs84 <- st_transform(map_data_sf, crs = 4326)

# 3. Define a clean 2-Class Color Palette
# Red for Urban, Green for Rural
ur_colors <- c("Urban" = "#E31A1C", "Rural" = "#31A354")
pal_ur <- colorFactor(palette = ur_colors, levels = c("Urban", "Rural"))


# Create the interactive map
degurba_time_map <- leaflet(map_data_wgs84) %>%
  
  # Base map (Light gray works best to make your red/green colors pop)
  addProviderTiles(providers$CartoDB.Positron) %>%
  
  # --- 2005 LAYER ---
  addPolygons(
    fillColor = ~pal_ur(Designation_2005),
    fillOpacity = 0.7,
    color = "#444444", weight = 1, # Thin grey borders
    group = "Year: 2005",
    label = ~District,
    popup = ~paste0("<b>District:</b> ", District, "<br>",
                    "<b>2005 Status:</b> ", Designation_2005, "<br>",
                    "<b>2005 Total Pop:</b> ", format(Pop_Total_2005, big.mark=","), "<br>",
                    "<b>2005 Urban Pop:</b> ", format(Pop_Urban_2005, big.mark=","), " (", Pct_Urban_2005, "%)")
  ) %>%
  
  # --- 2010 LAYER ---
  addPolygons(
    fillColor = ~pal_ur(Designation_2010),
    fillOpacity = 0.7,
    color = "#444444", weight = 1,
    group = "Year: 2010",
    label = ~District,
    popup = ~paste0("<b>District:</b> ", District, "<br>",
                    "<b>2010 Status:</b> ", Designation_2010, "<br>",
                    "<b>2010 Total Pop:</b> ", format(Pop_Total_2010, big.mark=","), "<br>",
                    "<b>2010 Urban Pop:</b> ", format(Pop_Urban_2010, big.mark=","), " (", Pct_Urban_2010, "%)")
  ) %>%
  
  # --- 2015 LAYER ---
  addPolygons(
    fillColor = ~pal_ur(Designation_2015),
    fillOpacity = 0.7,
    color = "#444444", weight = 1,
    group = "Year: 2015",
    label = ~District,
    popup = ~paste0("<b>District:</b> ", District, "<br>",
                    "<b>2015 Status:</b> ", Designation_2015, "<br>",
                    "<b>2015 Total Pop:</b> ", format(Pop_Total_2015, big.mark=","), "<br>",
                    "<b>2015 Urban Pop:</b> ", format(Pop_Urban_2015, big.mark=","), " (", Pct_Urban_2015, "%)")
  ) %>%
  
  # --- 2020 LAYER ---
  addPolygons(
    fillColor = ~pal_ur(Designation_2020),
    fillOpacity = 0.7,
    color = "#444444", weight = 1,
    group = "Year: 2020",
    label = ~District,
    popup = ~paste0("<b>District:</b> ", District, "<br>",
                    "<b>2020 Status:</b> ", Designation_2020, "<br>",
                    "<b>2020 Total Pop:</b> ", format(Pop_Total_2020, big.mark=","), "<br>",
                    "<b>2020 Urban Pop:</b> ", format(Pop_Urban_2020, big.mark=","), " (", Pct_Urban_2020, "%)")
  ) %>%
  
  # Add the Legend
  addLegend(
    position = "bottomright",
    colors = c("#E31A1C", "#31A354"),
    labels = c("Urban", "Rural"),
    title = "DEGURBA Status",
    opacity = 1
  ) %>%
  
  # Add the Layer Control Menu (Radio Buttons for Years)
  addLayersControl(
    baseGroups = c("Year: 2005", "Year: 2010", "Year: 2015", "Year: 2020"),
    options = layersControlOptions(collapsed = FALSE)
  )

# Display the map!
degurba_time_map

saveWidget(degurba_time_map, file = paste0(folder, "results/El_Salvador_degurba_Time_Map.html"), selfcontained = TRUE)
