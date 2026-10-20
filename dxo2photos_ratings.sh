#!/usr/bin/env bash
# dxo2photos_ratings.sh — check and sync star ratings with dxo2photos star keywords
#
# dxo2photos stores the DxO star rating as an IPTC keyword "0*" … "5*". This
# tool checks existing images for a star rating, a star keyword, or both, and
# can derive the missing one from the other.
#
#   Star rating:  XMP-xmp:Rating (preferred) or EXIF IFD0:Rating
#   Star keyword: IPTC:Keywords entry "0*" … "5*"
#
# Runtime dependency: exiftool (brew install exiftool). Run with --help for usage.
# Compatible with the bash 3.2 that ships with macOS.

set -u -o pipefail
set -f   # no globbing: star keywords like 4* must stay literal

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PROG=$(basename "$0")
EXTENSIONS="jpg jpeg tif tiff dng"   # scanned in directories (HEIC cannot hold IPTC)
FS=$'\x1f'                           # field separator in exiftool output
LS=$'\x1e'                           # keyword list separator in exiftool output
READ_FORMAT="\${Error}${FS}\${XMP-xmp:Rating}${FS}\${IFD0:Rating}${FS}\${IPTC:Keywords}${FS}\${Directory}/\${FileName}"
RATING_DELETE_ARGS=(-XMP-xmp:Rating= -IFD0:Rating= -IFD0:RatingPercent= -XMP-microsoft:RatingPercent=)
KEYWORD_DELETE_ARGS=("-IPTC:Keywords-=0*" "-IPTC:Keywords-=1*" "-IPTC:Keywords-=2*"
                     "-IPTC:Keywords-=3*" "-IPTC:Keywords-=4*" "-IPTC:Keywords-=5*")

usage() {
    cat <<EOF
Usage: $PROG [options] PATH...

Checks images for a star rating and a dxo2photos star keyword (0* … 5*).
PATH is an image file or a directory. In directories, JPEG, TIFF and DNG
files are checked; add -r to include subdirectories.

Options:
  -r, --recursive  also check images in subdirectories
  -m, --modify     write the missing value: star keyword from the star
                   rating, or star rating from the star keyword
  -d, --delete     with --modify: after writing, delete the original value
                   (star rating → keyword only, keyword → star rating only)
  -k, --keep WHAT  with --modify: leave only WHAT in every file, where WHAT
                   is "stars" or "keyword". Writes it where it is missing and
                   deletes the other value, also in OK files.
                   Cannot be combined with --delete.
  -b, --backup     with --modify: keep each original as FILE_original
  -q, --quiet      list only files that need changes or have problems
  -h, --help       show this help

Status per file:
  OK        star rating and star keyword present and equal
  STARS     star rating only                    --modify adds the keyword
  KEYWORD   star keyword only                   --modify adds the star rating
  NONE      neither
  CONFLICT  star rating and keyword differ, several star keywords, or XMP
            and EXIF ratings differ             never modified
  INVALID   rating outside 0–5 (e.g. -1 = rejected)  never modified
  ERROR     file could not be read or written

Star ratings are written to XMP-xmp:Rating and EXIF IFD0:Rating, keywords to
IPTC:Keywords. File modification dates are preserved.

Exit status: 0 no problems, 1 conflicts, invalid ratings or errors, 2 usage error.
EOF
}

die_usage() {
    echo "$PROG: $1" >&2
    echo "Try '$PROG --help'." >&2
    exit 2
}

# ── Options ───────────────────────────────────────────────────────────────────

recursive=0 modify=0 delete=0 backup=0 quiet=0 keep=""
paths=()
while [ $# -gt 0 ]; do
    case "$1" in
        -r|--recursive) recursive=1 ;;
        -m|--modify)    modify=1 ;;
        -d|--delete)    delete=1 ;;
        -k|--keep)      [ $# -ge 2 ] && [ -n "$2" ] || die_usage "$1 needs a value: stars or keyword"
                        keep=$2; shift ;;
        --keep=*)       keep=${1#--keep=}
                        [ -n "$keep" ] || die_usage "--keep needs a value: stars or keyword" ;;
        -b|--backup)    backup=1 ;;
        -q|--quiet)     quiet=1 ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done; break ;;
        -[a-z][a-z]*)   # combined short options, e.g. -rm
                        opts=${1#-}; shift; expanded=()
                        while [ -n "$opts" ]; do expanded+=("-${opts:0:1}"); opts=${opts:1}; done
                        set -- "${expanded[@]}" "$@"
                        continue ;;
        -*)             die_usage "unknown option: $1" ;;
        *)              paths+=("$1") ;;
    esac
    shift
done

[ ${#paths[@]} -gt 0 ] || die_usage "no file or directory given"
[ $delete -eq 0 ] || [ $modify -eq 1 ] || die_usage "--delete requires --modify"
[ $backup -eq 0 ] || [ $modify -eq 1 ] || die_usage "--backup requires --modify"
case "$keep" in
    ""|stars|keyword) ;;
    *) die_usage "invalid value for --keep: '$keep' (use stars or keyword)" ;;
esac
[ -z "$keep" ] || [ $modify -eq 1 ] || die_usage "--keep requires --modify"
[ -z "$keep" ] || [ $delete -eq 0 ] || die_usage "--keep cannot be combined with --delete"
# strip: delete the original value after writing the other one
if [ $delete -eq 1 ] || [ -n "$keep" ]; then strip=1; else strip=0; fi

if ! command -v exiftool >/dev/null 2>&1; then
    echo "$PROG: exiftool not found. Install it with: brew install exiftool" >&2
    exit 2
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dxo2photos_ratings.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────

for s in OK STARS KEYWORD NONE CONFLICT INVALID ERROR; do eval "n_$s=0"; done
count() { eval "n_$1=\$(( n_$1 + 1 ))"; }

show() {  # STATUS STARS KEYWORD PATH [NOTE]
    printf '%-8s  %-5s  %-7s  %s%s\n' "$1" "${2:--}" "${3:--}" "$4" "${5:+  – $5}"
}

# Reads metadata of all files listed in $1 (one per line) into $2; errors go to $3.
read_meta() {
    exiftool -q -q -m -sep "$LS" -p "$READ_FORMAT" -@ "$1" > "$2" 2> "$3"
}

# Prints exiftool "Error: MESSAGE - FILE" lines from $1 as ERROR entries.
show_exiftool_errors() {
    local line msg
    while IFS= read -r line; do
        case "$line" in
            Error:*) msg=${line#Error: }
                     show ERROR "" "" "${msg#* - }" "${msg%% - *}"
                     count ERROR ;;
            ?*)      echo "$line" >&2 ;;
        esac
    done < "$1"
}

# classify XMP_RATING EXIF_RATING KEYWORDS → sets C_STATUS, C_STARS, C_KW, C_NOTE
classify() {
    local xmp=$1 exif=$2 kws=$3 k IFS=$LS
    C_STATUS="" C_STARS="" C_KW="" C_NOTE=""

    for k in $kws; do   # distinct star keywords, space separated
        case "$k" in
            [0-5]\*) case " $C_KW " in *" $k "*) ;; *) C_KW="${C_KW:+$C_KW }$k" ;; esac ;;
        esac
    done

    if [ -n "$xmp" ] && [ -n "$exif" ] && [ "$xmp" != "$exif" ]; then
        C_STARS="$xmp/$exif" C_STATUS=CONFLICT C_NOTE="XMP rating $xmp, EXIF rating $exif"
        return
    fi
    C_STARS=${xmp:-$exif}

    case "$C_KW" in
        *" "*) C_STATUS=CONFLICT C_NOTE="several star keywords"; return ;;
    esac
    case "$C_STARS" in
        ""|[0-5]) ;;
        *) C_STATUS=INVALID C_NOTE="rating $C_STARS has no star keyword"; return ;;
    esac

    if   [ -z "$C_STARS" ] && [ -z "$C_KW" ]; then C_STATUS=NONE
    elif [ -z "$C_KW" ];                     then C_STATUS=STARS
    elif [ -z "$C_STARS" ];                  then C_STATUS=KEYWORD
    elif [ "$C_KW" = "$C_STARS*" ];          then C_STATUS=OK
    else C_STATUS=CONFLICT C_NOTE="star rating and keyword differ"
    fi
}

# ── Collect files ─────────────────────────────────────────────────────────────

filelist="$tmp/files.lst"
: > "$filelist"
name_expr=()
for e in $EXTENSIONS; do
    [ ${#name_expr[@]} -eq 0 ] || name_expr+=(-o)
    name_expr+=(-iname "*.$e")
done
if [ $recursive -eq 1 ]; then maxdepth=""; else maxdepth=1; fi

arg_errors=0
for p in "${paths[@]}"; do
    case "$p" in
        *.photoslibrary|*.photoslibrary/*)
            if [ $modify -eq 1 ]; then
                echo "$PROG: refusing to modify files inside a Photos library: $p" >&2
                exit 2
            fi ;;
    esac
    if [ -d "$p" ]; then
        d=$p
        while [ "$d" != "/" ] && [ "${d%/}" != "$d" ]; do d=${d%/}; done
        # Skip hidden entries and Photos libraries found below the given directory.
        find -H "$d" -mindepth 1 ${maxdepth:+-maxdepth "$maxdepth"} \
            \( -type d \( -name '.*' -o -name '*.photoslibrary' \) -prune \) -o \
            \( -type f ! -name '.*' \( "${name_expr[@]}" \) -print \) >> "$filelist"
    elif [ -f "$p" ]; then
        # Keep a directory part so exiftool never mistakes the name for an option.
        case "$p" in */*) printf '%s\n' "$p" ;; *) printf './%s\n' "$p" ;; esac >> "$filelist"
    else
        echo "$PROG: not found: $p" >&2
        arg_errors=$((arg_errors + 1))
    fi
done
sort -u -o "$filelist" "$filelist"
total=$(wc -l < "$filelist" | tr -d ' ')

if [ "$total" -eq 0 ]; then
    echo "No image files found."
    [ $arg_errors -eq 0 ] && exit 0 || exit 1
fi

# ── Check ─────────────────────────────────────────────────────────────────────

read_meta "$filelist" "$tmp/read.out" "$tmp/read.err"

show STATUS STARS KEYWORD FILE
while IFS=$FS read -r err xmp exif kws path; do
    if [ -n "$err" ]; then
        show ERROR "" "" "$path" "$err"
        count ERROR
        continue
    fi
    classify "$xmp" "$exif" "$kws"
    count "$C_STATUS"
    note=$C_NOTE
    if [ $modify -eq 1 ]; then
        case "$C_STATUS:$keep" in
            STARS:stars|KEYWORD:keyword) ;;   # already in the requested state
            STARS:*)   printf '%s\n' "$path" >> "$tmp/kw_$C_STARS.lst"
                       note="add keyword $C_STARS*"
                       [ $strip -eq 0 ] || note="$note, delete star rating" ;;
            KEYWORD:*) n=${C_KW%\*}
                       printf '%s\n' "$path" >> "$tmp/rt_$n.lst"
                       note="add star rating $n"
                       [ $strip -eq 0 ] || note="$note, delete keyword" ;;
            OK:stars)  printf '%s\n' "$path" >> "$tmp/del_kw.lst"
                       note="delete keyword" ;;
            OK:keyword) printf '%s\n' "$path" >> "$tmp/del_rt.lst"
                       note="delete star rating" ;;
        esac
    fi
    if [ $quiet -eq 1 ] && [ -z "$note" ]; then   # nothing to do for this file
        case $C_STATUS in
            OK|NONE)       continue ;;
            STARS|KEYWORD) [ $modify -eq 0 ] || continue ;;
        esac
    fi
    show "$C_STATUS" "$C_STARS" "$C_KW" "$path" "$note"
done < "$tmp/read.out"
show_exiftool_errors "$tmp/read.err"

# ── Modify ────────────────────────────────────────────────────────────────────

written=0 write_failed=0
if [ $modify -eq 1 ]; then
    write_opts=(-q -P)
    [ $backup -eq 1 ] || write_opts+=(-overwrite_original_in_place)

    # write_group LIST EXPECTED_STATUS EXIFTOOL_ARGS...
    # Writes all files in LIST, then re-reads them to confirm the new state.
    write_group() {
        local lst=$1 want=$2 err xmp exif kws path verified=0 listed
        shift 2
        exiftool "${write_opts[@]}" "$@" -@ "$lst" 2> "$tmp/write.err"
        sed 's/^/exiftool: /' "$tmp/write.err" >&2   # details; failures are listed below
        read_meta "$lst" "$tmp/verify.out" "$tmp/verify.err"
        while IFS=$FS read -r err xmp exif kws path; do
            classify "$xmp" "$exif" "$kws"
            if [ -z "$err" ] && [ "$C_STATUS" = "$want" ]; then
                written=$((written + 1))
            else
                show ERROR "$C_STARS" "$C_KW" "$path" "write failed, status now ${err:-$C_STATUS}"
                write_failed=$((write_failed + 1))
            fi
            verified=$((verified + 1))
        done < "$tmp/verify.out"
        listed=$(wc -l < "$lst" | tr -d ' ')
        write_failed=$((write_failed + listed - verified))
    }

    for n in 0 1 2 3 4 5; do
        lst="$tmp/kw_$n.lst"
        if [ -s "$lst" ]; then
            if [ $strip -eq 1 ]; then
                write_group "$lst" KEYWORD "-IPTC:Keywords-=$n*" "-IPTC:Keywords+=$n*" "${RATING_DELETE_ARGS[@]}"
            else
                write_group "$lst" OK "-IPTC:Keywords-=$n*" "-IPTC:Keywords+=$n*"
            fi
        fi
        lst="$tmp/rt_$n.lst"
        if [ -s "$lst" ]; then
            if [ $strip -eq 1 ]; then
                write_group "$lst" STARS "-XMP-xmp:Rating=$n" "-IFD0:Rating=$n" "-IPTC:Keywords-=$n*"
            else
                write_group "$lst" OK "-XMP-xmp:Rating=$n" "-IFD0:Rating=$n"
            fi
        fi
    done
    # --keep: OK files lose the other value
    [ ! -s "$tmp/del_kw.lst" ] || write_group "$tmp/del_kw.lst" STARS "${KEYWORD_DELETE_ARGS[@]}"
    [ ! -s "$tmp/del_rt.lst" ] || write_group "$tmp/del_rt.lst" KEYWORD "${RATING_DELETE_ARGS[@]}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

summary=""
for s in OK STARS KEYWORD NONE CONFLICT INVALID ERROR; do
    eval "c=\$n_$s"
    [ "$c" -eq 0 ] || summary="${summary:+$summary, }$c $s"
done
echo
echo "Checked $total files: $summary"
if [ $modify -eq 1 ]; then
    echo "Modified $written files."
    [ $write_failed -eq 0 ] || echo "Failed to modify $write_failed files (see ERROR lines above)."
    if [ $delete -eq 1 ] && [ "$n_OK" -gt 0 ]; then
        echo "$n_OK files have both a star rating and a keyword and were left unchanged."
        echo "Use --keep stars or --keep keyword to remove one of them."
    fi
elif [ $((n_STARS + n_KEYWORD)) -gt 0 ]; then
    echo "Run with --modify to add the missing values."
fi

problems=$((n_CONFLICT + n_INVALID + n_ERROR + write_failed + arg_errors))
[ $problems -eq 0 ] && exit 0 || exit 1
