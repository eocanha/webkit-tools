#!/bin/bash

. $(dirname $0)/env.sh

# Old systems use eth0/wlan0. Modern systems use those unpredictable enp0s31f6 and wlp0s20f3 names.
ETH0=$(/sbin/ifconfig -a | grep '^e' | sed 's/[: ].*$//' | head -n 1)
WLAN0=$(/sbin/ifconfig -a | grep '^w' | sed 's/[: ].*$//' | head -n 1)

# Find IP testing the interfaces in order. Set this IP by hand if needed
for IFACE in "${ETH0}" tun0 "${WLAN0}"
do
 export LAPTOP_IP=$(/sbin/ifconfig ${IFACE} 2>/dev/null | grep 'inet ' | sed 's/^.*inet //' | sed 's/ .*$//')
 if [ -n "${LAPTOP_IP}" ]; then break; fi
done
if [ -z "${LAPTOP_IP}" ]; then export LAPTOP_IP=127.0.0.1; fi
echo "LAPTOP_IP: ${LAPTOP_IP}"

# make sure the only dot files and append data dump files in /tmp are the new ones
rm  $W/tmp/*.dot $W/tmp/append-*.mp4

if [ "x$1" == "xdebug" ]
then
 OPT_DEBUG='--debug'
 shift
fi

if [ "x$1" == "xwait" ]
then
 export WEBKIT2_PAUSE_WEB_PROCESS_ON_LAUNCH=1 # To attach the debugger at the begining
 shift
fi

if [ "x$1" == "xurl" ]
then
 export _URL=$2
 shift; shift
fi

# Enable/disable this block
if false
then
 export http_proxy="http://localhost:3128"
 export https_proxy="http://localhost:3128"
 echo "-----------------------"
 echo "USING PROXY: ${http_proxy}"
fi

# Create coredumps to be debugged with ~/debug.sh -c <corefile>
# ulimit -c unlimited
# sudo sysctl kernel.core_pattern=core_%e.%p

export FULLSCREEN=0
#export GST_DEBUG_DUMP_DOT_DIR=$W/tmp
export GST_DEBUG_NO_COLOR=1

# Workaround for crash on nvidia
#export WEBKIT_DISABLE_COMPOSITING_MODE=1

#export WEBKIT_DEBUG='Media,MediaSource' # For wpe
#export MSE_MAX_BUFFER_SIZE='V:30M,A:1M,T:500K'
export WEBKIT_INSPECTOR_SERVER=0.0.0.0:9998

# Special vars for debug commits
#export DUMP_APPEND_PIPELINE_ON_APPEND_COMPLETE=1
#export DUMP_PLAYBACK_PIPELINE_AFTER_SOME_SECONDS=3
#export DUMP_APPENDED_DATA=1
#export DUMP_PROCESSED_DATA=1
#export DUMP_ENQUEUED_DATA=1

# TIP: Use gst-launch-1.0 --gst-debug-help to know the available GST_DEBUG categories

# Useful categories:
# MSE:                default webkitmse webkitmediaplayer:MEMDUMP webkitmediasrc webkitvideosink
# REGULAR PLAYER:     webkitwebsrc
# EME:                webkitplayready webkitcenc webkitclearkey
# DORNE:              dorne fusion dorneaudiosink dornevideosink
# OMX:                omxhdmiaudiosink omxvideosink omxvideodec omxaudiodec omx omx* videodecoder audiodecoder
#                     omxbufferpool eglimagememory glbufferpool
# GST ELEMENTS:       appsrc baseparse videosink basesink fakesink bin qtdemux mssdemux souphttpsrc typefind multiqueue
#                     playbin uridecodebin videodecoder audiodecoder faad h264parse playsink pipeline streamsynchronizer
#                     ringfubber audiosink audiobasesink audioclock matroskademux
# GST INTERNALS:      GST_EVENT GST_PAD GST_REFCOUNTING GST_STATES GST_LOCKING GST_SCHEDULING GST_BUFFER GST_MEMORY queue_dataflow task

#export GST_DEBUG="*:DEBUG,webkit*:DEBUG"
export GST_DEBUG="_webkit*:TRACE"

#export G_DEBUG=fatal-criticals
#export G_DEBUG=fatal-warnings

# Default value:
#export USER_AGENT='Mozilla/5.0 (Macintosh, Intel Mac OS X 10_11_4) AppleWebKit/602.1.28+ (KHTML, like Gecko) Version/9.1 Safari/601.5.17 WPE-Reference'

if [ -n "${USER_AGENT}" ]
then
 export OPT_USER_AGENT="--user-agent=${USER_AGENT}"
fi

URL="about:blank"
#URL="inspector://127.0.0.1:9998/" # Web Inspector
#URL="http://127.0.0.1:8000/media/video-no-content-length-stall.html"
URL="http://www.youtube.com" # Normal YouTube
#URL='https://www.youtube.com/watch?v=9Auq9mYxFEE' # Live stream (Sky News)
#URL="file://$W/WebKit/LayoutTests/media/track/in-band/track-in-band-kate-ogg-language.html"
#URL="http://${LAPTOP_IP}/mstest/normal-video-tag/back-fw-seek/test.html"
#URL='http://127.0.0.1/mstest/googleads-ima-html5-dai/hls_js/simple/dai.html'
#URL='http://127.0.0.1:8000/media-resources/media-source/media-source-seek-detach-crash.html' # Serve with run-webkit-httpd
#URL='http://127.0.0.1:8000/media-resources/media-source/media-source-remove-crash.html' # Serve with run-webkit-httpd
#URL='http://127.0.0.1/mstest/normal-video-tag/poster.html'
#URL='http://xeny.local/mstest/normal-video-tag/debug.html'


if [ -n "$_URL" ]
then
 URL="$_URL"
fi

OPT_MSE="--enable-mediasource=true --enable-write-console-messages-to-stdout=true --autoplay-policy=allow"
#OPT_MSE="--enable-write-console-messages-to-stdout=true"

echo "-----------------------"
echo "$URL"
echo "-----------------------"
echo "OPTIONS: ${OPT_DEBUG} ${OPT_MSE}"
echo "-----------------------"

if [ "${FULLSCREEN}" == "1" ]
then
 echo "NOTE: Fullscreen doesn't work!!!"
 FULLSCREEN_OPTION="--geometry=+0+0"
 {
  # Send F11 keypress after 1 second
  sleep 1
  echo -n "Sending fake F11 keypress: "
  /home/enrique/fake-keypress-event/XFakeKey
  echo "$?"
 } &
else
 FULLSCREEN_OPTION=""
fi

# Clean the cache (optional)
if true
then
 echo "Clearing the cache"
 rm -rf rm -rf ~/.cache/MiniBrowser
else
 echo; echo "### WARNING: *NOT* REMOVING CACHE FILES ###"; echo
fi

postprocess() {
 echo "Postprocessing..."
 # Enable/disable these blocks
 if false
 then
  # Get the append data files
  rm -rf /tmp/append-data
  mkdir /tmp/append-data
  mv $W/tmp/append-*.mp4 /tmp/append-data/
 fi

 if true
 then
  # Get the dot files and generate pdfs
  rm -rf /tmp/gst-pipelines
  mkdir /tmp/gst-pipelines
  mv $W/tmp/*.dot /tmp/gst-pipelines/
  for i in /tmp/gst-pipelines/*.dot
  do
   # See: https://github.com/gak/pycallgraph/issues/150
   dot -Tsvg -O $i || dot -Gnewrank=true -Tsvg -O $i
   rm $i
  done
 fi
 exit 0
}

# Also postprocess if the script is manually interrupted
trap postprocess SIGINT

set -x
run-minibrowser --gtk ${OPT_DEBUG} ${OPT_MSE} ${OPT_USER_AGENT:+"$OPT_USER_AGENT"} ${FULLSCREEN_OPTION} "${URL}" 2>&1 | tee /tmp/log.txt
set +x

postprocess
