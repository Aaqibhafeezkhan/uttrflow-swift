# Crash and hang reporting

Opt-in. Off by default, switched on in Settings → Privacy → *Send crash reports*
(`Settings.sendsCrashReports`). While it is off the crash reporter is not started, so
nothing is collected or sent; switching it off calls `SentrySDK.close()`.

## Where it lives

The Sentry SDK (`sentry-cocoa`) is linked by one module, `UttrflowDiagnostics`, and only
the app target depends on that module, so nothing on the dictation path can call it.
`Scripts/offline_audit.sh` checks both. `CrashReporter` holds the rules;
`LiveCrashReportingSDK` is the few lines that start and close the real SDK.

## Which builds can report

The DSN is not in any tracked file. `Scripts/bundle.sh` writes the `SentryDSN` Info.plist
key from the `SENTRY_DSN` environment variable, which `release.yml` fills from the GitHub
Actions secret of the same name. A development build never gets one, and a build with an
empty or missing key never starts the reporter, whatever the switch says.

## What is collected

Crashes (the crash handler) and app hangs, nothing else. The options are fixed in
`CrashReporter.configure`:

- `sendDefaultPii` off, `debug` off.
- No tracing (`tracesSampleRate` 0, automatic performance, network, file and Core Data
  tracing off), no profiling, no logs, no MetricKit forwarding.
- No breadcrumbs: automatic and network breadcrumbs off, `maxBreadcrumbs` 0, and
  `beforeBreadcrumb` drops anything left.
- No failed-request capture, no attached stack traces on messages.
- Session tracking stays on, so a crash rate has a denominator.
- `release` is `uttrflow@<CFBundleShortVersionString>+<CFBundleVersion>`.

The app never calls `capture` for an error or a message, and `beforeSend` drops any event
that carries no exception, so text that could hold a transcript has no way in.

## What `beforeSend` removes

`CrashReporter.scrub` runs on every event before it leaves:

- `user`, `server_name`, request, tags, extra, modules, breadcrumbs, message and the
  attached `NSError` are removed.
- Contexts other than `os` (name, version, build, kernel version), `device` (model,
  model id, architecture) and `app` (version, build, identifier, name, build type) are
  dropped, and so is every other key inside those three — the device name, which is the
  host name, among them.
- Every frame's `filename` and `package`, and every debug image's `code_file`, is cut to
  its last path component; a bare home folder becomes `~`. Source context lines and
  variables are removed.
- An exception's value is kept only when the system wrote it (Mach exceptions, signals
  and hangs), with every path in it cut the same way. The value of an `NSException` or a
  Swift error can be built from app data, so it is removed.

`CrashReporterTests` salts an event with a home-folder path and a host name in every
field Sentry has and fails if any of it survives serialisation.

## Symbols

`bundle.sh` builds with `DEBUG_INFORMATION_FORMAT=dwarf-with-dsym`, and `release.yml`
uploads the dSYMs with `sentry-cli debug-files upload` using the `SENTRY_AUTH_TOKEN`,
`SENTRY_ORG` and `SENTRY_PROJECT` secrets. The step does nothing when the token is absent.
