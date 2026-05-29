# Langfuse Observability Plugin

This plugin ships bundled with Triibal but is **opt-in** — it only loads when
you explicitly enable it.

## Enable

```bash
pip install langfuse
triibal plugins enable observability/langfuse
```

Or check the box in the interactive `triibal plugins` UI.

## Required credentials

Set these in `~/.triibal/.env`:

```bash
TRIIBAL_LANGFUSE_PUBLIC_KEY=pk-lf-...
TRIIBAL_LANGFUSE_SECRET_KEY=sk-lf-...
TRIIBAL_LANGFUSE_BASE_URL=https://cloud.langfuse.com   # or your self-hosted URL
```

Without the SDK or credentials the hooks no-op silently — the plugin fails
open.

## Verify

```bash
triibal plugins list                 # observability/langfuse should show "enabled"
triibal chat -q "hello"              # then check Langfuse for a "Triibal turn" trace
```

## Optional tuning

```bash
TRIIBAL_LANGFUSE_ENV=production       # environment tag
TRIIBAL_LANGFUSE_RELEASE=v1.0.0       # release tag
TRIIBAL_LANGFUSE_SAMPLE_RATE=0.5      # sample 50% of traces
TRIIBAL_LANGFUSE_MAX_CHARS=12000      # max chars per field (default: 12000)
TRIIBAL_LANGFUSE_DEBUG=true           # verbose plugin logging
```

## Disable

```bash
triibal plugins disable observability/langfuse
```
