#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert -define jpeg:size=200x200 icon.jpg  -thumbnail 181x256^ \
          -gravity center -extent 100x100  cut_to_fit.gif