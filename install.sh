#!/usr/bin/env bash

set -uo pipefail

app_name="$(basename "${BASH_SOURCE[0]}")"

if [ $(id -u) -ne 0 ]; then
	exec sudo "$BASH_SOURCE" "$HOME/.local/bin/discord"
	exit $?
fi

if [[ $# -ge 1 ]]; then
	target="$1"
else
	echo "$app_name: [Error] Need target path." >&2
	exit 2
fi

install -o root -g root -m u=rwsx,g=rwsx,o=rx -D -T bin/debug-linux-x86_64/discord-upstart "$target"
