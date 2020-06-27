#!/bin/bash
SCRIPT_NAME=$0
BASELINE_COMMIT=$1
NEW_COMMIT=$2

# --- Customizable options ----------------------------------------------------

FULL_REBUILD=0 # Enable (1) with care!
TESTS="${W}/tools/webkit-media-tests.txt" # If empty, all tests will be run
WEBKITDIR="${W}/WebKit"
SKIP_TO=start

export GST_DEBUG_DUMP_DOT_DIR=/tmp
export GST_DEBUG_NO_COLOR=1
export GST_DEBUG="webkitwebsrc:TRACE"

# Create coredumps to be debugged with debug.sh -c <corefile>
# ulimit -c unlimited
# sudo sysctl kernel.core_pattern=core_%e.%p

# --- Touch at your own risk beyond this point --------------------------------

. $(dirname $0)/env.sh

function switch_move() {
  # Pass empty values to just restore the last WebKitBuild to its location
  VERSION=$1
  COMMIT=$2
  cd "${WEBKITDIR}"

  if [ "${FULL_REBUILD}" == "1" ]
  then
    echo "Full rebuild not supported with switch_move"; exit 1;
  else
    # Restore the last WebKitBuild to its original place
    if [ -n "${LAST_WEBKITBUILD_LOCATION}" ]
    then
     mv WebKitBuild "${LAST_WEBKITBUILD_LOCATION}"
    fi
    if [ -z "${VERSION}" ]
    then
     return 0
    fi
    if [ ! -d "${TESTDIR}/${VERSION}/WebKitBuild" ]
    then
     echo "Pre-existing build dir ${TESTDIR}/${VERSION}/WebKitBuild not found"; exit 1;
    fi
    LAST_WEBKITBUILD_LOCATION="${TESTDIR}/${VERSION}/WebKitBuild"
    mv "${LAST_WEBKITBUILD_LOCATION}" WebKitBuild
  fi
  git co "${COMMIT}" || exit 1
}

function switch_link() {
  VERSION=$1
  COMMIT=$2
  cd "${WEBKITDIR}"

  # Empty values do nothing
  if [ -z "${VERSION}" ]
    then
     return 0
    fi

  if [ "${FULL_REBUILD}" == "1" ]
  then
    if [ -d WebKitBuild.bak ]; then rm -rf WebKitBuild.bak; fi
    if [ ! -L WebKitBuild ]
      then mv WebKitBuild WebKitBuild.bak
      else rm WebKitBuild
    fi
    if [ ! -d "${TESTDIR}/${VERSION}/WebKitBuild" ]
      then mkdir "${TESTDIR}/${VERSION}/WebKitBuild"
    fi
    ln -s "${TESTDIR}/${VERSION}/WebKitBuild" WebKitBuild
  else
    if [ ! -d "${TESTDIR}/${VERSION}/WebKitBuild" ]
    then
     mkdir "${TESTDIR}/${VERSION}/WebKitBuild"
     cp -a WebKitBuild/* "${TESTDIR}/${VERSION}/WebKitBuild"
    fi
    rm -rf WebKitBuild
    ln -s "${TESTDIR}/${VERSION}/WebKitBuild" WebKitBuild
  fi
  git co "${COMMIT}" || exit 1
}

function switch() {
  # switch_link $1 $2
  switch_move $1 $2
}

function build() {
  cd "${WEBKITDIR}"
  if [ "${FULL_REBUILD}" == "1" ]
  then
    go full-rebuild-noinstalldeps || exit 1
  else
    go || exit 1
  fi
}

function run_test() {
  VERSION=$1
  LOGFILE=${2:-"log.txt"} # 2nd param or default value
  ITERATIONS=${3:-"1"}    # 3rd param or default value

  #CUSTOM_PARAMS="--run-singly"
  CUSTOM_PARAMS="--skipped=always"

  cd "${WEBKITDIR}"
  NUMBER_OF_PROCESSORS=12 \
   Tools/Scripts/run-webkit-tests \
   --gtk --no-new-test-results --no-show-results \
   --fully-parallel --iterations=${ITERATIONS} ${CUSTOM_PARAMS} \
   $(cat ${TESTS}) 2>&1 | tee /tmp/log-tests.txt

  cd "${TESTDIR}/${VERSION}"
  cp ${W}/WebKit/WebKitBuild/GTK/Release/layout-test-results/results.html .
  cp /tmp/log-tests.txt "./${LOGFILE}"
}

function run_test_manually() {
  ITERATIONS=${1:-"1"}    # 1st param or default value
  ITERATIONS=$(echo "sqrt(${ITERATIONS})" | bc)
  if [ ${ITERATIONS} -eq 0 ]; then ITERATIONS=1; fi

  #CUSTOM_PARAMS="--no-show-results"
  #CUSTOM_PARAMS="--skipped=always"
  #CUSTOM_PARAMS="--skipped=ignore"
  CUSTOM_PARAMS="--force"

  echo "-------------------------------"
  echo "TESTS:"; echo; cat ${TESTS}; echo; echo; echo;
  echo "-------------------------------"

  cd "${WEBKITDIR}"
  CMD="NUMBER_OF_PROCESSORS=8 \
   Tools/Scripts/run-webkit-tests \
   --gtk --fully-parallel --repeat-each=${ITERATIONS} --iterations=${ITERATIONS} ${CUSTOM_PARAMS} \
   $(cat ${TESTS}) 2>&1 | tee /tmp/log-tests.txt"

  echo "${CMD}"
  echo "-------------------------------"

  eval ${CMD}
}

function highlight_unexpected() {
  cat "${TESTDIR}/baseline/log.txt" \
   | sed -n -e "/.* tests ran as expected.*:/,// p" \
   | grep '^  ' | sed 's/^  //' | sed 's/ .*//' \
   > /tmp/unexpected-unsorted.txt
  cat "${TESTDIR}/new/log.txt" \
   | sed -n -e "/.* tests ran as expected.*:/,// p" \
   | grep '^  ' | sed 's/^  //' | sed 's/ .*//' \
   >> /tmp/unexpected-unsorted.txt
  sort < /tmp/unexpected-unsorted.txt | uniq > "${TESTDIR}/unexpected.txt"
  rm /tmp/unexpected-unsorted.txt
}

function distill() {
  # Compute distilled-diff
  cat "${TESTDIR}/baseline/log-highlighted.txt" \
   | sed -n -e "/.* tests ran as expected.*:/,// p" \
   > "${TESTDIR}/baseline/distilled.txt"
  cat "${TESTDIR}/new/log-highlighted.txt" \
   | sed -n -e "/.* tests ran as expected.*:/,// p" \
   > "${TESTDIR}/new/distilled.txt"
  diff "${TESTDIR}/baseline/distilled.txt" "${TESTDIR}/new/distilled.txt" \
   > "${TESTDIR}/distilled-diff.txt"

  {
    # Compute new broken tests
    cat "${TESTDIR}/baseline/log-highlighted.txt" \
     | sed -n -e "/^.*Unexpected.*$/,/^$/ p" \
     | grep '^  ' | sed 's/^  //' | sed 's/ .*//' \
     | sort > "/tmp/distilled-extra-baseline.txt"
    cat "${TESTDIR}/new/log-highlighted.txt" \
     | sed -n -e "/^.*Unexpected.*$/,/^$/ p" \
     | grep '^  ' | sed 's/^  //' | sed 's/ .*//' \
     | sort > "/tmp/distilled-extra-new.txt"
    echo "New broken tests:"; echo
    diff "/tmp/distilled-extra-baseline.txt" "/tmp/distilled-extra-new.txt" \
     | grep '^>' | sed 's/^> //'

    # Compute new fixed tests
    cat "${TESTDIR}/baseline/log-highlighted.txt" \
     | sed -n -e "/^Expected.*$/,/^$/ p" \
     | grep '^  ' | sed 's/^  //' | sed 's/ .*//' \
     | sort > "/tmp/distilled-extra-baseline.txt"
    cat "${TESTDIR}/new/log-highlighted.txt" \
     | sed -n -e "/^Expected.*$/,/^$/ p" \
     | grep '^  ' | sed 's/^  //' | sed 's/ .*//' \
     | sort > "/tmp/distilled-extra-new.txt"
    echo; echo; echo "New fixed tests:"; echo
    diff "/tmp/distilled-extra-baseline.txt" "/tmp/distilled-extra-new.txt" \
     | grep '^>' | sed 's/^> //'

    #rm /tmp/distilled-extra-baseline.txt
    #rm /tmp/distilled-extra-new.txt
  } > "${TESTDIR}/distilled-extra-summary.txt"
}

# See: http://stackoverflow.com/a/31269848/752445
function skip_to { eval "$(sed -n "/$1:/{:a;n;p;ba};" $0 | grep -v ':$')"; exit; }

if [ "$#" != "2" -a "$1" != "--manual" -a "$1" != "--media" -a "$1" != "--media-source" ]; then
  echo "Usage: ${SCRIPT_NAME} <baseline-commit> <new-commit>"
  echo "       ${SCRIPT_NAME} --manual [extra parameters] [test]"
  echo "       ${SCRIPT_NAME} --manual-file [file with tests]"
  echo "       ${SCRIPT_NAME} --media"
  echo "       ${SCRIPT_NAME} --media-source"
  exit 1
fi

if [ "$1" == "--manual" -o "$1" == "--manual-file" -o "$1" == "--media" -o "$1" == "--media-source" ]
then
  SKIP_TO=manual
  if [ "$1" == "--manual" ]
  then
   shift
   TESTS="/tmp/webkit-manual-tests.txt"
   echo "$@" > /tmp/webkit-manual-tests.txt
  elif [ "$1" == "--media" ]
  then
   TESTS=${W}/tools/webkit-media-tests.txt
  elif [ "$1" == "--media-source" ]
  then
   TESTS=${W}/tools/webkit-media-source-tests.txt
  elif [ "$1" == "--manual-file" ]
  then
   TESTS="$2"
  else
   TESTS=${W}/tools/webkit-manual-tests.txt
  fi
else
  if [ "${FULL_REBUILD}" == "1" ]; then
    read -p "WARNING: A full rebuild will be done - Press ENTER to proceed or CTRL+C now!"
  fi

  TESTDIR="${HOME}/TESTRUN/${BASELINE_COMMIT}-${NEW_COMMIT}"
  mkdir -p "${TESTDIR}/baseline"
  mkdir -p "${TESTDIR}/new"
  echo "${SCRIPT_NAME} ${BASELINE_COMMIT} ${NEW_COMMIT}" > "${TESTDIR}/command.txt"
fi

if [ -z "${TESTS}" ]; then echo "" > /tmp/tests.txt; TESTS=/tmp/tests.txt; fi

# Tune the skip_to here to start at an intermediate point, in case something goes
# wrong in the middle of this script and you want to manually skip previous
# steps. Use "skip_to start" by default.
skip_to ${SKIP_TO}

start:

first:
echo; echo "=== FIRST ROUND: Build and one repetition of each test ==="; echo

first-baseline:
echo; echo "=== FIRST ROUND === TESTING BASELINE ==="; echo
switch baseline ${BASELINE_COMMIT}
build
run_test baseline

first-new:
echo; echo "=== FIRST ROUND === TESTING NEW ==="; echo
switch new ${NEW_COMMIT}
build
run_test new

highlight_unexpected

second:
echo; echo "=== SECOND ROUND: with cached build and several repetitions of each unexpected test ==="; echo

second-baseline:
echo; echo "=== SECOND ROUND === TESTING BASELINE ==="; echo
TESTS="${TESTDIR}/unexpected.txt"
switch baseline ${BASELINE_COMMIT}
run_test baseline log-highlighted.txt 10

second-new:
echo; echo "=== SECOND ROUND === TESTING NEW ==="; echo
TESTS="${TESTDIR}/unexpected.txt"
switch new ${NEW_COMMIT}
run_test new log-highlighted.txt 10
switch # Restore things

distill:
distill

end:
cp "${TESTDIR}/baseline/distilled.txt" /tmp/distilled-baseline.txt
cp "${TESTDIR}/new/distilled.txt" /tmp/distilled-new.txt
echo; echo "=== TESTING FINISHED ==="; echo
echo "Run this command to study the differences:"
echo "kdiff3 /tmp/distilled-{baseline,new}.txt"
echo
echo "Also, have a look at ${TESTDIR}/distilled-extra-summary.txt"
echo

exit 0

# --- Manual test run ---------------------------------------------------------
manual:

run_test_manually 1 # 100 # 3
