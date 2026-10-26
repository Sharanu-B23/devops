FROM jenkins/jenkins:lts
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl python3 python3-pip python3-venv docker.io \
    && rm -rf /var/lib/apt/lists/*
# Runs as root so it can use the mounted Docker socket (see README: security trade-off).
USER root
