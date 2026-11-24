#!/usr/bin/env bash
# Start a new HarmonyOS product from this repo's full layered skeleton.
#
#   tools/new-app.sh billing-portal ~/Documents/projects/billing-portal
#   BUNDLE=com.acme.billing tools/new-app.sh billing-portal ~/Documents/projects/billing-portal
#
# Copies the committed tree (git archive HEAD), so the product keeps AGENTS.md, CLAUDE.md,
# tools/ (scaffolding + hook + arch-check), the Jenkinsfile and the arch-qube gate. Creating an
# empty DevEco project and copying a few ets/ folders into it loses all of that (AGENTS.md §1).
#
# No --no-demo option: the template has no demo-only module. The User feature is the worked
# example tools/new-feature.sh anchors on (TYPES.UserService, AppContainer, Routes, tests);
# delete it only after your own features exist, layer by layer, not by flattening.
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <app-name> <dest-dir>" >&2; exit 1; }
APP="$1"
DEST="$2"
[[ "$APP" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]] || { echo "app-name: lower-case letters/digits, words joined by '-' (it becomes the CI, Sonar and storage names)" >&2; exit 1; }
case "$APP" in arcana|arcana-harmonyos|harmonyos-app) echo "app-name must differ from the template's own names" >&2; exit 1 ;; esac
[ ! -e "$DEST" ] || { echo "$DEST already exists — refusing to overwrite" >&2; exit 1; }
command -v perl >/dev/null || { echo "perl is required" >&2; exit 1; }

APP_ID="$(printf '%s' "$APP" | tr -d '-')"                       # billing-portal → billingportal
APP_US="$(printf '%s' "$APP" | tr '-' '_')"                      # → billing_portal
BUNDLE="${BUNDLE:-com.example.${APP_ID}}"
[[ "$BUNDLE" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}$ ]] || { echo "BUNDLE must be a reverse-domain bundleName with ≥3 parts (com.acme.app)" >&2; exit 1; }
TITLE="$(printf '%s' "$APP" | perl -pe 's/(^|-)([a-z])/($1?" ":"").uc($2)/ge')"     # → Billing Portal

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
git -C "$ROOT" diff --quiet HEAD -- AGENTS.md tools/ || echo "note: uncommitted changes in AGENTS.md/tools are NOT copied (git archive HEAD)" >&2

mkdir -p "$DEST"
git -C "$ROOT" archive HEAD | tar -x -C "$DEST"
SRC_SHA="$(git -C "$ROOT" rev-parse --short HEAD)"
cd "$DEST"

# ---- Product identity. Every place the template name is load-bearing:
#  1. bundleName com.arcana.harmonyos (AppScope/app.json5 and the WorkScheduler bundleName in
#     core/scheduling/BackgroundScheduler.ets) — two apps with one bundleName overwrite each
#     other on a device. vendor "Arcana", app_name / descriptions in every string.json.
#  2. Jenkins PROJECT_NAME/APP_NAME and Sonar key "harmonyos-app" + name "HarmonyOS App"
#     (Jenkinsfile, sonar-project.properties), the per-build container arcana-arch-qube-harmonyos-*
#     and the pushgateway project arcana-harmonyos — two products on one Jenkins must not share them.
#  3. On-device storage: preferences 'arcana_users', RDB 'arcana.db' / 'arcana_users.db', HUKS
#     key alias 'arcana_master_key' + AAD 'arcana_aad'; deep-link scheme arcana:// and host
#     arcana.app (two apps claiming one scheme fight over the link).
#  4. npm package arcana-harmonyos-jest (jest runner) and the ohpm descriptions.
# Not renamed on purpose: arcana.boo (registry / arch-qube / build-image host), module name
# "entry" (HarmonyOS convention), Arcana* colour constants in pages (theme names, not identity).
# tools/ is excluded: these scripts describe the template and must keep working in the product.
TEXT_FILES="$(grep -rIl -e arcana -e Arcana -e harmonyos-app -e "HarmonyOS App" . --exclude-dir=.git --exclude-dir=tools --exclude=CHANGELOG.md || true)"
printf '%s\n' "$TEXT_FILES" | xargs perl -pi -e "
    s/com\\.arcana\\.harmonyos/${BUNDLE}/g;
    s/arcana-arch-qube-harmonyos-/${APP}-arch-qube-/g;
    s/\\barcana-harmonyos-jest\\b/${APP}-jest/g;
    s/\\barcana-harmonyos\\b/${APP}/g;
    s/\\bharmonyos-app\\b/${APP}/g;
    s/HarmonyOS App/${TITLE}/g;
    s/Arcana HarmonyOS/${TITLE}/g;
    s/\\barcana_(?=[a-z])/${APP_US}_/g;
    s/'arcana\\.db'/'${APP_US}.db'/g;
    s/SCHEME = 'arcana'/SCHEME = '${APP_ID}'/g;
    s/\\barcana(?=:)/${APP_ID}/g;
    s/\\barcana(?=\\\\?\\.app\\b)/${APP_ID}/g;
    s/\"vendor\": \"Arcana\"/\"vendor\": \"${TITLE}\"/g;
    s/(\"value\": \"[^\"]*)\\bArcana\\b/\${1}${TITLE}/g;
    s/'Arcana'/'${TITLE}'/g;
"
LEFT="$(grep -rInE --exclude-dir=.git --exclude-dir=tools --exclude=CHANGELOG.md "com\\.arcana\\.harmonyos|\\barcana-harmonyos\\b|\\bharmonyos-app\\b|HarmonyOS App|arcana-arch-qube-harmonyos|Arcana HarmonyOS|\\barcana_[a-z]|'arcana\\.db'|\\barcana:|arcana\\\\?\\.app|\"value\": \"[^\"]*\\bArcana\\b|'Arcana'" . || true)"
if [ -n "$LEFT" ]; then
    echo "new-app: template identities still present after rename:" >&2
    printf '%s\n' "$LEFT" | head >&2
    exit 1
fi

# ---- Fresh history: version 0.1.0 (versionCode 1), empty changelog.
rm -f CHANGELOG.md
printf '{\n  ".": "0.1.0"\n}\n' > .release-please-manifest.json
perl -pi -e 's/"versionCode": \d+/"versionCode": 1/; s/"versionName": "[^"]+"/"versionName": "0.1.0"/' AppScope/app.json5
perl -0pi -e "s/(\"name\": \"${APP}-jest\",\\n\\s*\"version\": \")[^\"]+\"/\${1}0.1.0\"/" package.json
perl -0pi -e "s/(\"name\": \"${APP}-jest\",\\n\\s*\"version\": \")[^\"]+\"/\${1}0.1.0\"/g" package-lock.json
grep -q '"version": "0.1.0"' package.json || { echo "new-app: could not reset package.json version" >&2; exit 1; }
grep -q '"versionName": "0.1.0"' AppScope/app.json5 || { echo "new-app: could not reset AppScope/app.json5 version" >&2; exit 1; }

cat >> AGENTS.md <<EOT

## Origin

Created from arcana-harmonyos @ \`${SRC_SHA}\` by \`tools/new-app.sh\` (bundleName \`${BUNDLE}\`;
CI, Sonar, storage, HUKS and deep-link names renamed to \`${APP}\` / \`${APP_ID}\`). The layers, rules
and definition of done above apply unchanged. Replace the User example through
\`entry/src/main/ets/core/di/AppContainer.ets\` and \`core/navigation/Routes.ets\`, not by flattening.
EOT

git init -q
tools/install-hooks.sh >/dev/null
git add -A
# --no-verify only for this import commit: every file counts as "added" here, so the hook
# would judge the template's own legacy imports (e.g. data/local/DataMigration.ets) as new.
# The template itself passes arch-check; every later commit in the product goes through the hook.
git -c user.name="${GIT_AUTHOR_NAME:-new-app}" -c user.email="${GIT_AUTHOR_EMAIL:-new-app@localhost}" \
    commit -q --no-verify -m "chore: start ${APP} from arcana-harmonyos ${SRC_SHA}"

echo "created $DEST (${APP}, ${BUNDLE}) from arcana-harmonyos ${SRC_SHA}; hooks: $(git config core.hooksPath)"
echo "next: cd $DEST && tools/new-feature.sh <Name>"
