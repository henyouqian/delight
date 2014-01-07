#!/bin/bash
export DYLD_LIBRARY_PATH="./lib/"

bin/convert aa.gif -crop 150x150+74+70 \
     -thumbnail 150x150^ zz.gif