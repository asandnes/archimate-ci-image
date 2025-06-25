FROM docker.io/ubuntu:22.04 AS base

WORKDIR /archi

ARG TZ=UTC
ARG UID=1000
ARG GID=1000

# Create non-root user
RUN groupadd -r -g ${GID} archi && useradd -r -g archi -u ${UID} -m -d /home/archi archi

# DL3015 ignored for suppress org.freedesktop.DBus.Error.ServiceUnknown
# hadolint ignore=DL3008,DL3015
RUN set -eux; \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime; \
    echo "$TZ" > /etc/timezone; \
    apt-get update; \
    apt-get install -y \
      ca-certificates \
      libgtk2.0-cil \
      libswt-gtk-4-jni \
      dbus-x11 \
      xvfb \
      curl \
      git \
      openssh-client \
      unzip; \
    apt-get clean; \
    update-ca-certificates; \
    rm -rf /var/lib/apt/lists/*

FROM base AS archi
ARG ARCHI_MINOR_VERSION=5.6
ARG ARCHI_PATCH_VERSION=5.6.0
ARG ARCHI_URL=https://www.archimatetool.com/downloads/archi/${ARCHI_MINOR_VERSION}/Archi-Linux64-${ARCHI_PATCH_VERSION}.tgz

# Download & extract Archimate tool as root
RUN set -eux; \
    curl -#Lo archi.tgz \
      ${ARCHI_URL}; \
    tar zxf archi.tgz -C /opt/; \
    rm archi.tgz; \
    chmod +x /opt/Archi/Archi; \
    mkdir -p /home/archi/.archi/dropins /archi/report /archi/project; \
    chown -R archi:archi /opt/Archi /home/archi/.archi /archi

FROM archi AS coarchi
ARG COARCHI_VERSION=0.9.4
ARG COARCHI_URL=https://www.archimatetool.com/downloads/coarchi/coArchi_${COARCHI_VERSION}.archiplugin

# Download & extract Archimate coArchi plugin as root
RUN set -eux; \
    curl -#Lo coarchi.zip --request POST \
      ${COARCHI_URL}; \
    unzip coarchi.zip -d /home/archi/.archi/dropins/ && \
    rm coarchi.zip && \
    chown -R archi:archi /home/archi/.archi

FROM coarchi 

# Copy entrypoint script and set ownership
COPY entrypoint.sh /opt/Archi/
RUN chmod +x /opt/Archi/entrypoint.sh && \
    chown archi:archi /opt/Archi/entrypoint.sh

# Switch to non-root user
USER archi

# Set environment variables for non-root user
ENV HOME=/home/archi
ENV XDG_RUNTIME_DIR=/tmp/runtime-archi

# Create runtime directory
RUN mkdir -p /tmp/runtime-archi

ENTRYPOINT [ "/opt/Archi/entrypoint.sh" ]
