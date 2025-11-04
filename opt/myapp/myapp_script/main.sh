#!/bin/bash

# AppRun Script version
# date -u +%s
MYAPPRUN_VERSION=3.1.1
export MYAPPRUN_VERSION


# https://docs.appimage.org/packaging-guide/environment-variables.html
# Already receive below variables from AppRun:
#
# LANG:
#     $LANG from env, user can manually specify in commandline.
#
# APPIMAGE:
#     (running from appdir)empty.
#     (running appimage)Absolute path to AppImage file (with symlinks resolved).
#
# APPDIR:
#     (running from appdir)empty.
#     (running appimage)Full path of appdir. Path of mountpoint of the SquashFS image contained in the AppImage.
#
# OWD:
#     (running from appdir)empty.
#     (running appimage)Path to working directory at the time the AppImage is called.
#
# ARGV0:
#     (running from appdir)empty.
#     (running appimage)Name/path used to execute the script. This corresponds to the value you’d normally receive via the argv argument passed to your main method. Usually contains the filename or path to the AppImage, relative to the current working directory.


#############################################
## env settings
SELF=$(readlink -f "$0")
# moved script from HERE(AppDir) to HERE/opt/${MYAPP_NAME}/myapp_script/, therefore use $APPDIR to replace $HERE
HERE=${SELF%/*}
[[ -z $APPDIR ]] && APPDIR=${SELF%/opt/*}

# keep a backup of $PATH location. Because later I will compare the version number of local winetricks and builtin winetricks.
export PATH_OLD="$PATH"
export PATH="${SELF%/*}/:${APPDIR}/usr/bin/:${APPDIR}/usr/sbin/:${APPDIR}/usr/games/:${APPDIR}/bin/:${APPDIR}/sbin/${PATH:+:$PATH}"
export PATH_NEW="$PATH"

export LD_LIBRARY_PATH="${APPDIR}/usr/lib/:${APPDIR}/usr/lib/i386-linux-gnu/:${APPDIR}/usr/lib/x86_64-linux-gnu/:${APPDIR}/usr/lib32/:${APPDIR}/usr/lib64/:${APPDIR}/lib/:${APPDIR}/lib/i386-linux-gnu/:${APPDIR}/lib/x86_64-linux-gnu/:${APPDIR}/lib32/:${APPDIR}/lib64/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="${APPDIR}/usr/share/pyshared/${PYTHONPATH:+:$PYTHONPATH}"
# if XDG_DATA_DIRS is empty, after add ${APPDIR}/user/share/ into XDG_DATA_DIRS, also need to manual add default data path, otherwise local zenity could not load data files.
#export XDG_DATA_DIRS="${APPDIR}/usr/share/${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export XDG_DATA_DIRS="${APPDIR}/usr/share/${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}:/usr/local/share/:/usr/share/"
export PERLLIB="${APPDIR}/usr/share/perl5/:${APPDIR}/usr/lib/perl5/${PERLLIB:+:$PERLLIB}"
export GSETTINGS_SCHEMA_DIR="${APPDIR}/usr/share/glib-2.0/schemas/${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export QT_PLUGIN_PATH="${APPDIR}/usr/lib/qt4/plugins/:${APPDIR}/usr/lib/i386-linux-gnu/qt4/plugins/:${APPDIR}/usr/lib/x86_64-linux-gnu/qt4/plugins/:${APPDIR}/usr/lib32/qt4/plugins/:${APPDIR}/usr/lib64/qt4/plugins/:${APPDIR}/usr/lib/qt5/plugins/:${APPDIR}/usr/lib/i386-linux-gnu/qt5/plugins/:${APPDIR}/usr/lib/x86_64-linux-gnu/qt5/plugins/:${APPDIR}/usr/lib32/qt5/plugins/:${APPDIR}/usr/lib64/qt5/plugins/${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
#EXEC=$(grep -e '^Exec=.*' "${APPDIR}"/*.desktop | head -n 1 | cut -d "=" -f 2 | cut -d " " -f 1)
#exec "${EXEC}" "$@"
#############################################

# only for code analysis with coc.vim
source ./core.sh 2>/dev/null
source ./myapp-debug.sh 2>/dev/null
source ./myapp-plugin-wine.sh 2>/dev/null
source ./myapp-plugin-fusetool.sh 2>/dev/null
source ./myapp-plugin-exeinfo.sh 2>/dev/null

# actual source
source "${HERE}"/core.sh
source "${HERE}"/myapp-debug.sh
source "${HERE}"/myapp-plugin-wine.sh
source "${HERE}"/myapp-plugin-fusetool.sh
source "${HERE}"/myapp-plugin-exeinfo.sh

prevent_root

debug_set

# TODO: cannot use new unionfs because same commandline options was changed.
# WALKAROUND: ship old version unionfs in appimage package.
UNIONFS_BIN="${APPDIR}/usr/bin/unionfs"
debug_print_env UNIONFS_BIN >&3 2>&4


##############################################
## check if it is running from appimage or running from appdir

# if run directly from AppDir. 
if [[ -z ${APPIMAGE} ]];
then
    export APPIMAGE="$APPDIR"
fi
##############################################

core_handle_param "$@"


[[ $MYAPPDEBUG -eq 1 ]] && debug_print_env next_parameters
# unused option/argument will be passed to wine
#eval set -- "$next_parameters"

##############################################


##############################################
## setup *.cache directory
core_cache_dir_setup
##############################################


##############################################
## setup unionfs temp directory for this app
mpPlugin_fusetool_setVar

# backup the path of $HOME because exeinfo-gen need to read the real $HOME instead of the fake one
HOME_REAL="$HOME"
HOME_FAKE="$MNT_HOME"

##############################################


##############################################
## test runtime env
[[ $MYAPPDEBUG -eq 1 ]] && debug_print_env APPIMAGE APPDIR OWD ARGV0 0
##############################################

wine_set_env
MYAPPDEBUG_COLOR=1 debug_print_env "APPDIR" "WINEPREFIX"
##############################################


# load exeinfo_profile, may depends on $WINEARCH, (if savedata in c drive,) should set the $WINEARCH first
# it may also depends on $XDG_DOCUMENTS_DIR, if you add this env verb in exeinfo_profile
# should ensure the relevant variables were set
exeinfo_load_file

if [[ -z "$EXENAME" ]] && [[ ! $TEST_WINETRICKS_FLAG -eq 1 ]] && [[ ! $EXEINFO_GEN_FLAG -eq 1 ]];
then
    echo "EXENAME not found in config file. auto set --test-winetricks , redirect to launch winetricks"
    TEST_WINETRICKS_FLAG=1
    #EXENAME="$APPDIR/usr/bin/winetricks"
    EXENAME="$WINETRICKS_BIN"
fi

##############################################


##############################################
## mount unionfs
echo "[unionfs:0%] mount unionfs"

# before setup unionfs temp directory, check if exe is already running
if [[ -n "$EXENAME" && -n "$(pgrep -fi "$EXENAME")" ]];
then 
    echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: seems $EXENAME has been launched and is still running, plsease kill the process if the application encountered error" >&2
    exit 1
fi

mpPlugin_fusetool_mount

MYAPPDEBUG_COLOR=1 debug_print_env "PID_MYAPP" "PID_HOME"
echo "[unionfs:100%] mount unionfs"
##############################################


##############################################
## trap exit setting

# atexit function takes too much time, use a flag to indicate the running status of atexit()
# to prevent triggering atexit() again during running atexit()
ATEXIT_FLAG=0

# After successfully mount fuse file system,
# and before launch windows software,
# start to trap EXIT as soon as possible.
# Include unmount command in atexit().
trap atexit EXIT
#trap preexit SIGHUP SIGINT SIGQUIT SIGKILL SIGTERM
trap preexit SIGHUP SIGINT SIGQUIT SIGTERM
##############################################


myapp_launch "$next_parameters"

if [[ ! $EXEINFO_GEN_FLAG -eq 1 ]];
then
    monitor_exe_running
fi

if [[ ! $EXEINFO_GEN_FLAG -eq 1 ]];
then
    savedata_show_location
fi

