# Triibal

**Triibal is an open-source runtime for autonomous agent collectives.**

Triibal Genesis is the foundation release of the Triibal runtime. It ships a self-improving agent loop, skills, memory, tools, messaging gateway, cron scheduler, TUI, dashboard, ACP, MCP, and plugin architecture while setting the project direction around coordinated agent societies.

Genesis is the foundation release. The Lemma, Elder, Ritual, Lineage, Oracle, and simulation layers are the next phase.

## What Triibal Is

Triibal keeps the useful operational base:

- A terminal-first agent runtime with tool calling and long-running execution.
- Persistent memory, skill discovery, and self-improvement loops.
- Messaging gateways for platforms like Telegram, Discord, Slack, WhatsApp, Signal, and email.
- Cron scheduling for unattended work.
- A plugin system for tools, memory providers, model providers, dashboard surfaces, and integrations.
- TUI, dashboard, ACP, and MCP support.

Triibal changes the direction:

- From one assistant to coordinated agent collectives.
- From generic memory to domain-specific triibal knowledge.
- From single-agent autonomy to roles, lineage, rituals, and governance.
- From task automation to autonomous operational societies.

## Install From Source

```bash
git clone <your-triibal-repo-url> triibal
cd triibal
./setup-triibal.sh
./triibal
```

Manual development setup:

```bash
uv venv .venv --python 3.11
source .venv/bin/activate
uv pip install -e ".[all,dev]"
scripts/run_tests.sh tests/test_project_metadata.py
```

Windows users can install with the PowerShell installer:

```powershell
iex (irm https://raw.githubusercontent.com/Triibal/triibal/main/scripts/install.ps1)
```

## Commands

```bash
triibal              # Start the interactive CLI
triibal --tui        # Start the modern terminal UI
triibal dashboard    # Start the local web dashboard
triibal model        # Choose a model provider
triibal tools        # Configure enabled tools
triibal setup        # Run setup
triibal gateway      # Run messaging gateway
triibal doctor       # Diagnose local configuration
```

## Upstream Attribution

See [UPSTREAM.md](UPSTREAM.md) for attribution details. The original MIT license is preserved in [LICENSE](LICENSE).
