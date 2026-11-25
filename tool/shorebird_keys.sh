#!/usr/bin/env bash
# (25-11-2026, Shorebird – his decision: the app's updates without the store) THE PATCH-SIGNING KEY. Every release carries the PUBLIC
# key; the phone takes a Shorebird patch only when it is signed with the matching PRIVATE key (SHA-256 / RSA – Shorebird's own check).
# Made ONCE, like the app's signing key, and kept only in the private bucket "app-keys" of the Portal's Supabase:
#   shorebird-patch-private.pem – only the patch run reads it (never in an app, never in a release, never in chat)
#   shorebird-patch-public.pem  – put into every release (it is public by nature)
# Never replaced: an app of before takes a patch only signed with the key it was released with.
#   needs SB_URL / SB_KEY (the Portal's Supabase – the release's GitHub secrets)
#   bash tool/shorebird_keys.sh <folder> [private]  → <folder>/patch-public.pem (and <folder>/patch-private.pem with "private")
set -euo pipefail
D="$1"; WANT_PRIVATE="${2:-}"; mkdir -p "$D"; chmod 700 "$D"
get() { curl -sS -o "$2" -w "%{http_code}" "$SB_URL/storage/v1/object/app-keys/$1" -H "apikey: $SB_KEY"; }
put() { curl -sS -o "$D/put.json" -w "%{http_code}" -X POST "$SB_URL/storage/v1/object/app-keys/$1" -H "apikey: $SB_KEY" -H "Content-Type: text/plain" -H "x-upsert: false" --data-binary "@$2"; }
has_pub() { [ -s "$D/patch-public.pem" ] && grep -q "BEGIN PUBLIC KEY" "$D/patch-public.pem"; }
has_priv() { [ -s "$D/patch-private.pem" ] && grep -q "PRIVATE KEY" "$D/patch-private.pem"; }

if [ "$(get shorebird-patch-public.pem "$D/patch-public.pem")" = "200" ] && has_pub; then
  echo "the patch-signing key is there"
elif [ "$(get shorebird-patch-private.pem "$D/patch-private.pem")" = "200" ] && has_priv; then
  # the private one is kept but its public one is not (a run stopped in between): made again from it, never a new pair
  openssl pkey -in "$D/patch-private.pem" -pubout -out "$D/patch-public.pem"
  [ "$(put shorebird-patch-public.pem "$D/patch-public.pem")" = "200" ] || { echo "::error::Could not keep shorebird-patch-public.pem: $(head -c 200 "$D/put.json")"; exit 1; }
  echo "::notice::The public patch-signing key was made again from the private one."
else
  if [ -n "$WANT_PRIVATE" ]; then echo "::error::There is no patch-signing key yet – it is made by the first Shorebird release (release.yml / beta.yml)."; exit 1; fi
  rm -f "$D/patch-public.pem" "$D/patch-private.pem"
  openssl genrsa -out "$D/patch-private.pem" 2048 2>/dev/null
  openssl pkey -in "$D/patch-private.pem" -pubout -out "$D/patch-public.pem"
  [ "$(put shorebird-patch-private.pem "$D/patch-private.pem")" = "200" ] || { echo "::error::Could not keep the patch-signing key: $(head -c 200 "$D/put.json")"; exit 1; }
  [ "$(put shorebird-patch-public.pem "$D/patch-public.pem")" = "200" ] || { echo "::error::Could not keep shorebird-patch-public.pem: $(head -c 200 "$D/put.json")"; exit 1; }
  echo "::notice::A NEW patch-signing key was made and kept in the private bucket app-keys. Download a copy from Supabase and keep it offline."
fi
has_pub || { echo "::error::The public patch-signing key is not a PEM public key."; exit 1; }
if [ -n "$WANT_PRIVATE" ]; then
  has_priv || { [ "$(get shorebird-patch-private.pem "$D/patch-private.pem")" = "200" ] && has_priv; } || { echo "::error::The private patch-signing key could not be read."; exit 1; }
else
  rm -f "$D/patch-private.pem"      # a release needs only the public one
fi
rm -f "$D/put.json"
