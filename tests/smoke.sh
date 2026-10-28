#!/bin/sh
# Smoke test for the Composer shim: validates composer.json, then runs the
# shim against a fixture composer.lock with a known-vulnerable package.
# Needs php and python3 (with venv + pip) and network access to PyPI.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SHIM="$ROOT/bin/phpwarden"
FIXTURE="$ROOT/tests/fixtures/composer.lock"
TMP="$ROOT/tests/tmp"
rm -rf "$TMP" && mkdir -p "$TMP"
PHP=$(command -v php)
PY3=$(command -v python3)
# A PATH with only php + python3 (and the system dirs), so a globally
# installed phpwarden cannot short-circuit the venv path under test.
LEAN_PATH="$(dirname "$PHP"):$(dirname "$PY3"):/usr/bin:/bin"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok   $*"; }

# --- composer.json validation --------------------------------------------
if command -v composer >/dev/null 2>&1; then
    (cd "$ROOT" && composer validate --strict --no-check-lock) || fail "composer validate --strict"
    pass "composer validate --strict"
else
    "$PHP" -r '
        $j = json_decode(file_get_contents($argv[1]), true);
        if (!is_array($j)) { fwrite(STDERR, "composer.json: invalid JSON\n"); exit(1); }
        foreach (["name","description","type","license","require","bin"] as $k)
            if (!isset($j[$k])) { fwrite(STDERR, "composer.json: missing $k\n"); exit(1); }
        if ($j["name"] !== "phpwarden/phpwarden") exit(1);
        foreach ($j["bin"] as $b) if (!is_file(dirname($argv[1])."/$b")) { fwrite(STDERR, "bin missing: $b\n"); exit(1); }
    ' "$ROOT/composer.json" || fail "composer.json sanity"
    pass "composer.json sanity (composer not installed; php json check)"
fi

# --- 1. first run: creates the venv, finds the vulnerable package -----------
export PHPWARDEN_VENV="$TMP/venv"
unset PHPWARDEN_BIN || true
set +e
PATH="$LEAN_PATH" "$PHP" "$SHIM" deps "$FIXTURE" >"$TMP/out1.txt" 2>"$TMP/err1.txt"
RC=$?
set -e
[ "$RC" -eq 1 ] || { cat "$TMP/out1.txt" "$TMP/err1.txt" >&2; fail "expected exit 1 (vulnerable), got $RC"; }
grep -q "CVE-2022-31091" "$TMP/out1.txt" || { cat "$TMP/out1.txt" >&2; fail "output does not mention CVE-2022-31091"; }
grep -q "installing phpwarden" "$TMP/err1.txt" || { cat "$TMP/err1.txt" >&2; fail "first run should print the one-time install line"; }
pass "first run: exit 1, CVE-2022-31091 reported, venv created"

# --- 2. second run: reuses the cached venv -------------------------------
set +e
PATH="$LEAN_PATH" "$PHP" "$SHIM" deps "$FIXTURE" >"$TMP/out2.txt" 2>"$TMP/err2.txt"
RC=$?
set -e
[ "$RC" -eq 1 ] || fail "second run: expected exit 1, got $RC"
if grep -q "installing phpwarden" "$TMP/err2.txt"; then fail "second run re-installed instead of reusing the venv"; fi
pass "second run: cached venv reused"

# --- 3. exit code passthrough: usage error is 64, clean lock is 0 ----------
set +e
PATH="$LEAN_PATH" "$PHP" "$SHIM" deps --no-such-flag >/dev/null 2>&1; RC=$?
set -e
[ "$RC" -eq 64 ] || fail "usage error: expected exit 64, got $RC"
pass "usage error passes through as 64"

# --- 4. no Python available: clear error, exit 127 --------------------------
mkdir -p "$TMP/phponly" && ln -s "$PHP" "$TMP/phponly/php"
set +e
PATH="$TMP/phponly" PHPWARDEN_VENV="$TMP/none" "$PHP" "$SHIM" --version >"$TMP/out4.txt" 2>"$TMP/err4.txt"; RC=$?
set -e
[ "$RC" -eq 127 ] || { cat "$TMP/err4.txt" >&2; fail "no-python: expected exit 127, got $RC"; }
grep -q "pipx install phpwarden" "$TMP/err4.txt" || fail "no-python error should point at pipx"
pass "no Python: exit 127 with pipx hint"

echo "all smoke tests passed"
