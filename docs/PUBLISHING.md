# Publishing Jimaku

Prepared release: **0.9.0**. Repository: [agata/omarchy-jimaku](https://github.com/agata/omarchy-jimaku).

The [marketplace guide](https://plugins.omarchy.org/publish.html) requires a public GitHub repository, a valid root manifest, README, license and safe install/removal. Submission is reviewed; a passing local check does not imply marketplace approval.

## Before uploading

- Confirm the repository owner, `author` and MIT copyright attribution. The plugin ID is `io.github.agata.jimaku`; this namespace is not evidence of ownership of a GitHub account.
- Use the public repository above for releases.
- Run `bash setup.sh`, `bash scripts/test.sh`, and the Qt tests in `TESTING.md` on the supported Omarchy desktop.
- Test a clean `omarchy plugin add https://github.com/agata/omarchy-jimaku.git` installation, explicit `setup.sh`, update, disable and removal. Existing development installations with the same ID must not be overwritten; use a separate test account/session.
- Check a real translation session manually: intended stream only, output language, stop, history, network interruption. Automated tests use a mock service, not live OpenAI billing.
- Inspect the repository contents before pushing. Never include API keys, user history, `.venv`, local configuration or private screenshots.
- Keep installation examples current and previews free of private audio or credentials.
- Tag the verified revision `v0.9.0` and use the changelog for release notes.

## Listing draft

- Name: **Jimaku**
- Summary: **Live translated subtitles for app audio, in a separate resizable window.**
- Suggested category: Media (choose the closest available form option).
- Suggested tags: subtitles, translation, audio, accessibility.
- Requirements: Omarchy Shell plugins, PipeWire-Pulse tools, Python 3.11+, uv, a billed OpenAI API account.
- Setup note: Run the installed plugin's `setup.sh` once; Omarchy does not execute install hooks.
- Privacy note: Selected audio goes to OpenAI on explicit start; translated text is stored locally, unencrypted, with owner-only permissions.

Submit the actual repository link using the form linked from the publishing guide. Marketplace submission is separate from repository publication; this document does not indicate marketplace acceptance.
