#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo 'Run as root on the temporary benchmark VM.' >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg git jq chrony
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
arch=$(dpkg --print-architecture)
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' "$arch" "$codename" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker chrony
swapoff -a
mkdir -p /opt/jmeter-research
chmod 700 /opt/jmeter-research

printf 'host=%s\n' "$(hostname)"
printf 'architecture=%s\n' "$(uname -m)"
printf 'docker=%s\n' "$(docker version --format '{{.Server.Version}}')"
printf 'compose=%s\n' "$(docker compose version --short)"
printf 'clock=%s\n' "$(chronyc tracking | sed -n 's/^System time[[:space:]]*:[[:space:]]*//p')"
printf 'active_swap_devices=%s\n' "$(swapon --noheadings --show | wc -l)"
