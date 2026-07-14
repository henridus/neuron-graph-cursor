#!/usr/bin/env bash
# Oracle ARM — durcissement reseau de base. Run as ubuntu with sudo.
set -euo pipefail

sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git tmux ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
sudo ufw status

uname -m   # expect aarch64
echo "OK harden — verify Security List Oracle = SSH 22 only"
