#!/bin/bash

export WEBKITDIR="${W}/WebKit"
export GST_DEBUG="webkitwebsrc:TRACE"

# Create coredumps to be debugged with ~/debug.sh -c <corefile>
# ulimit -c unlimited
# sudo sysctl kernel.core_pattern=core_%e.%p

if [[ $1 == "-m" ]]
then
 MANUAL=1
 shift
fi

function showHelp() {
 {
  echo "Usage:   debug-test.sh testname"
  echo "         debug-test.sh -m <options to pass to WebKitTestRunner>"
  echo "Example: debug-test.sh LayoutTests/media/video-set-rate-from-pause.html"
  echo "         debug-test.sh media/video-set-rate-from-pause.html"
  echo "         # Tools/Scripts/run-webkit-httpd must be running for these http tests to work:"
  echo "         debug-test.sh http://127.0.0.1:8000/media/hls/video-cookie.html"
  echo "         debug-test.sh http://127.0.0.1:8000/media-resources/media-source/media-source-seek-detach-crash.html # Regular LayoutTests served by run-webkit-httpd"
  echo "         debug-test.sh -m -h"
  echo "         debug-test.sh -m --no-timeout --show-webview LayoutTests/media/video-set-rate-from-pause.html"
 } > /dev/stderr
}

TESTNAME=$1
if [[ ! -f "${TESTNAME}" ]]
then
 if [[ -f "LayoutTests/${TESTNAME}" ]]
 then
  TESTNAME="LayoutTests/${TESTNAME}"
 elif [[ -f "${WEBKITDIR}/${TESTNAME}" ]]
 then
  TESTNAME="${WEBKITDIR}/${TESTNAME}"
 elif [[ -f "${WEBKITDIR}/LayoutTests/${TESTNAME}" ]]
 then
  TESTNAME="${WEBKITDIR}/LayoutTests/${TESTNAME}"
 elif [[ "${TESTNAME}" =~ ^http.* ]]
 then
  TESTNAME=$TESTNAME
 else
  TESTNAME=""
 fi
fi

if [[ ! $MANUAL == 1 && ( $# == 0 || ( -z $TESTNAME ) ) ]]
then
 showHelp
 exit -1
fi

export ENV=\

cat > /tmp/test.sh << EOF
#!/bin/bash

#TEST_RUNNER_TEST_PLUGIN_PATH= WEB_PROCESS_CMD_PREFIX='/usr/bin/gdbserver localhost:8080' webkit-flatpak --debug --gtk -c /app/webkit/WebKitBuild/Debug/bin/WebKitTestRunner "-v" "LayoutTests/fast/forms/plaintext-mode-1.html"
# TEST_RUNNER_INJECTED_BUNDLE_FILENAME=WebKitBuild/Release/lib/libTestRunnerInjectedBundle.so \
# ./WebKitBuild/Release/bin/WebKitTestRunner "$@"

  if [[ "$MANUAL" == 1 ]]
  then
   GST_DEBUG_DUMP_DOT_DIR=/tmp \
   GST_DEBUG_NO_COLOR=1 \
   GST_DEBUG=${GST_DEBUG} \
   WEBKIT_INSPECTOR_SERVER=0.0.0.0:9998 \
   TEST_RUNNER_TEST_PLUGIN_PATH= \
   WEB_PROCESS_CMD_PREFIX='/usr/bin/gdbserver localhost:8080' \
   webkit-flatpak --gtk -c /app/webkit/WebKitBuild/Release/bin/WebKitTestRunner -v "$@"
  else
   GST_DEBUG_DUMP_DOT_DIR=/tmp \
   GST_DEBUG_NO_COLOR=1 \
   GST_DEBUG=${GST_DEBUG} \
   WEBKIT_INSPECTOR_SERVER=0.0.0.0:9998 \
   TEST_RUNNER_TEST_PLUGIN_PATH= \
   WEB_PROCESS_CMD_PREFIX='/usr/bin/gdbserver localhost:8080' \
   webkit-flatpak --gtk -c /app/webkit/WebKitBuild/Release/bin/WebKitTestRunner -v --verbose --no-timeout --show-webview ${TESTNAME}
  fi
EOF

chmod 755 /tmp/test.sh
cd ${WEBKITDIR}

cat > /tmp/gdbinit << EOF
target remote localhost:8080
EOF

# make sure the only dot files and append data dump files in /tmp are the new ones
rm  /tmp/*.dot /tmp/append-*.mp4 2>/dev/null

# sh function to be used with trap
ctrl_c() {
 # Enable/disable these blocks
 if false
 then
  # Get the append data files
  rm -rf /tmp/append-data
  mkdir /tmp/append-data
  mv /tmp/append-*.mp4 /tmp/append-data/
 fi 2>/dev/null

 if true
 then
  # Get the dot files and generate pdfs
  rm -rf /tmp/gst-pipelines
  mkdir /tmp/gst-pipelines
  mv /tmp/*.dot /tmp/gst-pipelines/
  for i in /tmp/gst-pipelines/*.dot
  do
   # See: https://github.com/gak/pycallgraph/issues/150
   dot -Tsvg -O $i || dot -Gnewrank=true -Tsvg -O $i
   rm $i
  done
 fi 2>/dev/null

 exit 0
}

# Prepare for ^C
trap ctrl_c INT

echo 'TODO: Run this in another terminal'
echo 'webkit-flatpak --command=gdb /app/webkit/WebKitBuild/Release/bin/WebKitWebProcess'
echo 'target remote localhost:8080'

/tmp/test.sh 2>&1 | tee /tmp/log.txt # &


ctrl_c
