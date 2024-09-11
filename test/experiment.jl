using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

using Rasters, ArchGDAL, CoordinateTransformations, GeoJSON, GeometryBasics, GLMakie, Markdown

path = "/Users/joshday/datasets/geospatial/FARAD_X_BAND/20151027_1027X04_PS0011_PT000001_N03_M1_CH0_OSAPF.ntf"

r = Raster(path, lazy=true)
r = Rasters._maybe_resample(r)  # Remove rotation: AffineMap => LinRange Axes
A = Observable(Rasters._subsample(r, 1000))

#-----------------------------------------------------------------------------# Figure
fig = Figure(size=(2000, 2000))
ax = Axis(fig[1, 2])
rowsize!(fig.layout, 1, Relative(1))

#-----------------------------------------------------------------------------# Polygons
coordinates = Observable(Point2f[])
coordinates_to_plot = Observable(Point2f[])  # Enclosed Polygon
dotted_line = Observable(Point2f[])

polygons = Observable(Vector{Point2f}[])

register_interaction!(ax, :polygon_click) do event::MouseEvent, axis
    # @info event.type
    if event.type === MouseEventTypes.leftclick
        push!(coordinates[], Point2f(event.data...))
        notify(coordinates)
        coordinates_to_plot[] = [coordinates[]..., coordinates[][1]]
    elseif !isempty(coordinates[])
        if event.type === MouseEventTypes.out
            dotted_line[] = [coordinates[][1], coordinates[][end]]
        else
            dotted_line[] = [coordinates[][end], Point2f(event.data...), coordinates[][1]]
        end
    end
end


#-----------------------------------------------------------------------------# UI Elements
width = 300

# remap functions
pseudolog10(x) = asinh(x/2) / log(10)
symlog10(x) = sign(x) * log10(abs(x) + 1)
remap_fun = Menu(fig; options=[cbrt, identity, log2, log10, sqrt, cbrt, pseudolog10, symlog10])

colormap = Menu(fig; options=[:viridis, :grays, :ground_cover, :inferno, :plasma, :magma, :tokyo, :devon, :hawaii, :buda, :RdBu, :BrBg])

max_res = Textbox(fig; placeholder="1000", validator=Int, width)

clear_btn = Button(fig; label="Clear Polygon", width)
save_btn = Button(fig; label="Save Polygon", width)
notes = Textbox(fig; placeholder="Notes in Markdown Format", width, height=300)

label(text) = Label(fig, text, fontsize=24, halign = :left, padding=(0,0,0,40))
polygons_label = label("Polygons (0 Saved)")

# UI Layout
fig[1,1] = vgrid!(
    label("Maximum Resolution"),
    max_res,

    label("Remap Function"),
    remap_fun,

    label("Colormap"),
    colormap,

    polygons_label,
    clear_btn,
    save_btn,
    notes,
    ;

    width, valign=:top
)



#-----------------------------------------------------------------------------# Observable Actions
on(max_res.stored_string) do v
    res = isnothing(v) ? 1000 : parse(Int, v)
    res = min(res, 5000)
    A[] = Rasters._subsample(r, res)
end

on(clear_btn.clicks) do _
    for ob in [coordinates, coordinates_to_plot, dotted_line]
        empty!(ob[])
        notify(ob)
    end
end

on(save_btn.clicks) do _
    push!(polygons[], copy(coordinates_to_plot[]))
    @info "Polygon Saved"
    clear_btn.clicks[] += 1
    polygons_label.text[] = "Polygons ($(length(polygons[])) Saved)"
end


#-----------------------------------------------------------------------------# Plot
h = heatmap!(ax, A, colormap=colormap.selection, colorscale=remap_fun.selection)
scatterlines!(ax, coordinates, markersize=20, color=:white)
lines!(ax, dotted_line, color=:white, linestyle=:dot)
Colorbar(fig[1,3], h)

fig
