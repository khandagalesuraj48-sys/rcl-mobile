#!/usr/bin/env bash
# (asked 21-11-2026: "old link warun click kel tewa old application yet … tya link war gel ki nehmi latest apk ch download hoil")
# AN OLD RELEASE'S PAGE SAYS SO: every published release older than the newest stable one gets, once, two lines at the top of its
# page – "an old version; the latest is always at <the app's own page>". Nothing is deleted, no file is touched; a page that has the
# lines already is left alone. The newest stable release and the Beta versions after it stay as they are (the apps read those).
# Needs: gh (GH_TOKEN), GITHUB_REPOSITORY.     bash tool/mark_old_releases.sh
set -euo pipefail
REPO="${GITHUB_REPOSITORY:?}"; PAGE="${APP_PAGE:-https://oneclicksolution-erp.vercel.app/app}"; MARK='<!-- rcl-old -->'
LATEST=$(gh api "repos/$REPO/releases/latest" -q '.id')
NOTE="$MARK
> ⚠️ **This is an OLD version.** Always download the latest app here: **$PAGE**
> ⚠️ **हे जुनं version आहे.** नवीन app नेहमी इथून घ्या: **$PAGE**
> ⚠️ **यह पुराना version है.** नया app हमेशा यहाँ से लें: **$PAGE**
"
n=0; seen=0
while read -r id; do
  if [ "$id" = "$LATEST" ]; then seen=1; continue; fi
  [ "$seen" = 1 ] || continue                      # (the list is newest first: before the newest stable one = the Beta versions after it)
  body=$(gh api "repos/$REPO/releases/$id" -q '.body // ""')
  case "$body" in *"$MARK"*) continue ;; esac
  printf '%s\n%s' "$NOTE" "$body" > /tmp/rcl-old-body.md
  gh api -X PATCH "repos/$REPO/releases/$id" -F body=@/tmp/rcl-old-body.md -q '.tag_name' >/dev/null
  n=$((n + 1))
done < <(gh api --paginate "repos/$REPO/releases?per_page=100" -q '.[] | select(.draft | not) | .id')
echo "::notice::Old releases told where the latest is: $n"
