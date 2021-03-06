#!/bin/bash -e

# ostree-push.sh - Push OSTree commits to a remote repo using sshfs
# Copyright (C) 2016  Dan Nicholson <nicholson@endlessm.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

ARGS=$(getopt -n "$0" \
              -o uvh \
              -l repo:,update,gpg-sign:,gpg-homedir:,verbose,debug,help \
              -- "$@")
eval set -- "$ARGS"

usage() {
    cat <<EOF
Usage: $0 [OPTION]... REMOTE [REF]...
Push OSTree REFs to REMOTE

  --repo=PATH			path to OSTree repository
  -u, --update			update the summary file
  --gpg-sign=KEY-ID		GPG key ID to sign the summary with
  --gpg-homedir=HOMEDIR		GPG homedir for finding keys
  -v, --verbose			print verbose information
  --debug			print debug information
  -h, --help			display this help and exit
EOF
}

PULL_ARGS=()
SUMMARY_ARGS=()
UPDATE=false
while true; do
    case "$1" in
        --repo)
            OSTREE_REPO=$2
            shift 2
            ;;
        -u|--update)
            UPDATE=true
            SUMMARY_ARGS+=("$1")
            shift
            ;;
        --gpg-sign|--gpg-homedir)
            SUMMARY_ARGS+=("$1=$2")
            shift 2
            ;;
        -v|--verbose)
            PULL_ARGS+=("$1")
            SUMMARY_ARGS+=("$1")
            shift
            ;;
        --debug)
            set -x
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ $# -lt 1 ]; then
    echo "No remote specified" >&2
    exit 1
fi

REMOTE=$1
shift

# Figure out the local repo. This emulates ostree_repo_new_default().
if [ -z "$OSTREE_REPO" ]; then
    if [ -e objects ] && [ -e config ]; then
        OSTREE_REPO=.
    else
        OSTREE_REPO=/ostree/repo
    fi
fi

# Exit handler
cleanup() {
    if [ -n "$remote_repo" ]; then
        fusermount -u "$remote_repo"
        rm -rf "$remote_repo"
    fi
}
trap cleanup EXIT

# Mount the remote repo
remote_repo=$(mktemp -d ostree-push.XXXXXXXXXX)
sshfs "$remote_repo" "$REMOTE"

# Use pull-local to emulate pushing
ostree pull-local --repo="$remote_repo" "${PULL_ARGS[@]}" "$OSTREE_REPO" "$@"

# Update the remote summary if asked
if $UPDATE; then
    ostree summary --repo="$remote_repo" "${SUMMARY_ARGS[@]}"
fi
