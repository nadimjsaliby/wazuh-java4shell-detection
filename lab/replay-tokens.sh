#!/bin/sh
# Layer 3: append sample proxy log lines to the file the lab agent tails.
# Two malformed tokens (should alert) and one ordinary, valid Basic credential that also
# ends in a single "=" (must NOT alert).
cd "$(dirname "$0")"
docker exec -i j4s-target sh -c 'cat >> /var/log/j4s/proxy-auth.json' < samples/proxy-auth.json
echo "[*] 3 lines appended to /var/log/j4s/proxy-auth.json on j4s-target; expect 2 alerts from rule 100525."
