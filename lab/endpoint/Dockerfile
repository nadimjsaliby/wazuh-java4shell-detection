# Lab endpoint: a known-affected JDK with a Wazuh agent on the same box, the way a real
# server would look. The agent runs the exposure scan and tails the JVM crash files.
#
# MUST run on an x86-64 AVX-512 VBMI host for the crash to reproduce. The platform pin
# keeps the image x86, but the bug only *fires* on real AVX-512 VBMI silicon
# (Intel Ice Lake+ / AMD Zen 4+).
#
# Pick a pre-fix build and check it with scanner/java4shell-check.sh (expect
# verdict=EXPOSED). Fixed builds will NOT reproduce the crash.
# Build context is the repo root (see docker-compose.yml).
ARG JDK_IMAGE=eclipse-temurin:21.0.5_11-jdk
FROM --platform=linux/amd64 ${JDK_IMAGE}

ARG WAZUH_VERSION=4.9.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates procps lsb-release \
 && curl -fsSL -o /tmp/wazuh-agent.deb \
      "https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VERSION}-1_amd64.deb" \
 && WAZUH_MANAGER=wazuh-manager WAZUH_AGENT_NAME=j4s-endpoint dpkg -i /tmp/wazuh-agent.deb \
 && rm -rf /tmp/wazuh-agent.deb /var/lib/apt/lists/*

# Layer 1 scanner, plus the lab's localfile blocks appended as a second <ossec_config>.
COPY scanner/java4shell-check.sh /var/ossec/active-response/bin/java4shell-check.sh
COPY lab/endpoint/java4shell-agent.conf /tmp/java4shell-agent.conf
RUN chmod 750 /var/ossec/active-response/bin/java4shell-check.sh \
 && chown root:wazuh /var/ossec/active-response/bin/java4shell-check.sh \
 && { echo '<ossec_config>'; cat /tmp/java4shell-agent.conf; echo '</ossec_config>'; } >> /var/ossec/etc/ossec.conf \
 && rm /tmp/java4shell-agent.conf \
 && mkdir -p /var/log/jvm /var/log/j4s /opt/poc \
 && touch /var/log/j4s/proxy-auth.json /var/log/jvm/service-stderr.log

COPY poc/Base64Trigger.java poc/Base64Crash.java /opt/poc/
WORKDIR /opt/poc
RUN javac Base64Trigger.java Base64Crash.java

COPY lab/endpoint/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
