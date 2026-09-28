# Verification

## Reproduce

Core tests require Python 3.11+, the pinned dependency and Node.js:

```bash
bash setup.sh
bash scripts/test.sh
```

`JIMAKU_TEST_PYTHON` can select a different prepared Python interpreter. The runner also checks shell syntax and runs `omarchy plugin validate` when Omarchy is installed. CI runs the core suite on Python 3.11 and 3.14; hosted CI results are only available after publishing the repository.

Qt integration tests require Omarchy's Quickshell (`qs`), `timeout`, `rg`, and the Japanese locale installed on the test machine:

```bash
bash scripts/test-qt.sh
```

The Qt runner creates disposable config/data/runtime directories, supplies a dummy API key, uses the offscreen renderer and removes its artifacts afterward. It does not read the user's key, settings or history. It links only the prepared Python runtime into the disposable data directory. Some Qt offscreen warnings (IPC sockets, unused shell import paths, window masks) are expected; process exit status determines success.

## Verified locally — 0.9.0, 2026-09-27

- Omarchy's manifest and plugin-tree validation passes with the runtime outside the source tree.
- 21 Python tests: selected-stream capture, playback filtering, locale/preference handling, mocked translation sessions, rejection before capture, stop/final-drain handling, disappearing stream, private key handling, history append/permissions, setup failures, XDG paths with spaces, conflicting install and dangling-link protection.
- JavaScript tests: 14 segmentation cases plus adaptive timing, display policies and punctuation boundary protection.
- Qt suite: missing-runtime guidance; continuous real-time captions; source selection; automatic font sizing; language selection and persistence; mode/localization behavior; adaptive timing; unconditional toolbar hiding; Python-backed demo; readable-mode punctuation/fallback.
- Native Omarchy Shell loads version 0.9.0, starts the backend without errors, and retains the existing Japanese target, readable mode and live theme binding. No translation was started.
- Explicit runtime setup succeeds without changes to existing user preferences, key or history.

## Manual release checks

On a clean Omarchy account/session, install from the actual public repository using `omarchy plugin add`, run setup, verify bar activation and the optional floating rule, then update/disable/remove. The local development checkout cannot prove remote installation or marketplace acceptance before the repository exists.

With your own billed API account, check a real video, target language, caption latency and translation quality. Verify stopping, closing the window, source disappearance, output-device change and a network interruption. Do not include private source text, API keys or history when reporting results.

Automated tests do **not** call a paid API, measure speech-to-caption latency, assess linguistic quality, or reproduce all audio hardware/browser combinations. Previous development tested selective PipeWire capture with two synthetic tones, but that is not part of the automated release suite. The user previously verified real translation; a fresh paid session was not initiated for this packaging release.

## README screenshots

```bash
bash scripts/screenshots.sh
```

`GalleryPreview.qml` renders the production `CaptionPanel` with an English UI, synthetic captions and a sample playback source. It never starts the Python backend. The script isolates config/data, removes the API key environment variable, and writes four PNGs under `docs/`. The background matches the window clear color, which an item-only Qt capture otherwise omits. These are reproducible UI renders, not screenshots of a live translated video or the user's desktop theme.

0.8.1: mocked sessions verify auto-close for silence and inactive playback and continued translation after a short pause. Test timeout constants are shortened to avoid real-time waiting. No paid API session was started.

0.9.0: user configuration and translation history moved to `jimaku` with byte-for-byte equality verified, runtime rebuilt at its new path, legacy plugin registration removed, and the new window rule reloaded without Hyprland errors.

0.9.1: 26 Python tests pass, including fail-closed preference writes for malformed/non-object JSON, invalid UTF-8, permission/I/O failures and dangling symlinks. Command-level tests verify an error response without changing the file or in-memory preferences; successful updates preserve unknown keys.

0.9.2: 37 Python tests include real subprocess output-flood, stderr pressure, timeout and cancellation cases, verifying that producers exit and oversized stdout never reaches JSON parsing. Discovery row/text/identifier caps are also covered.
