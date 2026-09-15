# Learnings

Append-only buffer of reusable, non-obvious learnings captured while working, so future sessions and tools do not rediscover them. This is not task state (`TASKS.md`), not a session handoff (`HANDOFF.md`), and not a durable decision record (`DECISIONS.md`).

## How to use

- Append one entry per learning. Do not rewrite or delete entries; to correct one, mark it `superseded` and add a new entry.
- Capture only learnings that are non-obvious and likely to recur. Skip anything already stated in `CONVENTIONS.md`, `DECISIONS.md`, `TOOLS.md`, or `VALIDATION.md`.
- Keep each entry short and evidence-based. Prefer `observed` facts over speculation.
- This file is a buffer, not a permanent home: promote durable learnings and keep the entry as a breadcrumb.

## Entry format

```text
### L-001 — <short title>
Date: YYYY-MM-DD
Status: active | superseded | promoted
Confidence: observed | inferred
Scope: repo | <path-or-glob> | <technology>
Context: <what was being done>
Evidence: <file:line, command output, or concrete observation>
Pattern / rule: <the reusable takeaway>
Promotion: none | CONVENTIONS.md | DECISIONS.md#ADR-nnn | TOOLS.md | VALIDATION.md
```

## Promotion rules

- Recurring pattern → `CONVENTIONS.md`
- Durable architectural choice → `DECISIONS.md` (ADR), cross-referenced here
- Safe or restricted command rule → `TOOLS.md`
- Completion or validation check → `VALIDATION.md`

After promotion, set the entry to `Status: promoted` and keep it as a breadcrumb; do not duplicate the rule body.

## Compaction

- Keep at most 40 active entries. When exceeded, consolidate related entries, promote what is durable, and mark the rest `superseded`.
- Compaction means summarizing and promoting, not erasing history. Record the compaction in `HANDOFF.md`.

## Entries

### L-001 — Workflows and prompts duplicate their content
Date: 2026-09-14
Status: active
Confidence: observed
Scope: .ai/workflows/**, .ai/prompts/**
Context: Auditing the template for maintainability.
Evidence: `.ai/prompts/review.md`, `.ai/prompts/security-review.md`, and `.ai/prompts/cloud-port.md` restate the same steps as the matching workflows.
Pattern / rule: Keep prompts as thin pointers to the workflow file; do not restate the procedure, or the two copies will diverge.
Promotion: none

### L-002 — Switching agents only survives if state is committed
Date: 2026-09-14
Status: active
Confidence: observed
Scope: repo | .ai/HANDOFF.md
Context: Designing handoff between agents and providers after a usage limit.
Evidence: An agent on the same checkout sees the working tree, but a different machine, cloud agent, or fresh clone sees only committed and pushed files.
Pattern / rule: Before switching agents, commit and push work in progress or list uncommitted files explicitly in `.ai/HANDOFF.md`; never rely on chat history.
Promotion: none

### L-003 — Remaining quota is usually not observable
Date: 2026-09-14
Status: active
Confidence: observed
Scope: repo | .ai/LIMITS.md
Context: Designing an automatic warning near provider usage limits.
Evidence: Providers meter usage differently and do not expose a uniform quota API; OpenCode Go documents usage only in the web console.
Pattern / rule: Combine reported usage when available with a work-volume proxy, and keep a continuously current Resume block; never state a remaining quota that was not observed.
Promotion: none

### L-004 — Physical script had a shell syntax error
Date: 2026-09-14
Status: promoted
Confidence: observed
Scope: ubuntu-system-prepare.sh
Context: Adopting the context layer and syntax-checking the scripts.
Evidence: `bash -n ubuntu-system-prepare.sh` reported `syntax error near unexpected token '('` at line 193, the stray sudoers example `your.userhere        ALL=(ALL) NOPASSWD:ALL`. Fixed in the modernization; `bash -n` now passes.
Pattern / rule: Run `bash -n` on every script after edits; a bare documentation line pasted without `#` breaks the whole script.
Promotion: VALIDATION.md

### L-005 — Scripts assumed pre-24.04 mechanisms
Date: 2026-09-14
Status: promoted
Confidence: observed
Scope: ubuntu-system-prepare*.sh
Context: Assessing 24.04/26.04 readiness.
Evidence: All scripts used `apt-key add` (removed in 24.04), installed `docker-compose` v1 and the legacy `ms-teams` package, and downloaded `amd64`-only binaries.
Pattern / rule: Modernization is not cosmetic: repos, keys, and several packages must change for 24.04/26.04, so a version bump alone will fail.
Promotion: DECISIONS.md#ADR-004, CONVENTIONS.md

### L-006 — Modern install recipes per tool (2026)
Date: 2026-09-14
Status: active
Confidence: observed
Scope: ubuntu-system-prepare-common.sh
Context: Modernizing the installers.
Evidence: Docker uses `/etc/apt/keyrings/docker.asc` + `signed-by` and `docker-compose-plugin`; kubectl uses `pkgs.k8s.io/core:/stable:/<vX.Y>/deb/`; Teams for Linux snap is `teams-for-linux`; Spotify key is `pubkey_5384CE82BA52C83A.asc`; Oracle VirtualBox has no `resolute` (26.04) repo yet; AWS CLI v2 URL is `awscli-exe-linux-<x86_64|aarch64>.zip`.
Pattern / rule: Prefer keyring `signed-by` sources and the official package for the target release; check per-codename availability instead of assuming every vendor repo carries the new LTS.
Promotion: none

### L-007 — Shellcheck flags the external os-release source; container smoke run passes
Date: 2026-09-15
Status: active
Confidence: observed
Scope: ubuntu-system-prepare-common.sh
Context: Completing the pending shellcheck + end-to-end validation from the Resume block.
Evidence: `koalaman/shellcheck:stable` reported only `SC1091` on `CODENAME="$(. /etc/os-release && ...)"`; adding `# shellcheck source=/dev/null` made all four scripts clean. `ubuntu-system-prepare-wsl-dev.sh` ran to exit 0 in `docker run --rm --privileged -v "$PWD:/work:ro" ubuntu:24.04` (arm64, `APT_UPGRADE=0`): the k8s `v1.36` repo resolves (`kubectl 1.36.4`), Docker CE 29.8.0 installs, and `has_systemd` correctly skips service tuning in the container.
Pattern / rule: Lint external `source` chains with an explicit `# shellcheck source=...` directive, and use a privileged `ubuntu:24.04` container with `APT_UPGRADE=0` as the disposable target for the non-GUI scripts.
Promotion: VALIDATION.md, TOOLS.md

### L-008 — Some vendors are amd64-only; container results can be artifacts
Date: 2026-09-15
Status: active
Confidence: observed
Scope: ubuntu-system-prepare-common.sh
Context: Function-level validation of the physical/`vm-dev` installers on `ubuntu:24.04` arm64.
Evidence: `spotify-client` is `amd64`-only (repo has no arm64 `Packages`) and `install_virtualbox` fetches an `arch=amd64` Oracle repo, both failing on arm64; guards were added. AnyDesk 8.0.4 arm64 downloads and installs but its dpkg postinst exits 1 without systemd, and `snap install` cannot talk to snapd in the container — both are environment artifacts, not script bugs. Chrome, VS Code, and Sublime installed fine on arm64.
Pattern / rule: Distinguish a real portability bug from a headless-container artifact before "fixing" it; guard genuinely `amd64`-only vendors (Spotify, VirtualBox) by `$ARCH`.
Promotion: none
