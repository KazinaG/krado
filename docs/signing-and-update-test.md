# Code signing, update testing, and clean uninstall

## Code signing

macOS records an app's *designated requirement* (DR) when Accessibility is granted and
checks every later version against it ([TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)).
An ad-hoc DR is the build's cdhash, so every new build loses the grant.

Release builds are therefore signed with one long-lived self-signed certificate:

- Identity: `krado Self-Signed` (no OU, so no Team ID), code-signing EKU, valid until 2056.
- DR: `identifier "io.github.kazinag.krado" and certificate leaf = H"…"`, identical for every build.
  `scripts/build-app.sh` fails if the DR is a cdhash or a Team ID is present.
- CI: `scripts/ci-signing-keychain.sh import` decodes the `KRADO_SIGNING_P12_BASE64`
  secret with `KRADO_SIGNING_P12_PASSWORD` into a temporary keychain under
  `$RUNNER_TEMP`, exports `KRADO_SIGN_IDENTITY`/`KRADO_SIGN_KEYCHAIN`, and
  `cleanup` deletes that keychain at the end of the job. No login keychain is used.
- Local builds without `KRADO_SIGN_IDENTITY` are signed ad hoc.
- **Never regenerate the certificate.** A new certificate means every user grants
  Accessibility once more. Its backup lives with the Sparkle EdDSA key.

This is not Developer ID: Gatekeeper still treats krado as an unidentified developer
on first launch (macOS 15+: **Open Anyway** in Privacy & Security). The
[Gatekeeper workflow](../.github/workflows/gatekeeper.yml) checks this on every build
with a quarantined copy; see the release checklist. Sparkle accepts
updates because they carry a valid EdDSA signature from the release key.

## Update defaults

- `SUEnableAutomaticChecks` = true: scheduled checks, no Sparkle permission prompt.
- `SUAutomaticallyUpdate` = false and `SUAllowsAutomaticUpdates` = false: an update is
  shown in Sparkle's standard alert and installs only when the user chooses
  **Install Update**. The alert offers no "install automatically" option.

## Testing an update between unpublished builds

Drafts are not downloadable without signing in, and the public feed
(`releases/latest/download/appcast.xml`) ignores drafts and pre-releases. For a test,
the app honours one opt-in user default through Sparkle's documented
`feedURLString(for:)` delegate:

```sh
defaults write io.github.kazinag.krado KradoTestFeedURL \
  "https://github.com/KazinaG/krado/releases/download/v0.1.1-test/appcast-test.xml"
```

Only `https://github.com/KazinaG/krado/releases/download/…/appcast-test.xml` is
accepted; anything else is ignored and the public feed is used. The update must still
be EdDSA-signed by the release key. Remove the override after the test:

```sh
defaults delete io.github.kazinag.krado KradoTestFeedURL
```

Build B for such a test is a `v<version>-test` tag (e.g. `v0.1.1-test`), which the
release workflow turns into a draft **pre-release** whose feed is named
`appcast-test.xml`. Publishing it as a pre-release (owner decision) makes its assets
downloadable; `releases/latest` never points at a pre-release, so public users are
not offered it. Delete the pre-release and its tag after the test.

Note: like every Sparkle app, Sparkle's installer removes the quarantine attribute
from an update it has verified (EdDSA and code signature) before swapping it in, so
an updated krado does not show the Gatekeeper first-launch dialog again. krado adds
no other quarantine, TCC, or Gatekeeper handling.

## What krado leaves on a Mac

| Item | Path / where |
| --- | --- |
| App | `/Applications/krado.app` (or `~/Applications/krado.app`) |
| Preferences (krado and Sparkle keys such as `SUHasLaunchedBefore`, `SULastCheckTime`, `SUSkippedVersion`, `KradoTestFeedURL`) | defaults domain `io.github.kazinag.krado` (`~/Library/Preferences/io.github.kazinag.krado.plist`) |
| Sparkle downloads and installer staging | `~/Library/Caches/io.github.kazinag.krado/org.sparkle-project.Sparkle/` (`PersistentDownloads`, `Installation`) |
| URL cache | `~/Library/Caches/io.github.kazinag.krado/` (other files) |
| HTTP cookies / HSTS | `~/Library/HTTPStorages/io.github.kazinag.krado` and `io.github.kazinag.krado.binarycookies` |
| Saved window state (if created) | `~/Library/Saved Application State/io.github.kazinag.krado.savedState` |
| Login item | System Settings → General → Login Items (registered only if the user turned it on) |
| Accessibility grant | System Settings → Privacy & Security → Accessibility |
| Crash reports (if any) | `~/Library/Logs/DiagnosticReports/krado-*.ips` |

krado writes nothing to Application Support. Sparkle's installer runs as a temporary
launchd job that is removed when the update finishes; it installs no permanent agent.

### Clean uninstall

**Uninstall krado…** in the menu does steps 1–4 below in that order (login item →
`tccutil reset Accessibility io.github.kazinag.krado` → `removePersistentDomain` →
caches/HTTPStorages → Trash) and quits; when a step fails (e.g. running from the DMG
or App Translocation) it keeps the app, explains the manual steps, and opens
Accessibility settings. Manual equivalent:

1. In krado's menu, turn **Launch at Login** off (if on), then **Quit krado**.
2. System Settings → Privacy & Security → Accessibility: select **krado**, click **−**.
3. System Settings → General → Login Items: remove **krado** if it is still listed.
4. Delete the app and its data:

   ```sh
   rm -rf /Applications/krado.app ~/Applications/krado.app
   defaults delete io.github.kazinag.krado 2>/dev/null || true
   rm -rf ~/Library/Caches/io.github.kazinag.krado \
          ~/Library/HTTPStorages/io.github.kazinag.krado \
          ~/Library/HTTPStorages/io.github.kazinag.krado.binarycookies \
          "$HOME/Library/Saved Application State/io.github.kazinag.krado.savedState"
   ```

   Use `defaults delete` rather than deleting the plist, so the preferences daemon
   does not keep a cached copy.
