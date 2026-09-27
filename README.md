# ubuntu-devops-setup

Scripts to prepare an Ubuntu machine with the common software a developer, DevOps, or platform engineer needs. Active Directory / domain-controller integration is planned but not implemented yet.

## Scripts

| Script | Target |
| --- | --- |
| `ubuntu-system-prepare-baremetal.sh` | Bare metal (baseline + GUI, communication and remote-desktop apps) |
| `ubuntu-system-prepare-vm-dev.sh` | Development VM (baseline + `x2go` and remote-desktop tools) |
| `ubuntu-system-prepare-wsl-dev.sh` | WSL2 development environment (minimum baseline) |
| `ubuntu-system-prepare-common.sh` | Shared library sourced by the scripts above |

## Usage

Run the script matching your environment on a fresh Ubuntu installation, with `sudo`. Set `gituser` and `gitemail` first if you want Git configured:

```bash
export gituser="Your Name"
export gitemail="you@example.com"
sudo -E ./ubuntu-system-prepare-baremetal.sh
```

The scripts are idempotent and can be re-run. They install packages, add third-party apt repositories (keyring `signed-by`), edit `/etc/sudoers.d/`, and by default disable `cups` and `ufw`. Review them first and run them only on a machine you can rebuild.

Switchable options (set before running): `K8S_MINOR`, `APT_UPGRADE`, `ENABLE_PASSWORDLESS_SUDO`, `DISABLE_UFW`, `DISABLE_CUPS`.

## Target

Ubuntu **24.04 / 26.04 LTS and derivatives**, on `amd64`/`arm64`, installing the newest available versions of each app. The scripts no longer use `apt-key`, Docker Compose v1, or the legacy `ms-teams` package; Teams is installed via **Teams for Linux**.

Vendors that publish `amd64` only (Spotify, VirtualBox) are skipped with a warning on `arm64`.

The `vm-dev` target is validated end-to-end on `arm64` (Ubuntu 24.04); the physical target is `amd64`-oriented because VirtualBox is not published for `arm64` Linux.

## Zsh setup

All three entry points automatically configure Zsh for `TARGET_USER` (the user invoking
`sudo`): Tab completion, history suggestions (accept with the right arrow), syntax
highlighting, Kubernetes completion/`k` alias, and a two-line Ubuntu/directory/Git
prompt. Tracked changes appear as `*` (unstaged) or `+` (staged). Zsh becomes the
default login shell.

The installer backs up an existing `.zshrc` before adding a single source line and
manages `~/.config/zsh/devops.zsh`. Existing configuration stays in place; the managed
configuration loads last and takes precedence for the prompt and shared settings.
Re-running updates the managed file without duplicating the source line. Keep the
`assets/` directory alongside the scripts when copying the repository.

JetBrainsMono Nerd Font Mono is installed for the Linux user. On WSL, Windows
PowerShell also installs/registers it for the current Windows user and sets the font
on the Windows Terminal profile matching the distribution name. Existing font size
and other profile settings are preserved; changed settings files are backed up.
Stable, Preview and unpackaged Windows Terminal settings locations are supported.
If Windows interop is disabled, the profile was renamed, or settings cannot be parsed,
the installer prints a warning with the manual font selection needed. Close and reopen
Windows Terminal after installation.

On bare metal/VM, a user fontconfig rule selects the font for the `monospace` alias;
terminals configured with an explicit font need **JetBrainsMono Nerd Font Mono**
selected in their preferences.

Optional environment variables: `CONFIGURE_WINDOWS_TERMINAL=0` skips Windows changes;
`NERD_FONT_REF` selects the Nerd Fonts Git ref for a first download (default `master`).
The font is downloaded only when missing. Plugins come from Ubuntu packages.
