# Changelog

## 0.9.1

- Refuse preference updates when existing settings cannot be read or are not a JSON object; preserve the file and current runtime preferences.
- Add regression coverage for invalid JSON/encoding, non-object JSON, permission/I/O errors, dangling symlinks, first-run creation and preservation of unknown keys.
- Add a root preview for the marketplace.


## 0.9.0 — Initial public release

- Live translated subtitles for app playback audio on Omarchy.
- Automatic playback discovery and a separate, resizable subtitle window.
- Punctuation-aware captions, adaptive font size, and real-time/readability modes.
- Thirteen translation targets, Japanese/English UI, and Omarchy theme support.
- Local translation history and a shortcut to open it from Settings.
- Automatic stopping after about 10 seconds of silence or inactive playback.
- Explicit dependency setup, installation/removal documentation, and automated tests.
