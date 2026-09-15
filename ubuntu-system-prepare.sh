#!/usr/bin/env bash
# Ubuntu system prepare - physical machine.
# Targets Ubuntu 24.04 / 26.04 LTS and derivatives.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ubuntu-system-prepare-common.sh
source "$SCRIPT_DIR/ubuntu-system-prepare-common.sh"

require_root
cd /tmp

# git identity, optional: export gituser / gitemail before running

install_base
install_flatpak
install_git
install_java
install_python
install_docker
install_kubectl
install_awscli
install_vscode
install_sublime
install_chrome
install_terminator
install_zsh
install_flameshot
install_remmina
install_teams
install_spotify
install_anydesk
install_teamviewer
install_discord
install_virtualbox
install_lens

configure_passwordless_sudo
tune_services
finish_upgrade

log "Done. Log out and back in to use docker without sudo."
