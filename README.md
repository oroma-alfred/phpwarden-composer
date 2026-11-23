# phpwarden for Composer

**Website and docs: [phpwarden.io](https://phpwarden.io)**

**PHP vulnerability scanner that ranks findings by real-world exploitation,
not CVSS.** Of about 19,500 PHP vulnerabilities in the feed, 54 are known to be
exploited (CISA KEV, as of 2026-11-14); phpwarden puts those first, then sorts
by EPSS probability, then CVSS. It scans your `composer.lock`, the PHP engine
and WordPress installs, straight from `vendor/bin`.

This package is a thin PHP shim around the [phpwarden](https://pypi.org/project/phpwarden/)
CLI (zero-dependency Python 3.8+, Apache-2.0). It needs **PHP 7.4+** and a
**Python 3.8+** interpreter on the machine; on first run it creates a private
virtualenv and installs the CLI into it (one line is printed when that
happens). If a `phpwarden` is already on `PATH` (for example from
`pipx install phpwarden`), it is used directly.

## Install

```bash
composer require --dev phpwarden/phpwarden
```

## Use

```bash
vendor/bin/phpwarden deps composer.lock   # Composer packages, ranked KEV → reachability → EPSS → CVSS
vendor/bin/phpwarden scan                 # this host's PHP engine against the engine CVE feed
vendor/bin/phpwarden wordpress /var/www   # WordPress core, plugins and themes
```

```
$ vendor/bin/phpwarden deps composer.lock
18 vulnerable package(s) in composer.lock; 0 actively exploited (KEV). Ranked by exploitation risk, then reachability:

  symfony/http-kernel 5.4.0  CVE-2022-24894 medium (CVSS 5.9)  [EPSS 4% (p90)]
      Symfony storing cookie headers in HttpCache
      fixed in: 4.4.50, 5.4.20, 6.0.20, 6.1.12, 6.2.6
  ...
```

Add it as a Composer script so `composer security` works for the whole team
and in CI:

```json
{
    "scripts": {
        "security": "phpwarden deps composer.lock"
    }
}
```

Every option of the CLI is passed through unchanged (`--json`,
`--no-reachability`, `--report-to`, …); run `vendor/bin/phpwarden --help` for
the full list. The scan is offline: the advisory feed ships inside the CLI and
nothing is sent anywhere unless you add `--report-to`.

## Send results to the dashboard

```bash
vendor/bin/phpwarden deps composer.lock --report-to https://app.phpwarden.io/v1/reports --report-token <token>
```

The result is also stored in [app.phpwarden.io](https://app.phpwarden.io) —
history per project and host, and an alert when a finding you already carry
lands in CISA KEV. The token can also be set as `PHPWARDEN_REPORT_TOKEN`.
Local output is printed first, so an unreachable dashboard never hides a
finding.

## Exit codes

The shim preserves the CLI's exit code, so it is safe to gate a pipeline on it.
Exit `1` means any known-vulnerable package; the CLI has no severity threshold
(the [GitHub Action](https://github.com/oroma-alfred/phpwarden-action) adds
`fail-on: exploited` for a KEV-only gate).

| Code | Meaning                                              |
|-----:|------------------------------------------------------|
| 0    | clean                                                |
| 1    | vulnerable / exposed                                 |
| 2    | possibly exposed (`scan`)                            |
| 3    | PHP version unknown (`scan`)                         |
| 4    | input or `--out` error                               |
| 5    | `--report-to` upload failed on an otherwise clean run |
| 64   | usage error                                          |
| 127  | the shim could not find or install the CLI           |

## How the CLI is located

1. `PHPWARDEN_BIN`, if set.
2. A `phpwarden` already on `PATH`.
3. A virtualenv under `vendor/phpwarden/.venv` (or `~/.cache/phpwarden/venv`
   when `vendor/` is not writable), created with `python -m venv` and
   `pip install "phpwarden>=2.6.0,<3"`. Override the location with
   `PHPWARDEN_VENV`, the pip spec with `PHPWARDEN_VERSION`, and the
   interpreter with `PHPWARDEN_PYTHON`.

   Each shim release raises the minimum version when the CLI gains something
   important. A changed spec rebuilds the virtualenv, so `composer update`
   brings an existing install up to date; you never need to delete `.venv`.

Python is looked up as `python3`, then `python` (and `py -3` on Windows). If
none is found the shim exits 127 with a message pointing at
`pipx install phpwarden`.

## Licensing

The scanning engine and the bundled community CVE feed are Apache-2.0, the
same as the [phpwarden source](https://github.com/oroma-alfred/phpwarden).
Free users get weekly feed updates (`phpwarden feed update`, no key) and a
one-project dashboard behind `--report-to`. Pro and Team at
[phpwarden.io](https://phpwarden.io) add the maintained feed (rebuilt twice a
day), more projects and alerts.

## CI

For GitHub Actions use the standalone
[phpwarden-action](https://github.com/oroma-alfred/phpwarden-action)
(on the GitHub Marketplace): it installs the CLI itself, supports
`fail-on: exploited`, and uploads SARIF to code scanning. GitLab CI and
Bitbucket Pipelines templates are in the
[main repo](https://github.com/oroma-alfred/phpwarden/tree/main/integrations).
Laravel apps can use [`phpwarden/laravel`](https://packagist.org/packages/phpwarden/laravel)
for `php artisan phpwarden:scan`.

## Development

```bash
sh tests/smoke.sh   # validates composer.json and runs the shim against a vulnerable fixture
```

Issues and feature requests: <https://github.com/oroma-alfred/phpwarden/issues>.
