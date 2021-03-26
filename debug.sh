#!/bin/bash

# Enable coredumps:
#  ulimit -c unlimited
#  sudo sysctl kernel.core_pattern=core_%e.%p
# Trigger coredumps:
#  kill -SIGABRT <pid>

#TARGET_NAME=MiniBrowser
TARGET_NAME=WebKitWebProcess
#TARGET_NAME=WebKitTestRunner

if [ "$(cat /proc/sys/kernel/yama/ptrace_scope)" == "1" ]
 then
 echo "Setting ptrace_scope to 0 for debugging..."
 echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
fi

if [ -z "$FLATPAK_ID" ]
 then
 echo "Entering flatpak shell..."
 FLATPAKID=""
 while [ -z "${FLATPAKID}" -o "${FLATPAKID}" == "0" ]
 do
  FLATPAKID=$(flatpak ps | grep org.webkit.Sdk | { read _ X _; echo $X; })
 done
 sudo flatpak enter ${FLATPAKID} /bin/bash --rcfile /home/enrique/.bashrc -i -c $0 "$@"
 exit $?
fi

if [ "$1" == "-c" ]
then
 echo "WARNING: I don't know if core file debugging works with flatpak!"
 CORE_FILE="$2"
else
 echo "Lookig for PID of existing process $TARGET_NAME or waiting until the process appears..."
 unset TARGET_PID
 while [ -z $TARGET_PID ]
 do
  TARGET_PID=$(pidof $TARGET_NAME)
 done
 echo "TARGET_PID: $TARGET_PID"
fi

cat > /tmp/webkit_gdbinit << EOF
python
import sys
sys.path.insert(0, "$W/WebKit/Tools/gdb/")
import webkit
end
set detach-on-fork off
set follow-fork-mode child
set pagination off
set print asm-demangle
EOF

if [ -n "${TARGET_PID}" ]
then
 echo "Attaching gdb to PID $TARGET_PID"
 gdb -x /tmp/webkit_gdbinit attach "${TARGET_PID}"
elif [ -n "${CORE_FILE}" ]
then
 echo "Loading coredump ${CORE_FILE}"
 gdb -x /tmp/webkit_gdbinit ${TARGET_BIN} ${CORE_FILE}
fi
