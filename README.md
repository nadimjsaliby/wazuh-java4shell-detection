# wazuh-java4shell-detection

Wazuh detection pack and a reproducible lab for **Java4Shell (CVE-2026-114938)**, the
OpenJDK `java.util.Base64` AVX-512 decoder heap overflow (pre-auth RCE in default
configurations of Keycloak, Jira, Jenkins and others).

Companion repo to the post **"Java4Shell on Wazuh"** on blog.nadimjsaliby.com.

At the time of writing there is no public Wazuh ruleset for this CVE. Network, Sigma and
ModSecurity rules exist (see Credits); this fills the Wazuh gap: agent-side exposure
inventory, the JVM crash-stack signal, a malformed-token heuristic, and post-exploitation
process behavior.

---

## ⚠️ Scope and safety

- **Authorized lab use only.** The `lab/` and `exploit/` material reproduces a real memory
  corruption bug. Run it only in an isolated environment you own or are authorized to test.
- **Hardware gate.** The overflow only triggers on **x86-64 CPUs with AVX-512 VBMI**
  (Intel Ice Lake or newer, AMD Zen 4 or newer). On ARM (Apple silicon, AWS Graviton) or
  older x86 the bug cannot fire, and the lab can only validate the non-crash layers.
- **Isolation.** The lab binds all ports to `127.0.0.1`, runs on a dedicated bridge
  network, and caps container memory and CPU so a crashing JVM cannot disturb the host.
- **Teardown.** `lab/teardown.sh` removes every container, volume and the lab network.
  Run it when you are done.

---

## Layout

```
rules/
  decoders/java4shell_decoders.xml   # decodes the exposure-scan output
  rules/java4shell_rules.xml         # rules 100510-100531 (four detection layers)
scanner/
  java4shell-check.sh                # agent-side exposure inventory (version + CPU)
poc/
  Base64Trigger.java                 # contained trigger that crashes a vulnerable JVM
  run.sh                             # compile and run with a collected error file
lab/
  docker-compose.yml                 # target app + attacker + wazuh, capped and localhost-bound
  vulnerable-jdk/Dockerfile          # pins a known-affected JDK build
  wazuh/                             # agent config and rule/decoder mounts
  teardown.sh                        # stop and remove everything the lab starts
exploit/                             # phased, lab-only walkthrough (uses public MIT components)
docs/
  attack-surface-map.md              # where untrusted Base64 reaches the decoder
  detection-mapping.md               # attack phase -> which rule fires
```

## Detection layers

| Rule IDs | Layer | Signal | Fidelity |
|---|---|---|---|
| 100510-100513 | Exposure inventory | Affected build on an AVX-512 VBMI host | Pre-attack |
| 100520-100521 | JVM crash | SIGSEGV with a Base64 frame in the stack | Highest |
| 100525 | Wire signature | Malformed Base64 in an Authorization value | Opportunistic |
| 100530-100531 | Post-exploitation | `java` spawns a shell or download tool | Behavioral |

## Quickstart

**Deploy the rules (Wazuh manager):**
```sh
cp rules/decoders/java4shell_decoders.xml /var/ossec/etc/decoders/
cp rules/rules/java4shell_rules.xml       /var/ossec/etc/rules/
chown wazuh:wazuh /var/ossec/etc/decoders/java4shell_decoders.xml /var/ossec/etc/rules/java4shell_rules.xml
/var/ossec/bin/wazuh-logtest -v   # sanity check, then:
systemctl restart wazuh-manager
```

**Run the exposure inventory (Wazuh agent):** see `scanner/README` for the `<localfile>`
command block; the script is also runnable standalone for a one-off check.

**Bring up the lab (AVX-512 VBMI x86-64 host only):**
```sh
cd lab && ./setup.sh        # build and start, capped and localhost-bound
# ... validate detections ...
./teardown.sh               # remove everything
```

## Requirements

- Wazuh 4.x manager and agent (validated on 4.x; adjust rule IDs if 100500s collide).
- For the lab: an x86-64 AVX-512 VBMI host with Docker and `docker compose`.

## Credits

- Vulnerability disclosed and named by **Calif** (CVE-2026-114938).
- Network / Sigma / ModSecurity rules and a public exploit chain:
  [`ikow/java4shell-poc`](https://github.com/ikow/java4shell-poc) (MIT). The `exploit/`
  walkthrough here reuses those public components rather than adding new offensive code.

## License

MIT. See [LICENSE](LICENSE).
