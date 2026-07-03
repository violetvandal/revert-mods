#!/usr/bin/env bash
#
# apply-widescreen.sh — apply WidescreenFixesPack (ThirteenAG) to a no-CD/WSFix THUG2 install.
#
#   ./apply-widescreen.sh <install-dir> <TonyHawksUnderground2.WidescreenFix.zip>
#
# Installs the Ultimate ASI Loader as winmm.dll (NOT dinput8.dll — that would break native
# controller enumeration under Wine) plus scripts/TonyHawksUnderground2.WidescreenFix.{asi,ini}.
# The default .ini auto-detects resolution (ResX/ResY = 0) and fixes HUD + FOV.
#
# NOTE: This is for the no-CD + WSFix runtime only. PARTYMOD installs already provide
# widescreen and explicitly want NO winmm/dinput8 WSFix — this script refuses if it sees
# THUG2PM.exe. Also ensure the Wine prefix has: winmm = native,builtin
#   WINEPREFIX=... wine reg add 'HKCU\Software\Wine\DllOverrides' /v winmm /d native,builtin /f
#
set -euo pipefail
log()  { printf '\033[1;34m[widescreen]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[widescreen:error]\033[0m %s\n' "$*" >&2; exit 1; }

INSTALL="${1:-}"; ZIP="${2:-}"
[[ -n "$INSTALL" && -n "$ZIP" ]] || err "Usage: apply-widescreen.sh <install-dir> <WidescreenFix.zip>"
[[ -f "$INSTALL/THUG2.exe" ]] || err "not a THUG2 install (no THUG2.exe): $INSTALL"
[[ -f "$INSTALL/THUG2PM.exe" ]] && err "PARTYMOD install detected (THUG2PM.exe) — it already provides widescreen; don't add WSFix."
[[ -f "$ZIP" ]] || err "WidescreenFix zip not found: $ZIP"
command -v unzip >/dev/null || err "unzip required"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
unzip -q -o "$ZIP" -d "$work"
[[ -f "$work/Game/dinput8.dll" ]] || err "unexpected WSFix layout (no Game/dinput8.dll)"

log "Installing ASI loader as winmm.dll (keeps dinput8 Wine-native for the controller)..."
cp -f "$work/Game/dinput8.dll" "$INSTALL/winmm.dll"
mkdir -p "$INSTALL/scripts"
cp -f "$work/Game/scripts/"*.asi "$work/Game/scripts/"*.ini "$INSTALL/scripts/"
log "Done — WSFix .asi + .ini installed (ResX/ResY=0 auto-detects; FixHUD/FixFOV on)."
log "Reminder: prefix needs  winmm = native,builtin  in HKCU\\Software\\Wine\\DllOverrides."
