#!/bin/fish

set SIZE 6
set OX 4
set OY 3

set ICON $argv[1]
set FRAMES (math ceil\((convert $ICON -format "%[fx:w/150]" info:)\))

convert $ICON -crop 150x150 +repage +adjoin tmp-sep%d.png
convert tmp-sep*.png -trim tmp-trimmed%d.png

for j in (seq $FRAMES)
	set i (math $j - 1)
	set offset (convert tmp-trimmed$i.png -format "%O" info:)
	
	set x (math ceil\(\((string match -rg "\+(\d+)\+\d+" $offset) - $OX\) / $SIZE\) \* $SIZE + $OX)
	set y (math floor\(\((string match -rg "\+\d+\+(\d+)" $offset) - $OY\) / $SIZE\) \* $SIZE + $OY)
	
	echo "FRAME $j: (old: $offset, new: +$x+$y)"
	
	convert tmp-trimmed$i.png -gravity NorthWest -background transparent -extent 150x150 -roll +$x+$y tmp-new$i.png
end

mv $ICON $ICON.bak
montage tmp-new*.png -background transparent -geometry 150x150 $ICON
rm tmp-sep*.png tmp-trimmed*.png tmp-new*.png