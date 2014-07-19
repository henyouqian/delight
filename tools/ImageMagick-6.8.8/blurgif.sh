#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert cover.gif -channel RGBA  -blur 0x16 coverBlur.gif