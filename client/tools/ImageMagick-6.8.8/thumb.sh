#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert -define jpeg:size=181x256 cover.jpg -quality 95 -thumbnail 181x256^ \
          -gravity center -extent 181x256 thumb.jpg