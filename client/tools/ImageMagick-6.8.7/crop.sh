#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert in.gif -coalesce -repage 0x0 -crop 256x256+125+83 +repage \
	-resize 128x128 \
    icon.gif