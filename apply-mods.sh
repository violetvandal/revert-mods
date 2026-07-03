#!/usr/bin/env bash
#
# apply-mods.sh — apply the THUG2 mod layer onto an install.
#
#   ./apply-mods.sh <install-dir> [--layer binary|source|all] [--only name,name]
#
# <install-dir> is a THUG2 install root (contains Data/pre/). Mods listed in mods.list
# are applied in order. Each mod is a directory with a mod.conf describing how it applies:
#
#   type=prx-overlay   layer=binary   — copy this mod's Data/ tree over <install>/Data/
#                                        (drops prebuilt .prx; embeds game data → PRIVATE)
#   type=prx-inject    layer=source   — inject authored blobs into the user's OWN base .prx
#                                        via prx.py (ships only your content → SHAREABLE).
#                                        Reads the mod's inject.list:
#                                          <archive-under-Data/pre>  <internal-name>  <blob-file>
#   type=overlay       layer=source   — copy this mod's Data/ tree over <install>/Data/
#                                        (whole-file content you authored, e.g. textures)
#
# By default applies all layers; the public installer passes --layer source (binary/ is
# gitignored and absent in the published repo).
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRX="$HERE/lib/prx.py"
NS="${NS:-$HERE/lib/ns}"   # NeverScript compiler (for source/ns-inject mods)

log()  { printf '\033[1;34m[mods]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[mods:warn]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[mods:error]\033[0m %s\n' "$*" >&2; exit 1; }

INSTALL=""; LAYER="all"; ONLY=""
while [[ $# -gt 0 ]]; do case "$1" in
  --layer) LAYER="$2"; shift 2;;
  --only)  ONLY=",$2,"; shift 2;;
  -h|--help) sed -n '2,/^set -euo/p' "$0" | sed 's/^#\s\?//; s/^set -euo.*//'; exit 0;;
  *) INSTALL="$1"; shift;;
esac; done

[[ -n "$INSTALL" ]] || err "Usage: apply-mods.sh <install-dir> [--layer binary|source|all]"
DATA="$INSTALL/Data"; [[ -d "$DATA/pre" ]] || DATA="$INSTALL"   # allow passing Data/ directly
[[ -d "$DATA/pre" ]] || err "Not a THUG2 install (no Data/pre/): $INSTALL"
command -v python3 >/dev/null || err "python3 required for the source (prx-inject) layer"
[[ -f "$HERE/mods.list" ]] || err "no mods.list next to apply-mods.sh"

want_layer() { [[ "$LAYER" == all || "$LAYER" == "$1" ]]; }

apply_one() {
  local mod="$1" dir conf type layer
  for base in "$HERE/packs" "$HERE/src"; do [[ -d "$base/$mod" ]] && dir="$base/$mod"; done
  [[ -n "${dir:-}" ]] || { warn "mod '$mod' not found in packs/ or src/ — skipping (ok if it's the gitignored binary layer)"; return; }
  conf="$dir/mod.conf"; [[ -f "$conf" ]] || err "mod '$mod' has no mod.conf"
  type="$(sed -n 's/^type=//p' "$conf" | head -1)"
  layer="$(sed -n 's/^layer=//p' "$conf" | head -1)"
  want_layer "${layer:-binary}" || { log "skip $mod (layer=$layer, want=$LAYER)"; return; }

  case "$type" in
    prx-overlay|overlay)
      [[ -d "$dir/Data" ]] || err "$mod: type=$type but no Data/ tree"
      log "apply $mod  ($type, $layer)"
      cp -a --no-preserve=mode "$dir/Data/." "$DATA/"
      ;;
    prx-inject)
      [[ -f "$dir/inject.list" ]] || err "$mod: type=prx-inject but no inject.list"
      log "apply $mod  (prx-inject, $layer)"
      local archive name blob tmp tgt
      while read -r archive name blob; do
        [[ -z "$archive" || "$archive" == \#* ]] && continue
        tgt="$DATA/pre/$archive"
        [[ -f "$tgt" ]] || err "  base archive missing: $tgt"
        [[ -f "$dir/$blob" ]] || err "  blob missing: $dir/$blob"
        tmp="$(mktemp)"
        python3 "$PRX" replace "$tgt" "$name" "$dir/$blob" "$tmp" >/dev/null \
          || err "  prx.py replace failed: $archive :: $name"
        mv "$tmp" "$tgt"
        log "  injected $blob -> $archive :: $name"
      done < "$dir/inject.list"
      ;;
    ns-inject)
      # True source: compile a NeverScript .ns with `ns`, then inject the .qb into the
      # user's own base archive via prx.py. inject.list columns:
      #   <archive-under-Data/pre>   <internal-name>   <ns-source-file-in-this-mod>
      [[ -f "$dir/inject.list" ]] || err "$mod: type=ns-inject but no inject.list"
      [[ -x "$NS" ]] || err "$mod: ns-inject needs the NeverScript compiler at $NS (set NS=...)"
      log "apply $mod  (ns-inject, $layer)"
      local archive name nssrc tmpqb tmp tgt
      while read -r archive name nssrc; do
        [[ -z "$archive" || "$archive" == \#* ]] && continue
        tgt="$DATA/pre/$archive"
        [[ -f "$tgt" ]] || err "  base archive missing: $tgt"
        [[ -f "$dir/$nssrc" ]] || err "  ns source missing: $dir/$nssrc"
        tmpqb="$(mktemp --suffix=.qb)"; tmp="$(mktemp)"
        "$NS" -c "$dir/$nssrc" -o "$tmpqb" >/dev/null 2>&1 \
          || err "  ns compile failed: $nssrc"
        # qb_scripts.prx has a hard load-size ceiling (~1.43 MB): a fresh boot
        # black-screens if the archive grows too large. Inject its entries
        # COMPRESSED (replacez, LZSS — the stock format, decompressed by the
        # loader) so several script mods + chapter_info fit. Other archives have
        # headroom, so store them uncompressed (replace) as before.
        local op=replace
        [[ "$archive" == qb_scripts.prx ]] && op=replacez
        python3 "$PRX" "$op" "$tgt" "$name" "$tmpqb" "$tmp" >/dev/null \
          || err "  prx.py $op failed: $archive :: $name"
        mv "$tmp" "$tgt"; rm -f "$tmpqb"
        log "  compiled+injected $nssrc -> $archive :: $name ($op)"
      done < "$dir/inject.list"
      ;;
    *) err "$mod: unknown type '$type'";;
  esac
}

log "target: $DATA   layer: $LAYER"
n=0
while read -r mod; do
  [[ -z "$mod" || "$mod" == \#* ]] && continue
  [[ -n "$ONLY" && "$ONLY" != *",$mod,"* ]] && continue
  apply_one "$mod"; n=$((n+1))
done < "$HERE/mods.list"
log "done — processed $n mod entr$([[ $n == 1 ]] && echo y || echo ies)."
