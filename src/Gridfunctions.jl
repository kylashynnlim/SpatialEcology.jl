xmin(g::GridTopology) = g.xmin
ymin(g::GridTopology) = g.ymin
cellsize(g::GridTopology) = g.xcellsize, g.ycellsize
xcellsize(g::GridTopology) = g.xcellsize
ycellsize(g::GridTopology) = g.ycellsize
xcells(g::GridTopology) = g.xcells
ycells(g::GridTopology) = g.ycells
cells(g::GridTopology) = g.xcells, g.ycells
xmax(g::GridTopology) = g.xmin + g.xcellsize*g.xcells
ymax(g::GridTopology) = g.ymin + g.ycellsize*g.ycells
xrange(g::GridTopology) = xmin(g):xcellsize(g):xmax(g)
yrange(g::GridTopology) = ymin(g):ycellsize(g):ymax(g)
boundingbox(g::GridTopology) = Bbox(xmin(g), xmax(g), ymin(g), ymax(g))
show(io::IO, b::Bbox) = println("xmin:\t$(g.xmin)\nxmax:\t$(g.xmax)\nymin:\t$(g.ymin)\nymax:\t$(g.ymax)\n")

@forward AbstractGridData.grid xmin, ymin, cellsize, xcellsize, ycellsize, xcells, ycells, cells, xmax, ymax, xrange, yrange, boundingbox
