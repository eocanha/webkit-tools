#!/bin/bash

# Avoid declaring things twice
if [ -z "$W" ]
then
 export W=/home/enrique/work/webkit
 export T=$W/tools
 export PATH=$W/tools:$W/WebKit/Tools/Scripts:$W/WebKit/Tools/gtk:$PATH
 export PS1='(webkit):\w$(__git_ps1 " (\[\033[31m\]%s\[\033[00m\])")\$ '
 alias cdw="cd $W"
 alias cdwk="cd $W/WebKit"
 alias cdt="cd $T"
fi
