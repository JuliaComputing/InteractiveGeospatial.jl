module InteractiveGeospatial

using GLMakie, Rasters, Observables, Markdown
using OrderedCollections: OrderedDict
import GeoJSON


#-----------------------------------------------------------------------------# remap functions
pseudolog10(x) = asinh(x/2) / log(10)
symlog10(x) = sign(x) * log10(abs(x) + 1)

#-----------------------------------------------------------------------------# PolygonFeature
struct PolygonFeature
    label::String
    coordinates::Vector{Point2f}
    notes::Markdown.MD
end

#-----------------------------------------------------------------------------# draw_features
function draw_features(r, ui_width=300, size=(1000, 1000))
    r = Rasters._maybe_resample(r)  # Remove rotation if rotated: AffineMap => LinRange Axes
    x_extrema, y_extrema = extrema.(r.dims)
    top_left = x_extrema[1], y_extrema[2]

    # Initialize Figure
    fig = Figure(; size)
    ax = Axis(fig[1, 2])
    rowsize!(fig.layout, 1, Relative(1))

    # Observables
    mouse_coords = Observable((x=0f0, y=0f0))  # where mouse is hovering in terms of raster coordinates
    click_coords = Observable(Point2f[])
    dotted_line = @lift isempty($click_coords) ? Point2f[] : [first($click_coords), last($click_coords)]
    features = Observable(OrderedDict{String, PolygonFeature}())

    register_interaction!(ax, :polygon_click) do event::MouseEvent, axis
        mouse_coords[] = (x = event.data[1], y = event.data[2])
        if event.type === MouseEventTypes.leftclick
            push!(click_coords[], event.data)
            notify(click_coords)
        end
    end

    # Create UI Observables
    draw_color = Menu(fig; options=[:white, :black, :red, :blue, :green, :orange, :gray])
    remap_fun = Menu(fig; options=[cbrt, identity, sqrt, cbrt, pseudolog10, symlog10])
    colormap = Menu(fig; options=[:viridis, :grays, :ground_cover, :inferno, :plasma, :magma, :tokyo, :devon, :hawaii, :buda, :RdBu, :BrBg])

    max_res = Textbox(fig; stored_string="1000", validator=Int, width=ui_width)
    A = @lift Rasters._subsample(r, parse(Int, $(max_res.stored_string)))

    clear_btn = Button(fig; label="Clear", width=ui_width)
    on(clear_btn.clicks) do _
        click_coords[] = []
    end

    save_btn = Button(fig; label="Save", width=ui_width)
    on(save_btn.clicks) do _
        if length(click_coords[]) > 2
            feat = PolygonFeature(polygon_label.stored_string[], [click_coords[]..., click_coords[][1]], md"")
            features[][feat.label] = feat
            notify(features)
            messages.color = :green
            messages.text[] = "Polygon Saved: \"$(feat.label)\""
            @info "Polygon Saved"
        else
            messages.color = :red
            messages.text[] = "Polygon must have at least 3 vertices"
        end
    end

    polygon_label = Textbox(fig; stored_string="Polygon 1", width=ui_width, validator= x -> x ∉ keys(features[]))

    messages = Label(fig, ""; color=:green)

    label(text) = Label(fig, text, fontsize=24, halign = :left, padding=(0,0,0,40))

    # UI Layout
    fig[1, 1] = vgrid!(valign=:top, width=ui_width,
        label("Maximum Resolution"),
            max_res,
        label("Remap Function"),
            remap_fun,
        label("Colormap"),
            colormap,
        label("Polygon"),
            Label(fig, "  Color:", halign=:left, fontsize=18),
                draw_color,
            Label(fig, "  Current Drawing", halign=:left, fontsize=18),
            clear_btn,
            polygon_label,
            save_btn,
            messages
    )

    # Plot
    h = heatmap!(ax, A, colormap=colormap.selection, colorscale=remap_fun.selection)
    text!(ax, top_left..., text=@lift(string($mouse_coords)), color=draw_color.selection, align=(:left, :top), fontsize=24)
    scatterlines!(ax, click_coords, color=draw_color.selection, linewidth=2, markersize=20)
    lines!(ax, dotted_line, color=draw_color.selection, linewidth=2, linestyle=:dash)
    Colorbar(fig[1, 3], h)

    display(fig)

    return features
end


# function interact!(f::Figure, ax::Axis)
#     feature_collection = @NamedTuple{geometry::Any}[]
#     f = Figure()
#     ax(f)
#     f
# end

# using GLMakie

# img = rand(50,50)

# fig, ax = image(img)

# display(fig)

# on(events(fig).mousebutton, priority=0) do event
#     if event.button == Mouse.left
#         x, y = mouseposition(ax.scene)
#         scatter!(ax, [x], [y], marker='+', color=:red, markersize=30)
#     end
# end

# 2015 FARAD X-band


# function Makie.convert_arguments(::Type{<:AbstractPlot}, ann::Annotation)
#     # TODO: figure out recipe for this
# end



# #-----------------------------------------------------------------------------# AnnotatedFigure
# struct AnnotatedAxis
#     axis::Axis
#     annotations::Observable{Vector{Annotation}}
# end
# # TODO: display
# # TODO: ability to add annotations
# # TODO: ability to delete annotations
# # TODO: button to download annotations as GeoJSON

# # #-----------------------------------------------------------------------------# test
# function test(r)
#     fig = Figure()
#     ax = Axis(fig[1,1])
# #     buttons = fig[2, 1] = GridLayout(tellwidth = false)
# #     buttons[1, 1] = Button(fig, label="Draw Polygon")
# #     buttons[1, 2] = Button(fig, label="Add Markdown Annotation")


# #     heatmap!(ax, r)
# #     fig
# end

#-----------------------------------------------------------------------------# draw_polygon
# function plotly_draw_polygon(z::AbstractMatrix{<:Number})
#     # trace for polygon
#     p = Plot(type="scatter", mode="markers+lines", x=[], y=[], name="",
# 		fill="toself", marker=Config(color="black",alpha=0.2))


# 	p(; type="heatmap", x, y, z=collect(eachrow(z)))

# 	p.layout.title = "Resize Factor=$resize, Remap=$remap"
# 	p.layout.yaxis.scaleratio = latlonratio(origin)
#     p.layout.geo.projection.type = "equirectangular"
# 	PlotlyLight.Defaults.parent_style[] = "height: 500px"

# 	# Add to trace on click
# 	p.js = Javascript("""
# 		const plotDiv = document.getElementById($(repr(p.id)))

# 		plotDiv.on('plotly_click', (data) => {
# 			console.log(plotDiv.data[0])
# 			var x = plotDiv.data[0].x
# 			var y = plotDiv.data[0].y

# 			x.push(data.points[0].x)
# 			y.push(data.points[0].y)
# 			Plotly.restyle(plotDiv, {x:[x], y:[y]}, 0)
# 		});

# 		const resetButtonDiv = document.getElementById("reset-button")

# 		resetButtonDiv.onclick = () => {
# 			console.log("reset button clicked")
# 			Plotly.restyle(plotDiv,{ x:[[]], y:[[]]}, 0)
# 		}

# 		const downloadButtonDiv = document.getElementById("download-button")

# 		// TODO: Download geojson
# 		downloadButtonDiv.onclick = () => {
# 			var x = plotDiv.data[0].x;
# 			var y = plotDiv.data[1].y;
# 			var coords = x.map((x,i) => [x, y[i]])
# 			coords.push(coords[0])
# 			var obj = { type: "Polygon", coordinates: coords }
# 			var dataStr = "data:text/json;charset=utf-8," +
# 				encodeURIComponent(JSON.stringify(obj));
# 		    var downloadAnchorNode = document.createElement('a');
# 		    downloadAnchorNode.setAttribute("href",     dataStr);
# 		    downloadAnchorNode.setAttribute("download", "polygon.geojson");
# 		    document.body.appendChild(downloadAnchorNode); // required for firefox
# 		    downloadAnchorNode.click();
# 		    downloadAnchorNode.remove();
# 		}
# 	""")
# 	h.div(
# 		h.div(p),
# 		h.button("Reset Polygon", type="button", id="reset-button"),
# 		h.button("Download Polygon", type="button", id="download-button")
# 	)
# end


end #module
