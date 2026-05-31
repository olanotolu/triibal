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
    cli._command_spinner_frame = lambda: "o"
    cli._pending_input = SimpleNamespace(put=MagicMock())
    cli._console_lines = []
    cli._console_print = lambda text: cli._console_lines.append(str(text))
    cli.agent = SimpleNamespace(_dispatch_delegate_task=MagicMock(return_value='{"results": []}'))
    return cli


def test_slash_tribe_ask_calls_shared_engine(monkeypatch):
    from cli import TribalCLI

    cli = _make_cli_stub()
    calls = []

    def fake_handle(command, *, agent):
        calls.append((command, agent))
        return "TRIBE OK"

    monkeypatch.setattr("tribal_cli.tribe.handle_tribe_slash_command", fake_handle)

    assert TribalCLI.process_command(cli, "/tribe ask Should I take Thursday at 4?") is True
    assert calls == [("/tribe ask Should I take Thursday at 4?", cli.agent)]
    assert cli._console_lines == ["TRIBE OK"]


def test_slash_tribe_status_does_not_require_agent(monkeypatch):
    from cli import TribalCLI

    cli = _make_cli_stub()
    cli.agent = None

    monkeypatch.setattr("tribal_cli.tribe.handle_tribe_slash_command", lambda command, *, agent: "STATUS OK")

    assert TribalCLI.process_command(cli, "/tribe status") is True
    assert cli._console_lines == ["STATUS OK"]


def test_slash_tribe_ask_initializes_agent_with_real_init_path(monkeypatch):
    from cli import TribalCLI

    cli = _make_cli_stub()
    cli.agent = None
    init_calls = []

    cli._ensure_runtime_credentials = lambda: True
    cli._resolve_turn_agent_config = lambda _message: {
        "model": "deepseek-v4-pro",
        "runtime": {"provider": "deepseek"},
        "request_overrides": {"reasoning": "minimal"},
        "signature": ("deepseek-v4-pro", "deepseek"),
    }
    cli._active_agent_route_signature = None

    def fake_init_agent(**kwargs):
        init_calls.append(kwargs)
        cli.agent = SimpleNamespace(_dispatch_delegate_task=MagicMock(return_value='{"results": []}'))
        return True

    cli._init_agent = fake_init_agent
    monkeypatch.setattr("tribal_cli.tribe.handle_tribe_slash_command", lambda command, *, agent: "TRIBE OK")

    assert TribalCLI.process_command(cli, "/tribe ask Should I ship the demo?") is True
    assert init_calls == [{
        "model_override": "deepseek-v4-pro",
        "runtime_override": {"provider": "deepseek"},
        "request_overrides": {"reasoning": "minimal"},
    }]
    assert cli._console_lines == ["Initializing agent...", "TRIBE OK"]
