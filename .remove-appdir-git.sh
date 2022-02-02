#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}

echo "remove git related files from AppDir"
rm -rfv "$HERE/.git*"
rm -rfv "$HERE/README.md"
rm -rfv "$HERE/readme-todo"
rm -rfv "$HERE/usr/share/drive_d/savedata/.git*"
rm -rfv "$HERE/.remove-appdir-git.sh"
