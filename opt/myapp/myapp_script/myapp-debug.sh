#!/bin/bash

##############################################
## Bash source setting
if [[ $MYAPP_PLUGIN_DEBUG_SOURCED -eq 1 ]];
then
    return
else
    MYAPP_PLUGIN_DEBUG_SOURCED=1
    export MYAPP_PLUGIN_DEBUG_SOURCED
fi
##############################################


#############################################
## print environment variables.
# optional env:
#     $MYAPPDEBUG_COLOR: if set to 1, will show the message with color.
#
# receive arguments:
#     environment variable name without any $ and {} symbols.
#     If input more than 1 arguments, split them with space.
#     for example, if you want to check value of $a, $b and $c,
#     just run:
#         debug_print_env a b c
#
# output:
#     echo variable name and value with below format:
#         name=value
function debug_print_env(){
    if [[ $MYAPPDEBUG_COLOR -eq 1 ]];
    then
        for i in "$@";
        do
            #eval echo -e "\ \ \ \ '\033[43m'$i'\033[0m'=\$$i"
            eval echo -e "\ \ \ \ '\033[1;93m'$i'\033[0m'=\$$i"
        done
    else
        for i in "$@";
        do
            eval echo "\ \ \ \ $i=\$$i"
        done
    fi
}
#############################################


#############################################
## set extra file descriptor for std_out/error.
# receive arguments:
#   "on":
#       show extra debug info
#
#   "off" or other string:
#       redirect all debug message to /dev/null,
#       not show extra debug info
function debug_fd_switch(){
    if [[ "$1" == "on" ]];
    then
        exec 3>&1
        exec 4>&2
    else
        exec 3>/dev/null
        exec 4>/dev/null
    fi
}
#############################################



#############################################
## set debug message level.
# Optional env:
#     $MYAPPDEBUG:
#       1:
#         if set to int 1, only show extra debug
#         info.
#
#       2:
#         if set to int 2,
#         show extra debug info and change bash to
#         debug mode. It may be noisy.
#
#       empty or other value(default):
#         no debug info,
#         only show message from &1 and &2.
function debug_set(){
    if [[ "$MYAPPDEBUG" -eq 2 ]];
    then
        # use bash debug + buildin debug info
        set -x
        MYAPPDEBUG=1
        debug_fd_switch "on"
    elif [[ "$MYAPPDEBUG" -eq 1 ]];
    then
        # only use buildin debug info
        set +x
        debug_fd_switch "on"
    else
        # invalid value, reset to empty
        set +x
        unset MYAPPDEBUG
        debug_fd_switch "off"
    fi
}
#############################################


#############################################
## ensure required variables were set before
## run a function.
# receive argument:
#   variable names witout any $ or {} symbols.
#   If input multiple variables,
#   split them by space.
#
# result:
#   if all variables have value, return normally.
#   if any of variables were not set, exit immediately.
#
# example:
#   If you want to ensure $APPDIR and $HOME have value
#   before you run a function, just run:
#     debug_test_required_var APPDIR HOME
function debug_test_required_var(){
    local EXIT_VAR_NOT_SET
    EXIT_VAR_NOT_SET=false
    for i in "$@";
    do
        if (eval test -z \$$i);
        then
            echo "error $i not set."
            EXIT_VAR_NOT_SET=true
        fi
    done
    if $EXIT_VAR_NOT_SET;
    then
        exit 1
    fi
}
#############################################
