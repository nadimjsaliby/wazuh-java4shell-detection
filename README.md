# wazuh-java4shell-detection

Wazuh detection pack and a reproducible lab for **Java4Shell (CVE-2026-114938)**, the
OpenJDK `java.util.Base64` AVX-512 decoder heap overflow (pre-auth RCE in default
configurations of Keycloak, Jira, Jenkins and others).

Companion repo to the post **"Java4Shell on Wazuh"** on blog.nadimjsaliby.com.

At the time of writing there is no public Wazuh ruleset for this CVE. Network, Sigma and
ModSecurity rules exist (see Credits); this fills the Wazuh gap: agent-side exposure
inventory, the JVM crash signal, a malformed-token check, and post-exploitation process
behavior.

---

## ⚠️ Scope and safety

- **Authorized lab use only.** The `lab/` and `poc/` material reproduces a real memory
  corruption bug. It crashes a JVM; it contains no code-execution exploit. Run it only in
  an isolated environment you own or are authorized to test.
- **Hardware gate.** The overflow only triggers on **x86-64 CPUs with AVX-512 VBMI**
  (Intel Ice Lake or newer, AMD Zen 4 or newer). On ARM (Apple silicon, AWS Graviton) or
  older x86 the bug cannot fire, and the lab can only validate the non-crash layers.
- **Isolation.** The lab publishes no ports, runs on a dedicated bridge network, and
  caps container memory and CPU so a crashing JVM cannot disturb the host.
- **Teardown.** `lab/teardown.sh` removes every container, volume and the lab network.
  Run it when you are done.

---

## Layout

```
rules/
  decoders/java4shell_decoders.xml   # decodes the exposure-scan output
  rules/java4shell_rules.xml         # rules 100510-100530 (four detection layers)
scanner/
  java4shell-check.sh                # agent-side exposure inventory (version + CPU)
poc/
  Base64Crash.java                   # heap-pressure reproducer that crashes a vulnerable JVM
  Base64Trigger.java                 # bare trigger loop; does the bad write, rarely crashes
  run.sh                             # compile and run either one outside the lab
lab/
  docker-compose.yml                 # endpoint (JDK + agent) and manager, capped, no host ports
  endpoint/                          # image for the vulnerable JDK with a Wazuh agent
  samples/                           # sample proxy lines and scan verdict lines
  setup.sh, crash.sh, replay-tokens.sh, alerts.sh, logtest-samples.sh, teardown.sh
```

## Detection layers

| Rule IDs | Layer | Signal | Lab status |
|---|---|---|---|
| 100510-100513 | Exposure inventory | Affected build on an AVX-512 VBMI host | Fires via a live agent |
| 100520, 100522 | JVM crash | Fatal error header and fatal-signal line of a crash report | Fires via a live agent on a real crash |
| 100521 | JVM crash | Crash stack references the Base64 intrinsic | 0 hits on the real crash (see `lab/README.md`) |
| 100525 | Wire signature | Base64 token with an invalid length in an Authorization value | Fires via a live agent on sample lines |
| 100530 | Post-exploitation | `java` spawns a shell or download tool (Windows, Sysmon) | Not tested |

There is no Linux post-exploitation rule. The `win.eventdata.*` fields only exist for
Windows event channel events, so write that rule against the fields your own Linux
process telemetry decodes to.

## Quickstart

**Deploy the rules (Wazuh manager):**
```sh
cp rules/decoders/java4shell_decoders.xml /var/ossec/etc/decoders/
cp rules/rules/java4shell_rules.xml       /var/ossec/etc/rules/
chown wazuh:wazuh /var/ossec/etc/decoders/java4shell_decoders.xml /var/ossec/etc/rules/java4shell_rules.xml
/var/ossec/bin/wazuh-logtest -v   # sanity check, then:
systemctl restart wazuh-manager
```

**Agent side:** `lab/endpoint/java4shell-agent.conf` has the `<localfile>` blocks for the
exposure scan and the crash report. Read the note in it before collecting crash reports:
tailing `hs_err_pid*.log` with a wildcard ships nothing.

**Bring up the lab (AVX-512 VBMI x86-64 host only):**
```sh
cd lab && ./setup.sh        # manager, rules, endpoint with an enrolled agent
./replay-tokens.sh && ./crash.sh && ./alerts.sh
./teardown.sh               # remove everything
```

## Requirements

- Wazuh 4.x manager and agent (validated on 4.9.2; adjust rule IDs if 100500s collide).
- For the lab: an x86-64 AVX-512 VBMI host with Docker and `docker compose`.

## Credits

- Vulnerability disclosed and named by **Calif** (CVE-2026-114938).
- Network / Sigma / ModSecurity rules and a public exploit chain:
  [`ikow/java4shell-poc`](https://github.com/ikow/java4shell-poc) (MIT). Nothing from it is
  included here; the PoCs in `poc/` are original and stop at a crash.

## License

MIT. See [LICENSE](LICENSE).
