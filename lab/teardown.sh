#!/bin/sh
# Remove every container, volume and network the lab created. Leaves nothing running.
cd "$(dirname "$0")"
docker compose down -v --remove-orphans
echo "[*] Lab removed. Nothing from the lab is left running on this host."
