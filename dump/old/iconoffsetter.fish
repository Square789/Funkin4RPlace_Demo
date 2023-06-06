#!/bin/fish
set ICON $argv[1]
set SCALE "$argv[2]%"
set x (math "$argv[3] * 6")
set y (math "$argv[4] * 6 + 1")
convert $ICON -crop 150x150 +repage +adjoin tmp-sep%d.png
convert tmp-sep*.png -trim -scale $SCALE -gravity NorthEast -background transparent -extent 150x150 -roll -$x+$y tmp-scaled%d.png
montage tmp-scaled*.png -tile 3x -background transparent -geometry 150x150 new-$ICON
rm tmp-sep*.png tmp-scaled*.png
