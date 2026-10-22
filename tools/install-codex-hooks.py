#!/usr/bin/python3
"""Install metadata-only Codex lifecycle hooks without changing notify, trust or provider settings."""
import argparse
import datetime
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

spec = importlib.util.spec_from_file_location("fishtank_installer", Path(__file__).with_name("install-claude-hooks.py"))
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hooks", type=Path, default=Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "hooks.json")
    parser.add_argument("--app", type=Path, default=Path("/Applications/Fishtank.app"))
    parser.add_argument("--bridge", type=Path)
    parser.add_argument("--uninstall", action="store_true")
    args = parser.parse_args()
    target = args.hooks.expanduser().resolve()
    script = Path.home() / "Library/Application Support/FishtankCodexHook/codex-hook.py"
    executable = args.app.expanduser().resolve() / "Contents/MacOS/FishtankMac"
    if args.bridge:
        bridge = args.bridge.expanduser().resolve()
        if not bridge.is_file(): parser.error("接入配置不存在")
        connection = ["--bridge", str(bridge)]
    else:
        connection = ["--app", str(executable)]
        if not args.uninstall:
            result = subprocess.run([str(executable), "--export-agent-bridge"], capture_output=True, timeout=2)
            config = json.loads(result.stdout) if result.returncode == 0 else {}
            if not isinstance(config.get("url"), str) or not isinstance(config.get("token"), str):
                parser.error("请先启动新版 Fishtank")
    original = target.read_bytes() if target.exists() else None
    settings = json.loads(original) if original else {}
    if not isinstance(settings, dict): parser.error("hooks.json 必须为对象，未修改配置")
    command = shlex.join([sys.executable, str(script), "--source", "codex"] + connection)
    merged = shared.merge(settings, script, command, remove=args.uninstall, events=shared.hook.CODEX_EVENTS)
    output = (json.dumps(merged, ensure_ascii=False, indent=2) + "\n").encode()
    if not args.uninstall: shared.atomic_write(script, Path(__file__).with_name("claude-hook.py").read_bytes())
    if original:
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        shared.atomic_write(target.with_name(target.name + ".fishtank-backup-" + stamp), original)
    shared.atomic_write(target, output)
    print("Fishtank Codex hooks 已移除，其他 hooks 已保留。" if args.uninstall else
          "Fishtank Codex hooks 已安装；请在 Codex /hooks 中审阅并信任新增的 Fishtank handler。未修改信任记录或 notify。")


if __name__ == "__main__":
    try: main()
    except Exception:
        print("安装未完成；请检查配置格式和文件权限。未输出私有配置。", file=sys.stderr)
        sys.exit(1)
