#!/bin/sh
# BYPASS W1 (see workarounds/README.md): frontend sign-in on cluster 1.1.0.
#
# The prebuilt frontend 7.1.0 has its configuration compiled into main.*.js.
# Two settings do not fit the admin of cluster 1.1.0, which accepts only POST on
# /api/auth/login:
#  1. "authentication":"Basic" signs in with GET /api/auth/login: 405, shown as
#     "Wrong credentials!". The bundle also has "BasicWithRealm", which POSTs
#     {username, password} as JSON; the admin then uses the default realm
#     (app-users, set by workarounds/realm-init.sh).
#  2. The stored session is verified with GET on the login endpoint: 405 instead
#     of 401, so a stale token is never cleared and the login page hangs after a
#     restart. "verification":"/users/me" answers 200 or 401.
#
# nginx serves main.*.js with "expires max", so the patched copy gets a name with
# its own checksum and index.html points to it.
#
# Runs before nginx starts (entrypoint of the frontend service). Idempotent.
set -eu
HTML=/usr/share/nginx/html
if grep -q 'main\.[0-9a-f]*\.w1-' "$HTML/index.html"; then
  echo "BYPASS W1: frontend already patched (container restart)"
  exit 0
fi
patched=0
for f in "$HTML"/main.*.js; do
  [ -f "$f" ] || continue
  grep -q '"authentication":"Basic"' "$f" || continue
  name="$(basename "$f" .js)"
  tmp="$HTML/.w1.tmp"
  sed -e 's/"authentication":"Basic"/"authentication":"BasicWithRealm"/' \
      -e 's#"endpoints":{"login":"/auth/login",#"endpoints":{"login":"/auth/login","verification":"/users/me",#' \
      "$f" > "$tmp"
  sum="$(md5sum "$tmp" | cut -c1-8)"
  mv "$tmp" "$HTML/$name.w1-$sum.js"
  sed -i "s/$name\.js/$name.w1-$sum.js/g" "$HTML/index.html"
  grep -q '"verification":"/users/me"' "$HTML/$name.w1-$sum.js" \
    || echo "BYPASS W1: session verification endpoint not set (pattern not found)" >&2
  echo "BYPASS W1: $name.js switched to BasicWithRealm sign-in and /users/me verification as $name.w1-$sum.js"
  patched=1
done
if [ "$patched" = 0 ]; then
  if ls "$HTML"/main.*.w1-*.js >/dev/null 2>&1; then
    echo "BYPASS W1: frontend already patched"
  else
    echo "BYPASS W1: no main.*.js with \"authentication\":\"Basic\" found; the image changed, check workarounds/README.md" >&2
  fi
fi
