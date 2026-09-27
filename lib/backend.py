#!/usr/bin/env python3
"""Private stdin/stdout bridge. Local translated-text history; no audio files."""
import array
import asyncio
import base64
import contextlib
import hashlib
from datetime import datetime
import json
import math
import os
from pathlib import Path
import signal
import stat
import sys
import tempfile
import time

IDLE_TIMEOUT_SECONDS = 10
SOURCE_POLL_SECONDS = 2

ENDPOINT = "wss://api.openai.com/v1/realtime/translations?model=gpt-realtime-translate"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "jimaku"
KEY_FILE = CONFIG / "openai-key"
SETTINGS_FILE = CONFIG / "settings.json"
HISTORY_FILE = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "jimaku" / "translations.txt"


def append_history(text):
    HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(HISTORY_FILE, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "a", encoding="utf-8") as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(text)


def read_preferences(path=None):
    try:
        value = json.loads((path or SETTINGS_FILE).read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def save_preference(name, value, path=None):
    path = path or SETTINGS_FILE
    data = read_preferences(path)
    data[name] = value
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".settings-")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


LANGUAGES = {
    "ja": "日本語", "en": "English", "zh": "中文", "ko": "한국어",
    "es": "Español", "pt": "Português", "fr": "Français", "de": "Deutsch",
    "it": "Italiano", "ru": "Русский", "hi": "हिन्दी", "id": "Bahasa Indonesia", "vi": "Tiếng Việt",
}


def system_language(env=None):
    env = os.environ if env is None else env
    primary = next((env[k] for k in ("LC_ALL", "LC_MESSAGES", "LANG") if env.get(k)), "C")
    candidates = [primary]
    if primary.split(".")[0] not in ("C", "POSIX") and env.get("LANGUAGE"):
        candidates = env["LANGUAGE"].split(":") + candidates
    for value in candidates:
        code = value.split(".")[0].split("@")[0].replace("-", "_").split("_")[0].lower()
        if code in LANGUAGES:
            return code, False
    return "en", True


def read_target(path=None):
    try:
        data = json.loads((path or SETTINGS_FILE).read_text())
        value = data.get("target_language", "auto") if isinstance(data, dict) else "auto"
        return value if isinstance(value, str) and (value == "auto" or value in LANGUAGES) else "auto"
    except (OSError, ValueError):
        return "auto"


def save_target(value, path=None):
    if value != "auto" and value not in LANGUAGES:
        raise ValueError("対応している翻訳先の言語を選んでください。")
    save_preference("target_language", value, path)

CHUNK = 4800  # 100 ms: mono, signed PCM16 little-endian, 24 kHz


def emit(kind, **fields):
    print(json.dumps({"type": kind, **fields}, ensure_ascii=False), flush=True)


def read_key(path=KEY_FILE):
    value = os.environ.get("OPENAI_API_KEY", "").strip()
    if value:
        return value
    if not path.exists():
        return ""
    if path.is_symlink() or stat.S_IMODE(path.stat().st_mode) & 0o077:
        raise ValueError("APIキーファイルの権限を600にしてください。")
    return path.read_text().strip()


def save_key(value, path=KEY_FILE):
    value = value.strip()
    if not value.startswith("sk-") or any(c.isspace() for c in value):
        raise ValueError("sk- で始まるOpenAI APIキーを入力してください。")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".key-")
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(value + "\n")
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


async def pactl(kind):
    proc = await asyncio.create_subprocess_exec(
        "pactl", "-f", "json", "list", kind,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        out, _ = await asyncio.wait_for(proc.communicate(), 3)
    except BaseException:
        proc.kill()
        await proc.wait()
        raise
    if proc.returncode:
        raise ValueError("音声サーバーに接続できません。Omarchyのセッション内で開いてください。")
    return json.loads(out)


def stream_rows(inputs, sinks):
    monitors = {str(s["index"]): s["monitor_source"] for s in sinks}
    rows = []
    for stream in inputs:
        p = stream.get("properties", {})
        monitor = monitors.get(str(stream.get("sink")))
        if monitor is None:
            continue
        name = p.get("application.name", "再生アプリ")
        media = p.get("media.name", "音声")
        rows.append({"id": str(stream["index"]), "label": f"{name} — {media}",
                     "monitor": str(monitor), "sink": str(stream["sink"]),
                     "app": name,
                     "active": not stream.get("corked", False) and not stream.get("mute", False)
                         and (not stream.get("volume") or any(v.get("value", 0) > 0 for v in stream["volume"].values())),
                     "fingerprint": [str(stream.get("client", "")), str(p.get("application.process.id", "")), name],
                     "browser": any(x in name.lower() for x in ("chrome", "chromium", "brave", "firefox"))})
    return sorted(rows, key=lambda row: (not row["browser"], row["label"]))


async def sources():
    inputs, sinks = await asyncio.gather(pactl("sink-inputs"), pactl("sinks"))
    return stream_rows(inputs, sinks)


def capture_command(row):
    # Never fall back to the microphone or an entire sink.
    return ["parec", "--raw", "--format=s16le", "--rate=24000", "--channels=1",
            "--latency-msec=100", "--client-name=Jimaku",
            "--device=" + row["monitor"], "--monitor-stream=" + row["id"]]


def level(data):
    samples = array.array("h", data)
    if sys.byteorder != "little":
        samples.byteswap()
    return math.sqrt(sum(v*v for v in samples) / max(1, len(samples))) / 32768


class Bridge:
    def __init__(self, send=emit, connector=None, capture=None, source_fn=sources):
        self.emit = send
        self.connector = connector
        self.capture = capture
        self.source_fn = source_fn
        self.task = None
        self.stop_event = asyncio.Event()
        self.last_text = 0.0
        self.history_header = ""
        self.target_preference = read_target()
        self.display_mode = read_preferences().get("display_mode", "realtime")
        if self.display_mode not in ("readable", "realtime"):
            self.display_mode = "realtime"

    def target_language(self):
        return system_language()[0] if self.target_preference == "auto" else self.target_preference

    def settings(self):
        system, fallback = system_language()
        self.emit("settings", key_ready=bool(read_key()), key_path=str(KEY_FILE),
                  target_preference=self.target_preference, target_language=self.target_language(),
                  ui_language="ja" if system == "ja" else "en", display_mode=self.display_mode,
                  system_language=system, system_fallback=fallback,
                  languages=[{"code": code, "label": label} for code, label in LANGUAGES.items()])

    async def stop(self):
        self.stop_event.set()
        if self.task:
            try:
                await asyncio.wait_for(asyncio.shield(self.task), 7)
            except asyncio.TimeoutError:
                self.task.cancel()
                with contextlib.suppress(asyncio.CancelledError):
                    await self.task
            self.task = None

    async def command(self, cmd):
        action = cmd.get("action")
        try:
            if action == "sources":
                self.emit("sources", items=await self.source_fn())
            elif action == "settings":
                self.settings()
            elif action == "prepare_history":
                append_history("")
                self.emit("history_file", url=HISTORY_FILE.resolve().as_uri())
            elif action == "set_display_mode":
                value = cmd.get("mode")
                if value not in ("readable", "realtime"):
                    raise ValueError("表示速度を選んでください。")
                save_preference("display_mode", value)
                self.display_mode = value
                self.settings()
            elif action == "set_target":
                if self.task and not self.task.done():
                    raise ValueError("翻訳を停止してから言語を変更してください。")
                value = str(cmd.get("language", ""))
                save_target(value)
                self.target_preference = value
                self.settings()
            elif action == "save_key":
                save_key(str(cmd.get("key", "")))
                self.settings()
                self.emit("notice", message="APIキーをこのPCに保存しました。")
            elif action in ("start", "demo"):
                if self.task and not self.task.done():
                    return
                if action == "start":
                    key = read_key()
                    if not key:
                        raise ValueError("設定からOpenAI APIキーを保存してください。")
                    row = next((r for r in await self.source_fn() if r["id"] == str(cmd.get("source"))), None)
                    if not row or not row.get("active", True):
                        raise ValueError("再生音声が見つかりません。動画を再生してください。")
                self.stop_event = asyncio.Event()
                self.emit("reset")
                self.task = asyncio.create_task(self.demo() if action == "demo" else self.session(row, key, self.target_language()))
            elif action == "stop":
                await self.stop()
            elif action == "quit":
                await self.stop()
                return False
        except (ValueError, OSError, asyncio.TimeoutError) as e:
            self.emit("error", operation=action, message=str(e) or "操作がタイムアウトしました。")
        return True

    async def demo(self):
        self.emit("status", state="demo", message="デモ · 録音・API通信なし")
        try:
            samples = [
                ("This is a sample caption, not a transcript of the X video. ", "これは表示テスト用のサンプルです。X動画の翻訳ではありません。\n\n"),
                ("The original audio keeps playing while Japanese captions appear here. ", "元の英語音声を聞きながら、このウィンドウで日本語字幕を読めます。\n\n"),
                ("Captions switch at sentence boundaries without scrolling. ", "文の区切りで次の字幕に切り替わります。スクロールは必要ありません。")]
            for en, ja in samples:
                for lane, text in (("source", en), ("translation", ja)):
                    for i in range(0, len(text), 4):
                        if self.stop_event.is_set():
                            return
                        self.emit("delta", lane=lane, text=text[i:i+4])
                        await asyncio.sleep(0.06)
        finally:
            self.emit("status", state="idle", message="デモ終了 · API通信なし")

    def transcript(self, event):
        lane = {"session.input_transcript.delta": "source",
                "session.output_transcript.delta": "translation"}.get(event.get("type"))
        if lane and isinstance(event.get("delta"), str):
            self.last_text = time.monotonic()
            if lane == "translation" and event["delta"]:
                try:
                    append_history(self.history_header + event["delta"])
                    self.history_header = ""
                except OSError:
                    raise ValueError("翻訳履歴を保存できません。空き容量と保存先の権限を確認してください。") from None
            self.emit("delta", lane=lane, text=event["delta"])

    async def session(self, row, key, language=None):
        language = language or self.target_language()
        self.history_header = "\n\n--- " + datetime.now().astimezone().isoformat(timespec="seconds") + " → " + language + " ---\n"
        proc = None
        children = []
        try:
            from websockets.asyncio.client import connect
            connector = self.connector or connect
            self.emit("status", state="connecting", message="OpenAIに接続中…")
            async with connector(ENDPOINT, additional_headers={
                    "Authorization": "Bearer " + key,
                    "OpenAI-Safety-Identifier": hashlib.sha256((str(Path.home()) + "jimaku").encode()).hexdigest()},
                    open_timeout=10, close_timeout=2, max_size=4*1024*1024, max_queue=16) as ws:
                created = json.loads(await asyncio.wait_for(ws.recv(), 10))
                if created.get("type") != "session.created":
                    raise ValueError("翻訳セッションを開始できませんでした。APIの利用権限を確認してください。")
                if self.stop_event.is_set():
                    await ws.send(json.dumps({"type": "session.close"}))
                    await self.drain(ws)
                    return
                await ws.send(json.dumps({"type": "session.update", "session": {"audio": {"output": {"language": language}}}}))
                # Do not stream anything until the target-language update is accepted.
                async with asyncio.timeout(10):
                    while True:
                        event = json.loads(await ws.recv())
                        if event.get("type") == "error":
                            raise ValueError("選択した言語への翻訳設定が拒否されました。APIの対応状況を確認してください。")
                        if event.get("type") == "session.updated":
                            break
                if self.stop_event.is_set():
                    await ws.send(json.dumps({"type": "session.close"}))
                    await self.drain(ws)
                    return
                factory = self.capture or asyncio.create_subprocess_exec
                proc = await factory(*capture_command(row), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
                self.emit("status", state="live", message="翻訳中 · " + row["label"])
                started = time.monotonic()
                self.last_text = started

                async def send_audio():
                    audible = time.monotonic()
                    while not self.stop_event.is_set():
                        try:
                            data = await asyncio.wait_for(proc.stdout.readexactly(CHUNK), 5)
                        except (asyncio.IncompleteReadError, asyncio.TimeoutError):
                            raise ValueError("再生音声の取り込みが止まりました。動画を再生してもう一度開始してください。")
                        rms = level(data)
                        if rms > 0.002:
                            audible = time.monotonic()
                        if time.monotonic() - audible >= IDLE_TIMEOUT_SECONDS:
                            raise ValueError("10秒間ほぼ無音だったため、自動停止しました。")
                        if self.stop_event.is_set():
                            break
                        await asyncio.wait_for(ws.send(json.dumps({"type": "session.input_audio_buffer.append", "audio": base64.b64encode(data).decode()})), 3)
                        self.emit("meter", level=min(1, rms * 8), seconds=int(time.monotonic() - started), delayed=time.monotonic()-self.last_text > 20)

                async def receive():
                    async for raw in ws:
                        event = json.loads(raw)
                        if event.get("type") == "error":
                            code = str(event.get("error", {}).get("code", "unknown"))[:80]
                            raise ValueError("翻訳APIエラー: " + code)
                        if event.get("type") == "session.closed":
                            return
                        self.transcript(event)
                    raise ValueError("接続が切れました。開始ボタンで再接続してください。")

                async def watch_source():
                    last_active = started
                    while True:
                        await asyncio.sleep(SOURCE_POLL_SECONDS)
                        now = next((r for r in await self.source_fn() if r["id"] == row["id"]), None)
                        if not now or (now["fingerprint"], now["sink"]) != (row["fingerprint"], row["sink"]):
                            raise ValueError("選択した再生音声が終了・変更されました。一覧を更新してください。")
                        if now.get("active", True):
                            last_active = time.monotonic()
                        elif time.monotonic() - last_active >= IDLE_TIMEOUT_SECONDS:
                            raise ValueError("10秒間再生が停止・ミュートされていたため、自動停止しました。")
                        if time.monotonic() - started > 3600:
                            raise ValueError("1時間の上限で停止しました。続ける場合は再開してください。")

                children = [asyncio.create_task(send_audio()), asyncio.create_task(receive()),
                            asyncio.create_task(watch_source()), asyncio.create_task(self.stop_event.wait())]
                done, _ = await asyncio.wait(children, return_when=asyncio.FIRST_COMPLETED)
                failure = next((t.exception() for t in done if not t.cancelled() and t.exception()), None)
                for task in children:
                    task.cancel()
                await asyncio.gather(*children, return_exceptions=True)
                self.emit("status", state="stopping", message="残りの字幕を受信中…")
                if proc.returncode is None:
                    proc.terminate()
                    await proc.wait()
                with contextlib.suppress(Exception):
                    await ws.send(json.dumps({"type": "session.close"}))
                    await self.drain(ws)
                if failure:
                    raise failure
        except asyncio.CancelledError:
            raise
        except Exception as error:
            # Never print remote bodies, request headers, or the key.
            message = str(error) if isinstance(error, ValueError) else "接続できませんでした。通信・APIキー・残高・モデル利用権限を確認してください。"
            self.emit("error", message=message.replace(key, "[redacted]"))
        finally:
            for task in children:
                task.cancel()
            await asyncio.gather(*children, return_exceptions=True)
            if proc and proc.returncode is None:
                proc.terminate()
                try:
                    await asyncio.wait_for(proc.wait(), 2)
                except asyncio.TimeoutError:
                    proc.kill()
                    await proc.wait()
            self.emit("status", state="idle", message="停止中")

    async def drain(self, ws):
        async with asyncio.timeout(4):
            while True:
                event = json.loads(await ws.recv())
                self.transcript(event)
                if event.get("type") == "session.closed":
                    break


async def main():
    bridge = Bridge()
    loop = asyncio.get_running_loop()
    reader = asyncio.StreamReader(limit=16384)
    transport, _ = await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
    running = asyncio.current_task()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, running.cancel)
    emit("ready")
    try:
        while line := await reader.readline():
            try:
                command = json.loads(line)
                if not isinstance(command, dict):
                    continue
                if not await bridge.command(command):
                    break
            except json.JSONDecodeError:
                emit("error", message="コマンドを読み取れませんでした。")
    finally:
        await bridge.stop()
        transport.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (BrokenPipeError, asyncio.CancelledError):
        pass
