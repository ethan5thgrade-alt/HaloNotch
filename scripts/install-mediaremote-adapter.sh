#!/usr/bin/env bash
#
# Installs the ungive/mediaremote-adapter so HaloNotch can read Now Playing
# from ANY app (browsers, podcast apps, etc.) on macOS 15.4+, where Apple now
# gates the private MediaRemote framework behind a com.apple.* entitlement.
#
# The trick: the system Perl binary (/usr/bin/perl) reports a com.apple.*
# bundle id, so it's allowed to load MediaRemote. We bundle a small Perl script
# + framework and run them through that Perl.
#
# Files land in:  ~/Library/Application Support/HaloNotch/mediaremote-adapter/
# HaloNotch picks them up automatically at launch — no rebuild needed.
#
# NOTE: this is a best-effort convenience script. The adapter repo layout can
# change; if it fails, follow the build steps in that repo's README and copy
# `mediaremote-adapter.pl` + `MediaRemoteAdapter.framework` into the dest dir.

set -euo pipefail

REPO="https://github.com/ungive/mediaremote-adapter.git"
DEST="$HOME/Library/Application Support/HaloNotch/mediaremote-adapter"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Cloning $REPO"
git clone --depth 1 "$REPO" "$TMP/src"

cd "$TMP/src"

echo "==> Locating adapter Perl script"
PL_PATH="$(find . -name 'mediaremote-adapter.pl' -print -quit || true)"
if [[ -z "$PL_PATH" ]]; then
  echo "!! Could not find mediaremote-adapter.pl in the repo. Check the repo README." >&2
  exit 1
fi

echo "==> Locating or building MediaRemoteAdapter.framework"
FW_PATH="$(find . -name 'MediaRemoteAdapter.framework' -type d -print -quit || true)"
if [[ -z "$FW_PATH" ]]; then
  # Try to build it if an Xcode project / scheme is present.
  PROJ="$(find . -name '*.xcodeproj' -maxdepth 2 -print -quit || true)"
  if [[ -n "$PROJ" ]]; then
    echo "   Building framework from $PROJ ..."
    xcodebuild -project "$PROJ" -scheme MediaRemoteAdapter \
      -configuration Release -derivedDataPath "$TMP/dd" build >/dev/null
    FW_PATH="$(find "$TMP/dd" -name 'MediaRemoteAdapter.framework' -type d -print -quit || true)"
  fi
fi
if [[ -z "$FW_PATH" ]]; then
  echo "!! Could not find or build MediaRemoteAdapter.framework. Build it per the repo README" >&2
  echo "   and copy it (plus mediaremote-adapter.pl) into:" >&2
  echo "   $DEST" >&2
  exit 1
fi

echo "==> Installing into $DEST"
mkdir -p "$DEST"
cp "$PL_PATH" "$DEST/mediaremote-adapter.pl"
rm -rf "$DEST/MediaRemoteAdapter.framework"
cp -R "$FW_PATH" "$DEST/MediaRemoteAdapter.framework"

echo "==> Done. Restart HaloNotch (or toggle Now Playing in Settings) to pick it up."
