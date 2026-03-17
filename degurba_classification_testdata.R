## DEGURBA CLASSIFICATION EL SALVADOR ##

# Luis de la Rua -- March 2026
## Implementing DEGURBA methodology to establish Standard Urban Rural Demarcation 
## using population grids.


# SETTINGS =====================================================================
# Clean workspace
rm(list = ls())
gc()

# libraries loaded from the script below
source("setup.R")

# paths 
folder <- "C:/GIS/UNFPA GIS/DEGURBA/SLV_degurba/" 
 

# 1. INPUT DATASETS ============================================================
# For the moment we use test data before we get the input datasets from NSO
# Population grid from Worldpop 1km resolution Constrained 2026 https://hub.worldpop.org/geodata/summary?id=77120
pop_grid_wgs <- rast(paste0(folder,"layers/slv_pop_2026_CN_1km_R2025A_UA_v1.tif"))

# Admin boundaries from HDX https://data.humdata.org/dataset/cod-em-slv
ab_wgs <- vect(paste0(folder,"layers/slv_adm_gadm_20240819_em_shp/slv_admbnda_adm3_gadm_20240819_em.shp"))

## 1.1 Setting projections ----
# Working Projection system Equal area projection World Mollweide (EPSG:54009)
eq_crs <- crs("ESRI:54009")

# admin boundaries reprojection
ab <- project(ab_wgs, eq_crs)

# Same for population grid but we are going to readjust pixel calculations (maybe later)
# Ask Central Bank to reproject their points datasets to equal area projection and 
# create the 1km resolution raster afterwards

# To avoid reprojection artifacts (regular reprojection gives ~1M population difference!!)
# we reproject using Density Method

# We are reprojecting using sum method as it deas the area math itself

# We create a template based on the original popgrid bur with new resolution and crs
template_1km<- project(pop_grid_wgs, eq_crs, res = 1000) 

# Reproject density 
pop_grid <- project(pop_grid_wgs, template_1km, method = "sum")

# Density = population as the area is 1km²

sum_wgs <- global(pop_grid_wgs, fun = "sum", na.rm = TRUE)
sum_rep <- global(pop_grid, fun = "sum", na.rm = TRUE)

diff_pop <- as.numeric(sum_rep - sum_wgs)
cat("Difference in population after strict 1km reprojection:", diff_pop, "\n")

# 2. CLASSIFY PIXELS BY POPULATION DENSITY THRESHOLDS AND CREATE CLUSTERS ------
## 2.1 Density Thresholds: Identifying cells with >1,500 inhabitants/km²  ----
# (Urban Centers) or >300 inhabitants/km² (Urban Clusters).

# Filter for high-density cells (> 1500 people)
# Set cells below 1500 to NA so they are ignored in the next steps
high_density <- ifel(pop_grid >= 1500, pop_grid, NA)
plot(ab)
plot(high_density, add = T)

#  Group touching cells into unique patches
# directions = 4 means they must share a flat edge (no diagonal connections)
center_patches <- patches(high_density, directions = 4)
plot(center_patches)

#  Calculate the total population inside each unique patch
# zonal() sums the original population values within each numbered patch
patch_pop_sums <- zonal(pop_grid, center_patches, fun = "sum", na.rm = TRUE)
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
moderate_density <- ifel(pop_grid >= 300, pop_grid, NA)

# Group touching cells into unique patches
# directions = 8 allows diagonal (corner-to-corner) connections
cluster_patches <- patches(moderate_density, directions = 8)

# Calculate the total population inside each patch
cluster_pop_sums <- zonal(pop_grid, cluster_patches, fun = "sum", na.rm = TRUE)
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
degurba_class <- classify(pop_grid, cbind(-Inf, Inf, 3))

# Overwrite with Urban Clusters (Class 2) where they exist
degurba_class <- ifel(!is.na(urban_clusters), 2, degurba_class)

# Overwrite with Urban Centers (Class 1) where they exist (Highest priority)
degurba_class <- ifel(!is.na(urban_centers), 1, degurba_class)

# Plot your final classification!
plot(degurba_class, col = c("red", "orange", "lightgreen"), 
     main = "DEGURBA Classification: 1=Center, 2=Cluster, 3=Rural")

