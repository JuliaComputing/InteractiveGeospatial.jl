using Test, InteractiveGeospatial, Rasters, ArchGDAL, RasterDataSources, GeoJSON, GLMakie, Markdown


files = getraster(WorldClim{Climate}, :wind; month=1:12)

r = Raster(files[1])

features = draw_features(r)

file = tempname()

write(file, geojson(features[]))

@test isempty(GeoJSON.read(file))

# Simulate interaction
features[]["test"] = InteractiveGeospatial.PolygonFeature("test", [Point2f(0, 0), Point2f(1, 1)], md"test")
write(file, geojson(features[]))
@test length(GeoJSON.read(file)) == 1
