Adding a new variant.

In the source folder, you need a VARIANT-tc.ps file which will define all of
the tiles that will be used in the variant. The VARIANT-map.ps file will then
place these tiles at the necessary coordinates to create an initial game map.

One of the trickiest things to get the hang of is defining the map layout.
See this sample taken from 1860.

	/mapRows 13 def
	/mapCols 12 def
	/mapScale 0.7 def
	/CM { 28.35 1 mapScale div mul mul } def
	mapScale dup scale
	20.5 CM 0 translate
	90 rotate
	/axesSwapped true def
	/mapFrame {
	0.7 CM 0.9 CM mapCols mapRows //hexSide 0.2 mul //hexSide 0.2 mul
		//hexHeight 0.25 mul //hexHeight 0.75 mul Map
	} def
	mapFrame

The mapFrame section is the fussiest part to figure out so we will look at it
first. mapScale will scale everything up accordingly. Use the largest scale
you can fit on a page.

The first two parameters (1.7 CM and 0.9 CM) are x- and y- offsets from the
corner of the page to the corner of the map bounding box. The next two vars
(mapCols and mapRows) are the numbers of columns and rows in the map. These
influence the size of the bounding box and control the number of labels
printed just outside the bounding box.

If you want the labels to start at something other than A1, you can use the
rowStart and colStart variables (such as 32-map.ps) to offset them.

The last four variables control the distance respetively from the left, right,
top and bottom of the first or last rows/columns on the grid to the bounding
box.
