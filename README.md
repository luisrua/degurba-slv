## Methodology: Two-Class DEGURBA

This project applies a two-class **Degree of Urbanisation (DEGURBA)** methodology to classify the municipalities of El Salvador as either **Urban** or **Rural** across a 20-year timeline (2005–2025). The spatial analysis follows a standard four-step workflow:

---

### 1. Data Harmonization
The analysis relies on two primary spatial inputs:
* **Administrative Boundaries:** Municipal borders of El Salvador (`LIM_MUNICIPAL.shp`).
* **Population Grids:** Global Human Settlement Layer (GHSL) population rasters at a 100m resolution.

To ensure accurate surface area calculations and prevent spatial distortion, the administrative boundaries are reprojected to the **Mollweide equal-area projection** to match the raster data.

### 2. Grid Cell Classification
Rather than classifying municipalities based on arbitrary administrative borders, the methodology analyzes population distribution at the micro-level (100m x 100m grid cells). Grid cells are evaluated based on population density and contiguity to form populated areas based on standard UN/Eurostat guidelines:

| Category | Contiguity Rule | Density Threshold | Minimum Total Population |
| :--- | :--- | :--- | :--- |
| **Urban Centers** | 4-way (borders) | ≥ 1,500 inhabitants/km² | 50,000 |
| **Urban Clusters** | 8-way (borders + corners) | ≥ 300 inhabitants/km² | 5,000 |

Cells meeting the criteria for either Urban Centers or Urban Clusters are merged into a single **Urban** category. All remaining unclassified grid cells are designated as **Rural**.

### 3. Municipal Classification (Zonal Aggregation)
Once the 100m grid is classified, a zonal statistics extraction calculates the population living within each municipality. A strict majority-rule threshold dictates the final designation:
* **Urban Municipality:** ≥ 50% of the population resides in Urban grid cells.
* **Rural Municipality:** < 50% of the population resides in Urban grid cells.

### 4. Longitudinal Tracking & Visualization
Because this classification is calculated independently for multiple years, the output tracks the longitudinal trend of urbanization. The final generated files include:
* **Statistical Matrix (CSV):** Population counts and percentages per municipality across all time periods.
* **Interactive Web Map (HTML):** A time-series map to toggle between years and visualize spatial urbanization shifts.
