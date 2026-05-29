"""Resolve TRIIBAL_HOME for standalone skill scripts.

Skill scripts may run outside the Triibal process (e.g. system Python,
nix env, CI) where ``triibal_constants`` is not importable.  This module
provides the same ``get_triibal_home()`` and ``display_triibal_home()``
contracts as ``triibal_constants`` without requiring it on ``sys.path``.

When ``triibal_constants`` IS available it is used directly so that any
future enhancements (profile resolution, Docker detection, etc.) are
picked up automatically.  The fallback path replicates the core logic
from ``triibal_constants.py`` using only the stdlib.

All scripts under ``google-workspace/scripts/`` should import from here
instead of duplicating the ``TRIIBAL_HOME = Path(os.getenv(...))`` pattern.
"""

from __future__ import annotations

import os
from pathlib import Path

try:
    from triibal_constants import display_triibal_home as display_triibal_home
    from triibal_constants import get_triibal_home as get_triibal_home
except (ModuleNotFoundError, ImportError):

    def get_triibal_home() -> Path:
        """Return the Triibal home directory (default: ~/.triibal).

        Mirrors ``triibal_constants.get_triibal_home()``."""
        val = os.environ.get("TRIIBAL_HOME", "").strip()
        return Path(val) if val else Path.home() / ".triibal"

    def display_triibal_home() -> str:
        """Return a user-friendly ``~/``-shortened display string.

        Mirrors ``triibal_constants.display_triibal_home()``."""
        home = get_triibal_home()
        try:
            return "~/" + str(home.relative_to(Path.home()))
        except ValueError:
            return str(home)
