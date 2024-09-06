using InteractiveGeospatial, Rasters, ArchGDAL, RasterDataSources


files = getraster(WorldClim{Climate}, :wind; month=1:12)

r = Raster(files[1])

features = draw_features(r)
