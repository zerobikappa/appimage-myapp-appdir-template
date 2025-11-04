#!/bin/bash

##############################################
## Bash source setting
if [[ $MYAPP_CORE_SOURCED -eq 1 ]];
then
    return
else
    MYAPP_CORE_SOURCED=1
    export MYAPP_CORE_SOURCED
fi

# only for code analysis with coc.vim
source ./myapp-debug.sh 2>/dev/null
source ./myapp-plugin-exeinfo.sh 2>/dev/null
source ./myapp-plugin-wine.sh 2>/dev/null
source ./myapp-plugin-unionfs-fuse.sh 2>/dev/null
#############################################


#############################################
## prevent running by root/sudo
## for security concern.
function prevent_root(){
    if [[ $(id -u) -eq 0 ]];
    then
        echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: prevent running by root/sudo"
        echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: you should not using root/sudo to run this application"
        exit
    fi
}
#############################################


##############################################
## Print help message when you add --help or -h
## after appimage. Replace the original help
## message.
function print_help(){
    cat << \EOF
run option:

  -s, --savedata
    load the full-completed savedata

  -w, --walkthrough
    open walkthrough with browser

  --browser=BROWSER_COMMAND
    only effect when -w is set.
    using another browser application to open
    walkthrough. for example, "--browser=firefox"
    means using firefox to open walkthrough.html

  -p, --portable-cache
    create ${APPIMAGE}.cache directory then exit.
    when running appimage, $HOME and $XDG_CONFIG_HOME
    will be redirect to this directory to prevent
    changing files in local $HOME.

  -h, --help
    show this help, then exit

  --version
    show application information and version, then exit


test option:

  -t, --test-winetricks
    open winetricks in temporary directory,
    use this option to test or install windows application.
    when this option set, -s and -w will be ignored.

  --exeinfo-gen [=gui|cli|zenity|kdialog]
        =gui :automatically find zenity or kdialog to run
        =cli :(only apply when launch from command line)
        =zenity :use zenity to run
        =kdialog :use kdialog to run
    after install windows application in AppDir,
    run "./AppRun --exeinfo-gen" to generate
    exeinfo_profile. default is "gui"


appimage option:

  --appimage-help
    show help about appimage function

  --appimage-extract [<pattern>]
    Extract content from embedded filesystem image
    If pattern is passed, only extract matching files

EOF
}
##############################################


##############################################
## print version message of the appimage file.
# required env:
#     $MYAPPRUN_VERSION: myapp script version.
#     $APPDIR
function print_version(){

    if [[ -d $APPIMAGE ]];
    then
        #APPIMAGEKIT_VERSION="AppImageKit Version: (empty)(directly running from AppDir)"
        echo "***AppImageKit Version***"
        echo "(empty)(directly running from AppDir)"
    else
        #APPIMAGEKIT_VERSION="AppImageKit $($APPIMAGE --appimage-version)"    #NOTUSED: printed out wrong format
        echo "***AppImageKit Version***"
        $APPIMAGE --appimage-version
    fi
    # Only detect exeinfo_profile under $APPDIR. 
    # exeinfo_profile under $APPIMAGE_CACHE_DIR was ignored.
    if [[ -f "$(readlink -m "${APPDIR}/opt/${MYAPP_NAME}/myapp/myapp_exeinfo/exeinfo_profile")" ]];
    then
        source "$(readlink -m "${APPDIR}/opt/${MYAPP_NAME}/myapp/myapp_exeinfo/exeinfo_profile")"
    fi
    [[ -z $EXENAME ]] && EXENAME="(empty)(not set in AppDir)"
    APPLICATION_NAME=$(cat "$APPDIR"/*.desktop | grep -i "name=") && APPLICATION_NAME=${APPLICATION_NAME#*"="}
    APPLICATION_DESCRIPTION=$(cat "$APPDIR"/*.desktop | grep -i "comment=") && APPLICATION_DESCRIPTION=${APPLICATION_DESCRIPTION#*"="}
    [[ -z $MYAPPLANG ]] && MYAPPLANG="(not set default language)"
    cat << EOF

  ***Application Info***
  AppRun script version: $MYAPPRUN_VERSION
  .exe name: $EXENAME
  application name: $APPLICATION_NAME
  application description: $APPLICATION_DESCRIPTION
  optional language:
      LANG=$MYAPPLANG(default)
EOF

# Only detect exeinfo_profile under $APPDIR. 
# exeinfo_profile under $APPIMAGE_CACHE_DIR was ignored.
find "$(readlink -m "${APPDIR}/opt/${MYAPP_NAME}/myapp/myapp_exeinfo")" -mindepth 1 -maxdepth 1 -name "exeinfo_profile.*" -print0 | sort -z | while read -d $'\0' OPTIONAL_EXEINFO_PROFILE;
    do
        local TEMP_KEY_WORD
        TEMP_KEY_WORD="$(cat "$OPTIONAL_EXEINFO_PROFILE" | grep '^[[:blank:]]*[^[:blank:]#]' | grep "MYAPPLANG=")"
        TEMP_KEY_WORD="${TEMP_KEY_WORD#*'MYAPPLANG='}"
        TEMP_KEY_WORD="${TEMP_KEY_WORD##\"}"
        TEMP_KEY_WORD="${TEMP_KEY_WORD%%\"}"
        [[ -z "$TEMP_KEY_WORD" ]] && continue
        echo '      LANG='"$TEMP_KEY_WORD"
    done
    unset TEMP_KEY_WORD
    echo ""
}
##############################################


##############################################
## option check, determine if the input argument
## is a long option, short option,
## or a normal argument.
#
# required argument:
#   a string without any whitespace. Not support
#   multiple arguments.
#
# output:
#   string "long": It is a long option with prefix "--".
#   string "short": It is a short option with prefix "-".
#   string "none": It is a normal argument.
function option_check(){
    # do not place any debug output here, because this function use "echo" command to return result.

    if [[ ${1::2} == "--" ]];
    then
        echo "long"
    elif [[ ${1::1} == "-" ]];
    then
        echo "short"
    else
        echo "none"
    fi
}
##############################################


##############################################
## handle the arguments, which were
## appended after appimage file or AppRun.sh
## when run appimage file or AppRun.sh from
## commandline.
# required argument:
#   "$@", which was passed from commandline.
#
# result:
#   (1)May set and export below environment variables:
#       $next_parameters
#       $SAVEDATA_FLAG
#       $WALKTHROUGH_FLAG
#       $TEST_WINETRICKS_FLAG
#       $EXEINFO_GEN_FLAG
#
#   (2)May print help message.
#
#   (3)May print version message.
#
#   (4)May create $APPIMAGE.cache directory. 
#
function core_handle_param(){
    #parameters=$(getopt -o swth --long save-data,walkthrough,browser:,test-winetricks,help -n "$0" -- "$@")    # NOTUSED: because $(getopt) cannot ignore unknown options
    
    local parameters
    parameters=$(echo "$@"|tr "=" " ")
    # in this script, if I initialize a variable to empty,
    # that means I want to avoid some unexpected error,
    # in case user pass an initial value in command line
    declare -g next_parameters
    export next_parameters=""

    eval set -- "$parameters"
    
    while [[ -n "$1" ]] ; do
        case "$1" in
            -h| --help)
                print_help
                exit ;;
            --version)
                print_version
                exit ;;
            -s| --savedata)
                declare -g SAVEDATA_FLAG
                SAVEDATA_FLAG=1
                shift ;;
            -w| --walkthrough)
                declare -g WALKTHROUGH_FLAG
                WALKTHROUGH_FLAG=1
                shift ;;
            --browser)
                #i3-sensible-browser will choose $BROWSER to open walkthrough first
                [[ $(option_check "$2") != "none" ]] && echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: invalid option $1" >&2 && exit 1
                BROWSER="$2"
                shift 2;;
            -t| --test-winetricks)
                declare -g TEST_WINETRICKS_FLAG
                TEST_WINETRICKS_FLAG=1
                shift ;;
            --exeinfo-gen)
                declare -g EXEINFO_GEN_FLAG
                declare -g EXEINFO_GEN_METHOD
                EXEINFO_GEN_FLAG=1
                if [[ $2 == "zenity" ]];
                then
                    EXEINFO_GEN_METHOD="zenity"
                    shift 2
                elif [[ $2 == "kdialog" ]];
                then
                    EXEINFO_GEN_METHOD="kdialog"
                    shift 2
                elif [[ $2 == "gui" ]];
                then
                    EXEINFO_GEN_METHOD="gui"
                    shift 2
                elif [[ $2 == "cli" ]];
                then
                    EXEINFO_GEN_METHOD="cli"
                    shift 2
                else
                    EXEINFO_GEN_METHOD="gui"
                    shift
                fi
                ;;
            -p| --portable-cache)
                mkdir -p "$APPIMAGE".cache/home/public_user/
                echo ""
                echo "created cache directory: $APPIMAGE.cache"
                exit ;;
            --)
                shift
                if [[ -z "$*" && -z "$next_parameters" ]];
                then
                    break
                elif [[ ! $MYAPPDEBUG -eq 1 ]];
                then
                    echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: not MYAPPDEBUG mode now. prevent to pass any unknown option." >&2
                    echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: unknown options, ignored: $next_parameters $@" >&2
                    # TODO: bugs: vimspector+vscode-bash-debug always append a "undefined" argument.
                    # which will cause exit here.
                    # refer:
                    # https://github.com/puremourning/vimspector/issues/766
                    #exit
                    shift $#
                    break
                else
                    # then $next_parameters will be passed to wine
                    [[ -z $next_parameters ]] && next_parameters="$@" || next_parameters="$next_parameters $@"
                    shift $#
                    break
                fi
                ;;
            *)
                if [[ "$(option_check "$1")" == "short" && ${#1} -gt 2 ]];
                then
                    parameters="$(getopt -o 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ -n "$0" -- "$1")"
                    parameters="${parameters%%' --'*}"
                    shift
                    parameters="$parameters $@"
                    eval set -- "$parameters"
                elif [[ $MYAPPDEBUG -eq 1 ]];
                then
                    [[ -z $next_parameters ]] && next_parameters="$1" || next_parameters="$next_parameters $1"
                    shift
                else
                    echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: not MYAPPDEBUG mode now. prevent to pass any unknow option." >&2
                    echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: unknown options, ignored: $1" >&2
                    # TODO: bugs: vimspector+vscode-bash-debug always append a "undefined" argument.
                    # which will cause exit here.
                    # refer:
                    # https://github.com/puremourning/vimspector/issues/766
                    #exit
                    shift
                fi
                ;;
        esac
    done
    
    # as the case<...>esac statement set above, if you want to debug your appimage and make some unknown option/argument passthrough to wine, you can follow:
    # set the env: MYAPPDEBUG=1 (otherwise it will prevent unknown option/argument passthrough)
    # then all unused option will be passed to wine.
    # you can also place "--" before your option to avoid my script catching your option. for example:
    # ./yourappimagename -s    the "-s" option will be catched by my script to run "load savedata"
    # ./yourappimagename -- -s    the "-s" option will pass to wine


    # if --exeinfo-gen or --test-winetricks is set, then -s and -w will be ignored.
    if [[ $TEST_WINETRICKS_FLAG -eq 1 || $EXEINFO_GEN_FLAG -eq 1 ]];
    then
        [[ $SAVEDATA_FLAG -eq 1 ]] && SAVEDATA_FLAG=0 && echo "--savedata option ignored"
        [[ $WALKTHROUGH_FLAG -eq 1 ]] && WALKTHROUGH_FLAG=0 && echo "--walkthrough option ignored"
    fi
    
    # if --exeinfo-gen is set, then -t will be ignored.
    if [[ $EXEINFO_GEN_FLAG -eq 1 ]];
    then
        [[ $TEST_WINETRICKS_FLAG -eq 1 ]] && TEST_WINETRICKS_FLAG=0 && echo "--test-winetricks option ignored"
    fi
}
##############################################


##############################################
## setup *.cache directory
# required env:
#   if run from appdir: N/A
#   if run appimage:
#       $APPIMAGE
#       $ARGV0
#
# export env:
#   $APPIMAGE_CACHE_DIR
function core_cache_dir_setup(){
    if [[ -d ${APPIMAGE}.cache ]];
    then
        APPIMAGE_CACHE_DIR="${APPIMAGE}.cache"
        export APPIMAGE_CACHE_DIR
    else
        echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
        echo "@"
        echo "  directory ${APPIMAGE}.cache/ not exist."
        echo "  all data will be saved in /tmp/$(basename "$APPIMAGE").cache/ , which will be deleted after restart computer."
        echo "  to keep your data, please run:"
        echo ""
        [[ -n $ARGV0 ]] && echo "    $ARGV0 --portable-cache" || echo "    ${APPIMAGE}/AppRun --portable-cache"
        echo ""
        echo "  to create a cache directory."
        echo "@"
        echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
        mkdir -p "/tmp/$(basename "$APPIMAGE").cache"
        APPIMAGE_CACHE_DIR="/tmp/$(basename "$APPIMAGE").cache"
        export APPIMAGE_CACHE_DIR
    fi


    ## setup standalone $HOME and $XDG_CONFIG_HOME directory
    ## not redirect $HOME and $XDG_CONFIG_HOME at this moment because exeinfo plugin need original $HOME and $XDG_CONFIG_HOME env.
    
    if [[ ! -d ${APPIMAGE_CACHE_DIR}/home/public_user/.config ]];
    then
        mkdir -p "${APPIMAGE_CACHE_DIR}/home/public_user/.config"
    fi
    
    if [[ -d ${APPIMAGE}.home ]];
    then
        echo "${APPIMAGE}.home exists but is not necessary."
        echo "Because we default to use $APPIMAGE_CACHE_DIR/home/public_user/ to save related files."
    fi
    
    if [[ -d ${APPIMAGE}.config ]];
    then
        echo "${APPIMAGE}.config exists but is not necessary."
        echo "Because we default to use $APPIMAGE_CACHE_DIR/home/public_user/.config to save related files."
    fi
}
##############################################


##############################################
## trap exit setting
function atexit() {
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    # atexit function takes too much time, use a flag to indicate the running status of atexit()
    # to prevent triggering atexit() again during running atexit()
    export ATEXIT_FLAG=1

    # "rm -rf" included, must check env first.
    [[ -z "$APPDIR" ]] && echo "[myapp:atexit] ERROR:\$APPDIR not set, could not clean temp files" >&2 && return
    [[ -z "$APPIMAGE_CACHE_DIR" ]] && echo "[myapp:atexit] ERROR:\$APPIMAGE_CACHE_DIR not set, could not clean temp files." >&2 && return

    # some application will change the reg in wine.
    # if return out of this function directly without waiting wine shutdown,
    # unionfs drive will be unmount immediately.
    # therefore we can add a "wineboot" command to wait for wine saving the registry.
    if [[ ! $EXEINFO_GEN_FLAG -eq 1 ]];
    then
        #go back to $APPDIR, then remove temp file
        cd "$APPDIR" || exit 2
    
        echo "[${FUNCNAME[0]}:10%] restore wine drive symlink entries..."
        wine_restore_prefix >&3 2>&4
        echo "[${FUNCNAME[0]}:30%] wait shutdown prefix..."
        wine_wait_shutdown >&3 2>&4
        # "wineserver -k" was included in wine_wait_shutdown, but still make second attempt here if previous step was interrupted.
        # to ensure all the exe process are killed
        if [[ $? -ne 0 ]];
        then
            wineserver -k
        fi

        [[ $SAVEDATA_FLAG -eq 1 ]] && savedata_restore
    fi

    echo "[${FUNCNAME[0]}:40%] removing drive symlink from wine prefix"
    find "$WINEPREFIX/dosdevices" -mindepth 1 -maxdepth 1 ! -name "c:" ! -name "d:" -exec rm -rf "{}" \;
    echo "[${FUNCNAME[0]}:50%] killing unionfs"

    mpPlugin_fusetool_unmount

    echo "[${FUNCNAME[0]}:100%] ended"
    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}

function preexit(){
    if [[ $ATEXIT_FLAG -eq 0 ]];
    then
        #TODO: unable to redirect fd when running
        #debug_fd_switch "on"
        exit
    else
        return
    fi
}
# default run in main.sh:
#ATEXIT_FLAG=0
#trap atexit EXIT
#trap preexit SIGHUP SIGINT SIGQUIT SIGKILL SIGTERM
##############################################


##############################################
## show the game walkthrough on std_out,
## you can see this info when using commandline
## to launch this app.
# required env:
#     $MNT_MYAPP
#     $WALKTHROUGH_TEMP
function walkthrough_browser(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    cat << EOF
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@
  you can also click below files to show game walkthrough:
@
EOF

    # NOTUSED: cannot handle file name with whitespace
    #for i in $(ls "$MNT_MYAPP/myapp_walkthrough"/*.html);
    #do
    #    #echo "  file://$MNT_MYAPP/drive_d/myapp_walkthrough/$i"
    #    # ls will output the full path if run -> ls /full/path/to/file/*.html
    #    echo "  file://$i"
    #done

    # althrough it can handle file name including whitespace character, it is still recommanded to remove all whitespace from filename
    find "$MNT_MYAPP/myapp_walkthrough" -mindepth 1 -maxdepth 1 -name "*.html" -print0 | while read -d $'\0' WALKTHROUGH_TEMP;
    do
        echo "  file://$WALKTHROUGH_TEMP"
    done
    find "$MNT_MYAPP/myapp_walkthrough" -mindepth 1 -maxdepth 1 -name "*.pdf" -print0 | while read -d $'\0' WALKTHROUGH_TEMP;
    do
        echo "  file://$WALKTHROUGH_TEMP"
    done

    cat << EOF
@
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

EOF
    # TODO: failed to using xdg-open to open html file.
    # TRY: use xdg-settings to get the default 
    # browser first.
    local OPEN_BROWSER
    if [[ -x "$(command -v xdg-settings 2>/dev/null)" ]];then
        OPEN_BROWSER=$(xdg-settings get default-web-browser)
        # remove ".desktop" extension.
        OPEN_BROWSER=${OPEN_BROWSER%.*}
    fi
    if ! [[ -x "$(command -v "$OPEN_BROWSER" 2>/dev/null)" ]];then
        OPEN_BROWSER="i3-sensible-browser"
    fi

    [[ -n "$(find "$MNT_MYAPP/myapp_walkthrough" -mindepth 1 -maxdepth 1 -name "*.html")" ]] && "$OPEN_BROWSER" "$MNT_MYAPP/myapp_walkthrough"/*.html &
    [[ -n "$(find "$MNT_MYAPP/myapp_walkthrough" -mindepth 1 -maxdepth 1 -name "*.pdf")" ]] && "$OPEN_BROWSER" "$MNT_MYAPP/myapp_walkthrough"/*.pdf &

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}

##############################################


##############################################
## replace user game savedata with built-in
## savedata.
# Required env:
#   $USER
#   $MNT_MYAPP
#   $HOME_FAKE
#
# Export env:
#   $HOME:
#     Always set $HOME to $HOME_FAKE
function savedata_replace(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    HOME="$HOME_FAKE"
    #exeinfo_user_dirs
    exeinfo_load_file
    #if [[ $SAVEDATA_IN_HOME -eq 0 ]];
    #then
    #    mkdir -p "$SAVEDATA_DIR"
    #    cp -r --suffix=.myapp."$USER".backup "$MNT_MYAPP/myapp_savedata"/* "$SAVEDATA_DIR"
    #elif [[ $SAVEDATA_IN_HOME -eq 1 ]];
    #then
    #    mkdir -p "$SAVEDATA_DIR"
    #    cp -r --suffix=.myapp."$USER".backup "$MNT_MYAPP/myapp_savedata"/* "$SAVEDATA_DIR"
    #fi

    #mkdir -p "$SAVEDATA_DIR"
    #if [[ $? -eq 0 ]];
    if (mkdir -p "$SAVEDATA_DIR");
    then
        cp -r --suffix=.myapp."$USER".backup "$MNT_MYAPP/myapp_savedata"/* "$SAVEDATA_DIR"
    else
        echo "failed to setup savedate directory: $SAVEDATA_DIR" >&2
    fi


    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################


##############################################
## restore user game savedata before end the
## application.
# Required env:
#   $USER
#   $MNT_MYAPP
#   $HOME_FAKE
#   $SAVEDATA_DIR
#
# Export env:
#   $HOME:
#     Always set $HOME to $HOME_FAKE
function savedata_restore(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    HOME="$HOME_FAKE"
    if [[ -z "$SAVEDATA_DIR" ]];
    then
        echo "[savedata_restore] ERROR:\$SAVEDATA_DIR is empty" >&2
        return
    fi

    echo ""
    echo "remove temp savedata..."
    find "$MNT_MYAPP/myapp_savedata/" -mindepth 1 -type f -print0 | while read -d $'\0' SAVEDATA_TEMP;
    do
        rm -fv "$SAVEDATA_DIR/${SAVEDATA_TEMP#"$MNT_MYAPP/myapp_savedata/"}" 2>/dev/null
    done
    unset SAVEDATA_TEMP

    echo ""
    echo "restore user savedata..."
    #SAVEDATA_RESTORE_LIST="$(find "$FIND_DIR" -type f -name "*.myapp.$USER.backup")"
    #for SAVEDATA_BACKUP in $SAVEDATA_RESTORE_LIST ; do    #NOT USED: could not handle filename with whitespace
    find "$SAVEDATA_DIR" -mindepth 1 -name "*.myapp.$USER.backup" -print0 | while read -d $'\0' SAVEDATA_BACKUP;
    do
        #echo  "$SAVEDATA_BACKUP" ' >>to>> ' "${SAVEDATA_BACKUP%".myapp.$USER.backup"}"
        mv -fv "$SAVEDATA_BACKUP" "${SAVEDATA_BACKUP%".myapp.$USER.backup"}"
    done
    echo ""
    unset SAVEDATA_BACKUP

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################

##############################################
## show user savedata location on std_out
# required env:
#   $UPPERDIR_MYAPP
#   $UPPERDIR_HOME
function savedata_show_location(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

cat << EOF
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@
@
  your files are saved in:
@
    file://$UPPERDIR_MYAPP/
    file://$UPPERDIR_HOME/
@
@
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
EOF

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}

##############################################



##############################################
## launch app
# Required env:
#   $HOME_REAL
#   $HOME_FAKE
#   $WINEARCH
#
# Receive argument:
#   $next_parameters passed from outside.
#
# Optional env:
#   $EXEINFO_GEN_FLAG
#   $TEST_WINETRICKS_FLAG
#   $MYAPPLANG
function myapp_launch(){
    # should mount unionfs before run exeinfo generator
    # because zenity and kdialog may read the config files in $HOME
    # what is more, it may need to use $XDG_{DOCUMENTS,DOWNLOAD,...}_DIR to 
    # calculate the relative path.
    if [[ $EXEINFO_GEN_FLAG -eq 1 ]];
    then
        # should use real $HOME to run
        # otherwise zenity/kdialog may output wrong path in file selection dialog
        HOME="$HOME_REAL" exeinfo_main
    
        # if I need to remove some file before end the program
        # I may forgot to change $HOME to fake home
        # it is better to switch to fake home immediately
        HOME="$HOME_FAKE"
    fi
    
    
    if [[ ! $EXEINFO_GEN_FLAG -eq 1 ]];
    then
        [[ -n $MYAPPLANG ]] && LANG=$MYAPPLANG || echo "MYAPPLANG not set, using current LANG:$LANG"
        export HOME="$HOME_FAKE"
        export XDG_CONFIG_HOME="$HOME_FAKE/.config"
        MYAPPDEBUG_COLOR=1 debug_print_env "HOME" "XDG_CONFIG_HOME" "WINETRICKS_BIN"
        echo "*****using $WINEARCH"
        if [[ $TEST_WINETRICKS_FLAG -eq 1 ]];
        then
            wine_run_winetricks "$@"
        else
            wine_run_exe "$@"
        fi
    fi
}
##############################################



##############################################
## monitor if the .exe is still running
## however, if the .exe file is only a launcher
## to launch other .exe files. pls change below
## code to monitor other the correct *.exe files.
# Required env:
#   $EXENAME
function monitor_exe_running(){
    echo "start >>>>>>>> [${FUNCNAME[0]}]" >&3

    # if you find the $EXENAME is only a launcher to launch other *.exe,
    # you can uncomment below line to change the $EXENAME to another name.

    #EXENAME="another name"        # uncomment this line if you need to monitor *.exe with another name.
    [[ -z "$EXENAME" ]] && return

    if [[ -n "$(pgrep -fi "$EXENAME")" ]];
    then
        echo "$(pgrep -fai "$EXENAME")" '-------- running'
    fi

    while true
    do
        sleep 5
        if [[ -z "$(pgrep -fi "$EXENAME")" ]];
        then
            echo "$EXENAME was ended"
            break    # the $EXENAME exe is no longer running
        fi
    done

    echo "end >>>>>>>> [${FUNCNAME[0]}]" >&3
}
##############################################
