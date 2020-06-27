#!/bin/bash
rm -rf ~/WebKit/WebKitBuild/DependenciesGTK/Build/gst-plugins-good-1.8.0
Tools/jhbuild/jhbuild-wrapper --gtk buildone -f gst-plugins-good
