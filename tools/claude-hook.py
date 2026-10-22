#!/usr/bin/python3
"""Fishtank metadata-only Claude Code hook. Always fail open, never print hook output."""
import json
import pathlib
import re
import sys
import subprocess
import time
import urllib.request
import uuid

EVENTS = ("SessionStart", "UserPromptSubmit", "PermissionRequest", "Notification", "Stop",
          "StopFailure", "SessionEnd", "PostToolUse", "PostToolUseFailure")
CODEX_EVENTS = ("SessionStart", "UserPromptSubmit", "PermissionRequest", "PreToolUse", "PostToolUse", "Stop", "Interrupt", "SessionEnd")
NOTIFICATIONS = ("permission_prompt", "idle_prompt", "elicitation_dialog",
                 "elicitation_url_dialog", "agent_needs_input")


def normalize(raw, source="claude-code"):
    event = raw.get("hook_event_name")
    session = raw.get("session_id")
    allowed = CODEX_EVENTS if source == "codex" else EVENTS if source == "claude-code" else EVENTS + ("NeedsInput", "Interrupt")
    if event not in allowed or not isinstance(session, str) or not session or len(session.encode()) > 256:
        return None
    if source == "codex" and event == "PreToolUse":
        if raw.get("tool_name") not in ("request_user_input", "functions.request_user_input"):
            return None
        event = "NeedsInput"
    kind = raw.get("notification_type")
    if event == "Notification" and kind not in NOTIFICATIONS:
        return None
    cwd = raw.get("cwd")
    project = pathlib.Path(cwd).name if isinstance(cwd, str) else "本地项目"
    project = "".join(c for c in project if c.isprintable())[:80] or "本地项目"
    # Explicit allowlist: no prompt, message, transcript path, response or tool input/output.
    payload = dict(id=str(uuid.uuid4()), sessionID=session, project=project, event=event,
                   notificationType=kind if event == "Notification" else None, sentAt=time.time())
    if source != "claude-code": payload["source"] = source
    return payload


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    try:
        arguments = sys.argv[1:]
        source = "claude-code"
        if len(arguments) >= 2 and arguments[0] == "--source":
            source = arguments[1]
            if not re.fullmatch(r"[a-z][a-z0-9-]{0,63}", source): return
            arguments = arguments[2:]
        if len(arguments) != 2 or arguments[0] not in ("--bridge", "--app"):
            return
        data = sys.stdin.buffer.read(1024 * 1024 + 1)
        if len(data) > 1024 * 1024:
            return
        payload = normalize(json.loads(data), source=source)
        if payload is None:
            return
        if arguments[0] == "--app":
            result = subprocess.run([arguments[1], "--export-agent-bridge" if source == "codex" else "--export-claude-bridge"], capture_output=True, timeout=0.7)
            if result.returncode != 0:
                return
            config = json.loads(result.stdout)
        else:
            config = json.loads(pathlib.Path(arguments[1]).read_text())
        url, token = config["url"], config["token"]
        if not re.fullmatch(r"http://127\.0\.0\.1:[0-9]{1,5}/claude", url) or not re.fullmatch(r"[A-Za-z0-9-]{32,128}", token):
            return
        request = urllib.request.Request(url, data=json.dumps(payload).encode(),
                    headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"}, method="POST")
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        with opener.open(request, timeout=0.35) as response:
            response.read(1)
    except Exception:
        pass  # Observational hooks must never interrupt agents or inject context.


if __name__ == "__main__":
    main()
