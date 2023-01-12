module InteractiveGeo

using Scratch
using Pluto

function __init__()
    global DIR = joinpath(@get_scratch!("InteractiveGeo-user"))
end


"Load raster data, draw a polygon layer, and save it as GeoJSON."
function draw_polygon()
    file = cp(joinpath(@__DIR__, "..", "notebooks", "draw_polygon.jl"), joinpath(DIR, "draw_polygon.jl"))
    Pluto.run(notebook=file)
end


end #module
