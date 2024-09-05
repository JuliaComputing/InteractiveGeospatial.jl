using InteractiveGeospatial, GeoMakie, Rasters, RasterDataSources, ArchGDAL, Test


getraster(WorldClim{Climate}, :wind; month=1:12)
