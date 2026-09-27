"""Installer safety checks using stub commands and temporary XDG directories."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parents[1]


class InstallTests(unittest.TestCase):
    def test_conflict_is_rejected_before_setup_or_desktop_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            commands = base / "bin"
            commands.mkdir()
            marker = base / "called"
            for name in ("omarchy", "omarchy-shell", "jq", "uv"):
                executable = commands / name
                executable.write_text('#!/bin/sh\nprintf called >> "$JIMAKU_MARKER"\n')
                executable.chmod(0o755)
            target = base / "config/omarchy/plugins/io.github.agata.jimaku"
            target.mkdir(parents=True)
            sentinel = target / "keep"
            sentinel.write_text("existing plugin")
            environment = {**os.environ, "PATH": str(commands) + os.pathsep + os.environ["PATH"],
                           "XDG_CONFIG_HOME": str(base / "config"), "JIMAKU_MARKER": str(marker)}
            result = subprocess.run(["bash", str(ROOT / "install.sh")], env=environment, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Refusing to replace", result.stderr)
            self.assertEqual(sentinel.read_text(), "existing plugin")
            self.assertFalse(marker.exists())

    def test_dangling_link_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            commands = base / "bin"
            commands.mkdir()
            for name in ("omarchy", "omarchy-shell", "jq"):
                executable = commands / name
                executable.write_text("#!/bin/sh\nexit 0\n")
                executable.chmod(0o755)
            target = base / "config/omarchy/plugins/io.github.agata.jimaku"
            target.parent.mkdir(parents=True)
            target.symlink_to(base / "missing")
            result = subprocess.run(["bash", str(ROOT / "install.sh")],
                env={**os.environ, "PATH": str(commands) + os.pathsep + os.environ["PATH"],
                     "XDG_CONFIG_HOME": str(base / "config")}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(target.is_symlink())
