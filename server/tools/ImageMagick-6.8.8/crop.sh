#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert in.gif -coalesce -repage 0x0 -crop 334x334+137+0 +repage \
	-resize 128x128 \
    icon.gif