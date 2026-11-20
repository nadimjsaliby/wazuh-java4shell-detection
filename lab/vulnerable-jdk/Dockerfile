# Known-affected JDK for the Java4Shell lab.
#
# MUST run on an x86-64 AVX-512 VBMI host. The platform pin keeps the image x86, but the
# bug only *fires* on real AVX-512 VBMI silicon (Intel Ice Lake+ / AMD Zen 4+).
#
# Pick a pre-fix build and verify on the host with scanner/java4shell-check.sh
# (expect verdict=EXPOSED). Fixed builds (e.g. 21.0.13.1) will NOT reproduce the crash.
# Build context is the repo root (see docker-compose.yml).
ARG JDK_IMAGE=eclipse-temurin:21.0.5_11-jdk
FROM --platform=linux/amd64 ${JDK_IMAGE}

RUN mkdir -p /var/log/jvm /opt/poc
COPY poc/Base64Trigger.java /opt/poc/
WORKDIR /opt/poc
RUN javac Base64Trigger.java

# Idle by default; the lab drives the trigger on demand.
CMD ["sleep", "infinity"]
