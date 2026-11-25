#!/bin/bash

##############################################
## Bash source setting
if [[ $MYAPP_PLUGIN_IMAGESHOW_SOURCED -eq 1 ]];
then
    return
else
    MYAPP_PLUGIN_IMAGESHOW_SOURCED=1
    export MYAPP_PLUGIN_IMAGESHOW_SOURCED
fi


# only for code analysis with coc.vim
source ./myapp-debug.sh 2>/dev/null
##############################################


##############################################
## detect terminal type
# Export env:
#   $MYAPP_IMAGESHOW_TYPE
function imageshow_test_terminal() {

    declare -g MYAPP_IMAGESHOW_TYPE

    # if support sixel
    IFS=";?c" read -a REPLY -s -t 1 -d "c" -p $'\e[c' >&2
    for code in "${REPLY[@]}"; do
	if [[ $code == "4" ]]; then
        export MYAPP_IMAGESHOW_TYPE="sixel"
	    #break
        return
	fi
    done

    # if using terminology
    if [ -n "$TERMINOLOGY" ];
    then
        export MYAPP_IMAGESHOW_TYPE="terminology"
        return
    fi

    # if support kitty
    if (kitten icat > /dev/null 2>&1);
    then
        export MYAPP_IMAGESHOW_TYPE="kitty"
        return
    fi

    # if none of above was supported
    export MYAPP_IMAGESHOW_TYPE="none"

}
##############################################


#############################################
## show game cover image
# Required env:
#   $APPDIR
#   $MYAPP_NAME
#   $MYAPP_IMAGESHOW_TYPE
#
function imageshow_show_coverimage() {
    if [ -z "$APPDIR" ];
    then
        echo "(APPDIR not found, cannot find cover image)"
        return
    fi

    if [ -z "$MYAPP_NAME" ];
    then
        MYAPP_NAME="myapp"
    fi

    if [[ "$MYAPP_IMAGESHOW_TYPE" == "sixel" ]];
    then
        cat "${APPDIR}"/opt/"${MYAPP_NAME}"/myapp_other/*.sixel
    elif [[ "$MYAPP_IMAGESHOW_TYPE" == "terminology" ]] && (command -v tycat >/dev/null 2>&1);
    then
        tycat "${APPDIR}"/opt/"${MYAPP_NAME}"/myapp_other/*.png
    elif [[ "$MYAPP_IMAGESHOW_TYPE" == "kitty" ]] && (command -v kitten >/dev/null 2>&1);
    then
        kitten icat "${APPDIR}"/opt/"${MYAPP_NAME}"/myapp_other/*.png
    else
        echo "(terminal does not support showing image)"
    fi

}
#############################################
