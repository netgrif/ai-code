#!/bin/sh
# BYPASS W1 (see workarounds/README.md): frontend sign-in on cluster 1.1.0.
#
# The prebuilt frontend 7.1.0 has its configuration compiled into main.*.js with
# "authentication":"Basic", which signs in with GET /api/auth/login. The admin of
# cluster 1.1.0 accepts only POST and answers 405, which the login form shows as
# "Wrong credentials!". The same bundle has the strategy "BasicWithRealm", which
# POSTs {username, password} as JSON; the admin then uses the default realm
# (app-users, set by workarounds/realm-init.sh).
#
# nginx serves main.*.js with "expires max", so a browser that loaded the
# original file would keep it. The patched copy gets a new name (main.<hash>.w1.js)
# and index.html points to it.
#
# Runs before nginx starts (entrypoint of the frontend service). Idempotent.
set -eu
HTML=/usr/share/nginx/html
if ls "$HTML"/main.*.w1.js >/dev/null 2>&1; then
  echo "BYPASS W1: frontend already patched ($(basename "$(ls "$HTML"/main.*.w1.js | head -1)"))"
  exit 0
fi
patched=0
for f in "$HTML"/main.*.js; do
  [ -f "$f" ] || continue
  grep -q '"authentication":"Basic"' "$f" || continue
  name="$(basename "$f" .js)"
  sed 's/"authentication":"Basic"/"authentication":"BasicWithRealm"/' "$f" > "$HTML/$name.w1.js"
  sed -i "s/$name\.js/$name.w1.js/g" "$HTML/index.html"
  echo "BYPASS W1: $name.js switched to BasicWithRealm sign-in as $name.w1.js"
  patched=1
done
if [ "$patched" = 0 ]; then
  echo "BYPASS W1: no main.*.js with \"authentication\":\"Basic\" found; the image changed, check workarounds/README.md" >&2
fi
