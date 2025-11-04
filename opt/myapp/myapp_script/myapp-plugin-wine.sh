#!/bin/bash

##############################################
## Bash source setting
if [[ $MYAPP_PLUGIN_WINE_SOURCED -eq 1 ]];
then
    return
else
    MYAPP_PLUGIN_WINE_SOURCED=1
    export MYAPP_PLUGIN_WINE_SOURCED
fi


# only for code analysis with coc.vim
source ./myapp-debug.sh 2>/dev/null
##############################################


##############################################
## test env
function wine_test_env(){
    # these env should be passed to this script
    echo "[$(basename "${BASH_SOURCE[0]}")]: test env"
    echo "required:"
    debug_print_env APPDIR APPIMAGE_CACHE_DIR EXEINFO_GEN_METHOD
    echo "optional:"
    debug_print_env MYAPPDEBUG EXE_LDIR EXE_WROOT EXE_WDIR EXENAME SAVEDATA_IN_HOME SAVEDATA_DIR MYAPPLANG
}
##############################################


##############################################
## detect winetricks bin
# Required env:
#   $APPDIR
#   $PATH_OLD
#   $PATH_NEW
#
# Export env:
#   $WINETRICKS_BIN
#   $PATH:
#     Will be always reset to "$PATH_NEW"
function wine_detect_winetricks(){
    local LOCAL_WINETRICKS_BIN
    local LOCAL_WINETRICKS_VERSION
    local APPIMAGE_WINETRICKS_BIN
    local APPIMAGE_WINETRICKS_VERSION
    LOCAL_WINETRICKS_BIN=""
    APPIMAGE_WINETRICKS_BIN=""

    export PATH="$PATH_OLD"
    if [[ -x "$(command -v winetricks)" ]];
    then
        LOCAL_WINETRICKS_BIN="$(command -v winetricks)"
    fi
    export PATH="$PATH_NEW"

    # Only search bin under $APPDIR
    # Ignore bin under $APPIMAGE_CACHE_DIR
    if [[ -x "$APPDIR/usr/bin/winetricks" ]];
    then
        APPIMAGE_WINETRICKS_BIN="$APPDIR/usr/bin/winetricks"
    fi


    if [[ -z "$LOCAL_WINETRICKS_BIN" ]];
    then
        if [[ -z "$APPIMAGE_WINETRICKS_BIN" ]];
        then
            # local:N, built-in:N
            echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: command not found: winetricks"
            exit 1
        else
            # local:N, built-in:Y
            WINETRICKS_BIN="$APPIMAGE_WINETRICKS_BIN"
        fi
    else
        if [[ -z "$APPIMAGE_WINETRICKS_BIN" ]];
        then
            # local:Y, built-in:N
            WINETRICKS_BIN="$LOCAL_WINETRICKS_BIN"
        else
            # local:Y, built-in:Y
            LOCAL_WINETRICKS_VERSION="$($LOCAL_WINETRICKS_BIN --version | awk '{print $1}')"
            APPIMAGE_WINETRICKS_VERSION="$($APPIMAGE_WINETRICKS_BIN --version | awk '{print $1}')"
            if [[ "$LOCAL_WINETRICKS_VERSION" > "$APPIMAGE_WINETRICKS_VERSION" ]];
            then
                # local is newer
                WINETRICKS_BIN="$LOCAL_WINETRICKS_BIN"
            else
                # built-in is newer
                WINETRICKS_BIN="$APPIMAGE_WINETRICKS_BIN"
            fi
        fi
    fi

    export WINETRICKS_BIN
}
##############################################


##############################################
## setup WINE env variables
# Required env:
#   $MNT_MYAPP:
#     Need to set $WINEPREFIX path under
#     $MNT_MYAPP.
#
# Optional env:
#   $WINEARCH:
#     User can specify $WINEARCH via command
#     line.
#
# Export env:
#   $WINEARCH
#   $WINEDEBUG:
#     Will be always disable.
#   $WINEDLLOVERRIDES
#     Will be always disable.(Not sure)
#   $WINEPREFIX
function wine_set_env(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    # default to run win64
    if [[ "$WINEARCH" == "win32" || $(getconf LONG_BIT) -eq 32 ]];
    then
        export WINEARCH=win32
    else
        export WINEARCH=win64
    fi

    # default to prevent wine showing "fixeme" message.
    if [[ -z $WINEDEBUG ]];
    then
        export WINEDEBUG=-all
    fi

    # prevent wine setup application menu，no confirm if this setting was effected or not
    export WINEDLLOVERRIDES=winemenubuilder.exe=d

    [[ -z "$MNT_MYAPP" ]] && echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: \$MNT_MYAPP not set" >&2 && exit
    export WINEPREFIX="$MNT_MYAPP/myapp_prefix/wine.$WINEARCH/pfx"

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################


##############################################
## restore wine prefix, should ensure unionfs
## is mounted before run this function, because
## $WINEPREFIX path include the unionfs drive.
# Required env:
#   $USER
#   $WINEARCH:
#     Should be already set.
#   $WINEPREFIX
#     Same reason as above.
#   $MNT_MYAPP
#   $PID_MYAPP:
#     # TODO: not add related code yet.
#     Should confirm already mount fuse
#     file system.
#   $MNT_HOME
#   $PID_HOME
function wine_restore_prefix(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3


    # "rm -rf" included, must check $WINEPREFIX first
    [[ -z "$WINEPREFIX" ]] && echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: \$WINEPREFIX not set, could not restore wine prefix." >&2 && exit 1

    mkdir -p "$MNT_MYAPP/myapp_prefix/wine.$WINEARCH"
    [[ ! -d "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/drive_d" ]] && mkdir -p "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/drive_d"

    # only setup wineprefix and do nothing
    [[ ! -d $WINEPREFIX ]] && wine cmd /C exit >&3 2>&4

    # not necessary to update WINEPREFIX automatically every time
    echo "disable" > "$WINEPREFIX/.update-timestamp"

    # only keep C: and D: drive and remove other drive symlink, to prevent wine motifing local files through Z: drive
    # it is not necessary to package other drive symlink into appimage
    # however, wine will recreate other drive symlink every time when you open explorer in wine/winetricks, we should delete them again after game is ended
    find "$WINEPREFIX/dosdevices" -mindepth 1 -maxdepth 1 ! -name "c:" ! -name "d:" ! -name "y:" -exec rm -rf "{}" \;
    [[ ! -L "$WINEPREFIX/dosdevices/c:" ]] && ln -sfn ../drive_c "$WINEPREFIX/dosdevices/c:"
    # D: drive is moved outside of $WINEPREFIX
    # you can feel free to delete your WINEPREFIX and just package D: drive into appimage
    ln -sfn ../../../../drive_d "$WINEPREFIX/dosdevices/d:"
    #refer path: .../myapp/myapp_prefix/wine.win64/pfx/drive_c/myapp_patch_reg
    [[ ! -L "$MNT_MYAPP/myapp_patch_reg" ]] && ln -sfn ../../../../myapp_patch_reg "$WINEPREFIX/drive_c/myapp_patch_reg"

    # Font directory is moved outside of $WINEPREFIX
    # this is a simple solution for font issue in japanese games
    # just place some CJK font in myapp_fonts directory and package it in appimage
    if [[ ! -L "$WINEPREFIX/drive_c/windows/Fonts" ]];
    then
        rm -rf "$WINEPREFIX/drive_c/windows/Fonts"
        #refer path: .../myapp/myapp_fonts
        #refer path: .../myapp/myapp_prefix/wine.win64/pfx/drive_c/windows/Fonts
        ln -sfnv ../../../../../myapp_fonts "$WINEPREFIX/drive_c/windows/Fonts"
    fi

    if [[ -d "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming" && ! -L "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming" ]];
    then
        mkdir -p "$MNT_HOME/AppData"
        mv -f "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming" "$MNT_HOME/AppData"
        rm -rf "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming"
    fi
    #refer path: .../myapp/myapp_fonts
    #refer path: .../myapp/myapp_prefix/wine.win64/pfx/drive_c/windows/Fonts
    ln -sfnv ../../../../../../../../../../home/public_user/AppData/Roaming "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming"

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################


##############################################
## Wait until winserver terminated
function wine_wait_shutdown(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    #wineboot -es    # this command run too slow
    #wineboot -s

    # to prevent launch the game too early(before complete reg patch)
    # or
    # to prevent unmount unionfs too early(before wine save changes)
    # wait until winserver terminated
    wineserver -w
    local WINE_WINESERVER_EXIT
    WINE_WINESERVER_EXIT=$?
    if [[ $WINE_WINESERVER_EXIT -ne 0 ]];
    then
        echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: wineserver did not shutdown normally. exit code=$WINE_WINESERVER_EXIT" >&2
        wineserver -k
        #NOTUSED: should not exit here. it may skip atexit() and let unionfs remain in background
        #exit
    fi
    unset WINE_WINESERVER_EXIT

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################


##############################################
## Patch some registry into wineprefix
# Required env:
#   $MNT_MYAPP
#   $PID_MYAPP:
#     # TODO: not add related code yet.
#     Should confirm already mount fuse
#     file system.
#   $WINEARCH
function wine_patch_reg(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    [[ -z "$MNT_MYAPP" ]] && echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: \$MNT_MYAPP not set" >&2 && exit

    # I tried to disable autostart winedbg via loading the .reg by regedit but failed.
    # as a workaround I use winetricks to disable autostart debugger.
    # TODO: seems the imported reg were effected in wow6432node instead of the correct reg path
    # update on 2022/3/25: No need to disable autostart_winedbg now because I fixed trap-exit function. Now I can easily use <Ctrl-C> to stop the process even when wine crash.
    #winetricks autostart_winedbg=disabled
    #"$WINETRICKS_BIN" autostart_winedbg=disabled >&3 2>&4

    if [[ -n "$(ls "$MNT_MYAPP"/myapp_patch_reg/*.reg 2>/dev/null )" ]];
    then
        #for i in $(ls "$MNT_MYAPP"/myapp_patch_reg/*.reg); do
        for i in "$MNT_MYAPP"/myapp_patch_reg/*.reg; do
            # ls /full/path/of/*.reg will output full path of file, need to use $(basename "$i") to get the file name.
            [[ -f "$i" ]] && i=$(basename "$i") || continue
            wine regedit "c:\\myapp_patch_reg\\$i"
        done
    fi

    if [[ -n "$(ls "$MNT_MYAPP"/myapp_patch_reg/"$WINEARCH"/*.reg 2>/dev/null )" ]];
    then
        for i in "$MNT_MYAPP"/myapp_patch_reg/"$WINEARCH"/*.reg; do
            # ls /full/path/of/*.reg will output full path of file, need to use $(basename "$i") to get the file name.
            [[ -f "$i" ]] && i=$(basename "$i") || continue
            wine regedit "c:\\myapp_patch_reg\\$WINEARCH\\$i"
        done
    fi

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################


##############################################
## Run winetricks
# Receive argument:
#   $next_parameters passed from outside.
# Required env:
#   $WINETRICKS_BIN
#   $WINEARCH:
#     Should be already set before run wine
#     or winetricks.
#   $WINEPREFIX:
#     Same reason as above.
function wine_run_winetricks(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    echo "[${FUNCNAME[0]}:10%] detect winetricks bin"
    wine_detect_winetricks

    echo "[${FUNCNAME[0]}:20%] prepare prefix"
    # move the command to background then wait, so that I can use ctrl-C to interrupt wine if wine encounter crash
    wine_restore_prefix >&3 2>&4 &
    wait
    #"$APPDIR"/usr/bin/winetricks sandbox    # this command run too slow
    echo "[${FUNCNAME[0]}:60%] patch wine registry"
    wine_patch_reg >&3 2>&4 &
    wait
    echo "[${FUNCNAME[0]}:70%] restore completed, wait shutdown prefix"
    wine_wait_shutdown >&3 2>&4
    MYAPPDEBUG_COLOR=1 debug_print_env "HOME" "XDG_CONFIG_HOME" "WINETRICKS_BIN"
    echo "[${FUNCNAME[0]}:100%] launch"
    #"$APPDIR"/usr/bin/winetricks "$@"
    "$WINETRICKS_BIN" "$@" >&3 2>&4

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################


##############################################
## Run exe file
# Receive argument:
#   $next_parameters passed from outside.
#
# Required env:
#   $MNT_MYAPP
#   $PID_MYAPP:
#     Should already mounted fuse file system.
#   $EXENAME
#   $EXE_LDIR
#   $EXE_WROOT
#   $EXE_WDIR
#
# Optional env:
#   $WALKTHROUGH_FLAG
#   $SAVEDATA_FLAG
function wine_run_exe(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    echo "[${FUNCNAME[0]}:20%] prepare prefix"
    wine_restore_prefix >&3 2>&4 &
    wait
    #"$APPDIR"/usr/bin/winetricks sandbox >/dev/null 2>&1    #NOTUSED: this command run too slow
    echo "[${FUNCNAME[0]}:60%] patch wine registry"
    wine_patch_reg >&3 2>&4 &
    wait
    echo "[${FUNCNAME[0]}:70%] restore completed, wait shutdown prefix"
    wine_wait_shutdown >&3 2>&4

    if [[ $WALKTHROUGH_FLAG -eq 1 ]];
    then
        echo "[${FUNCNAME[0]}:80%] open walkthrough"
        walkthrough_browser
    fi

    if [[ $SAVEDATA_FLAG -eq 1 ]];
    then
        echo "[${FUNCNAME[0]}:90%] load full achieved savedata"
        savedata_replace
    fi

    cd "$MNT_MYAPP/$EXE_LDIR" || exit 2 # Use the app installed location. Some .exe may not run if not cd into excute directory

    #"$APPDIR"/usr/bin/winetricks sandbox >/dev/null 2>&1 && wine "${EXE_WROOT}:\\${EXE_WDIR}\\$EXENAME" "$@"     # must use dos-style path instead of unix-style path if winetricks sandbox was set.
    MYAPPDEBUG_COLOR=1 debug_print_env "HOME" "XDG_CONFIG_HOME"
    echo "[${FUNCNAME[0]}:100%] launch"
    wine "${EXE_WROOT}:\\${EXE_WDIR}\\$EXENAME" "$@" >&3 2>&4

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################


##############################################
[[ "$0" == "${BASH_SOURCE[0]}" && $MYAPPDEBUG -eq 1 ]] && wine_test_env
if [[ "$0" == "${BASH_SOURCE[0]}" ]];
then
    [[ -n $APPDIR ]] || echo "[$(basename "${BASH_SOURCE[0]}")] required \$APPDIR but it was not set" >&2
    [[ -n $APPIMAGE_CACHE_DIR ]] || echo "[$(basename "${BASH_SOURCE[0]}")] required \$APPIMAGE_CACHE_DIR but it was not set" >&2
    [[ -n $EXEINFO_GEN_METHOD ]] || echo "[$(basename "${BASH_SOURCE[0]}")] required \$EXEINFO_GEN_METHOD but it was not set" >&2
    [[ -n $APPDIR || -n $APPIMAGE_CACHE_DIR || -n $EXEINFO_GEN_METHOD ]] || exit
fi
# TODO: Source this file at the beginning of
# "main.sh" then run wine_detect_winetricks
# later.
#wine_detect_winetricks

##############################################



