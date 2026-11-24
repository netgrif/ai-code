#!/usr/bin/env bash
# BYPASS W3 (see workarounds/README.md): REST helper for realms, test users, roles
# and role tests on cluster 1.1.0.
#
# engine-mcp (netgrif-nae-mcp-plugin 1.0.0) has no realm tools, no
# list_process_roles/list_global_roles, creates users without a password in the
# realm Admin (where every user is an administrator) and does not enforce role
# permissions for impersonated calls. This script calls the admin REST API as the
# admin and the gateway REST API as a real test user instead.
#
# Needs bash and curl (Git Bash on Windows). Tokens and the admin password are
# never printed. Output is the raw JSON body; an HTTP status >= 400 exits with 1.
#
# Usage (from anywhere):
#   workarounds/nae.sh admin  METHOD PATH [JSON]         admin REST as admin (realm Admin), http://localhost:8888
#   workarounds/nae.sh as USER METHOD PATH [JSON]        gateway REST as USER of realm app-users, http://localhost:8080
#   workarounds/nae.sh create-user USERNAME FIRST LAST   new user in realm app-users, password "password"
#   workarounds/nae.sh user REALM USER_ID                one user with processRoles and groups
#   workarounds/nae.sh users REALM                       users of a realm
#   workarounds/nae.sh roles [SEARCH]                    roles (importId, stringId, process); global roles have importId global_<id>
#   workarounds/nae.sh assign-roles REALM USER_ID ROLE_STRING_ID...
#                                                        replaces the whole role set: include the default role
#   workarounds/nae.sh realms                            realms (default realm must be app-users, see W2)
#
# Environment: NAE_APP_REALM (app-users), NAE_TEST_PASSWORD (password),
# NAE_ADMIN_URL (http://localhost:8888), NAE_GATEWAY_URL (http://localhost:8080).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REALM="${NAE_APP_REALM:-app-users}"
TEST_PASSWORD="${NAE_TEST_PASSWORD:-password}"
ADMIN_URL="${NAE_ADMIN_URL:-http://localhost:8888}"
GATEWAY_URL="${NAE_GATEWAY_URL:-http://localhost:8080}"

admin_password() {
  sed -n 's/^x-admin-password: *&[A-Za-z_-]* *//p' "$ROOT/docker-compose.yaml" | tr -d "\"' \r"
}

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# login BASE_URL USER PASSWORD REALM -> token on stdout
login() {
  local h
  h="$(curl -s -D - -o /dev/null -H 'Content-Type: application/json' -X POST "$1/api/auth/login" \
    --data "{\"username\":\"$(json_escape "$2")\",\"password\":\"$(json_escape "$3")\",\"realmId\":\"$4\"}")"
  local t
  t="$(printf '%s\n' "$h" | grep -i '^x-auth-token:' | cut -d' ' -f2 | tr -d '\r' || true)"
  if [ -z "$t" ]; then
    echo "login failed for $2 in realm $4: $(printf '%s\n' "$h" | head -1 | tr -d '\r')" >&2
    exit 1
  fi
  printf '%s' "$t"
}

# call BASE_URL TOKEN METHOD PATH [JSON]
call() {
  local out code
  out="$(mktemp)"
  if [ $# -ge 5 ]; then
    code="$(curl -s -o "$out" -w '%{http_code}' -H "X-Auth-Token: $2" -H 'Content-Type: application/json' \
      -H 'Accept: application/json, application/hal+json' -X "$3" "$1$4" --data "$5")"
  else
    code="$(curl -s -o "$out" -w '%{http_code}' -H "X-Auth-Token: $2" \
      -H 'Accept: application/json, application/hal+json' -X "$3" "$1$4")"
  fi
  cat "$out"; echo
  rm -f "$out"
  if [ "$code" -ge 400 ]; then echo "HTTP $code" >&2; exit 1; fi
}

admin_call() {
  local tok
  tok="$(login "$ADMIN_URL" admin "$(admin_password)" Admin)"
  call "$ADMIN_URL" "$tok" "$@"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  admin)
    admin_call "$@" ;;
  as)
    user="$1"; shift
    tok="$(login "$GATEWAY_URL" "$user" "$TEST_PASSWORD" "$REALM")"
    call "$GATEWAY_URL" "$tok" "$@" ;;
  create-user)
    u="$(json_escape "$1")"; f="$(json_escape "$2")"; l="$(json_escape "$3")"
    admin_call POST "/api/users/$REALM" \
      "{\"username\":\"$u\",\"email\":\"$u@example.test\",\"firstName\":\"$f\",\"lastName\":\"$l\",\"password\":\"$(json_escape "$TEST_PASSWORD")\"}" ;;
  user)
    admin_call GET "/api/users/$1/$2" ;;
  users)
    admin_call GET "/api/users/$1/all?page=0&size=200" ;;
  roles)
    admin_call GET "/api/petrinet/roles/search?page=0&size=500${1:+&search=$1}" ;;
  assign-roles)
    realm="$1"; id="$2"; shift 2
    list=""; for r in "$@"; do list="$list${list:+,}\"$r\""; done
    admin_call PUT "/api/users/$realm/$id/roles" "[$list]" ;;
  realms)
    admin_call GET /api/auth/realms/all ;;
  *)
    sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'
    exit 2 ;;
esac
