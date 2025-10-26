#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${SSH_PUBKEY:=}"
: "${PTERO_UUID:=}"

if [[ -z "${SSH_PUBKEY}" ]]; then
  echo "ERROR: SSH_PUBKEY env var is empty. Provide your public key." >&2
  exit 1
fi

# Write authorized_keys
install -d -m 0700 -o "${USERNAME}" -g "${USERNAME}" "/home/${USERNAME}/.ssh"
echo "${SSH_PUBKEY}" > "/home/${USERNAME}/.ssh/authorized_keys"
chmod 600 "/home/${USERNAME}/.ssh/authorized_keys"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.ssh"

# Also place in global path per sshd_config
install -d -m 0755 /etc/ssh/authorized_keys
echo "${SSH_PUBKEY}" > "/etc/ssh/authorized_keys/${USERNAME}"
chmod 600 "/etc/ssh/authorized_keys/${USERNAME}"

# Ensure workspace exists (mounted by compose)
if [[ ! -d /workspace/server ]]; then
  echo "WARNING: /workspace/server not found. Did you mount the Pterodactyl path?"
fi

# Simple banner with UUID for sanity
echo "Pterodactyl UUID: ${PTERO_UUID}" > /etc/motd
echo "Editing path: /workspace/server" >> /etc/motd

# Start SSHD in foreground
exec /usr/sbin/sshd -D -e
