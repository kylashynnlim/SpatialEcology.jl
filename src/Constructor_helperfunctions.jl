
function isWorldmapData(dat::DataFrames.DataFrame, latlong = true)
  DataFrames.ncol(dat) == 5 || return false

  if eltype(dat[:, 1]) <: String
    if eltype(dat[:, 4]) <: Number
      if eltype(dat[:, 5]) <: Number
        latlong || return true # risky
        if minimum(dropna(dat[:, 4])) > -181 && maximum(dropna(dat[:, 4])) < 181
          if minimum(dropna(dat[:, 5])) > -91 && maximum(dropna(dat[:, 5])) < 91
            return true
          end
        end
      end
    end
  end
  false
end


function parsesingleDataFrame(occ::DataFrames.DataFrame)
    if isWorldmapData(occ)
      println("Data format identified as Worldmap export file")
      coords = occ[4:5]
      coords[:sites] = createsitenames(coords)
      occ = DataFrame(site = coords[:sites], abu = ones(Int, DataFrames.nrow(occ)), species = occ[1])
      coords = unique(coords, :sites)
    else
     # if (firstnumeric = BenHoltMatrix(occ)) > 1
    #    println("Data assumed to be a concatenation of coordinates ($(firstnumeric - 1) columns) and occurrence matrix")
    #    coords = occ[1:(firstnumeric-1)]
    #    occ = occ[firstnumeric:end]
     # else
        error("If not commatrix is already of type distrib_data or nodiv_data, a worldmap matrix, or a
          concatenation of coords and community matrix, coords must be specified")
     # end
    end
  occ, coords
end


function parseDataFrame(occ::DataFrames.DataFrame)
  if DataFrames.ncol(occ) == 3 && eltypes(occ)[3] <: String
    println("Data format identified as Phylocom")
    occ = unstack(occ, 1, 2)
  end

  if eltypes(occ)[1] <: String
    sites = Vector(occ[1])
    occ = occ[2:end]
  else
    sites = string.(1:DataFrames.nrow(occ)) #TODO this means that occ will not have the right names in many cases - fix later
  end

  try
    occ = dataFrametoNamedMatrix(occ, sites, Bool, dimnames = ("sites", "species"))
    println("Matrix data assumed to be presence-absence")
  catch
    occ = dataFrametoNamedMatrix(occ, sites, Int, dimnames = ("sites", "species")) # This line means that this code is not completely type stable. So be it.
    println("Matrix data assumed to be abundances, minimum $(minimum(occ)), maximum $(maximum(occ))")
  end

  occ
end

function guess_xycols(dat::DataFrames.DataFrame)
  numbers = map(x -> x<:Number, eltypes(dat))
  sum(!numbers) == 1 || error("Site names cannot be numeric in the input matrix")
  ((find(numbers)[1:2])...)
end

function dataFrametoNamedMatrix(dat::DataFrames.DataFrame, rownames = string.(1:DataFrames.nrow(dat)), T::Type = Float64, replace = zero(T); sparsematrix = true, dimnames = ("A", "B"))
  colnames = string.(names(dat))
  a = 0
  # for i in 1:DataFrames.ncol(dat)
  #   a += sum(DataFrames.isna(dat[i]))
  #   dat[i] = convert(Array, dat[i], replace)  #This takes out any NAs that may be in the data frame and replace with 0
  # end

 for i in 1:DataFrames.ncol(dat)
     rep = DataFrames.isna(dat[i])
     a += sum(rep)
     dat[:,i][rep] = replace
 end

 dat = convert(Array{T}, dat)  # for some reason it really complains about this

  a > 0 && println("$a NA values were replaced with $(replace)'s")
  try
    dat = sparsematrix ? sparse(Matrix{T}(dat)) : Matrix{T}(dat)
  catch
    error("Cannot convert DataFrame to Matrix{$T}")
  end

  dat = NamedArrays.NamedArray(dat, (Vector{String}(rownames), Vector{String}(colnames)), dimnames) #the vector conversion is a bit hacky
  dat
end

function match_commat_coords(occ::ComMatrix, coords::AbstractMatrix{Float64}, sitestats::DataFrames.DataFrame)
  occ, coords, sitestats
 ## so far this does nothing TODO
end

function dropspecies!(occ::OccFields)
  occurring = occupancy(occ) .> 0
  occ.commatrix = occ.commatrix[:, occurring]
  occ.traits = occ.traits[occurring,:]
end

function dropbyindex!(site::PointData, indicestokeep)
  site.coords = site.coords[indicestokeep,:]
  site.sitestats = site.sitestats[indicestokeep,:]
end

# these functions will be removed eventually
maxrange(x) = diff([extrema(x)...])[1]

# remember here - something wrong with the indices, make sure they are based from 1!

function dropbyindex!(site::GridData, indicestokeep)
  site.indices = site.indices[indicestokeep,:]
  site.sitestats = site.sitestats[indicestokeep,:]
  site.grid.xmin = xrange(site.grid)[minimum(site.indices[:,1])]
  site.grid.ymin = yrange(site.grid)[minimum(site.indices[:,2])]
  site.grid.xcells = maxrange(site.indices[:,1]) + 1
  site.grid.ycells = maxrange(site.indices[:,2]) + 1
  site.indices = site.indices - minimum(site.indices) + 1
end

function dropsites!(occ::OccFields, site::SiteFields)
  hasspecies = find(richness(occ) .> 0)
  occ.commatrix = occ.commatrix[hasspecies,:]
  dropbyindex!(site, hasspecies)
end

function createsitenames(coords::AbstractMatrix)
  size(coords, 2) == 2 || error("Only defined for matrices with two columns")
  mapslices(x->"$(x[1])_$(x[2])", coords, 2)
end

function createsitenames(coords::DataFrames.DataFrame)
  size(coords, 2) == 2 || error("Only defined for matrices with two columns")
  ["$(coords[i,1])_$(coords[i,2])" for i in 1:DataFrames.nrow(coords)]
end

creategrid(coords::NamedArrays.NamedMatrix{Float64}, tolerance = sqrt(eps())) =
    GridTopology(gridvar(coords[:,1], tolerance)..., gridvar(coords[:,2], tolerance)...)

function gridvar(x, tolerance = sqrt(eps())) 
  sux = sort(unique(x))
  difx = diff(sux)
  length(difx) == 0 && error("Cannot make a grid with width 1 in the current implementation") #TODO
  rudifx = [extrema(unique(difx))...]
  if rudifx[1]/rudifx[2] < tolerance
    difx = difx[difx .> rudifx[2] * tolerance]
    rudifx = [extrema(unique(difx))...]
  end

  err1 = diff(rudifx)[1]
  if err1 > tolerance
    xx = rudifx ./ minimum(rudifx)
    err2 = maximum(abs(floor(xx) - xx))
    err2  > tolerance && error("Cannot be converted to grid, as coordinate intervals are not constant. Try adjusting the tolerance (currently $tolerance)")
    difx = difx[difx .< rudifx[1] + tolerance]
  end

  cellsize = mean(difx)
  min = minimum(sux)
  cellnumber = Int(round(maxrange(sux) / cellsize) + 1)

  min, cellsize, cellnumber
end

function getindices(coords::NamedArrays.NamedMatrix{Float64}, grid::GridTopology, tolerance = 2*sqrt(eps()))
  index1 = 1 + floor(Int,(coords[:,1] .- grid.xmin) ./ grid.xcellsize .+ tolerance)
  index2 = 1 + floor(Int,(coords[:,2] .- grid.ymin) ./ grid.ycellsize .+ tolerance)
  NamedArrays.NamedArray(hcat(index1, index2), NamedArrays.names(coords), dimnames(coords))
end
