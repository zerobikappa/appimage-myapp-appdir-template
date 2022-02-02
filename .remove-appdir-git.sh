#!/bin/bash

# you can run this script to remove the git project related files. It is not necessary to bundle these files into .appimage package.
# do not move this .sh files to other location because it detects $HERE directory and deletes git files under $HERE directory.

SELF=$(readlink -f "$0")
HERE=${SELF%/*}

echo "remove git related files from AppDir"
rm -rfv "$HERE"/.git*
rm -rfv "$HERE"/README.md
rm -rfv "$HERE"/readme-todo
rm -rfv "$HERE"/usr/share/drive_d/savedata/.git*
rm -rfv "$HERE"/.remove-appdir-git.sh
