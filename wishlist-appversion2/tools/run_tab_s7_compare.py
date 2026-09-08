#!/usr/bin/env python3
"""Tab S7 live compare — one mall at a time with ADB reset and cooldown."""
from __future__ import annotations

import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ADB = r"C:\Users\tingo\AppData\Local\Android\sdk\platform-tools\adb.exe"
DEVICE = "R54RB01SMVB"  # Tab S7 only; emulator may stay connected for other projects
FLUTTER = r"C:\Dev\0.sdk\flutter\bin\flutter.bat"
# 2026-09-07: 오늘 만든 수정은 전부 _worktree_mall_audit(브랜치 fix/mall-accuracy-audit)에만
# 있고 다른 경로(예: 예전 C:\Users\tingo\Dev\...)에는 없다 -- 반드시 이 worktree 경로를
# 가리켜야 방금 만든 수정이 실제로 테스트된다. 실행 전 이 경로가 최신인지 다시 확인할 것.
APP_DIR = Path(r"C:\0.My_Project\00.DEV_PROJECT\5.SOFT_SPARK\2026-softstudio-project\_worktree_mall_audit\wishlist-appversion2\flutter_app")
LOG_DIR = Path(r"C:\0.My_Project\00.DEV_PROJECT\5.SOFT_SPARK\2026-softstudio-project\_worktree_mall_audit\wishlist-appversion2\audit-logs")

# 2026-09-07: 규칙 지정 트랙(mall-fix-plan-2026-09-07.md 3차 갱신) 12개 몰 중
# 카탈로그가 있는 12개.
# 순서: A-1(오늘 코드 건드린 몰, 최우선) -> A-2(회귀 재검증, 순위 합산 순).
MALLS = [
    "무신사",
    "지그재그",
    "에이블리",
    "퀸잇",
    "29CM",
    "KREAM",
    "유니클로",
    "W컨셉",
    "4910",
    "나이키",
    "SSF샵",
    "포스티",
]

COOLDOWN_SEC = 12
EXTRACT_TIMEOUT_SEC = 900


def log(msg: str, log_path: Path) -> None:
    line = f"[{datetime.now():%H:%M:%S}] {msg}"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
    try:
        print(line, flush=True)
    except UnicodeEncodeError:
        print(line.encode("cp949", errors="replace").decode("cp949"), flush=True)


def adb(*args: str) -> None:
    subprocess.run([ADB, "-s", DEVICE, *args], capture_output=True)


def prep_device() -> None:
    # kill-server는 Tab을 offline으로 만드는 경우가 있어 생략. force-stop만.
    subprocess.run([ADB, "-s", DEVICE, "wait-for-device"], capture_output=True, timeout=60)
    adb("shell", "settings", "put", "global", "stay_on_while_plugged_in", "7")
    adb("shell", "input", "keyevent", "82")
    adb("shell", "am", "force-stop", "com.softstudio.wishlist")
    time.sleep(2)


def run_mall(mall: str, log_path: Path) -> tuple[int, bool]:
    """Returns (exit_code, got_live_compare)."""
    prep_device()
    out_file = LOG_DIR / f"compare-{mall}-{datetime.now():%H%M%S}.txt"
    cmd = [
        FLUTTER,
        "test",
        "integration_test/live_field_compare_test.dart",
        "-d",
        DEVICE,
        "--no-uninstall",
        f"--dart-define=LIVE_COMPARE_MALLS={mall}",
    ]
    log(f"RUN {mall}", log_path)
    try:
        with out_file.open("w", encoding="utf-8") as out:
            proc = subprocess.run(
                cmd,
                cwd=str(APP_DIR),
                stdout=out,
                stderr=subprocess.STDOUT,
                timeout=EXTRACT_TIMEOUT_SEC,
            )
    except subprocess.TimeoutExpired:
        log(f"TIMEOUT {mall} (>{EXTRACT_TIMEOUT_SEC}s)", log_path)
        return -1, False

    text = out_file.read_text(encoding="utf-8", errors="replace")
    has_probe = "LIVE_COMPARE_JS_PROBE" in text
    has_result = "LIVE_COMPARE_RESULT" in text
    for line in text.splitlines():
        if "LIVE_COMPARE_" in line:
            log(line.strip(), log_path)
    log(f"EXIT {proc.returncode} {mall} probe={has_probe} results={has_result}", log_path)
    ok = proc.returncode == 0 and has_result
    return proc.returncode, ok


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOG_DIR / f"compare-batch-{datetime.now():%Y-%m-%d-%H%M}.log"
    log(f"START {len(MALLS)} malls device={DEVICE} cooldown={COOLDOWN_SEC}s", log_path)

    failed = []
    for i, mall in enumerate(MALLS):
        code, ok = run_mall(mall, log_path)
        if not ok:
            failed.append(mall)
        if i < len(MALLS) - 1:
            log(f"COOLDOWN {COOLDOWN_SEC}s before next mall", log_path)
            time.sleep(COOLDOWN_SEC)

    log(f"DONE failed={failed}", log_path)
    return len(failed)


if __name__ == "__main__":
    sys.exit(main())
