#!/bin/sh
# Run the sample scan verdict lines through wazuh-logtest on the lab manager.
# Expect 100511 (EXPOSED), 100512 (AFFECTED), 100513 (AFFECTED_NOFIX) and, for the FIXED
# line, only the silent level-0 base rule 100510.
cd "$(dirname "$0")"
while read -r line; do
  printf '%s\n' "$line" | docker exec -i j4s-manager /var/ossec/bin/wazuh-logtest 2>&1 \
    | grep -E "id: |level: |Alert to be" | tr '\n' ' '
  echo "<= $(echo "$line" | cut -d' ' -f2-3)"
done < samples/scan-lines.log
