# InteractiveGeo

- **InteractiveGeo** is a Julia package that provides interactive tools that aid in working with geospatial data.
- **InteractiveGeo** is built primarily on top of [GLMakie](https://docs.makie.org/stable/explanations/backends/glmakie#glmakie) and [Rasters](https://rafaqz.github.io/Rasters.jl/dev/).

## Usage


```julia
using Rasters, InteractiveGeo, RasterDataSources

# Load a Raster
files = getraster(WorldClim{Climate}, :wind; month=1:12)
r = Raster(files[1])

# Create an Interactive Map of the Raster
# The returned `features` object is an `Observable` that is populated based on features (polygons) drawn on the map
features = draw_features(r)

# You can now add Markdown annotations to the polygon features
features[]["polygon_label"] = md"My notes"

# Finally, you can save features as GeoJSON
str = geojson(features[])  # String representation of the GeoJSON
write("features.geojson", str)  # Save the GeoJSON to a file
```

![](https://github.com/user-attachments/assets/dc7c8641-873b-4b9f-ade9-cff07a01b3ee)
