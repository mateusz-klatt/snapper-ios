# Security Policy

## Supported versions

Only the latest tagged release of `snapper-ios` receives security fixes. Older versions are not maintained.

| Version                           | Supported |
| --------------------------------- | --------- |
| latest tag (`vX.Y.Z`) on `master` | ✅        |
| anything else                     | ❌        |

## Reporting a vulnerability

**Please do not open a public issue for security reports.**

Use GitHub's private vulnerability reporting:

1. Go to the [Security Advisories](https://github.com/mateusz-klatt/snapper-ios/security/advisories) tab
2. Click **Report a vulnerability**
3. Include: affected version/commit, reproduction steps, observed impact, and (if known) suggested mitigation

If GitHub private reporting is not available to you, open an empty public issue titled "security contact request" — a maintainer will provide a private channel.

## What to expect

- Acknowledgement within 7 days
- Reasonable-effort fix or mitigation plan within 30 days for critical issues
- Coordinated disclosure — please do not publish details until a fix ships

## Out of scope

- Vulnerabilities in the upstream Snapper backend (report against the [`snapper`](https://github.com/mateusz-klatt/snapper) repo if it has its own policy, otherwise via the same private channel)
- Issues that require physical access to an unlocked iOS device
- Theoretical issues without a reproducible exploit
- Bugs in third-party simulator / Apple toolchain components — please report to Apple first; we'll bump deployment / Xcode versions as fixes land

## Scope examples

In scope: improper auth state handling, leaked credentials in build artefacts, unsafe URL handling that lets a hostile backend response trigger out-of-app actions, cleartext traffic in places it should not be.

Out of scope: theoretical attacks against an attacker-controlled backend (the app trusts the backend it's pointed at), dev-only conveniences (e.g. `http://` default in `Configuration.plist` for localhost testing — that is intentional opt-in).
