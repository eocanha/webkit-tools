#!/bin/sh
. /home/enrique/work/webkit/env.sh
PLATFORM=GTK
BUILD=Release
EXTRA_FLAGS='-D__OPTIMIZE__'
EXTRA_INCLUDE=$T/WebKit.config
cat $W/WebKit/WebKitBuild/GTK/$BUILD/compile_commands.json \
 | sed -e 's#/app/webkit#'$W'/WebKit#g' \
       -e 's#WebKitBuild/'$BUILD'#WebKitBuild/'$PLATFORM'/'$BUILD'#g' \
       -e 's#[.][.]/[.][.]/Source#../../../Source#g' \
       -e 's#-DBUILDING_WITH_CMAKE=1#-DBUILDING_WITH_CMAKE=1 '$EXTRA_FLAGS'#g' \
       -e 's#-c #-include'$EXTRA_INCLUDE' -c#g' \
 > $W/WebKit/compile_commands.json
