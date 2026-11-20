# Java4Shell lab

A small, isolated lab to validate the detection pack against a real crash and, during the
exploit walkthrough, a real target application.

## ⚠️ Run only here

- An **x86-64 host with AVX-512 VBMI** (Intel Ice Lake+ / AMD Zen 4+). Without it the
  overflow cannot fire; `setup.sh` warns and you can only exercise Layers 1, 3 and 4.
- Everything binds to `127.0.0.1`, runs on a dedicated bridge network, and is memory- and
  CPU-capped so a crashing JVM cannot disturb a host that also runs other work.
- Run `teardown.sh` when done. It removes every container, volume and the network.

## Pieces

| Service | Role | Caps |
|---|---|---|
| `j4s-target` | Vulnerable JDK hosting the trigger (or a real app for the walkthrough) | 1g / 2 cpu |
| `j4s-agent` | Wazuh agent: tails `hs_err` files, runs the exposure scan | 512m / 1 cpu |
| `j4s-manager` | Wazuh manager: analysis engine, alerts to `alerts.json` | 2g / 2 cpu |

Manager-only keeps RAM near 3 GB. For dashboard screenshots, add the Wazuh indexer and
dashboard with an override file; that pushes RAM past 6 GB, so only do it where there is
headroom.

## Use

```sh
./setup.sh                                   # build + start, capped, localhost-bound

# Confirm the target is actually vulnerable:
docker exec j4s-target sh -c 'java -version; grep -c avx512vbmi /proc/cpuinfo'

# Fire the crash (pad 64 for JDK 21/25/27, 128 for JDK 17):
docker exec j4s-target java -XX:ErrorFile=/var/log/jvm/hs_err_pid%p.log /opt/poc/Base64Trigger 64

# Watch the detections fire:
docker exec j4s-manager tail -f /var/ossec/logs/alerts/alerts.json

./teardown.sh                                # remove everything
```

## Choosing a vulnerable JDK

Set `JDK_IMAGE` (build arg in `vulnerable-jdk/Dockerfile`) to a pre-fix build, then confirm
with the scanner (`verdict=EXPOSED`). Fixed builds will not crash. Distribution numbering
differs from Oracle's, so verify on the host rather than trusting a tag name.

## Exploit walkthrough

See `../exploit/` for the phased, lab-only walkthrough that swaps `j4s-target` for a real
application (Keycloak / Jenkins) and maps each phase to the rule that catches it. It reuses
the public MIT components from `ikow/java4shell-poc`.
