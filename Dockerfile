FROM debian:stable-slim

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server ca-certificates sudo rsync git curl nano vim bash \
  && rm -rf /var/lib/apt/lists/*

# SSH daemon needs this dir
RUN mkdir -p /var/run/sshd /etc/ssh/authorized_keys

# non-root user (good for VS Code Remote SSH)
ENV USERNAME=dev \
    USER_UID=1000 \
    USER_GID=1000
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd  --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
 && usermod -aG sudo ${USERNAME} \
 && echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99_nopasswd

# Minimal, VS Code–friendly sshd config
RUN sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's|^#\?AuthorizedKeysFile.*|AuthorizedKeysFile /etc/ssh/authorized_keys/%u|' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 30/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 4/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?Subsystem\\s\\+sftp.*/Subsystem\tsftp\tinternal-sftp/' /etc/ssh/sshd_config

# Workspace mount point (your Pterodactyl server files will be here)
RUN mkdir -p /workspace/server && chown -R ${USER_UID}:${USER_GID} /workspace

# Env passed at runtime
ENV SSH_PUBKEY="" \
    PTERO_UUID=""

# Entry script writes your SSH key and verifies mount
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD test -S /run/sshd.pid || pgrep -x sshd > /dev/null || exit 1

CMD ["/usr/local/bin/entrypoint.sh"]
