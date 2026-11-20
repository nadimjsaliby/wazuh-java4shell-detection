# Exposure inventory

`java4shell-check.sh` enumerates every Java runtime on a host, decides whether each build
is affected by CVE-2026-114938, checks the CPU for AVX-512 VBMI, and prints a verdict line:

```
JAVA4SHELL_SCAN verdict=EXPOSED version=21.0.5 line=21 cpu_avx512vbmi=yes bin=/opt/java/bin/java
```

Verdicts: `EXPOSED` (affected build + AVX-512 VBMI CPU, patch now), `AFFECTED` (affected
build, CPU not capable), `AFFECTED_NOFIX` (affected line with no fixed build),
`FIXED`, `NOT_AFFECTED`, `UNKNOWN`.

## Deploy

```sh
install -m 750 java4shell-check.sh /var/ossec/active-response/bin/java4shell-check.sh
```

Add the `<localfile>` command block from the script header to the agent `ossec.conf`, then
restart the agent. Pair with the decoder and rules in `../rules/` on the manager.

## One-off

```sh
sh java4shell-check.sh
```

The version thresholds follow Oracle-style numbering. Other distributions number builds
differently, so the script always prints the raw version for a human to verify against the
matrix in the blog post.
