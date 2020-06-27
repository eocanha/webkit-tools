#!/bin/bash

set -x

rm -rf ~/WebKit/WebKitBuild || exit 1
cd ~/WebKit || exit 1

git co master || exit 1
~/go full-rebuild || exit 1
mv ~/WebKit/WebKitBuild ~/WebKit/WebKitBuild.master || exit 1

git co mse-backport-rebased-20160425-sq || exit 1
~/go full-rebuild || exit 1
mv ~/WebKit/WebKitBuild ~/WebKit/WebKitBuild.mse || exit 1
