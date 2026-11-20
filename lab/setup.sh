#!/bin/sh
# Bring up the Java4Shell lab: isolated, capped, localhost-bound. AUTHORIZED LAB USE ONLY.
set -e
cd "$(dirname "$0")"

echo "[*] Java4Shell lab - host CPU check..."
if grep -qw avx512vbmi /proc/cpuinfo 2>/dev/null; then
  echo "    AVX-512 VBMI present: the crash layers (2) will reproduce."
else
  echo "[!] No AVX-512 VBMI on this host: the crash will NOT reproduce."
  echo "    Layers 1, 3 and 4 can still be exercised with replayed events."
fi

docker compose up -d --build

cat <<'EOF'

[*] Lab is up (bound to 127.0.0.1 only).
    Manager logs:     docker logs -f j4s-manager
    Trigger a crash:  docker exec j4s-target sh -c \
                        'java -XX:ErrorFile=/var/log/jvm/hs_err_pid%p.log /opt/poc/Base64Trigger 64'
    Alerts:           docker exec j4s-manager tail -f /var/ossec/logs/alerts/alerts.json
    Tear down:        ./teardown.sh
EOF
