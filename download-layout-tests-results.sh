#!/bin/bash
BASE_URL='https://build.webkit.org/builders/GTK%20Linux%2064-bit%20Release%20%28Tests%29/builds/@BUILD/steps/layout-test/logs/stdio/text'
TARGET_BUILD=20937
START_BUILD=$((TARGET_BUILD-5))
END_BUILD=$((TARGET_BUILD+1))
FILTER="."

function bold() {
 if [ $1 -eq 1 ]
  then echo -e "\e[1m"
  else echo -e "\e[0m"
 fi
}

# Enable/disable these blocks
if true
then
 # Download test results
 for ((i=${START_BUILD}; i<=${END_BUILD}; i++))
 do
  echo "Downloading test results for build ${i}..."
  URL=$(echo "${BASE_URL}" | sed "s/@BUILD/${i}/")
  curl -s "${URL}" | grep -B0 -A999999 '=> Results' > ${i}.txt
 done
 echo
fi

if true
then
 # Process test results
 > /tmp/matches.txt # Clear file
 echo "MEDIASOURCE UNEXPECTED RESULTS:"
 echo
 for ((i=${START_BUILD}; i<=${END_BUILD}; i++))
 do
  if [ $i -eq $TARGET_BUILD ]; then bold 1; fi
  echo "Test ${i} -------------------"
  cat "${i}.txt" | egrep "${FILTER}" | tee -a /tmp/matches.txt
  if [ $i -eq $TARGET_BUILD ]; then bold 0; fi
 done
 echo
 echo "REPETITIONS OF EACH UNEXPECTED RESULT:"
 echo
 cat "/tmp/matches.txt" | sort | uniq -c
fi
