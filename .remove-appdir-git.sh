#!/bin/bash

# you can run this script to remove the git project related files. It is not necessary to bundle these files into .appimage package.
# do not move this .sh files to other location because it detects $HERE directory and deletes git files under $HERE directory.

SELF=$(readlink -f "$0")
HERE=${SELF%/*}

#############################################
## prevent running by root/sudo
if [[ $(id -u) -eq 0 ]];
then
	echo "[AppRun]: prevent running by root/sudo"
	echo "[AppRun]: you should not using root/sudo to run this application"
	exit
fi
#############################################

echo "remove git related files from AppDir"
find "$HERE" -name ".git*" -exec rm -rfv "{}" \;
rm -rfv "$HERE"/usr/bin/comment.myapp*.backup
rm -rfv "$HERE"/backup/screenshot.backup
rm -rfv "$HERE"/backup/unionfs-fuse_1.0-1ubuntu2_amd64.deb
rm -rfv "$HERE"/README.zh.md
rm -rfv "$HERE"/README.md
rm -rfv "$HERE"/readme-todo
rm -rfv "$HERE"/.remove-appdir-git.sh
