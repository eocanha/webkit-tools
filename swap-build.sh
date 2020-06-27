#!/bin/bash

BASE=~/WebKit/WebKitBuild

# This script swaps several versions of the same directory. For instance:
# From WebKitBuild.{old,new,backup,baseline} only one of them will become
# plain WebKitBuild at some point. Later it can be swapped with other version.
# One problem of this approach is that the current version will become
# WebKitBuild, so we won't know anymore that it was previously called
# WebKitBuild.new. To solve that, we use a "touched" (zero size) file to
# remember the original name, so at any point the {old,backup,baseline}
# variants will exist as directories, the new variand will exist as the
# WebKitBuild dir and also as the WebKitBuild.new empty file.

if [ ! -d "${BASE}" ]
then
 echo "base dir ${BASE} doesn't exist or isn't a dir" > /dev/stderr
 exit -2
fi

cd "${BASE}/.."
BASEPATH=$(dirname "${BASE}")
BASEFILE=$(basename "${BASE}")
CURRENT=""
VARIANTS=$(ls "$BASEPATH" | grep "$BASEFILE" | egrep -v "$BASEFILE"'$')

for F in $VARIANTS
do
 if [ -f "$F" -a ! -s "$F" ]; then CURRENT=$F; fi
done

if [[ ( ! -d "$BASEPATH/$BASEFILE" ) || -z "$CURRENT" || ! ( -f "$CURRENT" && ! -s "$CURRENT" ) ]]
then
 {
  echo "no variant currently selected"
  echo "available:"
  echo "${VARIANTS}"
 } > /dev/stderr
 exit -1
fi

if [ "$#" == 0 ]
then
 echo $CURRENT
else
 SELECTED=$1
 if [[ ! ( -f $BASEPATH/$BASEFILE.$SELECTED || -d $BASEPATH/$BASEFILE.$SELECTED ) ]]
 then
  echo "invalid variant"
  echo "Usage: swap-build.sh selected-variant"
  echo "         Sets the selected-variant as the current one"
  echo "       swap-build.sh"
  echo "         Prints the current variant"
  exit -2
 fi > /dev/stderr
 rm $CURRENT
 mv $BASEPATH/$BASEFILE $CURRENT
 mv $BASEPATH/$BASEFILE.$SELECTED $BASEPATH/$BASEFILE
 touch $BASEPATH/$BASEFILE.$SELECTED
fi
