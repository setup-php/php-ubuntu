#!/usr/bin/env bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd / || exit 1
mkdir -p /run/php
chmod 777 /run/php
touch /run/php/.snapshotkeep

# shellcheck source=scripts/filesystem-snapshot.sh
. "$script_dir/filesystem-snapshot.sh"
write_filesystem_manifest /tmp/php-ubuntu-before-files
