import asyncio
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
import backend as b

ROW = {"id": "42", "monitor": "8", "sink": "7", "fingerprint": ["1", "2", "Chrome"], "label": "Chrome"}


class SettingsTests(unittest.TestCase):
    def test_default_display_mode_is_realtime(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(b, "SETTINGS_FILE", Path(folder) / "settings.json"):
            self.assertEqual(b.Bridge().display_mode, "realtime")
            b.save_preference("display_mode", "invalid")
            self.assertEqual(b.Bridge().display_mode, "realtime")
            b.save_preference("display_mode", "readable")
            self.assertEqual(b.Bridge().display_mode, "readable")

    def test_locale_detection_and_precedence(self):
        for env, expected in [
            ({"LANG": "ja_JP.UTF-8"}, ("ja", False)),
            ({"LANG": "en_US.UTF-8", "LC_MESSAGES": "pt_BR.UTF-8"}, ("pt", False)),
            ({"LANG": "ja_JP.UTF-8", "LC_MESSAGES": "ko_KR", "LC_ALL": "fr_FR.UTF-8"}, ("fr", False)),
            ({"LANG": "en_US.UTF-8", "LANGUAGE": "zz:zh-Hant-TW:en"}, ("zh", False)),
            ({"LANG": "ja_JP.UTF-8", "LC_ALL": "C.UTF-8", "LANGUAGE": "ja"}, ("en", True)),
            ({"LANG": "ar_EG.UTF-8"}, ("en", True)),
            ({}, ("en", True)),
        ]:
            with self.subTest(env=env):
                self.assertEqual(b.system_language(env), expected)

    def test_language_preference_persists_and_recovers(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "settings.json"
            self.assertEqual(b.read_target(path), "auto")
            b.save_target("ko", path)
            self.assertEqual(b.read_target(path), "ko")
            with self.assertRaises(ValueError):
                b.save_target("invalid", path)
            self.assertEqual(b.read_target(path), "ko")
            b.save_target("auto", path)
            self.assertEqual(b.read_target(path), "auto")
            for bad in ['broken', '[]', '{"target_language": []}', '{"target_language": "xx"}']:
                path.write_text(bad)
                self.assertEqual(b.read_target(path), "auto")

    def test_secret_is_private_and_not_echoed(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(b.os.environ, {}, clear=True):
            path = Path(folder) / "settings" / "key"
            b.save_key("sk-test-only", path)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(b.read_key(path), "sk-test-only")
            path.chmod(0o644)
            with self.assertRaises(ValueError):
                b.read_key(path)

    def test_playback_state_filters_paused_muted_and_zero_volume(self):
        streams = [{"index": i, "sink": 7, "properties": {"application.name": "Chrome"}, **extra}
                   for i, extra in enumerate([{}, {"corked": True}, {"mute": True}, {"volume": {"mono": {"value": 0}}}])]
        rows = b.stream_rows(streams, [{"index": 7, "monitor_source": 8}])
        self.assertEqual([r["active"] for r in rows], [True, False, False, False])
        self.assertEqual(rows[0]["app"], "Chrome")

    def test_monitor_is_specific_and_no_microphone_fallback(self):
        rows = b.stream_rows([
            {"index": 42, "sink": 7, "properties": {"application.name": "Chrome"}},
            {"index": 9, "sink": 999, "properties": {"application.name": "unknown"}}
        ], [{"index": 7, "monitor_source": 8}])
        self.assertEqual(len(rows), 1)
        self.assertIn("--monitor-stream=42", b.capture_command(rows[0]))
        self.assertIn("--device=8", b.capture_command(rows[0]))
        self.assertEqual(b.level(bytes(4800)), 0)


class Socket:
    def __init__(self, accept=True):
        self.messages = []
        self.queue = asyncio.Queue()
        self.queue.put_nowait(json.dumps({"type": "session.created"}))
        self.accept = accept

    async def send(self, data):
        event = json.loads(data)
        self.messages.append(event)
        kind = event["type"]
        if kind == "session.update":
            self.queue.put_nowait(json.dumps({"type": "session.updated" if self.accept else "error"}))
        elif kind == "session.input_audio_buffer.append":
            self.queue.put_nowait(json.dumps({"type": "session.output_transcript.delta", "delta": "こんにちは"}))
        elif kind == "session.close":
            self.queue.put_nowait(json.dumps({"type": "session.output_transcript.delta", "delta": "最後の字幕"}))
            self.queue.put_nowait(json.dumps({"type": "session.closed"}))

    async def recv(self):
        return await self.queue.get()

    def __aiter__(self):
        return self

    async def __anext__(self):
        return await self.recv()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        pass


class Capture:
    def __init__(self):
        self.stdout = self
        self.returncode = None

    async def readexactly(self, count):
        await asyncio.sleep(0.01)
        return b"\x10\x01" * (count // 2)

    def terminate(self):
        self.returncode = 0

    async def wait(self):
        return self.returncode


class SessionTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        history_patch = patch.object(b, "HISTORY_FILE", Path(folder.name) / "history with spaces" / "translations.txt")
        history_patch.start()
        self.addCleanup(history_patch.stop)

    async def test_history_append_and_open_preserve_existing_text(self):
        await self.prepare()
        await self.bridge.command({"action": "prepare_history"})
        self.assertTrue(b.HISTORY_FILE.exists())
        self.assertEqual(self.events[-1]["url"], b.HISTORY_FILE.resolve().as_uri())
        self.assertIn("%20", self.events[-1]["url"])
        b.append_history("previous session")
        self.bridge.task = asyncio.create_task(self.bridge.session(ROW, "sk-test-only", "ja"))
        await asyncio.sleep(0.06)
        await self.bridge.stop()
        saved = b.HISTORY_FILE.read_text()
        full = "".join(e["text"] for e in self.events if e.get("lane") == "translation")
        self.assertTrue(saved.startswith("previous session"))
        self.assertTrue(saved.endswith(full))
        self.assertIn("→ ja", saved)
        self.assertNotIn("sk-test-only", saved)
        self.assertEqual(stat.S_IMODE(b.HISTORY_FILE.stat().st_mode), 0o600)
        await self.bridge.command({"action": "prepare_history"})
        self.assertEqual(b.HISTORY_FILE.read_text(), saved)

    async def prepare(self, accept=True):
        self.events = []
        self.socket = Socket(accept)
        self.capture_count = 0
        async def capture(*args, **kwargs):
            self.capture_count += 1
            self.proc = Capture()
            return self.proc
        async def source_fn():
            return [ROW]
        self.bridge = b.Bridge(lambda kind, **fields: self.events.append({"type": kind, **fields}),
                               lambda *a, **kw: self.socket, capture, source_fn)

    async def test_selected_language_reaches_session_and_survives_restart(self):
        await self.prepare()
        with tempfile.TemporaryDirectory() as folder, patch.object(b, "SETTINGS_FILE", Path(folder) / "settings.json"), patch.object(b, "read_key", return_value="sk-test-only"):
            await self.bridge.command({"action": "set_target", "language": "ko"})
            self.assertEqual(b.Bridge().target_language(), "ko")
            await self.bridge.command({"action": "start", "source": "42"})
            await asyncio.sleep(0.06)
            await self.bridge.command({"action": "set_target", "language": "fr"})
            self.assertEqual(b.read_target(), "ko")
            await self.bridge.stop()
            self.assertEqual(self.socket.messages[0]["session"]["audio"]["output"]["language"], "ko")
            await self.bridge.command({"action": "set_target", "language": "auto"})
            with patch.dict(b.os.environ, {"LANG": "ja_JP.UTF-8"}, clear=True):
                self.assertEqual(b.Bridge().target_language(), "ja")

    async def test_display_mode_persists_without_overwriting_language(self):
        await self.prepare()
        with tempfile.TemporaryDirectory() as folder, patch.object(b, "SETTINGS_FILE", Path(folder) / "settings.json"), patch.object(b, "read_key", return_value=""):
            await self.bridge.command({"action": "set_target", "language": "ko"})
            await self.bridge.command({"action": "set_display_mode", "mode": "realtime"})
            fresh = b.Bridge()
            self.assertEqual(fresh.display_mode, "realtime")
            self.assertEqual(fresh.target_language(), "ko")
            b.save_target("ja")
            self.assertEqual(b.Bridge().display_mode, "realtime")
            await self.bridge.command({"action": "set_display_mode", "mode": "bad"})
            self.assertEqual(b.Bridge().display_mode, "realtime")

    async def test_stop_flushes_last_caption_and_releases_capture(self):
        await self.prepare()
        self.bridge.task = asyncio.create_task(self.bridge.session(ROW, "sk-test-only"))
        await asyncio.sleep(0.06)
        await self.bridge.stop()
        self.assertTrue(any(e.get("text") == "最後の字幕" for e in self.events))
        self.assertEqual(self.proc.returncode, 0)
        kinds = [e["type"] for e in self.socket.messages]
        self.assertEqual(kinds[0], "session.update")
        self.assertEqual(kinds[-1], "session.close")
        self.assertTrue(any(e.get("text") == "こんにちは" for e in self.events))
        self.assertNotIn("sk-test-only", json.dumps(self.events))
        self.assertEqual(self.events[-1]["state"], "idle")

    async def test_silence_automatically_closes_session(self):
        await self.prepare()
        async def silent_read(capture, count):
            await asyncio.sleep(0.01)
            return bytes(count)
        with patch.object(b, "IDLE_TIMEOUT_SECONDS", 0.05), patch.object(Capture, "readexactly", silent_read):
            await asyncio.wait_for(self.bridge.session(ROW, "sk-test-only"), 1)
        self.assertTrue(any("ほぼ無音" in e.get("message", "") for e in self.events))
        self.assertEqual(self.proc.returncode, 0)
        self.assertEqual(self.socket.messages[-1]["type"], "session.close")
        self.assertEqual(self.events[-1]["state"], "idle")

    async def test_inactive_source_stops_even_with_capture_noise(self):
        await self.prepare()
        async def paused():
            return [{**ROW, "active": False}]
        self.bridge.source_fn = paused
        with patch.object(b, "IDLE_TIMEOUT_SECONDS", 0.06), patch.object(b, "SOURCE_POLL_SECONDS", 0.01):
            await asyncio.wait_for(self.bridge.session(ROW, "sk-test-only"), 1)
        self.assertTrue(any("停止・ミュート" in e.get("message", "") for e in self.events))
        self.assertEqual(self.proc.returncode, 0)
        self.assertEqual(self.socket.messages[-1]["type"], "session.close")

    async def test_short_pause_does_not_stop_resumed_audio(self):
        await self.prepare()
        polls = 0
        async def resumed():
            nonlocal polls
            polls += 1
            return [{**ROW, "active": polls > 2}]
        self.bridge.source_fn = resumed
        with patch.object(b, "IDLE_TIMEOUT_SECONDS", 0.08), patch.object(b, "SOURCE_POLL_SECONDS", 0.01):
            self.bridge.task = asyncio.create_task(self.bridge.session(ROW, "sk-test-only"))
            await asyncio.sleep(0.15)
            try:
                self.assertFalse(self.bridge.task.done())
                self.assertFalse(any(e["type"] == "error" for e in self.events))
            finally:
                await self.bridge.stop()

    async def test_rejected_language_never_captures_audio(self):
        await self.prepare(False)
        await self.bridge.session(ROW, "sk-test-only")
        self.assertEqual(self.capture_count, 0)
        self.assertTrue(any(e["type"] == "error" for e in self.events))

    async def test_disappearing_stream_stops_instead_of_switching(self):
        await self.prepare()
        async def vanished():
            return []
        self.bridge.source_fn = vanished
        await asyncio.wait_for(self.bridge.session(ROW, "sk-test-only"), 3)
        self.assertTrue(any("終了・変更" in e.get("message", "") for e in self.events))
        self.assertEqual(self.proc.returncode, 0)

    async def test_demo_never_connects_or_captures(self):
        await self.prepare()
        self.bridge.task = asyncio.create_task(self.bridge.demo())
        await asyncio.sleep(0.08)
        await self.bridge.stop()
        self.assertEqual(self.capture_count, 0)
        self.assertEqual(self.socket.messages, [])
        self.assertTrue(any(e["type"] == "delta" for e in self.events))
        self.assertFalse(b.HISTORY_FILE.exists())


if __name__ == "__main__":
    unittest.main()
