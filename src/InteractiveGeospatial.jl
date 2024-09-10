module InteractiveGeospatial

using GLMakie, Rasters, Observables, Markdown, JSON3, Statistics
using OrderedCollections: OrderedDict

export draw_features, @md_str, geojson

#-----------------------------------------------------------------------------# remap functions
pseudolog10(x) = asinh(x/2) / log(10)
symlog10(x) = sign(x) * log10(abs(x) + 1)

#-----------------------------------------------------------------------------# PolygonFeature
mutable struct PolygonFeature
    label::String
    coordinates::Vector{Point2f}
    notes::Markdown.MD
end

function prepare_geojson_write(feat::PolygonFeature)
    OrderedDict(
        "type" => "Feature",
        "geometry" => OrderedDict(
            "type" => "LineString",
            "coordinates" => feat.coordinates
        ),
        "properties" => OrderedDict(
            "label" => feat.label,
            "notes" => repr(feat.notes)
        )
    )
end
function prepare_geojson_write(features::OrderedDict{String, PolygonFeature})
    OrderedDict(
        "type" => "FeatureCollection",
        "features" => [prepare_geojson_write(feat) for feat in values(features)]
    )
end

geojson(x) = JSON3.write(prepare_geojson_write(x))


#-----------------------------------------------------------------------------# draw_features
function draw_features(r)
    r = Rasters._maybe_resample(r)  # Remove rotation if rotated: AffineMap => LinRange Axes
    x_extrema, y_extrema = extrema.(r.dims)
    top_left = x_extrema[1], y_extrema[2]
    top_right = x_extrema[2], y_extrema[2]
    ui_width = 200

    # Initialize Figure
    fig = Figure(; size = (1300, 1000))
    display(fig)
    ax = Axis(fig[1, 2])
    rowsize!(fig.layout, 1, Relative(1))

    # clicks and related observables
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

    #### UI Observables ####
    # UI Helper Functions
    menu(options...) = Menu(fig; options=collect(options), width=ui_width)
    button(label) = Button(fig; label, width=ui_width)
    # `padding = (left, right, bottom, top)`
    label(text) = Label(fig, text, fontsize=18, halign = :left, padding=(0,0,-5,5), color=:black)
    sublabel(text) = Label(fig, text, fontsize=10, halign=:left, padding = (0,0,-15,0), color=:gray)

    # `aggregate` Inputs
    init_scale = round(Int, maximum(size(r)) / 1000)
    scale = Textbox(fig; stored_string=string(init_scale), validator=Int, width=ui_width)
    aggregate_fun = menu(sum, mean, minimum, maximum)

    # `aggregate` Output (Raster plotted with heatmap)
    A = Observable{AbstractMatrix}(aggregate(sum, r, init_scale))
    onany(aggregate_fun.selection, scale.stored_string) do fun, scale
        A[] = aggregate(fun, r, parse(Int, scale))
    end

    draw_color = menu(:white, :black, :red, :blue, :green, :orange, :gray)
    remap_fun = menu(cbrt, identity, sqrt, cbrt, pseudolog10, symlog10)
    colormap = menu(:viridis, :grays, :ground_cover, :inferno, :plasma, :magma, :tokyo, :devon, :hawaii, :buda, :RdBu, :BrBg)

    polygon2view = menu("none")
    shape = @lift $(polygon2view.selection) == "none" ? Point2f[] : features[][$(polygon2view.selection)].coordinates


    clear_btn = button("Clear")
    on(clear_btn.clicks) do _
        click_coords[] = []
        messages.text[] = ""
    end

    polygon_label = Textbox(fig; placeholder="Polygon Label", width=ui_width, validator= x -> x ∉ keys(features[]))

    save_btn = button("Save")
    on(save_btn.clicks) do _
        if length(click_coords[]) > 2
            feat = PolygonFeature(polygon_label.stored_string[], [click_coords[]..., click_coords[][1]], md"")
            features[][feat.label] = feat
            notify(features)
            messages.color = :green
            push!(polygon2view.options[], feat.label)
            notify(polygon2view.options)
            messages.text[] = "Polygon Saved: \"$(feat.label)\""
            @info "Polygon Saved: \"$(feat.label)\""
        else
            messages.color = :red
            messages.text[] = "Polygon must have at least 3 vertices"
        end
    end

    messages = Label(fig, ""; color=:green)



    # UI Layout
    fig[1, 1] = vgrid!(valign=:top, halign=:left, width=1.2ui_width,
        label("Display Settings ($(size(r, 1)) × $(size(r, 2)))"),
        sublabel("Aggregate Function"),
        aggregate_fun,
        sublabel("Aggregate Scale"),
        scale,
        sublabel("Remap Function"),
            remap_fun,
        sublabel("Colormap"),
            colormap,
        label("Draw Polygon"),
            sublabel("Color"),
            draw_color,
            sublabel("Clear Current Drawing"),
            clear_btn,
            sublabel("Label (Unique Identifier)"),
            polygon_label,
            sublabel("Save to Return Value"),
            save_btn,
            messages,
        label("View Drawing"),
            polygon2view,
    )

    # Heatmap
    h = heatmap!(ax, A, colormap=colormap.selection, colorscale=remap_fun.selection)
    Colorbar(fig[1, 3], h)

    # Mouse position in top left corn
    text!(ax, top_left..., text=@lift(string(' ', map(Float64, ($mouse_coords)))), color=draw_color.selection, align=(:left, :top), fontsize=12)

    # Resolution
    text!(ax, top_right..., text=@lift(string("Resolution: ", size($A, 1), " × ", size($A, 2), ' ')), color=draw_color.selection, align=(:right, :top), fontsize=12)

    # Polygon Drawing
    scatterlines!(ax, click_coords, color=draw_color.selection, markersize=10)
    lines!(ax, dotted_line, color=draw_color.selection, linestyle=:dash)

    # Polygon Viewing
    poly!(ax, shape, color=draw_color.selection, linestyle=(:dot, :dense), alpha=.3)

    resize_to_layout!(fig)


    return (; features, click_coords)
end

end #module
