#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
# Sourcing only defines functions; it does not run or modify system settings.
source "$BASE/modules/password.sh"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
fixture="$work/login.defs"
cat > "$fixture" <<'DATA'
# PASS_MAX_DAYS 123
PASS_MAX_DAYS 99999
PASS_MIN_DAYS 0
PASS_WARN_AGE 7
PASS_MAX_DAYS 365
UMASK 027
DATA
chmod 640 "$fixture"
before_mode=$(stat -c '%a' "$fixture")
password_login_defs_set_file "$fixture" PASS_MAX_DAYS 90
password_login_defs_set_file "$fixture" PASS_MIN_DAYS 1
[[ $(awk '$1=="PASS_MAX_DAYS" {n++; v=$2} END {if(n==1) print v}' "$fixture") == 90 ]]
[[ $(awk '$1=="PASS_MIN_DAYS" {print $2}' "$fixture") == 1 ]]
grep -qx '# PASS_MAX_DAYS 123' "$fixture"
grep -qx 'UMASK 027' "$fixture"
[[ $(stat -c '%a' "$fixture") == "$before_mode" ]]
cp "$fixture" "$work/before"
password_login_defs_set_file "$fixture" PASS_MAX_DAYS 90
cmp -s "$fixture" "$work/before"
if password_login_defs_set_file "$fixture" PASS_MAX_DAYS invalid; then echo 'Bad value accepted' >&2; exit 1; fi
if password_login_defs_set_file "$fixture" NOT_ALLOWED 99; then echo 'Bad key accepted' >&2; exit 1; fi
cmp -s "$fixture" "$work/before"
[[ $(find "$work" -maxdepth 1 -name '.login.defs.*' | wc -l) == 0 ]]
# Must not follow a symlink.
ln -s "$fixture" "$work/symlink"
if password_login_defs_set_file "$work/symlink" PASS_MAX_DAYS 20; then echo 'Symlink accepted' >&2; exit 1; fi
cmp -s "$fixture" "$work/before"
echo 'OK: login.defs safe writer fixture tests passed'
