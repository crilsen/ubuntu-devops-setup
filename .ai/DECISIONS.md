# Architectural Decisions

## ADR-001 — Bounded learnings buffer with promotion

Status: Accepted

Context:
The template recorded state (`TASKS.md`, `HANDOFF.md`) and durable choices (`DECISIONS.md`), but had no mechanism for an agent to retain reusable, non-obvious learnings across sessions and tools.

Decision:
Introduce `.ai/LEARNINGS.md` as a bounded, append-only buffer with a fixed entry format, promotion rules, and compaction at 40 active entries. Durable learnings are promoted to `CONVENTIONS.md`, `DECISIONS.md`, `TOOLS.md`, or `VALIDATION.md` and the entry is marked `promoted`.

Reasoning:
Keeps the normative files clean and evidence-based while giving agents an explicit, portable place to capture what they learned, avoiding rediscovery and drift between tools.

Consequences:
- Learnings are portable and versioned with the repository.
- The buffer can grow and must be compacted; promotion directs durable rules to their permanent home.
- Agents must follow `.ai/workflows/capture-learning.md` rather than writing ad-hoc notes.

## ADR-002 — Agent-independent context with thin adapters

Status: Accepted

Context:
Work must continue across different agents, models, providers, and machines, including when one provider's usage limit is reached. Tool-specific files and chat history are not portable.

Decision:
Keep `AGENTS.md` and `.ai/` as the only source of truth. Any tool-specific file is a thin adapter that routes to `AGENTS.md` and contains no project facts; adapter paths are catalogued in `.ai/ADAPTERS.md`. Handoff state is carried by the Resume block in `.ai/HANDOFF.md` and the protocol in `.ai/workflows/switch-agent.md`, and must be committed and pushed or explicitly listed as uncommitted.

Reasoning:
The repository is the only medium every agent can read. Keeping adapters thin prevents drift, and centralizing handoff in version-controlled files makes agents interchangeable.

Consequences:
- Context survives agent, model, provider, and machine changes.
- Agents with lower context windows or tighter limits can resume because `AGENTS.md` stays small and `.ai/` is read on demand.
- Uncommitted work can be lost on a machine switch unless it is committed, pushed, or listed in `HANDOFF.md`.

## ADR-003 — Rolling checkpoints with usage-limit thresholds

Status: Accepted

Context:
Provider usage can be exhausted mid-task. The agent cannot always read the exact remaining quota, and losing work at the limit defeats the portability goals.

Decision:
Adopt a rolling checkpoint: the Resume block in `.ai/HANDOFF.md` is kept current after every meaningful step. Define usage thresholds in `.ai/LIMITS.md` (warn at 70%, stop starting new work and finalize at 85%). Use reported usage when the tool exposes it, plus a self-imposed work-volume proxy otherwise.

Reasoning:
A continuously current handoff makes any interruption resumable, and explicit thresholds turn an abrupt limit into a planned handoff.

Consequences:
- Interruptions and provider switches become routine rather than lossy.
- Agents must commit or list work in progress and must not claim an unobserved quota.
- Tool-specific watchers (statusline, hook, plugin) are optional and stay thin; the policy remains portable.

## ADR-004 — Modernize scripts toward Ubuntu 24.04 / 26.04 LTS and newest apps

Status: Accepted

Context:
The three scripts still target Ubuntu 20.04/22.04 and use patterns that are removed or deprecated there, notably `apt-key add` and the legacy `ms-teams` package, plus out-of-date tool URLs. The repository owner stated the intent to support the newest apps and Ubuntu 24.04 / 26.04 LTS and derivatives.

Decision:
Treat Ubuntu 24.04 / 26.04 LTS and derivatives as the primary targets and prefer the newest available app versions. Replace `apt-key`/`add-apt-repository` recipes with keyring-based `signed-by` apt sources, revisit packages that changed or disappeared on 24.04+ (`docker-compose` v1, `ms-teams`, `java-default`), and evaluate **Teams for Linux** as the Teams client.

Reasoning:
The current scripts cannot run cleanly on the stated targets because the removed/deprecated mechanisms fail, and the owner requires current app versions rather than the pinned ones.

Consequences:
- Scripts must be updated per target and validated on 24.04/26.04 before being considered complete.
- Architecture and package assumptions change; keep `ARCHITECTURE.md` in sync.
- Until updated, the scripts remain 20.04/22.04-era and should be treated as such.

## ADR-005 — Keep one script per target, sharing logic instead of copying

Status: Accepted

Context:
`ubuntu-system-prepare.sh`, `ubuntu-system-prepare-vm-dev.sh`, and `ubuntu-system-prepare-wsl-dev.sh` duplicated large blocks with small target-specific differences, so fixes had to be applied three times and drifted.

Decision:
Keep one entry-point script per target (physical, `vm-dev`, `wsl-dev`) so each environment stays independently runnable, and move shared installation steps into `ubuntu-system-prepare-common.sh`, sourced by each script.

Reasoning:
Preserves the existing per-target invocation while removing duplication, which was the main maintainability risk observed in the repository.

Consequences:
- Shared steps are edited once; entry scripts list only their target's calls.
- Each entry script stays runnable on its own, provided the common file ships next to it.
- Implemented in the 2026-09 modernization.

## ADR-006 — Drop retired and duplicate tooling from the install set

Status: Accepted

Context:
Several installs reference products or mechanisms that no longer exist or are superseded: consumer Skype was retired on 2025-05-05, `aws-iam-authenticator` is redundant with AWS CLI v2's `aws eks get-token`, the legacy `ms-teams` package is replaced by Teams for Linux, and the system-wide `pip3 install PyDrive` breaks under PEP 668 (externally managed environment) on 24.04+.

Decision:
Remove Skype, `aws-iam-authenticator`, the `ms-teams` apt repo, and the system `pip3 install PyDrive`. Install Teams for Linux via snap, keep `python3-pip`/`python3-venv`/`pipx` for Python tooling, and rely on `aws eks get-token`.

Reasoning:
These steps fail or are unnecessary on the target releases, and keeping them would break the run or install unsupported software.

Consequences:
- Google Drive automation previously implied by PyDrive must use a venv/pipx or a dedicated client; none is installed by default.
- `aws-iam-authenticator`, if still needed for an old workflow, must be installed separately.

Use this ADR format for durable, meaningful decisions:

```text
## ADR-NNN - Title

Status: Proposed | Accepted | Superseded | Deprecated

Context:
...

Decision:
...

Reasoning:
...

Consequences:
...
```

Do not backfill invented history. Record decisions that are observed, expressly documented, or approved during future work.
