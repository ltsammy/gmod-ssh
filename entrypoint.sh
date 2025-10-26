#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${SSH_PUBKEYS:=}"        # multiple keys supported (comma- or newline-separated)
: "${SSH_PUBKEY:=}"         # backward-compat: single key
: "${PTERO_UUID:=}"
: "${HOSTKEY_DIR:=/etc/ssh/hostkeys}"   # MUST match sshd_config HostKey paths in Dockerfile

# Merge legacy SSH_PUBKEY into SSH_PUBKEYS if provided
if [[ -n "${SSH_PUBKEY}" ]]; then
  if [[ -z "${SSH_PUBKEYS}" ]]; then
    SSH_PUBKEYS="${SSH_PUBKEY}"
  else
    SSH_PUBKEYS="${SSH_PUBKEYS}"$'\n'"${SSH_PUBKEY}"
  fi
fi

if [[ -z "${SSH_PUBKEYS}" ]]; then
  echo "ERROR: SSH_PUBKEYS env var is empty. Provide one or more public keys." >&2
  exit 1
fi

# Normalize multi-key input:
# - remove CR (Windows)
# - allow comma *or* newline as separator
# - drop empty lines
CLEAN_KEYS="$(echo "${SSH_PUBKEYS}" | tr -d '\r' | tr ',' '\n' | sed '/^[[:space:]]*$/d')"

# Ensure persistent hostkey dir and host keys (persist across rebuilds/redeploys)
install -d -m 0700 -o root -g root "${HOSTKEY_DIR}"
if [[ ! -f "${HOSTKEY_DIR}/ssh_host_ed25519_key" ]]; then
  ssh-keygen -t ed25519 -f "${HOSTKEY_DIR}/ssh_host_ed25519_key" -N '' -q
fi
if [[ ! -f "${HOSTKEY_DIR}/ssh_host_rsa_key" ]]; then
  ssh-keygen -t rsa -b 4096 -f "${HOSTKEY_DIR}/ssh_host_rsa_key" -N '' -q
fi
chmod 600 "${HOSTKEY_DIR}"/ssh_host_*_key || true
chmod 644 "${HOSTKEY_DIR}"/ssh_host_*_key.pub || true

# Write user authorized_keys (default OpenSSH location)
install -d -m 0700 -o "${USERNAME}" -g "${USERNAME}" "/home/${USERNAME}/.ssh"
printf '%s\n' "${CLEAN_KEYS}" > "/home/${USERNAME}/.ssh/authorized_keys"
chmod 600 "/home/${USERNAME}/.ssh/authorized_keys"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.ssh"

# Friendly MOTD
{
  echo "Pterodactyl UUID: ${PTERO_UUID}"
  echo "Editing path: /workspace/server"
} > /etc/motd || true

# Warn if mount is missing
[[ -d /workspace/server ]] || echo "WARNING: /workspace/server not found. Did you mount the Pterodactyl path?"

# Run sshd in foreground
exec /usr/sbin/sshd -D -e
