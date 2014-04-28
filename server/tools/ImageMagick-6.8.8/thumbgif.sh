#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert -define gif:size=128x128 cover.gif -quality 95 -thumbnail 128x128^ \
          -gravity center -extent 128x128 thumb.gif