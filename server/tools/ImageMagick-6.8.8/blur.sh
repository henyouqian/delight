#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert cover.jpg -channel RGBA  -blur 0x16 coverBlur.jpg