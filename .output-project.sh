#!/bin/bash

#############################################
## prevent running by root/sudo for security concern
if [[ $(id -u) -eq 0 ]];
then
	echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: prevent running by root/sudo"
	echo "[$(basename "${BASH_SOURCE[0]}")] ERROR: you should not using root/sudo to run this application"
	exit
fi
#############################################


#############################################
## env settings
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
#############################################

if [ -z "$MYAPP_NAME" ];
then
    echo "project name \$MYAPP_NAME not set, plsease specify a project name and run this script."
    echo "for example:"
    echo "MYAPP_NAME=YourProjectName ./.output-project.sh"
    exit 1
fi

RETURN_NUMBER="y"

if [ -e "${HERE}/output/" ];
then
    read -p "${HERE}/output/ exists, remove it?[y/u/N]:" RETURN_NUMBER
    case $RETURN_NUMBER in
        y| Y| yes| YES)
            RETURN_NUMBER="y"
            rm -rfv "${HERE}/output/"
            ;;
        u| U| update)
            RETURN_NUMBER="u"
            echo "Will only update files in output directory."
            ;;
        *)
            RETURN_NUMBER="n"
            echo "No action was taken." >&2
            exit 1
            ;;
    esac
fi

if [[ $RETURN_NUMBER == "u" ]];
then
    for i in "${HERE}/output/opt"/*;
    do
        if [[ "$(basename "$i")" != "${MYAPP_NAME}" ]];
        then
            rm -rf "$i"
        fi
    done
fi


if [[ $RETURN_NUMBER != "n" ]];
then
    mkdir -p "${HERE}/output/"
    cat << EOF > "${HERE}/output/AppRun"
#!/bin/bash

#############################################
## env settings
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}
#############################################

MYAPP_NAME="$MYAPP_NAME" \\
LANG=\$LANG \\
APPIMAGE=\$APPIMAGE \\
APPDIR=\$APPDIR \\
OWD=\$OWD \\
ARGV0=\$ARGV0 \\
"\$HERE"/opt/"$MYAPP_NAME"/myapp/myapp_script/myapp "\$@"
EOF

    chmod 0755 "${HERE}/output/AppRun"
    cp -ruv "${HERE}"/*.png "${HERE}/output/"
    cp -ruv "${HERE}"/*.desktop "${HERE}/output/"
    cp -ruv "${HERE}"/usr "${HERE}/output/"
    mkdir -p "${HERE}/output/opt/${MYAPP_NAME}/myapp"
    mkdir -p "${HERE}/output/usr/bin"
    mkdir -p "${HERE}/output/usr/share/applications"
    mkdir -p "${HERE}/output/usr/share/metainfo"
    mkdir -p "${HERE}/output/usr/share/pixmaps"
    cp -ruv "${HERE}"/opt/myapp/* "${HERE}/output/opt/${MYAPP_NAME}/myapp/"
    ln -sfv /opt/"${MYAPP_NAME}"/myapp/myapp_script/myapp "${HERE}/output/usr/bin/${MYAPP_NAME}"
fi

