module InteractiveGeospatial

using GLMakie, Rasters, Observables, Markdown, JSON3
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
            "type" => "Polygon",
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
function draw_features(r, ui_width=300, size=(800 + ui_width, 800))
    r = Rasters._maybe_resample(r)  # Remove rotation if rotated: AffineMap => LinRange Axes
    x_extrema, y_extrema = extrema.(r.dims)
    top_left = x_extrema[1], y_extrema[2]

    # Initialize Figure
    fig = Figure()
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

    polygon2view = Menu(fig; options=["none"])
    shape = @lift $(polygon2view.selection) == "none" ? Point2f[] : features[][$(polygon2view.selection)].coordinates

    max_res = Textbox(fig; stored_string="1000", validator=Int, width=ui_width)
    A = @lift Rasters._subsample(r, parse(Int, $(max_res.stored_string)))

    clear_btn = Button(fig; label="Clear", width=ui_width)
    on(clear_btn.clicks) do _
        click_coords[] = []
        messages.text[] = ""
    end

    polygon_label = Textbox(fig; placeholder="Polygon Label", width=ui_width, validator= x -> x ∉ keys(features[]))
    # ready_to_save = @lift $(polygon_label.stored_string) ∉ keys($features) && length($click_coords) > 2 && !isempty($(polygon_label.stored_string))


    save_btn = Button(fig; label="Save", width=ui_width)
    on(save_btn.clicks) do _
        if length(click_coords[]) > 2
            feat = PolygonFeature(polygon_label.stored_string[], [click_coords[]..., click_coords[][1]], md"")
            features[][feat.label] = feat
            notify(features)
            messages.color = :green
            push!(polygon2view.options[], feat.label)
            notify(polygon2view.options)
            messages.text[] = "Polygon Saved: \"$(feat.label)\""
            @info "Polygon Saved"
        else
            messages.color = :red
            messages.text[] = "Polygon must have at least 3 vertices"
        end
    end

    messages = Label(fig, ""; color=:green)

    label(text) = Label(fig, text, fontsize=24, halign = :left, padding=(0,0,0,40))
    sublabel(text) = Label(fig, text, fontsize=15, halign=:left, padding = (0,0,0,10))

    # UI Layout
    fig[1, 1] = vgrid!(valign=:top, width=ui_width,
        label("Maximum Resolution"),
            max_res,
        label("Remap Function"),
            remap_fun,
        label("Colormap"),
            colormap,
        label("Draw Polygon"),
            draw_color,
            clear_btn,
            sublabel("Enter Unique Label and Press Enter:"),
            polygon_label,
            save_btn,
            messages,
        label("View Saved Polygon"),
            polygon2view,
    )

    # Heatmap
    h = heatmap!(ax, A, colormap=colormap.selection, colorscale=remap_fun.selection)
    Colorbar(fig[1, 3], h)

    # Mouse position in top left corn
    text!(ax, top_left..., text=@lift(string($mouse_coords)), color=draw_color.selection, align=(:left, :top), fontsize=24)

    # Polygon Drawing
    scatterlines!(ax, click_coords, color=draw_color.selection, linewidth=2, markersize=20)
    lines!(ax, dotted_line, color=draw_color.selection, linewidth=2, linestyle=:dash)

    # Polygon Viewing
    poly!(ax, shape, color=draw_color.selection, linestyle=(:dot, :dense), alpha=.3)

    resize_to_layout!(fig)
    display(fig, px_per_unit = 2)

    return features
end

end #module
