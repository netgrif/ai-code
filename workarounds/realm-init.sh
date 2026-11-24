#!/bin/sh
# BYPASS W2 (see workarounds/README.md): realm for application users on cluster 1.1.0.
#
# Makes sure the realm $APP_REALM (app-users) exists, has the Basic sign-in method
# and is the default realm. A new realm has no sign-in method, so nobody could log
# in to it, and the worker looks users up without a realm (in the default realm),
# so actorList/actor values of app users fail unless their realm is the default.
# Admin accepts a new default realm only when no realm is default, so Admin is
# switched off first. The admin account still signs in: the admin UI and the MCP
# plugin name the realm Admin.
#
# One-shot job of the compose stack (service realm-init). Idempotent.
set -eu
A="${ADMIN_URL:-http://nae-admin:8888}"
REALM="${APP_REALM:-app-users}"
TMP="$(mktemp -d)"

login_body="{\"username\":\"admin\",\"password\":\"${ADMIN_PASSWORD}\",\"realmId\":\"Admin\"}"
tries=0
until curl -s -D "$TMP/h" -o /dev/null -H 'Content-Type: application/json' -X POST "$A/api/auth/login" --data "$login_body" \
  && grep -qi '^x-auth-token:' "$TMP/h"; do
  tries=$((tries + 1))
  [ "$tries" -ge 30 ] && { echo "BYPASS W2: admin login failed" >&2; exit 1; }
  sleep 5
done
TOK="$(grep -i '^x-auth-token:' "$TMP/h" | cut -d' ' -f2 | tr -d '\r')"

# api METHOD PATH [JSON] -> body in $TMP/b, prints the HTTP status
api() {
  if [ $# -ge 3 ]; then
    curl -s -o "$TMP/b" -w '%{http_code}' -H "X-Auth-Token: $TOK" -H 'Content-Type: application/json' -X "$1" "$A$2" --data "$3"
  else
    curl -s -o "$TMP/b" -w '%{http_code}' -H "X-Auth-Token: $TOK" -X "$1" "$A$2"
  fi
}

if [ "$(api GET "/api/auth/realms/$REALM")" != 200 ]; then
  st="$(api POST /api/auth/realms/create "{\"name\":\"$REALM\",\"description\":\"Users of the applications\",\"defaultRealm\":false,\"adminRealm\":false}")"
  [ "$st" = 200 ] || [ "$st" = 201 ] || { echo "BYPASS W2: creating realm $REALM failed ($st)" >&2; cat "$TMP/b" >&2; exit 1; }
  echo "BYPASS W2: realm $REALM created"
  api GET "/api/auth/realms/$REALM" >/dev/null
fi

if grep -q '"authMethods":\[\]' "$TMP/b"; then
  st="$(api POST "/api/auth/realms/$REALM/basic/add" "{\"name\":\"BasicAuth\",\"type\":\"basic\",\"description\":\"Basic Auth for application users\",\"enabled\":true,\"order\":100,\"realmId\":\"$REALM\",\"configuration\":{\"authMethod\":\"basic\",\"allowUserCreation\":true,\"allowUserUpdate\":true}}")"
  [ "$st" = 200 ] || { echo "BYPASS W2: adding Basic auth to $REALM failed ($st)" >&2; cat "$TMP/b" >&2; exit 1; }
  echo "BYPASS W2: Basic sign-in added to realm $REALM"
fi

api GET /api/auth/realms/default >/dev/null || true
if ! grep -q "\"name\":\"$REALM\"" "$TMP/b"; then
  api PUT /api/auth/realms/Admin/update '{"defaultRealm":false}' >/dev/null
  api PUT "/api/auth/realms/$REALM/update" '{"defaultRealm":true}' >/dev/null
  api GET /api/auth/realms/default >/dev/null || true
  grep -q "\"name\":\"$REALM\"" "$TMP/b" || { echo "BYPASS W2: could not make $REALM the default realm" >&2; cat "$TMP/b" >&2; exit 1; }
  echo "BYPASS W2: realm $REALM is now the default realm"
fi
echo "BYPASS W2: realm $REALM ready (exists, Basic sign-in, default realm)"
rm -rf "$TMP"
