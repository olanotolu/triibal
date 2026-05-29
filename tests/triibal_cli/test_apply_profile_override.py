"""Regression tests for _apply_profile_override TRIIBAL_HOME guard (issue #22502).

When TRIIBAL_HOME is set to the triibal root (e.g. systemd hardcodes
TRIIBAL_HOME=/root/.triibal), _apply_profile_override must still read
active_profile and update TRIIBAL_HOME to the profile directory.

When TRIIBAL_HOME is already a profile directory (.../profiles/<name>),
_apply_profile_override must trust it and return without re-reading
active_profile (child-process inheritance contract).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest


def _run_apply_profile_override(
    tmp_path, monkeypatch, *, triibal_home: str | None, active_profile: str | None,
    argv: list[str] | None = None,
):
    """Run _apply_profile_override in isolation.

    Returns the value of os.environ["TRIIBAL_HOME"] after the call,
    or None if unset.
    """
    triibal_root = tmp_path / ".triibal"
    triibal_root.mkdir(parents=True, exist_ok=True)

    if active_profile is not None:
        (triibal_root / "active_profile").write_text(active_profile)

    if active_profile and active_profile != "default":
        (triibal_root / "profiles" / active_profile).mkdir(parents=True, exist_ok=True)

    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    if triibal_home is not None:
        monkeypatch.setenv("TRIIBAL_HOME", triibal_home)
    else:
        monkeypatch.delenv("TRIIBAL_HOME", raising=False)

    monkeypatch.setattr(sys, "argv", argv or ["triibal", "gateway", "start"])

    from triibal_cli.main import _apply_profile_override
    _apply_profile_override()

    return os.environ.get("TRIIBAL_HOME")


class TestApplyProfileOverrideTriibalHomeGuard:
    """Regression guard for issue #22502.

    Verifies that TRIIBAL_HOME pointing to the triibal root does NOT suppress
    the active_profile check, while TRIIBAL_HOME already pointing to a
    profile directory IS trusted as-is.
    """

    def test_triibal_home_at_root_with_active_profile_is_redirected(
        self, tmp_path, monkeypatch
    ):
        """TRIIBAL_HOME=/root/.triibal + active_profile=coder must redirect
        TRIIBAL_HOME to .../profiles/coder.

        Bug scenario from #22502: systemd sets TRIIBAL_HOME to the triibal root
        and the user switches to a profile via `triibal profile use`.
        Before the fix, the guard returned early and active_profile was ignored.
        """
        triibal_root = tmp_path / ".triibal"
        triibal_root.mkdir(parents=True, exist_ok=True)

        result = _run_apply_profile_override(
            tmp_path,
            monkeypatch,
            triibal_home=str(triibal_root),
            active_profile="coder",
        )

        assert result is not None, "TRIIBAL_HOME must be set after profile redirect"
        assert "profiles" in result, (
            f"Expected TRIIBAL_HOME to point into profiles/ dir, got: {result!r}"
        )
        assert result.endswith("coder"), (
            f"Expected TRIIBAL_HOME to end with 'coder', got: {result!r}"
        )

    def test_triibal_home_already_profile_dir_is_trusted(self, tmp_path, monkeypatch):
        """TRIIBAL_HOME=.../profiles/coder must not be overridden even when
        active_profile says something different.

        Preserves the child-process inheritance contract: a subprocess spawned
        with TRIIBAL_HOME already set to a specific profile must stay in that
        profile.
        """
        triibal_root = tmp_path / ".triibal"
        profile_dir = triibal_root / "profiles" / "coder"
        profile_dir.mkdir(parents=True, exist_ok=True)

        (triibal_root / "active_profile").write_text("other")

        monkeypatch.setattr(Path, "home", lambda: tmp_path)
        monkeypatch.setenv("TRIIBAL_HOME", str(profile_dir))
        monkeypatch.setattr(sys, "argv", ["triibal", "gateway", "start"])

        from triibal_cli.main import _apply_profile_override
        _apply_profile_override()

        assert os.environ.get("TRIIBAL_HOME") == str(profile_dir), (
            "TRIIBAL_HOME must remain unchanged when already pointing to a profile dir"
        )

    def test_triibal_home_unset_reads_active_profile(self, tmp_path, monkeypatch):
        """Classic case: TRIIBAL_HOME unset + active_profile=coder must set
        TRIIBAL_HOME to the profile directory (existing behaviour must not regress).
        """
        result = _run_apply_profile_override(
            tmp_path,
            monkeypatch,
            triibal_home=None,
            active_profile="coder",
        )

        assert result is not None
        assert "coder" in result

    def test_triibal_home_unset_default_profile_no_redirect(self, tmp_path, monkeypatch):
        """active_profile=default must not redirect TRIIBAL_HOME."""
        triibal_root = tmp_path / ".triibal"
        triibal_root.mkdir(parents=True, exist_ok=True)

        monkeypatch.setattr(Path, "home", lambda: tmp_path)
        monkeypatch.delenv("TRIIBAL_HOME", raising=False)
        monkeypatch.setattr(sys, "argv", ["triibal", "gateway", "start"])
        (triibal_root / "active_profile").write_text("default")

        from triibal_cli.main import _apply_profile_override
        _apply_profile_override()

        assert os.environ.get("TRIIBAL_HOME") is None
