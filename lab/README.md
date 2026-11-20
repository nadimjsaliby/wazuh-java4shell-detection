# Java4Shell lab

A small, isolated lab that runs three of the four detection layers end to end: a
vulnerable JVM, a Wazuh agent on the same box, and a Wazuh manager.

## ⚠️ Run only here

- An **x86-64 host with AVX-512 VBMI** (Intel Ice Lake+ / AMD Zen 4+). Without it the
  overflow cannot fire; `setup.sh` warns, Layer 1 reports `AFFECTED` and the crash will
  not reproduce.
- Nothing is published to the host. Both containers sit on a dedicated bridge network
  and are memory- and CPU-capped so a crashing JVM cannot disturb other work.
- Run `teardown.sh` when done. It removes the containers, the volume and the network.

## Pieces

| Container | Role | Caps |
|---|---|---|
| `j4s-target` | Eclipse Temurin 21.0.5 (affected) plus a Wazuh 4.9.2 agent, named `j4s-endpoint` | 1g / 2 cpu |
| `j4s-manager` | Wazuh 4.9.2 manager; alerts in `/var/ossec/logs/alerts/alerts.json` | 2g / 2 cpu |

There is no indexer or dashboard, to keep the lab near 3 GB of RAM. See "With a
dashboard" below if you want one.

## Use

```sh
./setup.sh              # manager up, rules installed, endpoint built and enrolled
./alerts.sh             # Layer 1: rule 100511 within about 2 minutes, no action needed
./replay-tokens.sh      # Layer 3: 3 sample proxy lines, expect 2 alerts from 100525
./crash.sh              # Layer 2: crash the JVM, expect 100520 once and 100522 two or three times
./alerts.sh
./logtest-samples.sh    # the other Layer 1 verdicts, through wazuh-logtest
./teardown.sh
```

## What a run looks like

Validated on an AMD EPYC Genoa host, Wazuh 4.9.2, from a clean `setup.sh`:

| Rule | Level | Alerts | Source |
|---|---|---|---|
| 100511 exposed | 12 | 1 per scan (every 2 minutes) | real scanner output, via the agent's `command` |
| 100525 malformed token | 10 | 2 of 3 sample lines | sample JSON, via the agent |
| 100520 fatal error header | 8 | 1 | real crash report, via the agent |
| 100522 fatal signal | 11 | 2 or 3 per crash | real crash report, via the agent |
| 100521 Base64 frame in the stack | 13 | 0 | real crash report; see below |
| 100512, 100513 | 7, 9 | `wazuh-logtest` only | sample lines |
| 100530 java spawns a shell (Windows) | 12 | not tested | none |

The crash reproduced on 5 of 5 runs of `crash.sh`, a few seconds in each time. It is still
a race, so `crash.sh` is bounded to 100 seconds and can exit cleanly.

## Three things the lab taught

1. **The crash does not happen in the Base64 code.** The out-of-bounds write corrupts
   neighbouring heap memory and the JVM dies somewhere else, a little later: in the
   garbage collector (`DefNewGeneration::copy_to_survivor_space`) in one run, in
   JIT-compiled application code in another. No crash report had the decode intrinsic
   in the stack, so rule 100521 stayed silent and 100522 is the one that fires. 100522 fires on any hard JVM
   crash, which is why it is level 11 and not an attack verdict.
2. **Do not tail `hs_err_pid*.log` with a wildcard.** On Wazuh 4.9.2, logcollector starts
   at the end of a file it discovers through a wildcard, with or without
   `only-future-events`. A JVM writes `hs_err` once and never appends, so nothing is
   shipped. The lab starts the JVM with `-XX:+ErrorFileToStderr` and tails the log that
   already receives the service's stderr.
3. **The agent container needs an init.** On first connect the manager tells the agent
   to restart. Without an init to reap the stopped daemons, `wazuh-control restart` waits
   forever on zombies and the agent never comes back. Compose sets `init: true`.

The bare trigger loop (`Base64Trigger`) performs the bad write but did not crash the JVM
even after about 118 million iterations. `Base64Crash` adds heap pressure (32 MB heap,
serial collector, several threads, small live allocations around each decode) to turn the
corruption into a fault.

## With a dashboard

To see the alerts in the Wazuh dashboard, run the official `wazuh-docker` single-node
stack (4.9.2) next to the lab and enroll the endpoint with that manager instead. The
endpoint looks for a host called `wazuh-manager`, so give the stack's manager that alias
on the lab network (`<stack-manager>` is its container name):

```sh
docker cp ../rules/decoders/java4shell_decoders.xml <stack-manager>:/var/ossec/etc/decoders/
docker cp ../rules/rules/java4shell_rules.xml       <stack-manager>:/var/ossec/etc/rules/
docker exec <stack-manager> chown wazuh:wazuh \
  /var/ossec/etc/decoders/java4shell_decoders.xml /var/ossec/etc/rules/java4shell_rules.xml
docker exec <stack-manager> /var/ossec/bin/wazuh-control restart

docker network create java4shell-lab_j4s
docker network connect --alias wazuh-manager java4shell-lab_j4s <stack-manager>
docker compose up -d --no-deps target
```

`crash.sh` and `replay-tokens.sh` work unchanged. In the dashboard, filter Discover on
`rule.groups:java4shell`. The stack adds about 4 GB of RAM.

## Choosing a vulnerable JDK

Set `JDK_IMAGE` (build arg in `endpoint/Dockerfile`) to a pre-fix build. Layer 1 then
tells you whether the pair of build and CPU is `EXPOSED`. Fixed builds will not crash.
Distribution numbering differs from Oracle's, so check on the host instead of trusting a
tag name.
