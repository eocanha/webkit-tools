#!/bin/bash

# Get the append data files
rm -rf /tmp/append-data
mkdir /tmp/append-data
mv /tmp/append-*.mp4 /tmp/append-data/

# Get the dot files and generate pdfs
rm -rf /tmp/gst-pipelines
mkdir /tmp/gst-pipelines
mv /tmp/*.dot /tmp/gst-pipelines/
for i in /tmp/gst-pipelines/*.dot
do
 dot -Tpdf -o $i.pdf $i
 rm $i
done

