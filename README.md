# phpwarden for Composer

**PHP exposure & exploitation guard** — scan your PHP engine, Composer
dependencies and WordPress install against an exploitation-ranked
(CISA KEV + EPSS) CVE feed, straight from `vendor/bin`.

This package is a thin PHP shim around the [phpwarden](https://pypi.org/project/phpwarden/)
CLI (zero-dependency Python 3.8+). It needs **PHP 7.4+** and a **Python 3.8+**
interpreter on the machine; on first run it creates a private virtualenv and
installs the CLI into it (one line is printed when that happens). If a
`phpwarden` is already on `PATH` (for example from `pipx install phpwarden`),
it is used directly.

## Install

```bash
composer require --dev phpwarden/phpwarden
```

## Use

```bash
vendor/bin/phpwarden deps composer.lock   # vulnerable Composer packages, ranked by exploitation risk
vendor/bin/phpwarden scan                 # this host's PHP engine against the whole CVE feed
vendor/bin/phpwarden wordpress /var/www   # WordPress core, plugins and themes
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

Every option of the CLI is passed through unchanged (`--json`, `--out`,
`--report-to`, …); run `vendor/bin/phpwarden --help` for the full list.

## Exit codes

The shim preserves the CLI's exit code, so it is safe to gate a pipeline on it.

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
   `pip install "phpwarden>=2,<3"`. Override the location with
   `PHPWARDEN_VENV`, the pip spec with `PHPWARDEN_VERSION`, and the
   interpreter with `PHPWARDEN_PYTHON`.

Python is looked up as `python3`, then `python` (and `py -3` on Windows). If
none is found the shim exits 127 with a message pointing at
`pipx install phpwarden`.

## Licensing

The scanning engine and the bundled community CVE feed are Apache-2.0, the
same as the [phpwarden source](https://github.com/oroma-alfred/phpwarden).
A [phpwarden.io](https://phpwarden.io) subscription adds the maintained feed
(fresher advisories, KEV/EPSS refresh, dashboard reporting via `--report-to`).

## CI

For GitHub Actions use the standalone
[phpwarden-action](https://github.com/oroma-alfred/phpwarden-action)
(on the GitHub Marketplace), which installs the CLI itself and uploads SARIF to code scanning.

## Development

```bash
sh tests/smoke.sh   # validates composer.json and runs the shim against a vulnerable fixture
```

Issues and feature requests: <https://github.com/oroma-alfred/phpwarden/issues>.
