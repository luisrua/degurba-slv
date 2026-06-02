## Methodology: Two-Class DEGURBA
### (Spanish version below)

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

* ## Metodología: DEGURBA de Dos Clases

Este proyecto aplica una metodología de **Grado de Urbanización (DEGURBA)** de dos clases para clasificar los municipios de El Salvador como **Urbanos** o **Rurales** a lo largo de un período de 20 años (2005–2025). El análisis espacial sigue un flujo de trabajo estándar de cuatro pasos:

---

### 1. Armonización de Datos
El análisis se basa en dos insumos espaciales principales:
* **Límites Administrativos:** Fronteras municipales de El Salvador (`LIM_MUNICIPAL.shp`).
* **Cuadrículas de Población:** Rásteres de población de la Capa Global de Asentamientos Humanos (GHSL, por sus siglas en inglés) a una resolución de 100m.

Para garantizar cálculos precisos de la superficie y evitar distorsiones espaciales, los límites administrativos se reproyectan a la **proyección equivalente de Mollweide** para que coincidan con los datos ráster.

### 2. Clasificación de las Celdas de la Cuadrícula
En lugar de clasificar los municipios basándose en fronteras administrativas arbitrarias, la metodología analiza la distribución de la población a nivel micro (celdas de cuadrícula de 100m x 100m). Las celdas se evalúan en función de la densidad de población y la contigüidad para formar áreas pobladas según las directrices estándar de la ONU/Eurostat:

| Categoría | Regla de Contigüidad | Umbral de Densidad | Población Total Mínima |
| :--- | :--- | :--- | :--- |
| **Centros Urbanos** | 4 direcciones (bordes) | ≥ 1.500 habitantes/km² | 50.000 |
| **Aglomeraciones Urbanas** | 8 direcciones (bordes + esquinas) | ≥ 300 habitantes/km² | 5.000 |

Las celdas que cumplen los criterios para Centros Urbanos o Aglomeraciones Urbanas se agrupan en una única categoría **Urbana**. Todas las celdas restantes no clasificadas se designan como **Rurales**.

### 3. Clasificación Municipal (Agregación Zonal)
Una vez clasificada la cuadrícula de 100m, una extracción de estadísticas zonales calcula la población que vive dentro de cada municipio. Un umbral estricto de regla de la mayoría dicta la designación final:
* **Municipio Urbano:** ≥ 50% de la población reside en celdas de cuadrícula Urbanas.
* **Municipio Rural:** < 50% de la población reside en celdas de cuadrícula Urbanas.

### 4. Seguimiento Longitudinal y Visualización
Debido a que esta clasificación se calcula de forma independiente para varios años, el resultado permite rastrear la tendencia longitudinal de la urbanización. Los archivos finales generados incluyen:
* **Matriz Estadística (CSV):** Conteos de población y porcentajes por municipio en todos los períodos de tiempo.
* **Mapa Web Interactivo (HTML):** Un mapa de series temporales para alternar entre años y visualizar los cambios espaciales de urbanización.
