"""Runtime bootstrap tests; no network, audio or user data access."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("jimaku_launch", Path(__file__).parents[1] / "lib/launch.py")
launch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(launch)


class LauncherTests(unittest.TestCase):
    def test_missing_runtime_returns_setup_exit(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_DATA_HOME": directory}):
            self.assertEqual(launch.main(), 78)

    def test_broken_dependency_returns_setup_exit(self):
        with patch.object(launch.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)):
            self.assertEqual(launch.main(), 78)

    def test_launch_uses_xdg_path_as_single_argument(self):
        with patch.dict(os.environ, {"XDG_DATA_HOME": "/tmp/jimaku data"}), \
             patch.object(launch.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), \
             patch.object(launch.os, "execv") as execute:
            launch.main()
            runtime = "/tmp/jimaku data/jimaku/runtime/bin/python"
            self.assertEqual(execute.call_args.args[0], runtime)
            self.assertEqual(execute.call_args.args[1][0], runtime)
            self.assertEqual(Path(execute.call_args.args[1][-1]).name, "backend.py")
