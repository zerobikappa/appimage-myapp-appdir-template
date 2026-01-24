#!/bin/bash

##############################################
## Bash source setting
if [[ $MYAPP_PLUGIN_OVERLAYFS_FUSE_SOURCED -eq 1 ]];
then
    return
else
    MYAPP_PLUGIN_OVERLAYFS_FUSE_SOURCED=1
    export MYAPP_PLUGIN_OVERLAYFS_FUSE_SOURCED
fi


# only for code analysis with coc.vim
source ./myapp-debug.sh 2>/dev/null
##############################################


#############################################
## Prepare fuse mount point env variables.
# Required env:
#   $USER
#   $APPIMAGE_CACHE_DIR
#   $APPDIR
#
# Optional env:
#   $MYAPP_NAME
#
# Export env:
#   $LOWERDIR_MYAPP
#   $UPPERDIR_MYAPP
#   $WORKDIR_MYAPP
#   $MNT_MYAPP
#   $LOWERDIR_HOME
#   $UPPERDIR_HOME
#   $WORKDIR_HOME
#   $MNT_HOME
function mpPlugin_fusetool_setVar(){
    LOWERDIR_MYAPP="${APPDIR}/opt/${MYAPP_NAME}"
    LOWERDIR_MYAPP=$( readlink -m "${LOWERDIR_MYAPP}" )
    UPPERDIR_MYAPP="${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}"
    UPPERDIR_MYAPP=$( readlink -m "${UPPERDIR_MYAPP}" )
    WORKDIR_MYAPP="$APPIMAGE_CACHE_DIR/.workdir-app"
    # the ".unionfs" extension was defined by AppimageKit
    MNT_MYAPP="/tmp/$(basename "$APPDIR").unionfs/opt/${MYAPP_NAME}"
    MNT_MYAPP=$( readlink -m "${MNT_MYAPP}" )

    LOWERDIR_HOME="/home/$USER/"
    UPPERDIR_HOME="$APPIMAGE_CACHE_DIR/home/public_user"
    WORKDIR_HOME="$APPIMAGE_CACHE_DIR/.workdir-home"
    # the ".unionfs" extension was defined by AppimageKit
    MNT_HOME="/tmp/$(basename "$APPDIR").unionfs/home/public_user"

}
#############################################


#############################################
## Mount fuse mountpoint.
# Required env:
#   $UNIONFS_BIN
#   $UID
#   $APPDIR
#   $APPIMAGE_CACHE_DIR
#   $LOWERDIR_MYAPP
#   $UPPERDIR_MYAPP
#   $WORKDIR_MYAPP
#   $MNT_MYAPP
#   $LOWERDIR_HOME
#   $UPPERDIR_HOME
#   $WORKDIR_HOME
#   $MNT_HOME
#
# Export env:
#   $PID_MYAPP
#   $PID_HOME
#
# Result:
#   Successfully mount the fuse file system,
#   or
#   Exit.
function mpPlugin_fusetool_mount(){
    rm -rf "$WORKDIR_MYAPP"
    mkdir -p "$MNT_MYAPP" "$UPPERDIR_MYAPP" "$WORKDIR_MYAPP"

    "$UNIONFS_BIN" -o lowerdir="$LOWERDIR_MYAPP",upperdir="$UPPERDIR_MYAPP",workdir="$WORKDIR_MYAPP" "$MNT_MYAPP" || exit 1
    
    rm -rf "$WORKDIR_HOME"
    mkdir -p "$MNT_HOME" "$UPPERDIR_HOME" "$WORKDIR_HOME"

    if [[ -d "$APPDIR/home/public_user" ]];
    then
        # should also refer home/public_user directory in $APPDIR, if user also add this directory into appimage
        "$UNIONFS_BIN" -o lowerdir="$APPDIR/home/public_user":"$LOWERDIR_HOME",upperdir="$UPPERDIR_HOME",workdir="$WORKDIR_HOME" "$MNT_HOME" || exit 1
    else
        "$UNIONFS_BIN" -o lowerdir="$LOWERDIR_HOME",upperdir="$UPPERDIR_HOME",workdir="$WORKDIR_HOME" "$MNT_HOME" || exit 1
    fi
    
    PID_MYAPP="$(pgrep -a fuse-overlayfs | grep "$MNT_MYAPP" | awk '{print $1}')"
    PID_HOME="$(pgrep -a fuse-overlayfs | grep "$MNT_HOME" | awk '{print $1}')"
}
#############################################


#############################################
## Unmount fuse mountpoint.
# Required env:
#   $APPDIR:
#     Function contents "rm -rf", must ensure
#     this env variables not empty.
#   $APPIMAGE_CACHE_DIR
#     Same reason as above.
#   $PID_MYAPP
#   $PID_HOME
#
# Optional env:
#   $MYAPP_NAME
function mpPlugin_fusetool_unmount(){
    kill -9 "$PID_MYAPP"
    kill -9 "$PID_HOME"
    sleep 1
    umount "/tmp/$(basename "$APPDIR").unionfs/opt/${MYAPP_NAME}"
    umount "/tmp/$(basename "$APPDIR").unionfs/home/public_user"
    echo "[${FUNCNAME[0]}:] removing /tmp/$(basename "$APPDIR").unionfs"
    rm -rf "/tmp/$(basename "$APPDIR").unionfs"
    # if not clean up unionfs hide files, may encounter some read file error next time.
    echo "[${FUNCNAME[0]}:] removing unionfs hidden files"
    rm -rf "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}"/.unionfs* >/dev/null 2>&1
    rm -rf "$APPIMAGE_CACHE_DIR/home/public_user"/.unionfs* >/dev/null 2>&1
}
#############################################


