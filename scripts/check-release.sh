#!/usr/bin/env bash
# Release checks for Hereabouts.
#
#   scripts/check-release.sh                 checks the repository
#   scripts/check-release.sh path/to/X.app   checks a built app, plus the source settings it was built from
#
# Fails unless: the free plan holds 15 things and 1 packing kit, the App Group matches project.yml,
# every bundle (the app and each extension) carries a PrivacyInfo.xcprivacy, and the licence texts
# for both typefaces (Atkinson Hyperlegible and Fraunces) are present.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-}"
WANT_THINGS=15
WANT_KITS=1
failures=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }

if [[ -n "$APP" && ! -d "$APP" ]]; then
    echo "No app bundle at $APP" >&2
    exit 2
fi

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }
yml_setting() { sed -n "s/^ *$1: *'\{0,1\}\([^']*\)'\{0,1\} *$/\1/p" "$ROOT/project.yml" | head -1; }

# 1. Free thing limit.
if [[ -n "$APP" ]]; then
    things="$(plist_value "$APP/Info.plist" HereaboutsFreeThings)"; where="HereaboutsFreeThings in the app"
else
    things="$(yml_setting HEREABOUTS_FREE_THINGS)"; where="HEREABOUTS_FREE_THINGS in project.yml"
fi
if [[ "$things" == "$WANT_THINGS" ]]; then pass "free thing limit is $WANT_THINGS ($where)"
else fail "free thing limit is '${things:-missing}', want $WANT_THINGS ($where)"; fi

# 2. Free kit limit (compiled in, so read from source).
kits="$(sed -n 's/.*case \.kit: *\([0-9][0-9]*\).*/\1/p' "$ROOT/Localiser/Purchases/ProAccess.swift" | head -1)"
if [[ "$kits" == "$WANT_KITS" ]]; then pass "free kit limit is $WANT_KITS (ProAccess.swift)"
else fail "free kit limit is '${kits:-missing}', want $WANT_KITS (ProAccess.swift)"; fi

# 3. App Group is what project.yml intends, in the Info.plist value and the entitlements.
intended="$(yml_setting HEREABOUTS_APP_GROUP)"
if [[ -n "$APP" ]]; then
    actual="$(plist_value "$APP/Info.plist" HereaboutsAppGroup)"
    entitled="$(codesign -d --entitlements :- "$APP" 2>/dev/null | plutil -extract 'com\.apple\.security\.application-groups' xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | tr '\n' ' ' | sed 's/ $//')"
    # Simulator builds keep their entitlements inside the binary, where codesign can't print them.
    if [[ -z "$entitled" && "$(plist_value "$APP/Info.plist" DTPlatformName)" == "iphonesimulator" ]]; then
        entitled="$(plutil -extract 'com\.apple\.security\.application-groups' xml1 -o - "$ROOT/Localiser/Localiser.entitlements" 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | tr '\n' ' ' | sed 's/ $//')"
    fi
else
    actual="$intended"
    entitled="$(plutil -extract 'com\.apple\.security\.application-groups' xml1 -o - "$ROOT/Localiser/Localiser.entitlements" 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | tr '\n' ' ' | sed 's/ $//')"
fi
if [[ "$actual" == "$intended" && "$entitled" == "$intended" ]]; then
    pass "App Group is '${intended:-off}' as project.yml intends"
else
    fail "App Group: project.yml wants '${intended:-off}', Info.plist has '${actual:-off}', entitlements have '${entitled:-none}'"
fi

# 4. A privacy manifest in every bundle.
if [[ -n "$APP" ]]; then
    bundles=("$APP")
    for ext in "$APP"/PlugIns/*.appex "$APP"/Extensions/*.appex; do [[ -d "$ext" ]] && bundles+=("$ext"); done
    for bundle in "${bundles[@]}"; do
        name="$(basename "$bundle")"
        if [[ -f "$bundle/PrivacyInfo.xcprivacy" ]]; then pass "privacy manifest in $name"
        else fail "no PrivacyInfo.xcprivacy in $name"; fi
    done
else
    # Targets that ship a bundle: the application and every app-extension in project.yml. Each
    # target's first source folder is named after it.
    targets="$(awk '
        /^targets:/ { in_targets = 1; next }
        in_targets && /^[^ ]/ { in_targets = 0 }
        in_targets && /^  [A-Za-z0-9_]+:$/ { name = $1; sub(":", "", name) }
        in_targets && /^    type: *(application|app-extension)/ { print name }
    ' "$ROOT/project.yml")"
    for target in $targets; do
        if [[ -f "$ROOT/$target/PrivacyInfo.xcprivacy" ]]; then pass "privacy manifest for $target"
        else fail "no $target/PrivacyInfo.xcprivacy"; fi
    done
fi

# 5. Licence texts for both typefaces.
search_dir="${APP:-$ROOT/Localiser}"
for font in "Atkinson Hyperlegible" "Fraunces"; do
    found=""
    while IFS= read -r -d '' file; do
        base="$(basename "$file" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
        key="$(echo "$font" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
        if grep -qi "${font}" "$file" 2>/dev/null || [[ "$base" == *"$key"* ]]; then
            found="$file"; break
        fi
    done < <(find "$search_dir" -type f \( -iname '*licen[cs]e*' -o -iname '*OFL*' \) -print0 2>/dev/null)
    if [[ -n "$found" ]]; then pass "licence text for $font (${found#"$search_dir"/})"
    else fail "no licence text for $font in ${search_dir#"$ROOT"/}"; fi
done

echo
if (( failures == 0 )); then echo "All release checks passed."; exit 0
else echo "$failures release check(s) failed."; exit 1; fi
