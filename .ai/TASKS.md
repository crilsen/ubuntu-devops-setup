# Current Work

## Active

- End-to-end validation of `ubuntu-system-prepare.sh` and `ubuntu-system-prepare-vm-dev.sh` on a disposable Ubuntu 24.04/26.04 desktop (they need snap/flatpak/GUI; the WSL entry point already passed — see Completed).

## Planned

- Re-run the physical/`vm-dev` installers on `amd64`, where Spotify and VirtualBox are available (the arch guards added on 2026-09-15 skip them on `arm64`).
- Decide whether to install a Google Drive client by default; currently none is installed and users are expected to use `pipx install pydrive2` or `rclone`.
- Revisit `K8S_MINOR` (default `v1.36`, validated as `1.36.4`) as new Kubernetes versions are released.

## Blocked

- None.

## Completed

- Adopted the portable agent-context template with observed facts.
- Modernized all scripts per ADR-004/ADR-005/ADR-006:
  - Fixed the `ubuntu-system-prepare.sh` syntax error and the `puthon3`/`java-default`/`aws-iam-authenticatorku` bugs.
  - Replaced `apt-key` with keyring `signed-by` sources; Docker Compose v2 plugin; `kubectl` via `pkgs.k8s.io`.
  - Teams for Linux via snap; removed retired Skype and redundant `aws-iam-authenticator`.
  - Added `set -euo pipefail`, root guard, `TARGET_USER`/`ARCH`/`CODENAME` detection, and idempotency.
  - Extracted shared logic into `ubuntu-system-prepare-common.sh` (ADR-005).
- `bash -n` passes for all four scripts.
- Ran `shellcheck` via the `koalaman/shellcheck:stable` container; fixed the only finding (`SC1091`) with a `# shellcheck source=/dev/null` directive.
- Ran `ubuntu-system-prepare-wsl-dev.sh` end-to-end in a disposable `ubuntu:24.04` arm64 container → exit 0 (base, git, java, python, Docker CE, kubectl 1.36.4, AWS CLI v2, zsh, passwordless sudo).
- Validated the apt-based physical/`vm-dev` installers in `ubuntu:24.04` arm64 → pass for base, git, java, python, Docker, kubectl, AWS CLI, Chrome, VS Code, Sublime, Terminator, zsh, Flameshot, Remmina, X2Go, Flatpak. Spotify is `amd64`-only and AnyDesk's postinst needs systemd (container artifact), so both were out of scope for the container.
- Added `arm64` guards to `install_spotify` and `install_virtualbox` (both `amd64`-only); corrected the AD claim in `README.md`.
- Resolved pending decisions: ADR-007 (security defaults stay `1`, documented and switchable) and ADR-008 (AD/domain integration deferred).
