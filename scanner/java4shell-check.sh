#!/bin/sh
# java4shell-check.sh - CVE-2026-114938 exposure check for Wazuh logcollector.
# Prints one JAVA4SHELL_SCAN line per Java runtime found; the decoder keys on it.
#
# Wazuh agent ossec.conf:
#   <localfile>
#     <log_format>command</log_format>
#     <command>sh /var/ossec/active-response/bin/java4shell-check.sh</command>
#     <alias>java4shell-check</alias>
#     <frequency>86400</frequency>
#   </localfile>
# If pushed via centralized agent.conf, set logcollector.remote_commands=1 on agents.

# --- Condition 2: does this CPU run the vulnerable AVX-512 stub? ---
cpu="no"
if grep -qw avx512vbmi /proc/cpuinfo 2>/dev/null \
   && grep -qw avx512f  /proc/cpuinfo 2>/dev/null \
   && grep -qw avx512bw /proc/cpuinfo 2>/dev/null \
   && grep -qw bmi2     /proc/cpuinfo 2>/dev/null; then
  cpu="yes"
fi

ver_lt() {   # true when $1 is strictly lower than $2
  [ "$1" = "$2" ] && return 1
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

verdict_for() {   # $1 = raw version string, e.g. 17.0.21.0.3 or 1.8.0_511
  v="$1"
  case "$v" in 1.8.*|8.*|11.*) echo NOT_AFFECTED; return ;; esac
  line="${v%%.*}"
  case "$line" in
    17) ver_lt "$v" 17.0.6   && { echo NOT_AFFECTED; return; }
        ver_lt "$v" 17.0.21.1 && echo AFFECTED || echo FIXED ;;
    21) ver_lt "$v" 21.0.13.1 && echo AFFECTED || echo FIXED ;;
    25) ver_lt "$v" 25.0.5.1  && echo AFFECTED || echo FIXED ;;
    27) ver_lt "$v" 27.0.1.1  && echo AFFECTED || echo FIXED ;;
    18|19|20|22|23|24|26) echo AFFECTED_NOFIX ;;
    *)  echo UNKNOWN ;;
  esac
}

# --- Condition 1: find every java runtime on disk, not just the one on PATH ---
{ command -v java 2>/dev/null
  ls /usr/lib/jvm/*/bin/java /opt/*/bin/java /opt/*/*/bin/java 2>/dev/null
} | sort -u | while read -r jbin; do
  [ -x "$jbin" ] || continue
  v=$("$jbin" -version 2>&1 | awk -F'"' '/version/{print $2; exit}')
  [ -n "$v" ] || continue
  verdict=$(verdict_for "$v")
  # EXPOSED = affected build AND a CPU that runs the bad path. That is "patch now".
  [ "$verdict" = AFFECTED ] && [ "$cpu" = yes ] && verdict=EXPOSED
  line="${v%%.*}"; case "$v" in 1.8.*) line=8 ;; esac
  echo "JAVA4SHELL_SCAN verdict=$verdict version=$v line=$line cpu_avx512vbmi=$cpu bin=$jbin"
done
