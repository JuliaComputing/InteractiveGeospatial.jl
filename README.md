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


## Graphical User Interface

![](https://github.com/user-attachments/assets/dc7c8641-873b-4b9f-ade9-cff07a01b3ee)

The above GUI is launched via the `draw_features` function.  The left panel contains the UI, and the right panel contains the map/raster.

Going top down, the UI contains the following components:

### Display Settings

- **Aggregate Function and Aggregate Scale.**  To avoid visualizing every pixel of a large raster, InteractiveGeospatial will aggregate the raster data into a smaller number of bins.  These two inputs are passed to the [`Rasters.aggregate`](https://rafaqz.github.io/Rasters.jl/dev/api#Rasters.aggregate) function.
- **Remap Function**.  This function is applied to the raster data before visualization.  For example, you can apply a logarithmic transformation to the data.
- **Colormap**.  The color map used to visualize the raster data.

### Draw Polygon

- **Color**.  The color of the polygon and text displayed over the image.
- **Clear Current Drawing**.  Clear the current drawing.
- **Label (Unique Identifier)**.  Polygons must be labeled with a unique name before they can be saved.
- **Save to Return Value**.  Save the polygon to the returned `Observable` from the `draw_features` function.
- **View Drawing**.  Display a previously-saved polygon over the image.
