### A Pluto.jl notebook ###
# v0.19.46

using Markdown
using InteractiveUtils

# ╔═╡ eaa940d8-660f-11ef-3578-c7ec2f570496
begin 
	using Pkg 
	Pkg.activate(joinpath(@__DIR__, ".."))

	using ArchGDAL, CoordinateTransformations, Rasters, PlutoUI, Extents, GLMakie, 
		  About, PlutoHooks, DataFrames
	using Cobweb: h
	using PlotlyLight
	PlotlyLight.settings.div = h.div(style="width:700px;height:700px")
	import GeoJSON
	PlutoUI.TableOfContents()
end

# ╔═╡ 3a8b1fd6-d4ef-41f2-8862-44588d4f933d
md"""
# Load Raster

| Variable (w/ Default) | Description |
|----------|-------------|
`path = ""` | file path of raster
`geojson_path = ""` | file path of geojson file
`max_res = 1000` | Maximum resolution to plot
`colorscale = cbrt` | Remap function
`colormap = :viridis` | Colorscale of heatmap
`band = 1` | Band to view (only for 3D Arrays)
"""

# ╔═╡ 0d1f7998-bfc7-477b-9b30-c37ec8a53b79
path = "/Users/joshday/datasets/geospatial/FARAD_X_BAND/20151027_1027X04_PS0011_PT000001_N03_M1_CH0_OSAPF.ntf"

# ╔═╡ c2008154-09ec-4599-88c6-06d5686e6cf2
geojson_path = ""

# ╔═╡ 8b31bd88-a734-49cf-a147-e61274385d47
max_res = 1000

# ╔═╡ 058602ca-ebb8-446a-86f5-6a929eb25846
colorscale = cbrt

# ╔═╡ 9c28755a-db49-4317-9d6d-a9d6150f4348
colormap = :viridis

# ╔═╡ 766ea541-72c0-4da9-8067-a7f220c34b0e
band = 1

# ╔═╡ f76f9eb8-8edd-4693-8901-342a9e2cf0d3
begin 
	geojson = if isempty(geojson_path) 
		@info "No GeoJSON File provided.  Creating new table."
		DataFrame(; geometry=[]) 
	else
		DataFrame(GeoJSON.read(geojson_path))
	end
end

# ╔═╡ 72c8035f-0b08-4529-bfe7-788efda4f834
Rasters.GeoJSON

# ╔═╡ bb7b0c84-aeed-4f15-9f58-651f994f63d9
begin 
	colorscale_opts = sort!(["Greys", "Blues", "YlOrRd", "YlGnBu", "RdBu", "Portland", "Picnic", "Jet", "Hot", "Greens", "Electric", "Earth", "Bluered", "Blackbody"])

	md"""
	# Plot
	"""
end

# ╔═╡ df240886-bdf1-4f2d-a2df-5a0bd642c5af
# ╠═╡ disabled = true
#=╠═╡
begin 
	idx = length(size(r2)) == 3 ? [:, :, band] : [:, :]

	fig = Figure()
	ax = Axis(fig[1,1])
	hmap = heatmap!(ax, getindex(r2, idx...); colormap, colorscale)
	Colorbar(fig[1,2], hmap)
	fig
end
  ╠═╡ =#

# ╔═╡ b0740d40-9d57-44cb-aff0-752e8e054653
md"""
# State
"""

# ╔═╡ d799c8ba-363f-4c29-9672-5f1f60e57dbe
coordinates, set_coordinates = @use_state([])

# ╔═╡ 7064de72-e113-4f1f-9629-b4abe9f431d7
features, set_features = @use_state([])

# ╔═╡ bad0141f-ee94-48ba-84be-9b6a2477eed3
md"# Notebook Utilities"

# ╔═╡ e0ed90e2-12ee-456b-9491-4628871f49be
macro ifdata(ex)
	esc(quote
		if !isempty(path)
			$ex
		elseif !isfile(path)
			@warn "No file found at path: $path"
		else
			@info "no dataset selected."
		end
	end)
end

# ╔═╡ f238af1b-0643-44dd-9ed6-f2177b1c564a
@ifdata begin
	r = Raster(path)
	ext = Extents.extent(r)
	nbands = size(r.data, 3)

	@info """
	Source Raster
	=============
	
	- $(summary(r))
	- X: $(ext.X)
	- Y: $(ext.Y)
	"""
end;

# ╔═╡ 314472b5-9eab-47f1-a629-f77f72e030cb
begin 
	r2 = Rasters._maybe_resample(r)
    r2 = Rasters._subsample(r2, max_res)
	@info """
	Subsampled Raster
	=================
	
	- $(summary(r2))
	"""
end

# ╔═╡ 0c0528c0-f989-4afb-963c-0b52bf52238d
begin 
	idx = length(size(r2)) == 3 ? [:, :, band] : [:, :]
	A = getindex(r2, idx...)
	@info """
	Raster to Plot
	==============

	- $(summary(A))
	"""
end

# ╔═╡ d6f6ea9e-4064-48ad-a0a3-3016b660a803
begin 
	p = PlotlyLight.plot(z=A, type="heatmap")

	h.div(class="width=100%;height=100%",
		PlotlyLight.html_div(p; id="_plot_"),
		h.script("""
		var p = document.getElementById("_plot_");

		console.log("hi")
		""")
	)
end

# ╔═╡ 43b89c8c-4149-4900-9e5e-445ffe81902c
function haversine(a, b; R=6372.8)
    Δlat = b.lat - a.lat
    Δlon = b.lon - a.lon
    a = sind(Δlat / 2) ^ 2 + cosd(a.lat) * cosd(b.lat) * sind(Δlon / 2) ^ 2
    2R * asin(min(sqrt(a), one(a)))
end

# ╔═╡ 15526a94-7d8f-4494-8a2a-0388da1609ed
function latlonratio(lat, lon)
    Δlat = haversine((lat=0,lon=0), (lat=1,lon=0))
    Δlon = haversine((;lat, lon = lon - .5), (;lat, lon = lon + .5))
    Δlat / Δlon
end

# ╔═╡ Cell order:
# ╠═eaa940d8-660f-11ef-3578-c7ec2f570496
# ╟─3a8b1fd6-d4ef-41f2-8862-44588d4f933d
# ╠═0d1f7998-bfc7-477b-9b30-c37ec8a53b79
# ╠═c2008154-09ec-4599-88c6-06d5686e6cf2
# ╠═8b31bd88-a734-49cf-a147-e61274385d47
# ╠═058602ca-ebb8-446a-86f5-6a929eb25846
# ╠═9c28755a-db49-4317-9d6d-a9d6150f4348
# ╠═766ea541-72c0-4da9-8067-a7f220c34b0e
# ╟─f238af1b-0643-44dd-9ed6-f2177b1c564a
# ╟─314472b5-9eab-47f1-a629-f77f72e030cb
# ╟─0c0528c0-f989-4afb-963c-0b52bf52238d
# ╠═d6f6ea9e-4064-48ad-a0a3-3016b660a803
# ╠═f76f9eb8-8edd-4693-8901-342a9e2cf0d3
# ╠═72c8035f-0b08-4529-bfe7-788efda4f834
# ╠═bb7b0c84-aeed-4f15-9f58-651f994f63d9
# ╠═df240886-bdf1-4f2d-a2df-5a0bd642c5af
# ╟─b0740d40-9d57-44cb-aff0-752e8e054653
# ╠═d799c8ba-363f-4c29-9672-5f1f60e57dbe
# ╠═7064de72-e113-4f1f-9629-b4abe9f431d7
# ╟─bad0141f-ee94-48ba-84be-9b6a2477eed3
# ╟─e0ed90e2-12ee-456b-9491-4628871f49be
# ╟─43b89c8c-4149-4900-9e5e-445ffe81902c
# ╟─15526a94-7d8f-4494-8a2a-0388da1609ed
