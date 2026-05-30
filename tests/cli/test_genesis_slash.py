from types import SimpleNamespace
from unittest.mock import MagicMock


def _make_cli_stub():
    from cli import TribalCLI

    cli = TribalCLI.__new__(TribalCLI)
    cli._sudo_state = None
    cli._secret_state = None
    cli._approval_state = None
    cli._clarify_state = None
    cli._clarify_freetext = False
    cli._command_running = False
    cli._agent_running = False
    cli._voice_recording = False
    cli._voice_processing = False
    cli._voice_mode = False
    cli._command_spinner_frame = lambda: "⟳"
    cli._pending_input = SimpleNamespace(put=MagicMock())
    cli._console_lines = []
    cli._console_print = lambda text: cli._console_lines.append(str(text))
    return cli


def test_slash_genesis_calls_shared_engine(monkeypatch):
    from cli import TribalCLI

    cli = _make_cli_stub()
    calls = []

    def fake_run_genesis(**kwargs):
        calls.append(kwargs)
        return SimpleNamespace(status="born")

    monkeypatch.setattr("tribal_cli.genesis.run_genesis", fake_run_genesis)
    monkeypatch.setattr("tribal_cli.genesis.render_genesis", lambda result: "GENESIS OK")

    assert TribalCLI.process_command(cli, "/genesis --domain hospitality.nyc.fnb") is True
    assert calls == [{
        "domain": "hospitality.nyc.fnb",
        "mode": "slash",
        "rebirth": False,
        "confirm": None,
    }]
    assert cli._console_lines == ["GENESIS OK"]


def test_slash_genesis_rebirth_without_confirmation_reports_refusal(monkeypatch):
    from cli import TribalCLI
    from tribal_cli.genesis import GenesisConfirmationError

    cli = _make_cli_stub()

    def fake_run_genesis(**kwargs):
        raise GenesisConfirmationError("Type REBIRTH local to continue.")

    monkeypatch.setattr("tribal_cli.genesis.run_genesis", fake_run_genesis)

    assert TribalCLI.process_command(cli, "/genesis --rebirth") is True
    assert "REBIRTH local" in cli._console_lines[0]
