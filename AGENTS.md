# Agent Notes

This checkout is Yurii's personal AeroSpace fork used to keep local fixes on top of the original project.

## Repository Layout

- Local repo: `/Users/yuriicherniak/my-projects/AeroSpace`
- Fork remote: `origin` -> `https://github.com/sudo-yurii-cherniak/AeroSpace.git`
- Upstream remote: `upstream` -> `https://github.com/nikitabobko/AeroSpace.git`
- Patch branch: `fix/fullscreen-restore-tiling-state`
- `upstream` push URL is intentionally disabled. Do not push directly to the original repo.

## Current Patch Stack

Keep user-specific/local fixes as commits on `fix/fullscreen-restore-tiling-state`.

The first patch preserves tiling order and sibling weights when windows leave and return from macOS native fullscreen/minimized/hidden states. It was created for a YouTube/browser fullscreen regression where Telegram stayed on the right but became too wide after exiting fullscreen.

## Add A New Local Fix

```bash
cd /Users/yuriicherniak/my-projects/AeroSpace
git switch fix/fullscreen-restore-tiling-state
git status --short
# edit files
git add <files>
git commit -m "Describe the AeroSpace fix"
git push
```

Prefer small commits, one behavior fix per commit. Keep unrelated refactors out of this branch unless needed for the fix.

## Pull Original AeroSpace Updates

Use the repo script:

```bash
/Users/yuriicherniak/my-projects/AeroSpace/script/update-patched-install.sh
```

The script fetches `upstream/main`, fast-forwards local `main`, rebases `fix/fullscreen-restore-tiling-state` onto it, force-pushes the rebased patch branch to the fork with lease, rebuilds AeroSpace, backs up the installed app/CLI, reinstalls the patched build, and relaunches `/Applications/AeroSpace.app`.

The old convenience path is a symlink to the same script:

```bash
/Users/yuriicherniak/my-projects/update-patched-aerospace.sh
```

## Build And Install

Manual build commands:

```bash
cd /Users/yuriicherniak/my-projects/AeroSpace
source ./script/setup.sh
swift build -c release --product AeroSpaceApp
swift build -c release --product aerospace
```

The installed patched app is `/Applications/AeroSpace.app`. The installed CLI resolves through `/opt/homebrew/bin/aerospace`.

The install script signs locally with ad-hoc signing. macOS may require re-allowing AeroSpace in Accessibility after a reinstall or reboot. A Homebrew `brew upgrade aerospace` can overwrite the patched install; rerun the script afterward.

## Testing Notes

Useful checks:

```bash
git diff --check
source ./script/setup.sh
swift build --product AeroSpaceApp
swift build -c release --product AeroSpaceApp
swift build -c release --product aerospace
/opt/homebrew/bin/aerospace --version
/opt/homebrew/bin/aerospace list-windows --monitor all --count
```

`swift test` may fail on this machine if only Command Line Tools are installed because `XCTest` is unavailable. Do not treat that environment failure as proof the patch is broken; verify with build commands and focused manual testing.

