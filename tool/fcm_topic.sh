#!/bin/bash
# (3.42.0, asked 26-10-2026: "app updet pasun te sagle kahi" notification) THE RELEASE TELLS EVERY PHONE WITH THE APP: "RCL ERP
# <version> is ready" – one Firebase message to the topic rcl-app-update (the app listens to it – lib/core/push.dart). Used by
# .github/workflows/release.yml after the release is published:  tool/fcm_topic.sh <version> <build>
# The key is the GitHub secret FCM_SERVICE_ACCOUNT_JSON (env FCM_SA) – never in a file of this public repository; it is written only
# to a temporary file of the build machine (removed at the end). Only Google's two addresses are called.
set -euo pipefail
VER="$1"; BN="$2"
[ -n "${FCM_SA:-}" ] || { echo "no FCM_SA"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
python3 - "$T" <<'PY'
import base64, json, os, sys, time
t = sys.argv[1]
k = json.loads(os.environ['FCM_SA'])
fd = os.open(t + '/key.pem', os.O_WRONLY | os.O_CREAT, 0o600)
os.write(fd, k['private_key'].encode()); os.close(fd)
b = lambda x: base64.urlsafe_b64encode(x).rstrip(b'=').decode()
now = int(time.time())
head = b(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode())
claim = b(json.dumps({'iss': k['client_email'], 'scope': 'https://www.googleapis.com/auth/firebase.messaging', 'aud': 'https://oauth2.googleapis.com/token', 'iat': now, 'exp': now + 600}).encode())
open(t + '/unsigned', 'w').write(head + '.' + claim)
open(t + '/project', 'w').write(k['project_id'])
PY
SIG=$(openssl dgst -sha256 -sign "$T/key.pem" "$T/unsigned" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
JWT="$(cat "$T/unsigned").$SIG"
AT=$(curl -sS --max-time 30 https://oauth2.googleapis.com/token --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" --data-urlencode "assertion=$JWT" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")
[ -n "$AT" ] || { echo "Google did not accept the key"; exit 1; }
echo "::add-mask::$AT"
BODY=$(python3 -c "import json,sys; print(json.dumps({'message': {'topic': 'rcl-app-update', 'data': {'t': 'upd', 'version': sys.argv[1], 'build': sys.argv[2]}, 'android': {'priority': 'HIGH', 'ttl': '604800s'}}}))" "$VER" "$BN")
C=$(curl -sS --max-time 30 -o "$T/r.json" -w "%{http_code}" -X POST "https://fcm.googleapis.com/v1/projects/$(cat "$T/project")/messages:send" \
  -H "Authorization: Bearer $AT" -H "Content-Type: application/json" -d "$BODY")
[ "$C" = "200" ] || { echo "Firebase answered $C: $(head -c 300 "$T/r.json")"; exit 1; }
echo "::notice::Every phone with the app was told: RCL ERP $VER ($BN) is ready."
