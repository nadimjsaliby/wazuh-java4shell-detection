#!/bin/sh
# Start the Wazuh agent (it enrolls with the manager on first start), then idle.
# The lab drives the crash on demand with `docker exec`.
cd /var/ossec/bin && ./wazuh-control start
exec sleep infinity
