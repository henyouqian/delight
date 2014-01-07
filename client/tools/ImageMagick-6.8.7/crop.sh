#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert icon.gif -coalesce -repage 0x0 -crop 256x256+55+0 +repage \
	#-resize 128x128 \
    iconNew.gif