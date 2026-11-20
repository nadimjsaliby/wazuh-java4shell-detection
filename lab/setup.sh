#!/bin/sh
# Bring up the Java4Shell lab: isolated, capped, no published ports. AUTHORIZED LAB USE ONLY.
set -e
cd "$(dirname "$0")"

echo "[*] Java4Shell lab - host CPU check..."
if grep -qw avx512vbmi /proc/cpuinfo 2>/dev/null; then
  echo "    AVX-512 VBMI present: the crash (Layer 2) can reproduce."
else
  echo "[!] No AVX-512 VBMI on this host: the crash will NOT reproduce."
  echo "    Layers 1 and 3 still work; Layer 1 will report AFFECTED, not EXPOSED."
fi

echo "[*] Starting the manager..."
docker compose up -d wazuh-manager

printf "[*] Waiting for wazuh-analysisd"
i=0
until docker exec j4s-manager /var/ossec/bin/wazuh-control status 2>/dev/null | grep -q "wazuh-analysisd is running"; do
  i=$((i+1)); [ "$i" -gt 60 ] && { echo; echo "[!] manager did not come up; see: docker logs j4s-manager"; exit 1; }
  printf "."; sleep 3
done
echo " ok"

echo "[*] Installing the Java4Shell decoder and rules (copy, then restart)..."
docker cp ../rules/decoders/java4shell_decoders.xml j4s-manager:/var/ossec/etc/decoders/
docker cp ../rules/rules/java4shell_rules.xml       j4s-manager:/var/ossec/etc/rules/
docker exec j4s-manager chown wazuh:wazuh \
  /var/ossec/etc/decoders/java4shell_decoders.xml /var/ossec/etc/rules/java4shell_rules.xml
docker exec j4s-manager /var/ossec/bin/wazuh-control restart >/dev/null

echo "[*] Building and starting the endpoint (vulnerable JDK + Wazuh agent)..."
docker compose up -d --build target

cat <<'EOF2'

[*] Lab is up. The agent enrolls by itself; give it about a minute.
    Agent connected?  docker exec j4s-manager /var/ossec/bin/agent_control -l
    Layer 1 (scan):   fires on its own within ~2 minutes of the agent connecting
    Layer 2 (crash):  ./crash.sh
    Layer 3 (token):  ./replay-tokens.sh
    Alerts:           ./alerts.sh
    Tear down:        ./teardown.sh
EOF2
