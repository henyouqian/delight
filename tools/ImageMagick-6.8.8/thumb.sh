#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert -define jpeg:size=256x256 cover.jpg -quality 95 -thumbnail 256x256^ \
          -gravity center -extent 256x256 thumb.jpg