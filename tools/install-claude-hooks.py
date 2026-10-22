#!/usr/bin/python3
"""Merge only Fishtank's own handlers; preserve every other Claude setting and hook."""
import argparse
import datetime
import json
import os
import pathlib
import shlex
import sys
import subprocess
import tempfile

import importlib.util
spec = importlib.util.spec_from_file_location("fishtank_claude_hook", pathlib.Path(__file__).with_name("claude-hook.py"))
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".fishtank-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(data)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def merge(settings, script, command, remove=False, events=None):
    hooks = settings.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("hooks 必须是对象，未修改配置")
    for event in events if events is not None else hook.EVENTS:
        rows = hooks.get(event, [])
        if not isinstance(rows, list):
            raise ValueError("hook 结构无法安全合并，未修改配置")
        kept = []
        for row in rows:
            if not isinstance(row, dict) or not isinstance(row.get("hooks"), list):
                raise ValueError("hook 结构无法安全合并，未修改配置")
            handlers = []
            for handler in row["hooks"]:
                if not isinstance(handler, dict):
                    raise ValueError("hook 结构无法安全合并，未修改配置")
                try:
                    parts = shlex.split(handler.get("command", ""))
                except ValueError:
                    parts = []
                owned = handler.get("type") == "command" and len(parts) >= 2 and parts[1] == str(script)
                if not owned:
                    handlers.append(handler)
            if handlers:
                kept.append(dict(row, hooks=handlers))
        if not remove:
            kept.append({"hooks": [{"type": "command", "command": command, "timeout": 2}]})
        if kept:
            hooks[event] = kept
        else:
            hooks.pop(event, None)
    return settings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--settings", type=pathlib.Path, default=pathlib.Path.home() / ".claude/settings.json")
    parser.add_argument("--bridge", type=pathlib.Path)
    parser.add_argument("--app", type=pathlib.Path, default=pathlib.Path("/Applications/Fishtank.app"))
    parser.add_argument("--uninstall", action="store_true")
    args = parser.parse_args()
    settings_path = args.settings.expanduser().absolute()
    # Resolving a symlink keeps the user's config link intact.
    settings_path = settings_path.resolve()
    support = pathlib.Path.home() / "Library/Application Support"
    script = support / "FishtankClaudeHook/claude-hook.py"
    bridge = args.bridge
    if bridge:
        bridge = bridge.expanduser().resolve()
        if not bridge.is_file():
            parser.error("接入配置不存在，请先启动新版 Fishtank")
        connection_args = ["--bridge", str(bridge)]
    else:
        executable = args.app.expanduser().resolve() / "Contents/MacOS/FishtankMac"
        if not args.uninstall:
            result = subprocess.run([str(executable), "--export-claude-bridge"], capture_output=True, timeout=2)
            if result.returncode != 0:
                parser.error("请先启动新版 Fishtank；非默认安装位置可用 --app 指定")
            config = json.loads(result.stdout)
            if not isinstance(config.get("token"), str) or not isinstance(config.get("url"), str):
                parser.error("应用未提供有效接入配置")
        connection_args = ["--app", str(executable)]
    original = settings_path.read_bytes() if settings_path.exists() else None
    settings = json.loads(original) if original else {}
    if not isinstance(settings, dict):
        raise ValueError("Claude 配置必须是对象，未修改配置")
    command = shlex.join([sys.executable, str(script)] + connection_args)
    merged = merge(settings, script, command, args.uninstall)
    # Validate everything before changing existing configuration.
    output = (json.dumps(merged, ensure_ascii=False, indent=2) + "\n").encode()
    if not args.uninstall:
        atomic_write(script, pathlib.Path(__file__).with_name("claude-hook.py").read_bytes())
    if original:
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        backup = settings_path.with_name(settings_path.name + ".fishtank-backup-" + stamp)
        atomic_write(backup, original)
    atomic_write(settings_path, output)
    print("Fishtank hooks 已移除，其他配置已保留。" if args.uninstall else "Fishtank hooks 已安装，其他配置已保留。请重启 Claude Code 会话后生效。")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("安装未完成；请检查配置格式和文件权限。未输出私有配置。", file=sys.stderr)
        sys.exit(1)
