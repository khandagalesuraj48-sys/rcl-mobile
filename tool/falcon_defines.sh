#!/usr/bin/env bash
# (3.171.0) FALCON inside this app – the build's settings for it (GitHub → rcl-mobile → Settings → Secrets and variables → Actions →
# Variables, the same values as in FALCONAPK): FALCON_SUPABASE_URL, FALCON_SUPABASE_KEY (the PUBLISHABLE key – public by design),
# FALCON_SERVER. Prints the --dart-define flags, or nothing when they are not set (the Mess card then opens FALCON's web, as before).
# A SECRET key stops the build – it must never be inside an app.
set -euo pipefail
u="${FALCON_SUPABASE_URL:-}"; k="${FALCON_SUPABASE_KEY:-}"; s="${FALCON_SERVER:-}"
if [ -z "$u" ] || [ -z "$k" ]; then echo "::warning::FALCON_SUPABASE_URL / FALCON_SUPABASE_KEY not set – FALCON opens on its web from the Mess card." >&2; exit 0; fi
case "$k" in sb_secret_*) echo "::error::FALCON_SUPABASE_KEY is a SECRET key – give the publishable key (sb_publishable_…)." >&2; exit 1;; esac
if printf '%s' "$k" | cut -d. -f2 | base64 -d 2>/dev/null | grep -q '"service_role"'; then echo "::error::FALCON_SUPABASE_KEY is the service_role key – give the publishable key." >&2; exit 1; fi
printf -- '--dart-define=FALCON_SUPABASE_URL=%s --dart-define=FALCON_SUPABASE_KEY=%s' "$u" "$k"
[ -n "$s" ] && printf -- ' --dart-define=FALCON_SERVER=%s' "$s"
echo
