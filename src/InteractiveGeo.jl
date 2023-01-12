module InteractiveGeo

using Scratch
using Pluto

function __init__()
    global DIR = joinpath(@get_scratch!("InteractiveGeo-user"))
end

function scratchfile(src)
    file = joinpath(DIR, basename(src))
    rm(file, force=true)
    cp(src, file)
end


"Load raster data, draw a polygon layer, and save it as GeoJSON."
function draw_polygon()
    Pluto.run(notebook=scratchfile(joinpath(@__DIR__, "..", "notebooks", "draw_polygon.jl")))
end


end #module
