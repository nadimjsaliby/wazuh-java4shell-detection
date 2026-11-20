#!/bin/sh
# Drive the heap-corruption crash on the lab endpoint. AUTHORIZED LAB USE ONLY.
# Bounded: Base64Crash gives up cleanly after 100 seconds if nothing faults. The crash is
# a race against the garbage collector, so a clean exit can happen; just run it again.
#
# -XX:+ErrorFileToStderr sends the crash report to stderr, which is appended to the
# service log the agent already tails. See endpoint/java4shell-agent.conf for why the
# lab does not tail hs_err_pid*.log files.
docker exec j4s-target sh -c 'java -Xmx32m -XX:+UseSerialGC -XX:+ErrorFileToStderr \
  -cp /opt/poc Base64Crash 2>> /var/log/jvm/service-stderr.log; echo "[*] JVM exit code: $?  (134 = aborted after a fatal signal; 0 = no crash this run)"'
docker exec j4s-target sh -c 'echo "[*] crash headers in the service log: $(grep -c "A fatal error has been detected" /var/log/jvm/service-stderr.log)"'
