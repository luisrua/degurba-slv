## Analisis de tendencias de crecimiento urbanistico para El Salvador ##
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


# ghs_BUILT_S 2007
ghs_builts_2005 <- rast(paste0(folder, "layers/ghs/GHS_BUILT_S_E2005_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))
ghs_builts_2010 <- rast(paste0(folder, "layers/ghs/GHS_BUILT_S_E2010_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))
summary(ghs_builts_2010)

# Census was 2007 we are going to interpolate between 2005 and 2010 to get a proxy of 2007 scenario
ghs_builts_2007 <- ghs_builts_2005 + (ghs_builts_2010 - ghs_builts_2005) * 0.4

# ghs_BUILT_S 2024
ghs_builts_2020 <- rast(paste0(folder, "layers/ghs/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))
ghs_builts_2025 <- rast(paste0(folder, "layers/ghs/GHS_BUILT_S_E2025_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))

ghs_builts_2024 <- ghs_builts_2020 + (ghs_builts_2025 - ghs_builts_2020) * 0.8
summary(ghs_builts_2024)

ab_mol <- project(ab, crs(ghs_builts_2007))
ab_mol

# Built growth raster NET
builts_change <- ghs_builts_2024 - ghs_builts_2007

mun_bchange <- zonal(builts_change, ab_mol, fun = "sum", na.rm = TRUE)

# Attach info to mun layer
ab_mol$built_surface_growth_sqm <- mun_bchange[,1]

plot(ab_mol, "built_surface_growth_sqm")

# Built growth raster %
sum2007 <- zonal(ghs_builts_2007, ab_mol, fun =  "sum", na.rm = T)
sum2024 <- zonal(ghs_builts_2024, ab_mol, fun =  "sum", na.rm = T)

ab_mol$built_sqm_2007 <- sum2007[,1]
ab_mol$built_sqm_2024 <- sum2024[,1]

ab_mol$built_surface_pct_growth <- ((ab_mol$built_sqm_2024 - ab_mol$built_sqm_2007) / ab_mol$built_sqm_2007) * 100

plot(ab_mol, "built_surface_pct_growth")

write.csv(ab_mol, paste0(folder,"Municipios_Tend_Urban.csv"))

# 2. WHAT DEGURBA WOULD LOOK LIKE IN 2007 ======================================
# Generate population grid interpolated for 2007
pop2005 <- rast(paste0(folder, "layers/ghs/GHS_POP_E2005_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))
pop2010 <- rast(paste0(folder, "layers/ghs/GHS_POP_E2010_GLOBE_R2023A_54009_100_V1_0_R8_C10.tif"))

pop2007 <- pop2005 + (pop2010 - pop2005) * 0.4 

pop1km <- aggregate(pop2007, fact = 10, fun = "sum", na.rm = TRUE)

## 2.1 Density Thresholds: Identifying cells with >1,500 inhabitants/km²  ----
# (Urban Centers) or >300 inhabitants/km² (Urban Clusters).

# Filter for high-density cells (> 1500 people)
# Set cells below 1500 to NA so they are ignored in the next steps
high_density <- ifel(pop1km >= 1500, pop1km, NA)
plot(ab_mol)
plot(high_density, add = T)


#  Group touching cells into unique patches
# directions = 4 means they must share a flat edge (no diagonal connections)
center_patches <- patches(high_density, directions = 4)
plot(center_patches)

#  Calculate the total population inside each unique patch
# zonal() sums the original population values within each numbered patch
patch_pop_sums <- zonal(pop1km, center_patches, fun = "sum", na.rm = TRUE)
colnames(patch_pop_sums) <- c("patch_id", "total_pop")

# Identify which patches meet the 50,000 total population threshold
valid_center_ids <- patch_pop_sums$patch_id[patch_pop_sums$total_pop >= 50000]

# Create the final Urban Centers raster
# We keep only the patches whose IDs are in our valid list
urban_centers <- ifel(center_patches %in% valid_center_ids, 1, NA)

cat("Number of distinct Urban Centers found:", length(valid_center_ids), "\n")

## 2.2. Identify Urban Clusters (Moderate-Density Clusters) ----
# > 300 people/km², 8-way contiguity, > 5,000 total population

# Filter for moderate-density cells (> 300 people)
moderate_density <- ifel(pop1km >= 300, pop1km, NA)

# Group touching cells into unique patches
# directions = 8 allows diagonal (corner-to-corner) connections
cluster_patches <- patches(moderate_density, directions = 8)

# Calculate the total population inside each patch
cluster_pop_sums <- zonal(pop1km, cluster_patches, fun = "sum", na.rm = TRUE)
colnames(cluster_pop_sums) <- c("patch_id", "total_pop")

# Filter for > 5,000 total population
valid_cluster_ids <- cluster_pop_sums$patch_id[cluster_pop_sums$total_pop >= 5000]

# Create the final Urban Clusters raster
urban_clusters <- ifel(cluster_patches %in% valid_cluster_ids, 1, NA)

cat("Number of distinct Urban Clusters found:", length(valid_cluster_ids), "\n")

## 2.3 Combine categories to get final DEGURBA classification ----
# According to the hierarchy, if a pixel is an Urban Center, 
# it takes priority. If it's not a Center but it is a Cluster, 
# it gets the Cluster class. Everything else is Rural.

# Create an empty raster with the same dimensions, defaulting to 3 (Rural)
degurba_class <- classify(pop1km, cbind(-Inf, Inf, 3))

# Overwrite with Urban Clusters (Class 2) where they exist
degurba_class <- ifel(!is.na(urban_clusters), 2, degurba_class)

# Overwrite with Urban Centers (Class 1) where they exist (Highest priority)
degurba_class <- ifel(!is.na(urban_centers), 1, degurba_class)

# Plot your final classification!
plot(degurba_class, col = c("red", "orange", "lightgreen"), 
     main = "DEGURBA Classification: 1=Center, 2=Cluster, 3=Rural")

# writeRaster(degurba_class,paste0(folder,"layers/test.tif"))

## 2.4 Filling potential gaps within urban areas ----

# Create a binary canvas
# Urban Centers = 1, EVERYTHING else (including ocean/NoData) = 0
# We want to treat water bodies as fillable gaps too, just like parks!
uc_binary <- ifel(is.na(urban_centers), 0, 1)

# Isolate all the "empty" space
empty_space <- ifel(uc_binary == 0, 1, NA)

# Group the touching empty cells into unique patches (directions = 4)
# The Urban Centers act as walls, trapping the internal gaps into their own unique patches
holes <- patches(empty_space, directions = 4)

# Calculate the size (in km² / pixels) of every empty patch
hole_sizes <- freq(holes)

# Identify ONLY the patches smaller than 15 km²
# The massive outside world will have a count in the thousands/millions and is ignored
valid_hole_ids <- hole_sizes$value[hole_sizes$count < 15]

# Fill the gaps safely
if(length(valid_hole_ids) > 0) {
  
  # Turn those specific small holes into '1's, and make everything else NA
  filled_holes <- subst(holes, valid_hole_ids, 1, others = NA)
  
  # Layer the newly filled holes underneath your original Urban Centers
  urban_centers_gapfilled <- cover(urban_centers, filled_holes)
  
  # Calculate how many total cells were rescued
  cells_filled <- sum(hole_sizes$count[hole_sizes$count < 15])
  cat("Gap filling complete! Filled", length(valid_hole_ids), "distinct holes (Total area:", cells_filled, "km²).\n")
  
} else {
  urban_centers_gapfilled <- urban_centers
  cat("No gaps smaller than 15 km² were found.\n")
}

# 3. ADMIN UNITS CLASSIFICATION ----
# According to the methodology, an administrative unit is classified into one of 
# three categories based on the percentage of its population living in the different 
# 1km grid classes:
# 1. Cities (Densely Populated Areas): >= 50% of the population lives in Urban Centers.
# Rural Areas (Thinly Populated Areas): >= 50% of the population lives in Rural grid cells.
# Towns and Suburbs (Intermediate Density): If it doesn't meet the >= 50% for Centers 
# OR Rural cells, it defaults to this middle category. (This usually happens when a large chunk of the population lives in Urban Clusters).

# Isolate the population belonging to each DEGURBA grid class
# We create three separate rasters where the pixels only contain population 
# if they match the specific class. Otherwise, they are 0.
pop_centers  <- ifel(degurba_class == 1, pop1km, 0)
pop_clusters <- ifel(degurba_class == 2, pop1km, 0)
pop_rural    <- ifel(degurba_class == 3, pop1km, 0)

# Stack them together with the total population raster
pop_stack <- c(pop_centers, pop_clusters, pop_rural, pop1km)
names(pop_stack) <- c("pop_center", "pop_cluster", "pop_rural", "pop_total")

# Extract the population sums for each administrative polygon
# exact = TRUE calculates fractions of pixels if a polygon boundary cuts through a 1km cell
lau_pop <- terra::extract(pop_stack, ab_mol, fun = sum, na.rm = TRUE, exact = TRUE)

# Calculate the population percentages for Centers and Rural cells
lau_pop$pct_center <- lau_pop$pop_center / lau_pop$pop_total
lau_pop$pct_rural  <- lau_pop$pop_rural / lau_pop$pop_total

# Apply the DEGURBA LAU logic
# We start by assuming everything is a Town/Suburb (Class 2), then overwrite 
# based on the strict 50% thresholds.
lau_pop$degurba_class <- 2 # By default first peri urban classification
lau_pop$degurba_class[lau_pop$pct_center >= 0.5] <- 1  # City
lau_pop$degurba_class[lau_pop$pct_rural >= 0.5]  <- 3  # Rural Area

# 6. Bind the final classification back to your spatial polygons!
ab <- cbind(ab_mol, lau_pop)
# Plot the final administrative map
plot(ab, "degurba_class", 
     col = c("red", "orange", "lightgreen"),
     main = "Admin Units DEGURBA 2007 based on GHS popgrid: 1=City, 2=Town/Suburb, 3=Rural")

# 4. MAPPING RESULTS -----
## 4.1 Prepare data for leaflet ----
library(htmlwidgets)

# Reproject the Administrative Polygons to WGS84
# Leaflet strongly prefers the 'sf' package for polygons rather than 'terra'
admin_sf <- st_as_sf(ab)
admin_sf_wgs <- st_transform(admin_sf, crs = 4326)

# Reproject the DEGURBA Raster back to WGS84
# CRITICAL: Because this is categorical data (1, 2, 3), you MUST use method = "near"
# (Nearest Neighbor). If you use bilinear, it will average 1 and 3 and create a 
# fake "Class 2" where it shouldn't exist!
degurba_class_wgs <- project(degurba_class, "EPSG:4326", method = "near")

# Reproject population grid into WGS84
pop_grid_wgs <- project(pop1km, "EPSG:4326", method = "bilinear")

## 4.2 Map settings ----
# DEGURBA Colors (Works for both the grid and the admin units)
# 1 = Centers/Cities (Red), 2 = Clusters/Towns (Orange), 3 = Rural (Green)
degurba_colors <- c("#E31A1C", "#FD8D3C", "#74C476")
pal_degurba <- colorFactor(palette = degurba_colors, levels = c(1, 2, 3), na.color = "transparent")

# WorldPop Colors (Continuous density)
# Using a Yellow-to-Purple viridis palette for population counts
pal_pop <- colorNumeric(palette = "inferno", domain = values(pop_grid_wgs), na.color = "transparent")

## 4.3 Draw Map ----
# Build the interactive map
degurba_map <- leaflet() %>%
  
  # Base map (A clean, light grey canvas makes the data pop)
  addProviderTiles(providers$CartoDB.Positron) %>%
  
  # Layer 1: WorldPop WGS84 Raster
  addRasterImage(pop_grid_wgs, 
                 colors = pal_pop, 
                 opacity = 0.7, 
                 group = "1. WorldPop Density",
                 maxBytes = 8 * 1024 * 1024) %>% # Increases memory limit for large rasters
  
  # Layer 2: DEGURBA 1km Grid Raster
  addRasterImage(degurba_class_wgs, 
                 colors = pal_degurba, 
                 opacity = 0.8, 
                 group = "2. DEGURBA Grid") %>%
  
  # Layer 3: Administrative Units Polygons
  addPolygons(data = admin_sf_wgs,
              fillColor = ~pal_degurba(degurba_class),
              fillOpacity = 0.6,
              color = "#333333",       
              weight = 1,              
              group = "3. Municipios",
              
              # --- NEW: Add the Hover Labels ---
              label = ~NAM,
              
              # Optional: Make the hover labels look clean and professional
              labelOptions = labelOptions(
                style = list("font-weight" = "bold", padding = "3px 8px"),
                textsize = "13px",
                direction = "auto"
              ),
              
              # --- UPDATED: Add the name to the click popup too ---
              popup = ~paste("<b>Name:</b>", NAM, "<br>",
                             "<b>DEGURBA Class:</b>", degurba_class)) %>%
  
  # Add Legends
  addLegend(position = "bottomright", pal = pal_degurba, values = c(1, 2, 3),
            title = "DEGURBA Class 2007 <br>(1=City, 2=Town, 3=Rural)", group = "2. DEGURBA Grid") %>%
  
  # Add the Layer Control Menu (Top Right)
  addLayersControl(
    overlayGroups = c("1. WorldPop Density", "2. DEGURBA Grid", "3. Municipios"),
    options = layersControlOptions(collapsed = FALSE)
  ) %>%
  
  # Hide WorldPop by default so the map isn't too cluttered when first opened
  hideGroup("1. WorldPop Density")

degurba_map

# Save the map as a standalone HTML file
# selfcontained = TRUE ensures all data is embedded in this single file
saveWidget(degurba_map, file = paste0(folder,"Interactive_DEGURBA_2007_Map.html"), selfcontained = TRUE)

# Save final results.
write.csv(ab, paste0(folder,"Municipios_DEGURBA_2007.csv"))
