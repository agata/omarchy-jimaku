#!/usr/bin/env python3
"""Launch the external runtime; never install packages on plugin load."""
import os
from pathlib import Path
import subprocess
import sys


def main():
    runtime = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "jimaku/runtime/bin/python"
    try:
        result = subprocess.run(
            [str(runtime), "-c", 'import websockets; assert websockets.__version__ == "15.0.1"'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10,
        )
        if result.returncode:
            return 78
    except (OSError, subprocess.TimeoutExpired):
        return 78
    os.execv(str(runtime), [str(runtime), "-u", str(Path(__file__).with_name("backend.py"))])


if __name__ == "__main__":
    sys.exit(main())
