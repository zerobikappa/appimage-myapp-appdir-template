#!/bin/bash

##############################################
## Bash source setting
if [[ $MYAPP_PLUGIN_EXEINFO_SOURCED -eq 1 ]];
then
    return
else
    MYAPP_PLUGIN_EXEINFO_SOURCED=1
    export MYAPP_PLUGIN_EXEINFO_SOURCED
fi


# only for code analysis with coc.vim
source ./myapp-debug.sh 2>/dev/null
##############################################


##############################################
## test env
function exeinfo_test_env(){
    # these env should be passed to this script
    cat << EOF
[myapp-exeinfo-plugin-gen]: test env
required:
APPDIR=$APPDIR
APPIMAGE_CACHE_DIR=$APPIMAGE_CACHE_DIR
EXEINFO_GEN_METHOD=$EXEINFO_GEN_METHOD

optional:
MYAPPDEBUG=$MYAPPDEBUG
EXE_LDIR=$EXE_LDIR
EXE_WROOT=$EXE_WROOT
EXE_WDIR=$EXE_WDIR
EXENAME=$EXENAME
SAVEDATA_IN_HOME=$SAVEDATA_IN_HOME
SAVEDATA_DIR=$SAVEDATA_DIR
MYAPPLANG=$MYAPPLANG
EOF
}
##############################################


##############################################
## convert absolute path to relative path
# usage:
#     apprun_realpath $source_Path $target_Path
#
# required argument:
#     (1)Requires 2 argument wich indicate source path
#     and target path.
#     (2)Both $source_Path and $target are absolute
#     paths beginning with "/".
#
# result:
#     Returns relative path which is from $source_Path
#     to $target_Path.
function apprun_realpath(){
    source=${1%/}
    target=${2%/}    # remove the "/" character at the end
    
    if [[ -z $1 || -z $2 ]];
    then
        echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: please inpute two variables." >&2
        exit 1
    fi
    
    common_part=$source # for now
    result="" # for now
    
    while [[ "${target#"$common_part"}" == "$target" ]]; do
        # no match, means that candidate common part is not correct
        # go up one level (reduce common part)
        common_part="$(dirname "$common_part")"
        # and record that we went back, with correct / handling
        if [[ -z $result ]]; then
            result=".."
        else
            result="../$result"
        fi
    done

    if [[ $common_part == "/" ]]; then
        # special case for root (no common path)
        result="$result/"
    fi

    # since we now have identified the common part,
    # compute the non-common part
    forward_part="${target#"$common_part"}"
    
    # and now stick all parts together
    if [[ -n $result ]] && [[ -n $forward_part ]]; then
        result="$result$forward_part"
    elif [[ -n $forward_part ]]; then
        # extra slash removal
        result="${forward_part:1}"
    fi
    
    echo "$result"

}
##############################################


##############################################
## Load xdg standard directories' name from
## current user setting.
## Some user may change directories' name (for
## example, change "Desktop" directory to a
## lower case name "desktop". Therefore we need
## to load the directory names from latest
## user config file.
## This function is also used to set/reset
## XDG_*_DIR env variables.
# Export env:
#   $XDG_DESKTOP_DIR
#   $XDG_DOWNLOAD_DIR
#   $XDG_TEMPLATES_DIR
#   $XDG_PUBLICSHARE_DIR
#   $XDG_DOCUMENTS_DIR
#   $XDG_MUSIC_DIR
#   $XDG_PICTURES_DIR
#   $XDG_VIDEOS_DIR
#   $FAKE_DESKTOP_DIR
#   $FAKE_DOWNLOAD_DIR
#   $FAKE_TEMPLATES_DIR
#   $FAKE_PUBLICSHARE_DIR
#   $FAKE_DOCUMENTS_DIR
#   $FAKE_MUSIC_DIR
#   $FAKE_PICTURES_DIR
#   $FAKE_VIDEOS_DIR
function exeinfo_user_dirs(){
    # if user-dirs.dirs exists, it would replace the default setting
    if [[ -f "$XDG_CONFIG_HOME/user-dirs.dirs" ]];
    then
        source "$XDG_CONFIG_HOME/user-dirs.dirs"
    elif [[ -f "$HOME/.config/user-dirs.dirs" ]];
    then
        source "$HOME/.config/user-dirs.dirs"
    else
        echo "cannot find user-dirs.dirs setting, using default setting"
        XDG_DESKTOP_DIR="$HOME/Desktop"
        XDG_DOWNLOAD_DIR="$HOME/Downloads"
        XDG_TEMPLATES_DIR="$HOME/Templates"
        XDG_PUBLICSHARE_DIR="$HOME/Public"
        XDG_DOCUMENTS_DIR="$HOME/Documents"
        XDG_MUSIC_DIR="$HOME/Music"
        XDG_PICTURES_DIR="$HOME/Pictures"
        XDG_VIDEOS_DIR="$HOME/Videos"
    fi

    FAKE_DESKTOP_DIR_NAME="$(basename "$XDG_DESKTOP_DIR")"
    FAKE_DOWNLOAD_DIR_NAME="$(basename "$XDG_DOWNLOAD_DIR")"
    FAKE_TEMPLATES_DIR_NAME="$(basename "$XDG_TEMPLATES_DIR")"
    FAKE_PUBLICSHARE_DIR_NAME="$(basename "$XDG_PUBLICSHARE_DIR")"
    FAKE_DOCUMENTS_DIR_NAME="$(basename "$XDG_DOCUMENTS_DIR")"
    # refer: "/etc/xdg/user-dirs.defaults", some distribution may
    # group {Music,Pictures,Videos} directories into Documents directory.
    if [[ "${XDG_MUSIC_DIR#"$XDG_DOCUMENTS_DIR"}" != "$XDG_MUSIC_DIR" ]];
    then
        FAKE_MUSIC_DIR_NAME="$(basename "$XDG_DOCUMENTS_DIR")/$(basename "$XDG_MUSIC_DIR")"
    else
        FAKE_MUSIC_DIR_NAME="$(basename "$XDG_MUSIC_DIR")"
    fi

    if [[ "${XDG_PICTURES_DIR#"$XDG_DOCUMENTS_DIR"}" != "$XDG_PICTURES_DIR" ]];
    then
        FAKE_PICTURES_DIR_NAME="$(basename "$XDG_DOCUMENTS_DIR")/$(basename "$XDG_PICTURES_DIR")"
    else
        FAKE_PICTURES_DIR_NAME="$(basename "$XDG_PICTURES_DIR")"
    fi

    if [[ "${XDG_VIDEOS_DIR#"$XDG_DOCUMENTS_DIR"}" != "$XDG_VIDEOS_DIR" ]];
    then
        FAKE_VIDEOS_DIR_NAME="$(basename "$XDG_DOCUMENTS_DIR")/$(basename "$XDG_VIDEOS_DIR")"
    else
        FAKE_VIDEOS_DIR_NAME="$(basename "$XDG_VIDEOS_DIR")"
    fi
}
##############################################


##############################################
## If a path is under $HOME or other xdg
## directories, convert the path from absolute
## path to a path with xdg_dirs env variable.
## When write path setting into exeinfo_profile,
## write env name itself and prevent escaping.
#
# Example:
#   exeinfo_convert_xdg_path /home/someuser/Desktop/foo.file
#
# then it will return '${XDG_DESKTOP_DIR}/foo.file'
function exeinfo_convert_xdg_path(){
    [[ -z "$1" ]] && echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: no argument was input" >&2 && return
    if [[ ${1#"$XDG_VIDEOS_DIR"} != "$1" ]];
    then
        echo '${XDG_VIDEOS_DIR}'"${1#"$XDG_VIDEOS_DIR"}"
    elif [[ ${1#"$XDG_PICTURES_DIR"} != "$1" ]];
    then
        echo '${XDG_PICTURES_DIR}'"${1#"$XDG_PICTURES_DIR"}"
    elif [[ ${1#"$XDG_MUSIC_DIR"} != "$1" ]];
    then
        echo '${XDG_MUSIC_DIR}'"${1#"$XDG_MUSIC_DIR"}"
    elif [[ ${1#"$XDG_DOCUMENTS_DIR"} != "$1" ]];
    then
        echo '${XDG_DOCUMENTS_DIR}'"${1#"$XDG_DOCUMENTS_DIR"}"
    elif [[ ${1#"$XDG_PUBLICSHARE_DIR"} != "$1" ]];
    then
        echo '${XDG_PUBLICSHARE_DIR}'"${1#"$XDG_PUBLICSHARE_DIR"}"
    elif [[ ${1#"$XDG_TEMPLATES_DIR"} != "$1" ]];
    then
        echo '${XDG_TEMPLATES_DIR}'"${1#"$XDG_TEMPLATES_DIR"}"
    elif [[ ${1#"$XDG_DOWNLOAD_DIR"} != "$1" ]];
    then
        echo '${XDG_DOWNLOAD_DIR}'"${1#"$XDG_DOWNLOAD_DIR"}"
    elif [[ ${1#"$XDG_DESKTOP_DIR"} != "$1" ]];
    then
        echo '${XDG_DESKTOP_DIR}'"${1#"$XDG_DESKTOP_DIR"}"
    elif [[ ${1#"$HOME"} != "$1" ]];
    then
        echo '${HOME}'"${1#"$HOME"}"
    fi

}
##############################################


##############################################
## Load env variables from setting file.
# Required env:
#   $APPIMAGE_CACHE_DIR
#   $APPDIR
#
# Optional env:
#   $MYAPP_NAME
#
# Export env:
#   $EXE_LDIR
#       .exe file location. Relative path(linux
#       format) from wine prefix location.
#   $EXE_WROOT
#       Drive letter, indicate the windows drive
#       where the exe file located.
#   $EXE_WDIR
#       Relative path under $EXE_WROOT drive
#       to exe file location.
#   $EXENAME
#       exe file name(include extension ".exe")
#   $SAVEDATA_IN_HOME
#       "0" or "1". Whether the savedate is in
#       linux $HOME.
#   $SAVEDATA_DIR
#       savedata path(linux format path).
#   $MYAPPLANG
#       LANG env variable for this game.
function exeinfo_load_file(){
    unset EXEINFO_CURRENT_PROFILE
    if [[ -f "${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile.$LANG" ]];
    then
        EXEINFO_CURRENT_PROFILE="${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile.$LANG"
    elif [[ -f "${APPDIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile.$LANG" ]];
    then
        EXEINFO_CURRENT_PROFILE="${APPDIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile.$LANG"
    elif [[ -f "${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile" ]];
    then
        EXEINFO_CURRENT_PROFILE="${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile"
    elif [[ -f "${APPDIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile" ]];
    then
        EXEINFO_CURRENT_PROFILE="${APPDIR}/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile"
    else
        echo "cannot find exeinfo_profile for your LANG:$LANG"
        echo "also cannot find default exeinfo_profile"
        return
    fi
    # remove duplicate '/' in the result path in case ${MYAPP_NAME} is empty value.
    #EXEINFO_CURRENT_PROFILE=$(readlink -m "$EXEINFO_CURRENT_PROFILE")

    # only for test
    if (cat "$EXEINFO_CURRENT_PROFILE" |grep '^[[:blank:]]*[^[:blank:]#]' |grep --quiet -e '$WINEARCH' -e '${WINEARCH}' -e '${WINEARCH:.*}' -e '${WINEARCH%.*}' -e '${WINEARCH#.*}');
    then
        [[ -z $WINEARCH ]] && echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: $EXEINFO_CURRENT_PROFILE includes \$WINEARCH but \$WINEARCH was not set. Failed to load exeinfo." >&2 && return
    fi

    source "$EXEINFO_CURRENT_PROFILE"
}
##############################################


##############################################
## load old exeinfo env from setting file
# Export env:
#   $TEMP_EXE_LDIR
#   $TEMP_EXE_WROOT
#   $TEMP_EXE_WDIR
#   $TEMP_EXENAME
#   $TEMP_SAVEDATA_IN_HOME
#   $TEMP_SAVEDATA_DIR
#   $TEMP_MYAPPLANG
function exeinfo_load_temp(){
    [[ -z "$EXEINFO_CURRENT_PROFILE" ]] && exeinfo_load_file
    if [[ -n "$EXEINFO_CURRENT_PROFILE" ]];
    then
        for i in "EXE_LDIR" "EXE_WROOT" "EXE_WDIR" "EXENAME" "SAVEDATA_IN_HOME" "SAVEDATA_DIR" "MYAPPLANG"
        do
            eval TEMP_$i=\'$(grep '^[[:blank:]]*[^[:blank:]#]' "$EXEINFO_CURRENT_PROFILE" | grep "$i" | sed 's/^[^=]*//' | sed 's/=//' | sed 's/"//g' )\'
        done
    else
        # if not found exeinfo_profile, initialize below variables to empty
        TEMP_EXE_LDIR=""
        TEMP_EXE_WROOT=""
        TEMP_EXE_WDIR=""
        TEMP_EXENAME=""
        TEMP_SAVEDATA_IN_HOME=""
        TEMP_SAVEDATA_DIR=""
        TEMP_MYAPPLANG=""
    fi

    # NOTUSED: it would output wrong result if they include other
    # env name($WINEARCH, $XDG_DOCUMENTS_DIR...)
    #TEMP_EXE_LDIR=$EXE_LDIR
    #TEMP_EXE_WROOT=$EXE_WROOT
    #TEMP_EXE_WDIR=$EXE_WDIR
    #TEMP_EXENAME=$EXENAME
    #TEMP_SAVEDATA_IN_HOME=$SAVEDATA_IN_HOME
    #TEMP_SAVEDATA_DIR=$SAVEDATA_DIR
    #TEMP_MYAPPLANG=$MYAPPLANG
}
##############################################


##############################################
## Select gui/cli to set exeinfo
## Support zenity/kdialog/cli
# Required env:
#   $EXEINFO_GEN_METHOD
#
# Optional env:
#   $XDG_CURRENT_DESKTOP
#
# Export env:
#   $EXIT_MAIN_MENU
function exeinfo_test_gui(){
    if [[ $EXEINFO_GEN_METHOD == "kdialog" ]];
    then
        [[ -x "$(command -v kdialog 2>/dev/null)" ]] && return || EXIT_MAIN_MENU=1
    elif [[ $EXEINFO_GEN_METHOD == "zenity" ]];
    then
        [[ -x "$(command -v zenity 2>/dev/null)" ]] && return || EXIT_MAIN_MENU=1
    elif [[ $EXEINFO_GEN_METHOD == "gui" ]];
    then
        if [[ "${XDG_CURRENT_DESKTOP}" == "KDE" ]];
        then
            [[ -x "$(command -v kdialog 2>/dev/null)" ]] && EXEINFO_GEN_METHOD="kdialog" && return
            [[ -x "$(command -v zenity 2>/dev/null)" ]] && EXEINFO_GEN_METHOD="zenity" && return
            # if not returned, that means above command not found, then:
            EXIT_MAIN_MENU=1
        else
            [[ -x "$(command -v zenity 2>/dev/null)" ]] && EXEINFO_GEN_METHOD="zenity" && return
            [[ -x "$(command -v kdialog 2>/dev/null)" ]] && EXEINFO_GEN_METHOD="kdialog" && return
            # if not returned, that means above command not found, then:
            EXIT_MAIN_MENU=1
        fi
    elif [[ $EXEINFO_GEN_METHOD == "cli" ]];
    then
        return
    else
        echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: unknow option $EXEINFO_GEN_METHOD" >&2
        EXIT_MAIN_MENU=1
    fi

    # fallback solution
    # launch from commandline but fail to find gui: go to CLI mode.
    # launch by double click but fail to find gui: exit directly.
    # avoid hangup in background when launch by double click
    if [[ -t 0 ]];
    then
        echo "cannot find $EXEINFO_GEN_METHOD, using commandline to read input."
        EXEINFO_GEN_METHOD="cli"
        EXIT_MAIN_MENU=0
    else
        notify-send --app-name "AppRun" --expire-time 15000 "AppRun:plugin-exeinfo error" "$EXEINFO_GEN_METHOD not found, cannot run exeinfo-gen. Please install [kdialog] or [zenity]. Otherwise you can run in commandline with --exeinfo-gen=cli option to enter exeinfo-gen."
        EXIT_MAIN_MENU=1
    fi

}
##############################################


##############################################
## main menu to set exeinfo
# Required env:
#   $EXEINFO_GEN_METHOD
#
# Optional env:
#   If old setting file exists, should import
#   below env:
#     $TEMP_EXE_LDIR
#     $TEMP_EXE_WROOT
#     $TEMP_EXE_WDIR
#     $TEMP_EXENAME
#     $TEMP_SAVEDATA_IN_HOME
#     $TEMP_SAVEDATA_DIR
#     $TEMP_MYAPPLANG
function exeinfo_main_menu(){
    if [[ $EXEINFO_GEN_METHOD == "kdialog" ]];
    then
        MENU_SELECT_ITEM=$(kdialog --geometry 800x600 --title "exe info setting" --menu "select one of items to go" \
            1 "1. set exe file location($TEMP_EXENAME)" \
            2 "2. set savedata directory location($TEMP_SAVEDATA_DIR)" \
            3 "3. set \$LANG for this game($TEMP_MYAPPLANG)" \
            4 "4. ***write into exeinfo_profile" \
            5 "5. ***cancel and exit without saving into exeinfo_profile" \
            --ok-label "go" --cancel-label "close")
        # result:
        # $? return 0: click ok, also echo item tag(1/2/3/4/5)
        # $? return 1: click cancel
        [[ $? -eq 1 ]] && MENU_SELECT_ITEM=5
    elif [[ $EXEINFO_GEN_METHOD == "zenity" ]];
    then
        MENU_SELECT_ITEM=$(zenity --width=800 --height=600 --list --title="exe info setting" \
            --ok-label="go" --cancel-label="close" \
            --text="select one of items to go" \
            --column="item" --column="action" \
            "1" "set exe file location($TEMP_EXENAME)" \
            "2" "set savedata directory location($TEMP_SAVEDATA_DIR)" \
            "3" "set \$LANG for this game($TEMP_MYAPPLANG)" \
            "4" "***write into exeinfo_profile" \
            "5" "***cancel and exit without saving into exeinfo_profile")
        # result:
        # $? return 0: click ok, also echo item tag(1/2/3/4/5)
        # $? return 1: click cancel
        [[ $? -eq 1 ]] && MENU_SELECT_ITEM=5
    elif [[ $EXEINFO_GEN_METHOD == "cli" ]];
    then
        while true; do
            cat << EOF
##################################################
  selected EXENAME=$TEMP_EXENAME
  selected SAVEDATA_DIR=$TEMP_SAVEDATA_DIR
  selected MYAPPLANG=$TEMP_MYAPPLANG
##################################################
  please select one of below items:
  1. set .exe file location
  2. set savedata directory location
  3. set \$LANG for this game
  4. ***write into exeinfo_profile then exit
  5. ***cancel and exit without saving into exeinfo_profile
##################################################
EOF
            read -p "select item (1/2/3/4/5):" MENU_SELECT_ITEM
            case "$MENU_SELECT_ITEM" in
                1| 2| 3| 4| 5)
                    break
                    ;;
                *)
                    clear
                    echo "invalid number. please input again!"
                    ;;
            esac
        done
    fi
}
##############################################


##############################################
## Select a exe file, then detect its name
## and path. Then save the result in TEMP_EXE*
## env variables.
# Required env:
#   $EXEINFO_GEN_METHOD
#   $APPIMAGE_CACHE_DIR
#   $APPDIR
#
# Optional env:
#   $MYAPP_NAME:
#       project name of this app project.
#
# Export env:
#   $TEMP_EXENAME
#   $TEMP_EXE_LDIR
#   $TEMP_EXE_WROOT
#   $TEMP_EXE_WDIR
function exeinfo_exe_location(){
    local TEMP
    local TEMP_FILENAME
    local TEMP_END
    local TEMP_EXEPATH
    local TEMP_EXE_LROOT
    local RETURN_STATUS
    if [[ $EXEINFO_GEN_METHOD == "kdialog" ]];
    then
        TEMP_FILENAME=$(readlink -m "${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}")
        TEMP_EXEPATH="$(kdialog --geometry 800x600 --title "select the .exe file" --getopenfilename "$TEMP_FILENAME" )"
        RETURN_STATUS="$?"
    elif [[ $EXEINFO_GEN_METHOD == "zenity" ]];
    then
        TEMP_EXEPATH="$(zenity --width=800 --height=600 --file-selection --title="select the .exe file" --filename="$TEMP_FILENAME" )"
        RETURN_STATUS="$?"
    else
        clear
        echo "  to go back to previous menu, please <backspace> to earse all words then push <enter>"
        echo ""
        echo ""
        echo "##################################################"
        echo "  select .exe file location(use <tab> key for prompt)"
        echo "  it should be under"
        echo "  (cache dir:) $APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/myapp/"
        echo "  or"
        echo "  (app dir:) ${APPDIR}/opt/${MYAPP_NAME}/myapp/"
        echo "##################################################"
        echo ""
        read -e -p "input .exe file path: " -i "$APPIMAGE_CACHE_DIR" TEMP_EXEPATH
        RETURN_STATUS="$?"
    fi

    if [[ -z "$TEMP_EXEPATH" ]];
    then
        clear
        return
    elif [[ ! -f "$TEMP_EXEPATH" ]];
    then
        clear
        echo "########################################"
        echo "ERROR: invalid file name: $TEMP_EXEPATH" >&2
        echo "########################################"
        echo ""
        TEMP_EXEPATH=""
        return
    fi

    clear
    # if clicked "ok"
    TEMP_EXEPATH="$(readlink -f "$TEMP_EXEPATH")"
    if [[ $RETURN_STATUS -eq 0 && -n $TEMP_EXEPATH ]];
    then
        # check if .exe file in appdir or in appdir.cache
        if [[ "${TEMP_EXEPATH#"$(readlink -f "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}")"}" != "$TEMP_EXEPATH" ]];
        then
            # .exe file in AppDir.cache or in *.appimage.cache directory
            TEMP_EXE_LROOT=$(readlink -f "${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}")
        elif [[ "${TEMP_EXEPATH#"$(readlink -f "$APPDIR/opt/${MYAPP_NAME}")"}" != "$TEMP_EXEPATH" ]];
        then
            # .exe file in AppDir, running AppRun directly from AppDir at this moment.
            TEMP_EXE_LROOT=$(readlink -f "$APPDIR/opt/${MYAPP_NAME}")
        else
            [[ $EXEINFO_GEN_METHOD == "kdialog" ]] && kdialog --error "you selected *.exe file outside of appimage dir."
            [[ $EXEINFO_GEN_METHOD == "zenity" ]] && zenity --width=300 --height=100 --error --text="you selected *.exe file outside of appimage dir."
            clear
            echo "########################################"
            # outside of AppDir and *.cache. Should not install .exe outside of AppDir or *.cache.
            echo "ERROR: .exe file outside of appimage dir." >&2
            echo "########################################"
            echo ""
            TEMP_EXEPATH=""
            return
        fi

        TEMP="$(dirname "$TEMP_EXEPATH")"
        TEMP_END=""
        while [[ -n $TEMP && $TEMP != "/" ]] ; do
            case "$(basename "$TEMP")" in
                drive_d)
                    export TEMP_EXE_WROOT="d"
                    #EXE_WDIR=$(apprun_realpath "$MNT_MYAPP/drive_d" "$(dirname $TEMP_EXEPATH)")
                    TEMP_EXE_WDIR="$TEMP_END"
                    break
                    ;;
                drive_c)
                    export TEMP_EXE_WROOT="c"
                    #EXE_WDIR=$(apprun_realpath "$MNT_MYAPP/$WINEARCH/drive_c" "$(dirname $TEMP_EXEPATH)")
                    TEMP_EXE_WDIR="$TEMP_END"
                    break
                    ;;
                *)
                    TEMP_END="$(basename "$TEMP")"'\\'"$TEMP_END"
                    TEMP=$(dirname "$TEMP")
                    ;;
            esac
        done
        TEMP_EXE_WDIR=${TEMP_END%'\\'}
    fi
    [[ -n $TEMP_EXE_LROOT && -n $TEMP_EXEPATH ]] && TEMP_EXE_LDIR=$(apprun_realpath "$TEMP_EXE_LROOT" "$(dirname "$TEMP_EXEPATH")")
    [[ -n $TEMP_EXEPATH ]] && TEMP_EXENAME=$(basename "$TEMP_EXEPATH")

    # only keep $TEMP_EXENAME, $TEMP_EXE_LDIR, $TEMP_EXE_WROOT, $TEMP_EXE_WDIR
    unset TEMP
    unset TEMP_FILENAME
    unset TEMP_END
    unset TEMP_EXEPATH
    unset TEMP_EXE_LROOT
    unset RETURN_STATUS
}
##############################################


##############################################
## Select savedata location, then detect
## relative path. Then save the result in
## TEMP_SAVEDATA* env variables.
# Required env:
#   $EXEINFO_GEN_METHOD
#   $HOME_FAKE
#   $HOME_REAL
#
# Export env:
#   $TEMP_SAVEDATA_DIR
#   $TEMP_SAVEDATA_IN_HOME
function exeinfo_savedata_location(){
    export HOME="$HOME_FAKE"
    exeinfo_user_dirs

    local RETURN_STATUS
    local TEMP_SAVEDATAPATH
    local TEMP_SAVEDATAPATH_REAL
    local TEMP_APPIMAGE_CACHE_DIR_TO_MYAPP
    local TEMP_APPDIR_TO_MYAPP

    if [[ $EXEINFO_GEN_METHOD == "kdialog" ]];
    then
        TEMP_SAVEDATAPATH=$(kdialog --geometry 800x600 --title "select the directory where to save the savedata files" --getexistingdirectory "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}" )
        RETURN_STATUS="$?"
    elif [[ $EXEINFO_GEN_METHOD == "zenity" ]];
    then
        TEMP_SAVEDATAPATH="$(zenity --width=800 --height=600 --file-selection --directory --title="select the directory where to save the savedata files" --filename="$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}" )"
        RETURN_STATUS="$?"
    else
        clear
        echo "  to go back to previous menu, please <backspace> to earse all words then push <enter>"
        echo ""
        echo ""
        echo "##################################################"
        echo "  select savedata directory location(use <tab> key for prompt)"
        echo "  it should be under:"
        echo "  (game folder under cache dir:) ${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}/"
        echo "  or"
        echo "  (game folder under app dir:) ${APPDIR}/opt/${MYAPP_NAME}/"
        echo "  or"
        echo "  (fake home:) ${HOME_FAKE}"
        echo "##################################################"
        echo ""
        read -e -p "input savedata directory path: " -i "$APPIMAGE_CACHE_DIR" TEMP_SAVEDATAPATH
        RETURN_STATUS="$?"
    fi

    if [[ -n "$TEMP_SAVEDATAPATH" && ! -d "$TEMP_SAVEDATAPATH" ]];
    then
        clear
        echo "########################################"
        echo "ERROR: invalid directory name: $TEMP_SAVEDATAPATH" >&2
        echo "########################################"
        echo ""
        TEMP_SAVEDATAPATH=""
        return
    fi

    clear

    # TODO: when unionfs write RO branch, which's path includes symlinks, unionfs will go passthrough the symlink
    # and write the data into RO branch, instead of writing the RW branch.
    # As a result, it failed to match $HOME_FAKE with $TEMP_SAVEDATAPATH. 
    # As a workaround, I separate $TEMP_SAVEDATAPATH and $TEMP_SAVEDATAPATH_REAL
    TEMP_SAVEDATAPATH_REAL="$(readlink -f "$TEMP_SAVEDATAPATH")"
    TEMP_APPIMAGE_CACHE_DIR_TO_MYAPP="$(readlink -f "${APPIMAGE_CACHE_DIR}/opt/${MYAPP_NAME}")"
    TEMP_APPDIR_TO_MYAPP="$(readlink -f "${APPDIR}/opt/${MYAPP_NAME}")"
    if [[ $RETURN_STATUS -eq 0 && -n $TEMP_SAVEDATAPATH ]];
    then
        if [[ "${TEMP_SAVEDATAPATH_REAL#"${TEMP_APPIMAGE_CACHE_DIR_TO_MYAPP}"}" != "$TEMP_SAVEDATAPATH_REAL" ]];
        then
            TEMP_SAVEDATA_IN_HOME=0
            TEMP_SAVEDATA_DIR='${MNT_MYAPP}/'"$(apprun_realpath "$TEMP_APPIMAGE_CACHE_DIR_TO_MYAPP" "$TEMP_SAVEDATAPATH_REAL")"
        elif [[ "${TEMP_SAVEDATAPATH_REAL#"${TEMP_APPDIR_TO_MYAPP}"}" != "$TEMP_SAVEDATAPATH_REAL" ]];
        then
            TEMP_SAVEDATA_IN_HOME=0
            TEMP_SAVEDATA_DIR='${MNT_MYAPP}/'"$(apprun_realpath "$TEMP_APPDIR_TO_MYAPP" "$TEMP_SAVEDATAPATH_REAL")"
        elif [[ "${TEMP_SAVEDATAPATH%/home/public_user/*}" != "$TEMP_SAVEDATAPATH" ]];
        then
            TEMP_SAVEDATA_IN_HOME=1
            TEMP_SAVEDATA_DIR="$(exeinfo_convert_xdg_path "$TEMP_SAVEDATAPATH")"
        else
            [[ $EXEINFO_GEN_METHOD == "kdialog" ]] && kdialog --error "you selected savedata directory outside of appimage dir."
            [[ $EXEINFO_GEN_METHOD == "zenity" ]] && zenity --width=300 --height=100 --error --text="you selected savedata directory outside of appimage dir."
            echo "########################################"
            # outside of AppDir and *.appimage.
            echo "ERROR: savedata directory outside of appimage dir." >&2
            echo "########################################"
            echo ""
            TEMP_SAVEDATAPATH=""
        fi
    fi

    export HOME="$HOME_REAL"
    exeinfo_user_dirs

    # only keep $TEMP_SAVEDATA_DIR, $TEMP_SAVEDATA_IN_HOME
    unset RETURN_STATUS
    unset TEMP_SAVEDATAPATH
    unset TEMP_SAVEDATAPATH_REAL
    unset TEMP_APPIMAGE_CACHE_DIR_TO_MYAPP
    unset TEMP_APPDIR_TO_MYAPP
}
##############################################


##############################################
## Select language env variable for exeinfo,
## then save the result into $TEMP_MYAPPLANG
# Required env:
#   $EXEINFO_GEN_METHOD
#
# Export env:
#   $TEMP_MYAPPLANG
function exeinfo_locale(){
    local TEMP_LANG
    local RETURN_STATUS

    if [[ "$EXEINFO_GEN_METHOD" == "kdialog" ]];
    then
        #NOTUSED: did not use kdialog --checklist because it only reply the tag number instead of the LANG itself
        TEMP_LANG=$(kdialog --geometry 800x600 --inputbox \
"set \$LANG for this game:
supported locale in current system:

$(localectl list-locales)

you can only choose one of above items to setup.
because if you cannot find your language in this list,
that means you cannot use this language setting to run this game.
if you cannot find your language in this list,
please use locale-gen to generate locale setting first." "$LANG")
        RETURN_STATUS="$?"
    elif [[ "$EXEINFO_GEN_METHOD" == "zenity" ]];
    then
        TEMP_LANG=$(zenity --width=800 --height=600 --list --text=\
" \
set \$LANG for this game:\n \
you can only choose one of below items to setup.\n \
because if you cannot find your language in this list,\n \
that means you cannot use this language setting to run this game.\n \
if you cannot find your language in this list,\n \
please use locale-gen to generate locale setting first.\n" \
--column="supported locale in current system:" $(localectl list-locales) )
        RETURN_STATUS=$?
    else
        clear
        echo "  to go back to previous menu, please <backspace> to earse all words then push <enter>"
        echo ""
        echo ""
        echo "##################################################"
        echo "  set \$LANG for this game:"
        echo "  supported locale in current system:"
        echo ""
        #TODO: only show *.UTF-8 in result
        localectl list-locales
        echo ""
        echo "  you can only choose one of above items to setup."
        echo "  because if you cannot find your language in this list,"
        echo "  that means you cannot use this language setting to run this game."
        echo "  if you cannot find your language in this list,"
        echo "  please use locale-gen to generate locale setting first."
        echo "##################################################"
        echo ""
        read -p "set MYAPPLANG=: " -i "$LANG" TEMP_LANG
        RETURN_STATUS="$?"
    fi

    clear
    if [[ $RETURN_STATUS -eq 0 && -n $TEMP_LANG ]];
    then
        if (localectl list-locales| grep "$TEMP_LANG" -x --quiet 2>/dev/null );
        then
            TEMP_MYAPPLANG=$TEMP_LANG
        else    
            echo "########################################"
            echo "ERROR: unsupport MYAPPLANG: $TEMP_LANG" >&2
            echo "########################################"
            echo ""
        fi
    fi
    unset TEMP_LANG
    unset RETURN_STATUS
}
##############################################


##############################################
## Save and export exeinfo file.
# Required env:
#   $EXEINFO_GEN_METHOD
#   $EXE_LDIR
#   $EXE_WROOT
#   $EXE_WDIR
#   $EXENAME
#   $SAVEDATA_IN_HOME
#   $SAVEDATA_DIR
#   $MYAPPLANG
#   $TEMP_EXE_LDIR
#   $TEMP_EXE_WROOT
#   $TEMP_EXE_WDIR
#   $TEMP_EXENAME
#   $TEMP_SAVEDATA_IN_HOME
#   $TEMP_SAVEDATA_DIR
#   $TEMP_MYAPPLANG
#
# Export env:
#   $EXIT_MAIN_MENU
#
# Result:
#   Save and export exeinfo file,
#   or
#   cancel then go back to main menu.
function exeinfo_write_file(){
    local RETURN_NUMBER

    if [[ $EXEINFO_GEN_METHOD == "kdialog" ]];
    then
        kdialog --geometry 800x600 --warningcontinuecancel \
"old:
EXE_LDIR=\"$EXE_LDIR\"
EXE_WROOT=\"$EXE_WROOT\"
EXE_WDIR=\"$EXE_WDIR\"
EXENAME=\"$EXENAME\"
SAVEDATA_IN_HOME=\"$SAVEDATA_IN_HOME\"
SAVEDATA_DIR=\"$SAVEDATA_DIR\"
MYAPPLANG=\"$MYAPPLANG\"

new:
EXE_LDIR=\"$TEMP_EXE_LDIR\"
EXE_WROOT=\"$TEMP_EXE_WROOT\"
EXE_WDIR=\"$TEMP_EXE_WDIR\"
EXENAME=\"$TEMP_EXENAME\"
SAVEDATA_IN_HOME=\"$TEMP_SAVEDATA_IN_HOME\"
SAVEDATA_DIR=\"$TEMP_SAVEDATA_DIR\"
MYAPPLANG=\"$TEMP_MYAPPLANG\"

write into exeinfo_profile?
"
        RETURN_NUMBER=$?
    elif [[ $EXEINFO_GEN_METHOD == "zenity" ]];
    then
        zenity --width=800 --height=600 --question --ok-label="continue" --text=\
" \
old:\n \
EXE_LDIR=\"$EXE_LDIR\"\n \
EXE_WROOT=\"$EXE_WROOT\"\n \
EXE_WDIR=\"$EXE_WDIR\"\n \
EXENAME=\"$EXENAME\"\n \
SAVEDATA_IN_HOME=\"$SAVEDATA_IN_HOME\"\n \
SAVEDATA_DIR=\"$SAVEDATA_DIR\"\n \
MYAPPLANG=\"$MYAPPLANG\"\n \
\n \
new:\n \
EXE_LDIR=\"$TEMP_EXE_LDIR\"\n \
EXE_WROOT=\"$TEMP_EXE_WROOT\"\n \
EXE_WDIR=\"$TEMP_EXE_WDIR\"\n \
EXENAME=\"$TEMP_EXENAME\"\n \
SAVEDATA_IN_HOME=\"$TEMP_SAVEDATA_IN_HOME\"\n \
SAVEDATA_DIR=\"$TEMP_SAVEDATA_DIR\"\n \
MYAPPLANG=\"$TEMP_MYAPPLANG\"\n \
\n \
write into exeinfo_profile?\n"
        RETURN_NUMBER=$?
    elif [[ $EXEINFO_GEN_METHOD == "cli" ]];
    then
        while true; do
            clear
            cat << EOF
old:
EXE_LDIR="$EXE_LDIR"
EXE_WROOT="$EXE_WROOT"
EXE_WDIR="$EXE_WDIR"
EXENAME="$EXENAME"
SAVEDATA_IN_HOME="$SAVEDATA_IN_HOME"
SAVEDATA_DIR="$SAVEDATA_DIR"
MYAPPLANG="$MYAPPLANG"

new:
EXE_LDIR="$TEMP_EXE_LDIR"
EXE_WROOT="$TEMP_EXE_WROOT"
EXE_WDIR="$TEMP_EXE_WDIR"
EXENAME="$TEMP_EXENAME"
SAVEDATA_IN_HOME="$TEMP_SAVEDATA_IN_HOME"
SAVEDATA_DIR="$TEMP_SAVEDATA_DIR"
MYAPPLANG="$TEMP_MYAPPLANG"

EOF
            read -p "write into exeinfo_profile?(y/n): " RETURN_NUMBER
            case $RETURN_NUMBER in
                y| Y| yes| YES)
                    RETURN_NUMBER=0
                    break
                    ;;
                n| N| no| NO)
                    RETURN_NUMBER=1
                    break
                    ;;
                *)
                    ;;
            esac
        done
    else
        return
    fi

    if [[ ! $RETURN_NUMBER -eq 0 ]];
    then
        RETURN_NUMBER=""
        clear
        return
    fi
    mkdir -p "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/myapp_exeinfo"
    cat << EOF > "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile"
EXE_LDIR="$TEMP_EXE_LDIR"
EXE_WROOT="$TEMP_EXE_WROOT"
EXE_WDIR="$TEMP_EXE_WDIR"
EXENAME="$TEMP_EXENAME"
SAVEDATA_IN_HOME="$TEMP_SAVEDATA_IN_HOME"
SAVEDATA_DIR="$TEMP_SAVEDATA_DIR"
MYAPPLANG="$TEMP_MYAPPLANG"
EOF
    echo "saved into $APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile"
    if [[ -n "$TEMP_MYAPPLANG" ]];
    then
        cat "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile" > "$APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile.$TEMP_MYAPPLANG"
        echo "saved into $APPIMAGE_CACHE_DIR/opt/${MYAPP_NAME}/myapp_exeinfo/exeinfo_profile.$TEMP_MYAPPLANG"
    fi
    EXIT_MAIN_MENU=1

}
##############################################


##############################################
## Confirm before exit exeinfo main menu
# Required env:
#   $EXEINFO_GEN_METHOD
#
# Export env:
#   $EXIT_MAIN_MENU
function exeinfo_confirm_exit(){
    local RETURN_NUMBER
    if [[ "$EXEINFO_GEN_METHOD" == "kdialog" ]];
    then
        kdialog --yesno "exit exeinfo setting?"
        RETURN_NUMBER=$?
    elif [[ "$EXEINFO_GEN_METHOD" == "zenity" ]];
    then
        zenity --question --text="exit exeinfo setting?"
        RETURN_NUMBER=$?
    elif [[ "$EXEINFO_GEN_METHOD" == "cli" ]];
    then
        while true; do
            read -p "exit exeinfo setting?(y/n): " RETURN_NUMBER
            case "$RETURN_NUMBER" in
                y| Y| yes| YES)
                    RETURN_NUMBER=0
                    break
                    ;;
                n| N| no| NO)
                    RETURN_NUMBER=1
                    break
                    ;;
                *)
                    ;;
            esac
        done
    else
        return
    fi

    if [[ $RETURN_NUMBER -eq 0 ]];
    then
        EXIT_MAIN_MENU=1
    elif [[ $RETURN_NUMBER -eq 1 ]];
    then
        clear
        return
    else
        echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] unknow error" >&2
        EXIT_MAIN_MENU=1
    fi
}
##############################################


##############################################
## Exeinfo plugin main background process
# Optional env:
#   $EXIT_MAIN_MENU:
#       when set to 1, end the loop then exit.
#
# Export env:
#   $EXIT_MAIN_MENU
function exeinfo_main(){
    clear
    local MENU_SELECT_ITEM
    exeinfo_load_temp
    exeinfo_test_gui
    EXIT_MAIN_MENU=0
    while [[ $EXIT_MAIN_MENU -eq 0 ]];do
        exeinfo_main_menu
        clear
        if [[ $MENU_SELECT_ITEM -eq 1 ]];
        then 
            exeinfo_exe_location
        elif [[ $MENU_SELECT_ITEM -eq 2 ]];
        then
            exeinfo_savedata_location
        elif [[ $MENU_SELECT_ITEM -eq 3 ]];
        then
            exeinfo_locale
        elif [[ $MENU_SELECT_ITEM -eq 4 ]];
        then
            exeinfo_write_file
        elif [[ $MENU_SELECT_ITEM -eq 5 ]];
        then
            exeinfo_confirm_exit
        else
            echo "[$(basename "${BASH_SOURCE[0]}"):${FUNCNAME[0]}] ERROR: unknown \$MENU_SELECT_ITEM=$MENU_SELECT_ITEM"
            EXIT_MAIN_MENU=1
        fi
    done
    unset MENU_SELECT_ITEM
}

[[ "$0" == "${BASH_SOURCE[0]}" && $MYAPPDEBUG -eq 1 ]] && exeinfo_test_env
if [[ "$0" == "${BASH_SOURCE[0]}" ]];
then
    [[ -n "$APPDIR" ]] || echo "[$(basename "${BASH_SOURCE[0]}")] required \$APPDIR but it was not set" >&2
    [[ -n "$APPIMAGE_CACHE_DIR" ]] || echo "[$(basename "${BASH_SOURCE[0]}")] required \$APPIMAGE_CACHE_DIR but it was not set" >&2
    [[ -n "$EXEINFO_GEN_METHOD" ]] || echo "[$(basename "${BASH_SOURCE[0]}")] required \$EXEINFO_GEN_METHOD but it was not set" >&2
    [[ -n "$APPDIR" && -n "$APPIMAGE_CACHE_DIR" && -n "$EXEINFO_GEN_METHOD" ]] || exit 1
    exeinfo_main
fi

##############################################



