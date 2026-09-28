import asyncio
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
import backend as b


class DiscoveryTests(unittest.IsolatedAsyncioTestCase):
    async def run_producer(self, script):
        factory = asyncio.create_subprocess_exec
        self.children = []
        async def create(*args, **kwargs):
            self.assertEqual(kwargs["limit"], b.PACTL_PIPE_LIMIT)
            child = await factory(sys.executable, "-c", script, **kwargs)
            self.children.append(child)
            if hasattr(self, "created"):
                self.created.set()
            return child
        with patch.object(b.asyncio, "create_subprocess_exec", create):
            try:
                return await asyncio.wait_for(b.pactl("sink-inputs"), 5)
            finally:
                self.assertTrue(self.children)
                self.assertTrue(all(p.returncode is not None for p in self.children))

    async def test_small_json(self):
        self.assertEqual(await self.run_producer('print("[]")'), [])

    async def test_stdout_flood_is_killed_before_json_parsing(self):
        with patch.object(b.json, "loads") as parse:
            with self.assertRaisesRegex(ValueError, "大きすぎる"):
                await self.run_producer('import os\nwhile True: os.write(1, b"x" * 65536)')
            parse.assert_not_called()

    async def test_stderr_flood_is_killed(self):
        with self.assertRaisesRegex(ValueError, "大きすぎる"):
            await self.run_producer('import os\nwhile True: os.write(2, b"x" * 65536)')

    async def test_both_pipes_are_drained_concurrently(self):
        self.assertEqual(await self.run_producer('import os\nos.write(2, b"x" * 60000)\nprint("[]")'), [])

    async def test_row_limit_before_ui(self):
        with self.assertRaisesRegex(ValueError, "大きすぎる"):
            await self.run_producer(f'print("[" + ",".join(["{{}}"] * {b.SOURCE_ROW_LIMIT + 1}) + "]")')

    async def test_malformed_json_and_non_list_are_rejected(self):
        for value in ['broken', '{}', '[' * 2000]:
            with self.subTest(value=value[:10]), self.assertRaisesRegex(ValueError, "読み取れません"):
                await self.run_producer(f'print({value!r})')

    async def test_stalled_producer_is_killed_on_timeout(self):
        with self.assertRaises(asyncio.TimeoutError):
            await self.run_producer('import time\ntime.sleep(30)')

    async def test_external_cancellation_reaps_producer(self):
        self.created = asyncio.Event()
        task = asyncio.create_task(self.run_producer('import time\ntime.sleep(30)'))
        await asyncio.wait_for(self.created.wait(), 2)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task


class SourceRowTests(unittest.TestCase):
    def test_text_fields_are_bounded(self):
        rows = b.stream_rows([{"index": 42, "sink": 7, "client": "9" * 1000,
            "properties": {"application.name": "a" * 10000, "media.name": "b" * 10000,
                           "application.process.id": "8" * 1000}}],
            [{"index": 7, "monitor_source": 8}])
        row = rows[0]
        self.assertEqual(len(row["app"]), b.SOURCE_NAME_LIMIT)
        self.assertEqual(len(row["label"]), b.SOURCE_NAME_LIMIT + b.SOURCE_MEDIA_LIMIT + 3)
        self.assertEqual(row["fingerprint"][:2], ["", ""])
        self.assertLess(len(json.dumps(rows)), 1500)

    def test_both_source_lists_are_capped(self):
        for inputs, sinks in [([{}] * (b.SOURCE_ROW_LIMIT + 1), []), ([], [{}] * (b.SOURCE_ROW_LIMIT + 1))]:
            with self.assertRaises(ValueError):
                b.stream_rows(inputs, sinks)

    def test_malformed_rows_and_identifiers_are_not_forwarded(self):
        self.assertEqual(b.stream_rows([None, [], {"index": "x" * 1000, "sink": 7}],
                                     [None, {"index": 7, "monitor_source": 8}]), [])
        rows = b.stream_rows([{"index": 1, "sink": 7, "properties": [], "volume": "bad"}],
                             [{"index": 7, "monitor_source": 8}])
        self.assertFalse(rows[0]["active"])
