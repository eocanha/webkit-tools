#!/bin/sh
#set -x

. $(dirname $0)/env.sh

# See Flatpak docs:
# https://hackmd.io/@philn/HJXBb15uU
# https://hackmd.io/@philn/ByMT3wWoL

#OPT_EXTRA='--no-bubblewrap-sandbox --no-gstreamer-gl'
#OPT_EXTRA='--no-bubblewrap-sandbox --cmakeargs="-DUSE_WPE_RENDERER=OFF"'

if false
then
 echo "Distributed build using sccache. See $0"
 export WEBKIT_USE_SCCACHE=1
 export NUMBER_OF_PROCESSORS=45
else
 echo "Local build, NOT using icecc! See $0"
 unset CCACHE_PREFIX
 export NUMBER_OF_PROCESSORS=$(cat /proc/cpuinfo | grep processor | wc | { read N _; echo $N; })
 #OPT_MAKEARGS='--makeargs=-j12'
fi

while [ $# -gt 0 ]
do
 case "$1" in
 debug)
  OPT_DEBUG="--debug"
  RUNTESTS_DEBUG="debug"
  echo "I can't get debug builds working on icecc, disabling..."
  unset CCACHE_PREFIX
  ;;
 pro)
  RUNTESTS=1
  ;;
 full-rebuild)
  install-dependencies
  /usr/bin/time -o /tmp/webkit-deps-build-time.txt update-webkitgtk-libs
  # Fix for xvimagesink X11 error on NVidia
  rm $(find $W/WebKit/WebKitBuild/UserFlatpak/runtime -iname "*xvimagesink.so")
  UPDATE_COMPILE_COMMANDS=1
  ;;
 full-rebuild-noinstalldeps)
  update-webkitgtk-libs
  # Fix for xvimagesink X11 error on NVidia
  rm $(find $W/WebKit/WebKitBuild/UserFlatpak/runtime -iname "*xvimagesink.so")
  UPDATE_COMPILE_COMMANDS=1
  ;;
 shell)
  webkit-flatpak --command=bash
  exit 0
  ;;
 attach)
  # Shell on existing process environment
  sudo flatpak enter $(flatpak ps | grep org.webkit.Sdk | { read _ X _; echo $X; }) /bin/bash --rcfile /home/enrique/.bashrc
  exit 0
  ;;
 update)
  UPDATE_COMPILE_COMMANDS=1
 esac
shift
done

export V=1
/usr/bin/time -o /tmp/webkit-build-time.txt build-webkit --gtk $OPT_DEBUG $OPT_MAKEARGS $OPT_EXTRA || exit $?

echo; echo; echo
echo ' ----------------------- '
echo '|    GO FINISHED  :-)   |'
echo ' ----------------------- '

if [ -n "$RUNTESTS" ]
then
 runtest.sh $RUNTESTS_DEBUG
fi
if [ -n "$UPDATE_COMPILE_COMMANDS" ]
then
 compile_commands.sh
fi
