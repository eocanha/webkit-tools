#!/bin/bash
if [ $# -lt 1 ]
then
 echo "Usage: $0 {base,good,bad,ugly,...}"
 exit 1
fi
rm -rf ~/WebKit/WebKitBuild/DependenciesGTK/Build/gst-plugins-$1-* && \
~/WebKit/Tools/jhbuild/jhbuild-wrapper --gtk buildone -f gst-plugins-$1
