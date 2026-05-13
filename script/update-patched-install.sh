#!/bin/zsh
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: script/update-patched-install.sh

Fetch upstream AeroSpace, rebase the local patch branch, rebuild, reinstall,
and relaunch the patched /Applications/AeroSpace.app.

Optional environment variables:
  AEROSPACE_PATCH_BRANCH   Patch branch to rebase and install.
  AEROSPACE_APP_PATH       App bundle to replace.
  AEROSPACE_CLI            CLI link or binary to replace.
  AEROSPACE_BACKUP_ROOT    Directory for install backups.
EOF
  exit 0
fi

script_path="${0:A}"
repo="$(cd "${script_path:h}/.." && pwd -P)"
patch_branch="${AEROSPACE_PATCH_BRANCH:-fix/fullscreen-restore-tiling-state}"
app_path="${AEROSPACE_APP_PATH:-/Applications/AeroSpace.app}"
cli_link="${AEROSPACE_CLI:-/opt/homebrew/bin/aerospace}"
backup_root="${AEROSPACE_BACKUP_ROOT:-"$repo/../aerospace-install-backups"}"

cd "$repo"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "AeroSpace repo has uncommitted changes. Commit or stash them before updating."
  exit 1
fi

git fetch upstream main
git switch main
git merge --ff-only upstream/main
git switch "$patch_branch"
git rebase main
git push --force-with-lease origin "$patch_branch"

source ./script/setup.sh
swift build -c release --product AeroSpaceApp
swift build -c release --product aerospace
release_dir="$(swift build -c release --show-bin-path)"

backup_dir="$backup_root/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
if [ -d "$app_path" ]; then
  ditto "$app_path" "$backup_dir/AeroSpace.app"
fi

if [ -L "$cli_link" ]; then
  raw_cli_target="$(readlink "$cli_link")"
  if [[ "$raw_cli_target" = /* ]]; then
    cli_target="$raw_cli_target"
  else
    cli_target="$(cd "$(dirname "$cli_link")" && cd "$(dirname "$raw_cli_target")" && pwd -P)/$(basename "$raw_cli_target")"
  fi
else
  cli_target="$cli_link"
fi

if [ -f "$cli_target" ]; then
  cp "$cli_target" "$backup_dir/aerospace"
fi

pkill -f '/Applications/AeroSpace.app/Contents/MacOS/AeroSpace' 2>/dev/null || true
pkill -f '/AeroSpaceApp$' 2>/dev/null || true
sleep 1

install -m 755 "$release_dir/AeroSpaceApp" "$app_path/Contents/MacOS/AeroSpace"
install -m 755 "$release_dir/aerospace" "$cli_target"

entitlements="$(mktemp)"
cat > "$entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.get-task-allow</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --sign - --entitlements "$entitlements" "$cli_target"
codesign --force --deep --sign - --entitlements "$entitlements" "$app_path"
rm -f "$entitlements"
xattr -dr com.apple.quarantine "$app_path" 2>/dev/null || true

open "$app_path"
for _ in {1..10}; do
  sleep 1
  if "$cli_link" list-windows --monitor all --count >/dev/null 2>&1; then
    "$cli_link" --version
    echo "Installed patched AeroSpace from $repo"
    echo "Backup saved to $backup_dir"
    exit 0
  fi
done

echo "AeroSpace did not respond after launch."
exit 1
