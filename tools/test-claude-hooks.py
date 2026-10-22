#!/usr/bin/python3
"""Isolated hook, installer, socket and offscreen UI integration checks."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
APP = None
if "--app" in sys.argv:
    index = sys.argv.index("--app")
    APP = Path(sys.argv[index + 1]).resolve()
    del sys.argv[index:index + 2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


hook = load("fishtank_hook", ROOT / "tools/claude-hook.py")
installer = load("fishtank_installer", ROOT / "tools/install-claude-hooks.py")


class HookTests(unittest.TestCase):
    def test_only_metadata_leaves_hook(self):
        raw = dict(hook_event_name="Stop", session_id="test", cwd="/private/project", prompt="PRIVATE",
                   last_assistant_message="PRIVATE", transcript_path="PRIVATE", tool_input={"secret": "PRIVATE"})
        event = hook.normalize(raw)
        self.assertEqual(set(event), {"id", "sessionID", "project", "event", "notificationType", "sentAt"})
        self.assertNotIn("PRIVATE", json.dumps(event))
        self.assertEqual(event["project"], "project")
        self.assertIsNone(hook.normalize(dict(hook_event_name="SubagentStop", session_id="test")))
        self.assertIsNone(hook.normalize(dict(hook_event_name="Notification", session_id="test", notification_type="auth_success")))

    def test_custom_agent_metadata_and_shared_states(self):
        for name in ["SessionStart", "NeedsInput", "Interrupt", "StopFailure"]:
            event = hook.normalize(dict(hook_event_name=name, session_id="local", cwd="/project", prompt="PRIVATE"), source="agent-local")
            self.assertEqual(event["source"], "agent-local")
            self.assertEqual(event["event"], name)
            self.assertNotIn("PRIVATE", json.dumps(event))

    def test_codex_metadata_and_supported_events(self):
        raw = dict(hook_event_name="UserPromptSubmit", session_id="same", cwd="/project", prompt="PRIVATE", turn_id="PRIVATE")
        event = hook.normalize(raw, source="codex")
        self.assertEqual(event["source"], "codex")
        self.assertNotIn("PRIVATE", json.dumps(event))
        raw["hook_event_name"] = "PreToolUse"
        raw["tool_name"] = "request_user_input"
        self.assertEqual(hook.normalize(raw, source="codex")["event"], "NeedsInput")
        raw["tool_name"] = "Bash"
        self.assertIsNone(hook.normalize(raw, source="codex"))
        raw["hook_event_name"] = "Notification"
        self.assertIsNone(hook.normalize(raw, source="codex"))
        raw["hook_event_name"] = "Interrupt"
        self.assertEqual(hook.normalize(raw, source="codex")["event"], "Interrupt")

    def test_codex_installer_preserves_hooks_config_and_trust(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            config_root = home / ".codex"
            config_root.mkdir()
            config = config_root / "config.toml"
            original_config = b'notify = ["existing-notifier"]\n[hooks.state.original]\ntrusted_hash = "existing"\n'
            config.write_bytes(original_config)
            hooks = config_root / "hooks.json"
            original = {"description": "existing", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo keep"}]}]}}
            hooks.write_text(json.dumps(original))
            bridge = home / "bridge.json"; bridge.write_text("{}")
            command = [sys.executable, str(ROOT / "tools/install-codex-hooks.py"), "--bridge", str(bridge)]
            env = dict(os.environ, HOME=str(home), CODEX_HOME=str(config_root))
            for _ in range(2): subprocess.run(command, env=env, capture_output=True, check=True)
            self.assertEqual(len(json.loads(hooks.read_text())["hooks"]["Stop"]), 2)
            self.assertEqual(config.read_bytes(), original_config)
            subprocess.run(command + ["--uninstall"], env=env, capture_output=True, check=True)
            self.assertEqual(json.loads(hooks.read_text()), original)
            self.assertEqual(config.read_bytes(), original_config)

    def test_merge_preserves_unrelated_handlers_and_is_idempotent(self):
        script = Path("/tmp/FishtankClaudeHook/claude-hook.py")
        original = {"env": {"example": "preserved"}, "hooks": {"Stop": [
            {"matcher": "*", "hooks": [{"type": "command", "command": "echo existing"}]}]}}
        first = installer.merge(json.loads(json.dumps(original)), script, "/usr/bin/python3 /tmp/FishtankClaudeHook/claude-hook.py --bridge /tmp/bridge")
        second = installer.merge(json.loads(json.dumps(first)), script, "/usr/bin/python3 /tmp/FishtankClaudeHook/claude-hook.py --bridge /tmp/bridge")
        self.assertEqual(first, second)
        restored = installer.merge(second, script, "", remove=True)
        self.assertEqual(restored, original)

    def test_install_backup_and_uninstall_in_temporary_home(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            settings = home / ".claude/settings.json"
            settings.parent.mkdir()
            original = b'{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep"}]}]}}'
            settings.write_bytes(original)
            bridge = home / "bridge.json"
            bridge.write_text("{}")
            command = [sys.executable, str(ROOT / "tools/install-claude-hooks.py"), "--settings", str(settings), "--bridge", str(bridge)]
            env = dict(os.environ, HOME=str(home))
            for _ in range(2):
                subprocess.run(command, env=env, check=True, capture_output=True)
            installed = json.loads(settings.read_text())
            self.assertEqual(len(installed["hooks"]["Stop"]), 2)
            backups = list(settings.parent.glob("settings.json.fishtank-backup-*"))
            self.assertTrue(any(p.read_bytes() == original for p in backups))
            self.assertEqual(settings.stat().st_mode & 0o777, 0o600)
            subprocess.run(command + ["--uninstall"], env=env, check=True, capture_output=True)
            self.assertEqual(json.loads(settings.read_text()), json.loads(original))

    def test_offline_and_malformed_hooks_never_block_or_print(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / "bridge.json"
            config.write_text(json.dumps(dict(url="http://127.0.0.1:1/claude", token="x" * 64)))
            for data in [b'invalid', json.dumps(dict(hook_event_name="Stop", session_id="test")).encode()]:
                result = subprocess.run([sys.executable, str(ROOT / "tools/claude-hook.py"), "--bridge", str(config)], input=data, capture_output=True, timeout=2)
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"", b""))

    @unittest.skipUnless(APP, "pass --app for live loopback and offscreen rendering")
    def test_live_bridge_and_hook(self):
        folder = ROOT / "build/claude-hook-validation"
        folder.mkdir(parents=True, exist_ok=True)
        config = folder / "bridge.json"
        config.unlink(missing_ok=True)
        (folder / "received.json").unlink(missing_ok=True)
        diagnostics = (folder / "validation-process.log").open("wb")
        process = subprocess.Popen([str(APP / "Contents/MacOS/FishtankMac"), "--validate-claude-hooks", str(folder)], stdout=subprocess.DEVNULL, stderr=diagnostics)
        try:
            for _ in range(100):
                if config.exists():
                    break
                if process.poll() is not None:
                    self.fail("validation process exited before listener was ready: %s" % process.returncode)
                time.sleep(0.1)
            self.assertTrue(config.exists(), "listener did not publish configuration")
            checks = (folder / "presenter-checks.txt").read_text()
            self.assertIn("waiting expiry", checks)
            self.assertIn("new-prompt preemption", checks)
            connection = json.loads(config.read_text())
            self.assertEqual(config.stat().st_mode & 0o777, 0o600)
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            unauthorized = urllib.request.Request(connection["url"], data=b"{}", method="POST")
            with self.assertRaises(urllib.error.HTTPError) as error:
                opener.open(unauthorized, timeout=2)
            self.assertEqual(error.exception.code, 401)
            def post(data):
                req = urllib.request.Request(connection["url"], data=json.dumps(data).encode(), headers={"Authorization": "Bearer " + connection["token"]}, method="POST")
                return opener.open(req, timeout=2)
            with self.assertRaises(urllib.error.HTTPError) as error:
                post({})
            self.assertEqual(error.exception.code, 422)
            sample = hook.normalize(dict(hook_event_name="Stop", session_id="stale", cwd="/project"))
            sample["sentAt"] -= 120
            with self.assertRaises(urllib.error.HTTPError) as error:
                post(sample)
            self.assertEqual(error.exception.code, 422)
            for event in ["UserPromptSubmit", "PermissionRequest", "PostToolUse", "Stop", "StopFailure", "SessionEnd"]:
                raw = dict(hook_event_name=event, session_id="validation", cwd="/projects/fishtank-apple", prompt="not transmitted")
                result = subprocess.run([sys.executable, str(ROOT / "tools/claude-hook.py"), "--bridge", str(config)], input=json.dumps(raw).encode(), capture_output=True, timeout=2)
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"", b""))
                # Let main-thread offscreen render complete before sending a newer state.
                for _ in range(40):
                    received = folder / "received.json"
                    if received.exists() and event in json.loads(received.read_text()):
                        break
                    time.sleep(0.05)
            received = json.loads((folder / "received.json").read_text())
            self.assertEqual(received, ["UserPromptSubmit", "PermissionRequest", "PostToolUse", "Stop", "StopFailure", "SessionEnd"])
            for _ in range(40):
                if (folder / "toast-claude-code-SessionEnd-960.png").exists():
                    break
                time.sleep(0.05)
            for width in [320, 640, 960]:
                self.assertTrue((folder / ("toast-claude-code-PermissionRequest-%s.png" % width)).is_file())
            for event_name in ["UserPromptSubmit", "PermissionRequest", "Interrupt", "SessionEnd"]:
                raw = dict(hook_event_name=event_name, session_id="validation", cwd="/projects/codex-check")
                result = subprocess.run([sys.executable, str(ROOT / "tools/claude-hook.py"), "--source", "codex", "--bridge", str(config)], input=json.dumps(raw).encode(), capture_output=True, timeout=2)
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"", b""))
            for _ in range(40):
                if len(json.loads((folder / "received.json").read_text())) == 10: break
                time.sleep(0.05)
            self.assertEqual(json.loads((folder / "received.json").read_text())[-4:], ["UserPromptSubmit", "PermissionRequest", "Interrupt", "SessionEnd"])
            for _ in range(40):
                if (folder / "toast-codex-SessionEnd-960.png").is_file(): break
                time.sleep(0.05)
            self.assertTrue((folder / "toast-codex-PermissionRequest-320.png").is_file())
        finally:
            process.terminate()
            process.wait(timeout=5)
            diagnostics.close()
            config.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
