#!/bin/bash

# Converts dot files to pdf.
# /tmp is the default directory for dot files.
#
# Usage: dot-to-pdf.sh [<dir-with-dot-files>]
#
# See also: get-pipelines

rm -rf /tmp/gst-pipelines
mkdir /tmp/gst-pipelines

cd /tmp

if [ -n "$1" ]
then
 cd "$1"
fi

for i in *.dot
do
 dot -Tpdf -o /tmp/gst-pipelines/$i.pdf $i
 rm $i
done
