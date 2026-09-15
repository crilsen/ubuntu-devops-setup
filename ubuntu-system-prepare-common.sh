#!/usr/bin/env bash
# Shared library for the ubuntu-system-prepare* scripts.
# Source this file from a target script; do not execute it directly.

set -euo pipefail

TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(id -un)}}"
TARGET_HOME="${TARGET_HOME:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}"
ARCH="$(dpkg --print-architecture)"
# shellcheck source=/dev/null
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
KEYRINGS_DIR=/etc/apt/keyrings

K8S_MINOR="${K8S_MINOR:-v1.36}"
APT_UPGRADE="${APT_UPGRADE:-1}"
ENABLE_PASSWORDLESS_SUDO="${ENABLE_PASSWORDLESS_SUDO:-1}"
DISABLE_UFW="${DISABLE_UFW:-1}"
DISABLE_CUPS="${DISABLE_CUPS:-1}"

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

has_systemd() { [[ -d /run/systemd/system ]]; }

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script as root or with sudo."
  [[ -n "$TARGET_HOME" ]] || die "Could not resolve the home directory of user '$TARGET_USER'."
}

as_user() {
  local user="$1"
  shift
  sudo -u "$user" -H "$@"
}

apt_update() { DEBIAN_FRONTEND=noninteractive apt-get update -y; }
apt_install() { DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
apt_remove() { DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@" 2>/dev/null || true; }

add_apt_repo() {
  local name="$1" key_url="$2" repo_line="$3"
  install -m 0755 -d "$KEYRINGS_DIR"
  local key="$KEYRINGS_DIR/$name.gpg"
  if [[ ! -s "$key" ]]; then
    curl -fsSL "$key_url" | gpg --dearmor --yes -o "$key"
    chmod a+r "$key"
  fi
  printf '%s\n' "${repo_line//@KEY@/$key}" > "/etc/apt/sources.list.d/$name.list"
}

add_bashrc_block() {
  local tag="$1" body="$2"
  local file="$TARGET_HOME/.bashrc"
  [[ -f "$file" ]] || install -m 0644 /dev/null "$file"
  if ! grep -q ">>> ${tag} >>>" "$file"; then
    {
      printf '\n# >>> %s >>>\n' "$tag"
      printf '%s\n' "$body"
      printf '# <<< %s <<<\n' "$tag"
    } >> "$file"
  fi
  chown "$TARGET_USER:$TARGET_USER" "$file"
}

snap_install() {
  local pkg="$1"
  shift
  if snap list "$pkg" >/dev/null 2>&1; then
    log "snap $pkg already installed"
  else
    snap install "$pkg" "$@"
  fi
}

flatpak_install() { flatpak install -y --noninteractive flathub "$1"; }

install_base() {
  log "Base packages"
  apt_update
  apt_install ca-certificates curl wget gnupg lsb-release \
    apt-transport-https software-properties-common vim htop jq unzip zip snapd
}

install_flatpak() {
  log "Flatpak + Flathub"
  apt_install flatpak
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_git() {
  log "Git"
  add-apt-repository -y ppa:git-core/ppa
  apt_update
  apt_install git git-lfs
  if [[ -n "${gituser:-}" && -n "${gitemail:-}" ]]; then
    as_user "$TARGET_USER" git config --global user.name "$gituser"
    as_user "$TARGET_USER" git config --global user.email "$gitemail"
  else
    warn "gituser/gitemail not set; skipping git identity."
  fi
}

install_java() {
  log "Java (default JDK)"
  apt_install default-jdk
}

install_python() {
  log "Python"
  apt_install python3 python3-pip python3-venv pipx
}

install_chrome() {
  log "Google Chrome"
  add_apt_repo google-chrome https://dl.google.com/linux/linux_signing_key.pub \
    "deb [arch=$ARCH signed-by=@KEY@] https://dl.google.com/linux/chrome/deb/ stable main"
  apt_update
  apt_install google-chrome-stable
}

install_vscode() {
  log "Visual Studio Code"
  add_apt_repo microsoft-vscode https://packages.microsoft.com/keys/microsoft.asc \
    "deb [arch=amd64,arm64,armhf signed-by=@KEY@] https://packages.microsoft.com/repos/code stable main"
  apt_update
  apt_install code
}

install_sublime() {
  log "Sublime Text"
  add_apt_repo sublime-text https://download.sublimetext.com/sublimehq-pub.gpg \
    "deb [signed-by=@KEY@] https://download.sublimetext.com/ apt/stable/"
  apt_update
  apt_install sublime-text
}

install_docker() {
  log "Docker Engine + Compose v2"
  apt_remove docker docker-engine docker.io containerd runc \
    docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker
  add_apt_repo docker https://download.docker.com/linux/ubuntu/gpg \
    "deb [arch=$ARCH signed-by=@KEY@] https://download.docker.com/linux/ubuntu $CODENAME stable"
  apt_update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  if has_systemd; then
    systemctl enable --now docker
  else
    service docker start 2>/dev/null || warn "Could not start docker without systemd."
  fi
  if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx docker; then
    usermod -aG docker "$TARGET_USER"
    warn "Added $TARGET_USER to the docker group; log out and back in for it to apply."
  fi
}

install_kubectl() {
  log "kubectl ($K8S_MINOR)"
  add_apt_repo kubernetes "https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/Release.key" \
    "deb [signed-by=@KEY@] https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/ /"
  apt_update
  apt_install kubectl
  add_bashrc_block kubectl 'source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
dr="--dry-run=client -o yaml"'
}

install_awscli() {
  log "AWS CLI v2"
  local aws_arch tmp
  case "$(uname -m)" in
    x86_64) aws_arch=x86_64 ;;
    aarch64 | arm64) aws_arch=aarch64 ;;
    *)
      warn "Unsupported architecture for AWS CLI: $(uname -m)"
      return 0
      ;;
  esac
  tmp="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o "$tmp/awscliv2.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  "$tmp/aws/install" --update
  rm -rf "$tmp"
}

install_terminator() {
  log "Terminator"
  apt_install terminator
}

install_zsh() {
  log "Zsh"
  apt_install zsh
}

install_flameshot() {
  log "Flameshot"
  apt_install flameshot
}

install_remmina() {
  log "Remmina"
  apt_install remmina
}

install_teams() {
  log "Teams for Linux"
  snap_install teams-for-linux
}

install_spotify() {
  log "Spotify"
  add_apt_repo spotify https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
    "deb [signed-by=@KEY@] https://repository.spotify.com stable non-free"
  apt_update
  apt_install spotify-client
}

install_anydesk() {
  log "AnyDesk"
  add_apt_repo anydesk https://keys.anydesk.com/repos/DEB-GPG-KEY \
    "deb [signed-by=@KEY@] http://deb.anydesk.com/ all main"
  apt_update
  apt_install anydesk
}

install_teamviewer() {
  log "TeamViewer"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "https://download.teamviewer.com/download/linux/teamviewer_${ARCH}.deb" -o "$tmp/teamviewer.deb"
  apt_install "$tmp/teamviewer.deb"
  rm -rf "$tmp"
}

install_discord() {
  log "Discord"
  flatpak_install com.discordapp.Discord
}

install_virtualbox() {
  log "VirtualBox"
  case "$CODENAME" in
    jammy | noble)
      add_apt_repo virtualbox https://www.virtualbox.org/download/oracle_vbox_2016.asc \
        "deb [arch=amd64 signed-by=@KEY@] https://download.virtualbox.org/virtualbox/debian $CODENAME contrib"
      apt_update
      apt_install "linux-headers-$(uname -r)" dkms
      local pkg
      pkg="$(apt-cache search --names-only '^virtualbox-[0-9]' | awk '{print $1}' | sort -V | tail -n1)"
      apt_install "${pkg:-virtualbox}"
      ;;
    *)
      warn "Oracle publishes no VirtualBox repo for '$CODENAME'; using the Ubuntu package."
      apt_install virtualbox
      ;;
  esac
}

install_x2go() {
  log "X2Go server"
  apt_install x2goserver x2goserver-xsession
}

install_lens() {
  log "Lens"
  snap_install kontena-lens --classic
}

configure_passwordless_sudo() {
  if [[ "$ENABLE_PASSWORDLESS_SUDO" != "1" ]]; then
    log "Skipping passwordless sudo (ENABLE_PASSWORDLESS_SUDO=$ENABLE_PASSWORDLESS_SUDO)"
    return 0
  fi
  log "Passwordless sudo for $TARGET_USER"
  local file="/etc/sudoers.d/90-$TARGET_USER"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$TARGET_USER" > "$file"
  chmod 0440 "$file"
  if ! visudo -cf "$file"; then
    rm -f "$file"
    die "Invalid sudoers rule; removed $file"
  fi
}

tune_services() {
  if [[ "$DISABLE_CUPS" == "1" ]] && has_systemd; then
    log "Disabling cups"
    systemctl disable --now cups 2>/dev/null || true
  fi
  if [[ "$DISABLE_UFW" == "1" ]] && has_systemd; then
    log "Disabling ufw"
    systemctl disable --now ufw 2>/dev/null || true
  fi
}

finish_upgrade() {
  [[ "$APT_UPGRADE" == "1" ]] || return 0
  log "Upgrading installed packages"
  apt_update
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}
