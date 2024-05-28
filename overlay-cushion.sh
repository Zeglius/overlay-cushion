#!/bin/bash

set -euo pipefail

function _help() {
    cat <<EOF
$(basename "$0") [mount | umount] [--help]
Script to mount a throwaway overlayfs in /home to test programs.
EOF
}

function _mount() {
    [[ $# -lt 1 ]] && { echo >&2 "only 1 arg allowed"; return 1; }

    # shellcheck disable=SC2064
    trap "set $-" RETURN
    set -x

    for SRC in "$@"; do
        # Check if SRC is already an overlay mountpoint.
        # If so, skip it.
        findmnt -t overlay "$SRC" >/dev/null && continue
        declare -A dirs
        dirs=(
            [upper]="/run/user/1000/overlay-cushion/overlay_dirs/${SRC/#\/}/upper"
            [work]="/run/user/1000/overlay-cushion/overlay_dirs/${SRC/#\/}/work"
        )

        mkdir -p "${dirs[@]}"
        sudo mount -t overlay overlay \
            -o lowerdir="$SRC",upperdir="${dirs[upper]}",workdir="${dirs[work]}" \
            "$SRC"
    done
}

function _umount() {
    [[ $# -lt 1 ]] && { echo >&2 "only 1 arg allowed"; return 1; }

    # shellcheck disable=SC2064
    trap "set $-" RETURN
    set -x
    for SRC in "$@"; do
        if findmnt -t overlay "$SRC" >/dev/null; then
            sudo umount --lazy -t overlay "$SRC"
        fi
    done
}

if [[ "$*" =~ --help || $# -lt 1 ]]; then
    _help; exit
fi

readonly -a TOMOUNT=(
    # /etc
    "${HOME}"
)

if [[ "$1" == "mount" ]]; then
    echo "These are the directories that will be overlayed:"
    printf -- '- %s\n' "${TOMOUNT[@]}"
    _mount "${TOMOUNT[@]}"
elif [[ "$1" == "umount" ]]; then
    _umount "${TOMOUNT[@]}"
else
    _help
    exit 1
fi
