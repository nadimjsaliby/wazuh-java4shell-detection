#!/bin/sh
# Print the Java4Shell alerts the lab manager has raised so far, one per line.
docker exec j4s-manager sh -c 'grep java4shell /var/ossec/logs/alerts/alerts.json' | python3 -c '
import sys, json
n = 0
for line in sys.stdin:
    a = json.loads(line); n += 1
    print(a["timestamp"][:19], a["rule"]["id"], "lvl", a["rule"]["level"], a["agent"]["name"], "|", a["rule"]["description"][:100])
print(n, "Java4Shell alerts")'
