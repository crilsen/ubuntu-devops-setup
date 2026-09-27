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
  log "Zsh + Oh My Zsh + Powerlevel10k"
  apt_install zsh git curl

  local zsh_dir="${TARGET_HOME}/.oh-my-zsh"
  local p10k_dir="${zsh_dir}/custom/themes/powerlevel10k"

  # Oh My Zsh
  if [[ ! -d "$zsh_dir" ]]; then
    sudo -u "$TARGET_USER" sh -c \
      "RUNZSH=no KEEP_ZSHRC=yes sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
  fi

  # Powerlevel10k
  if [[ ! -d "$p10k_dir" ]]; then
    sudo -u "$TARGET_USER" git clone --depth=1 \
      https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
  fi

  # External plugins (zsh-users)
  local custom_plugins="${zsh_dir}/custom/plugins"
  sudo -u "$TARGET_USER" mkdir -p "$custom_plugins"
  for _plug in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
    if [[ ! -d "${custom_plugins}/${_plug}" ]]; then
      sudo -u "$TARGET_USER" git clone --depth=1 \
        "https://github.com/zsh-users/${_plug}.git" "${custom_plugins}/${_plug}" 2>/dev/null || true
    fi
  done

  # .zshrc — Ubuntu-themed Powerlevel10k prompt
  local zshrc="${TARGET_HOME}/.zshrc"
  sudo -u "$TARGET_USER" tee "$zshrc" >/dev/null <<'ZSHRC'
# Enable Powerlevel10k instant prompt (should stay at top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  # ── Core ─────────────────────────────────────────────────────────
  git
  command-not-found
  colored-man-pages
  history
  sudo              # press Esc Esc to toggle sudo on last command
  dirhistory         # Alt+Arrow for directory navigation
  copypath           # copy current path to clipboard
  copyfile           # copy file contents to clipboard

  # ── Languages ───────────────────────────────────────────────────
  python
  pip
  golang
  rust
  node
  npm

  # ── Containers & Orchestration ──────────────────────────────────
  docker
  docker-compose
  kubectl
  kubectx            # fast context/namespace switching (kubectx/kubens)
  helm
  helmfile
  helm-diff
  flux
  minikube
  skaffold
  tilt

  # ── IaC & Provisioning ─────────────────────────────────────────
  terraform
  terraform-docs
  ansible

  # ── Cloud CLIs ──────────────────────────────────────────────────
  aws
  gcloud

  # ── Extra completions & suggestions ─────────────────────────────
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Fallback: only source oh-my-zsh if the theme is present
source $ZSH/oh-my-zsh.sh

# ── Autosuggestions config ──────────────────────────────────────────────
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#586069"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ── Completions ─────────────────────────────────────────────────────────
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' squeeze-slashes true

# ── History ─────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# ── DevOps aliases ──────────────────────────────────────────────────────
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kgn='kubectl get nodes'
alias kl='kubectl logs -f'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kctx='kubectx'
alias kns='kubens'

alias dc='docker compose'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dcps='docker compose ps'
alias dcl='docker compose logs -f'
alias dcbuild='docker compose build'
alias dcpull='docker compose pull'

alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfs='terraform state list'
alias tfsh='terraform show'

alias helmup='helm repo update'
alias helmls='helm list -A'
alias helmig='helm install'
alias helmug='helm upgrade'
alias helmun='helm uninstall'

alias ans='ansible'
alias anp='ansible-playbook'

alias gp='git push'
alias gl='git pull'
alias gst='git status'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcm='git commit -m'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gaa='git add -A'
alias lg='lazygit'

# ── Misc ────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ll='ls -lah --color=auto'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ports='ss -tulanp'
alias myip='curl -s ifconfig.me'
alias localip='hostname -I | awk '"'"'{print $1}'"'"'

# ── Powerlevel10k config ──────────────────────────────────────────────
() {
  emulate -L zsh
  setopt no_unset
  (( ${+parameters[POWERLEVEL9K_INSTANT_PROMPT]} )) || POWERLEVEL9K_INSTANT_PROMPT=quiet

  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
  [[ -f ~/.p10k.zsh ]] && return

  (( ${+functions[p10k]} )) || source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme"
  (( ${+functions[p10k]} )) || return

  # ── Prompt style ───────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=true
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
  typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false

  # ── Separators (clean thin lines) ──────────────────────────────────
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=' '

  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''

  # ── Prompt elements ────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon                 # Ubuntu symbol
    dir                     # current directory
    vcs                     # git status
    prompt_char             # prompt symbol
  )

  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # exit code of last command
    command_execution_time  # duration of last command
    background_jobs         # presence of background jobs
    virtualenv              # python virtual environment
    kubecontext             # kubernetes context
    aws                     # aws profile
    docker_context          # docker context
    nvm                     # node version
    node_version            # node version
    go_version              # go version
    rust_version            # rust version
    php_version             # php version
    context                 # user@host
  )

  # ── Ubuntu symbol ──────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=249
  typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION=' %BNICE%b'

  # ── Directory ──────────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=true
  typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_FOREGROUND=1

  # ── VCS (git) ──────────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=248
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=248
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=' '
  typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1

  # ── Prompt char ────────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION=' ❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION=' ❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION=' V'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION=' ▶'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true

  # ── Status / execution time / background jobs ──────────────────────
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=196
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=101
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=70

  # ── Context (user@host) ────────────────────────────────────────────
  typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=248
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_CONTENT_EXPANSION='%BNICE%b'

  # ── Segment icons ──────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=''
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'

  (( ${+functions[p10k]} )) && p10k reload
}

# Tell p10k this file has been sourced (so it doesn't show the config wizard again)
[[ ! -f ~/.p10k.zsh ]] && (( ${+functions[p10k]} )) && p10k reload
# ── End Powerlevel10k config ──────────────────────────────────────────
ZSHRC

  # Set default shell to zsh
  chsh -s "$(which zsh)" "$TARGET_USER" 2>/dev/null || \
    warn "Could not change default shell to zsh for $TARGET_USER; run 'chsh -s \$(which zsh)' manually."
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
  if [[ "$ARCH" != "amd64" ]]; then
    warn "Spotify publishes amd64-only packages; skipping on $ARCH."
    return 0
  fi
  add_apt_repo spotify https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
    "deb [arch=amd64 signed-by=@KEY@] https://repository.spotify.com stable non-free"
  apt_update
  apt_install spotify-client
}

install_discord() {
  log "Discord"
  flatpak_install com.discordapp.Discord
}

install_virtualbox() {
  log "VirtualBox"
  if [[ "$ARCH" != "amd64" ]]; then
    warn "VirtualBox has no arm64 Linux build; skipping on $ARCH."
    return 0
  fi
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
