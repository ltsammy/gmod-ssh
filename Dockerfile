FROM debian:stable-slim

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server ca-certificates sudo rsync git curl nano vim bash \
  && rm -rf /var/lib/apt/lists/*

# sshd runtime dir
RUN mkdir -p /var/run/sshd

# Non-root user (good for VS Code Remote-SSH)
ENV USERNAME=dev \
    USER_UID=1000 \
    USER_GID=1000 \
    HOSTKEY_DIR=/etc/ssh/hostkeys
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd  --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
 && usermod -aG sudo ${USERNAME} \
 && echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99_nopasswd

# sshd config (use defaults for AuthorizedKeysFile; pin HostKey to persistent dir)
RUN sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 30/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 4/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?UseDNS.*/UseDNS no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?Subsystem\\s\\+sftp.*/Subsystem\tsftp\tinternal-sftp/' /etc/ssh/sshd_config && \
    sed -i 's|^#\?HostKey .*||g' /etc/ssh/sshd_config && \
    printf '%s\n' \
      "HostKey /etc/ssh/hostkeys/ssh_host_ed25519_key" \
      "HostKey /etc/ssh/hostkeys/ssh_host_rsa_key" \
    >> /etc/ssh/sshd_config

# Workspace mount point (Pterodactyl files)
RUN mkdir -p /workspace/server && chown -R ${USER_UID}:${USER_GID} /workspace

# Runtime env
ENV SSH_PUBKEYS="" \
    PTERO_UUID=""

# Entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep -x sshd >/dev/null || exit 1

CMD ["/usr/local/bin/entrypoint.sh"]
