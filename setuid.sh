#!/usr/bin/env bash

set -uo pipefail

if [ $(id -u) -ne 0 ]; then
	exec sudo "$BASH_SOURCE" "$@"
	exit $?
fi

find bin -type f -executable -print0 | while IFS= read -r -d '' f; do
	chown root:root -- "$f" &&
	chmod u+s,g+s -- "$f"
done
