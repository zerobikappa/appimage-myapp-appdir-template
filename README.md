# appimage-myapp-appdir-template

[English](https://github.com/zerobikappa/appimage-myapp-appdir-template/blob/main/README.md) - [简体中文](https://github.com/zerobikappa/appimage-myapp-appdir-template/blob/main/README.zh.md)

(some content may be outdate due to project holder was too lazy to update README (´･ω･`) )

My bash script tool to install or test windows .exe before bundle it into .appimage package.

---

## Build

#### 1. clone .git repo

```bash
git clone https://github.com/zerobikappa/appimage-myapp-appdir-template
```

#### 2. remove unnecessary files

remove files which are unnecessary to bundle into .appimage package.

```bash
appimage-myapp-appdir-template/.remove-appdir-git.sh
```

#### 3. update winetricks script(optional)

(optional) [winetricks](https://github.com/Winetricks/winetricks) script bundled in this repo. If not work in your system, please get the lastest script and replace the script.

```bash
wget -c "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -O appimage-myapp-appdir-template/usr/bin/winetricks
chmod u+x appimage-myapp-appdir-template/usr/bin/winetricks
```

#### 4. update unionfs(optional)

(optional) [unionfs-fuse](https://github.com/rpodgorny/unionfs-fuse) binary (from unionfs-fuse_1.0-1ubuntu2_amd64.deb)(for Ubuntu 18.04 LTS) bundled in this repo. Supposes to apply to the most of Linux distributions. If not work in your system, please download `unionfs-fuse` from repository of your Linux distribution and replace the binary.

```bash
# for Ubuntu
sudo apt-get install -y unionfs-fuse
cp -fv /usr/bin/unionfs appimage-myapp-appdir-template/usr/bin
```

#### 5. get AppimageTool

source: [AppImageKit](https://github.com/AppImage/AppImageKit)

```bash
wget -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O  appimagetool.AppImage
chmod u+x appimagetool.AppImage
```

#### 6. build myapp-template.AppImage

```bash
ARCH=x86_64 ./appimagetool.AppImage -n appimage-myapp-appdir-template
rm -rf appimage-myapp-appdir-template
```

now you get the `myapp-template-x86_64.AppImage` binary.

```bash
ls
###>>>
myapp-template-x86_64.AppImage
```

---

## Usage

#### 1. install wine

```bash
# for ubuntu
sudo apt-get wine
```

#### 2. create a appimage.cache directory(optional)

(optional) if not manually create a `appimage.cache` directory, the .cache directory will be created in /tmp/, all data will be deleted after restart computer. by the way, you may find that you can use `--appimage-portable-home`and`--appimage-portable-config` to create a `appimage.home` directory and a `appimage.config` directory. However, in this project, both directories will be ignored.
`$HOME` directory will be redirected to `appimage.cache/home/public_user` directory and `$XDG_CONFIG_HOME` will be redirected to `appimage.cache/home/public_user/.config` directory. In order to keep the same structure between `AppDir` and `appimage.cache` directory.

```bash
./myapp-template-x86_64.AppImage --portable-cache
```

then you can see `myapp-template-x86_64.AppImage.cache` directory was created.

```bash
ls
###>>>
myapp-template-x86_64.AppImage
myapp-template-x86_64.AppImage.cache/
```

#### 3. test to open wine with winetricks

```bash
./myapp-template-x86_64.AppImage -t
# or
./myapp-template-x86_64.AppImage --test-winetricks
```

this action will also create a wine prefix if no wineprefix was found in appimage.cache.
default using `WINEARCH=win64`, which will create a `appimage.cache/usr/share/win64` prefix directory. you can also create a win32 prefix with`WINEARCH=win32` in your command:

```bash
## to create win32 prefix
WINEARCH=win32 ./myapp-template-x86_64.AppImage -t
# or
WINEARCH=win32 ./myapp-template-x86_64.AppImage --test-winetricks
```

`win32` and `win64` prefix are separated and will not conflict with each other. you can test your EXE in different wine prefix.

#### 4. install your exe application

in previous step, if `winetricks` GUI is opened with no error, you can choose menu to open `explorer` and launch `.exe` file to install game.
in my script, I setup a `D drive`(d:\\) for installing software. please do not install software in any other drives. It is OK to install software in `C drive`(c:\\) but NOT RECOMMAND. because it would be deleted if you remove the wine prefix (`myapp-template-x86_64.AppImage.cache/usr/share/win64` and `myapp-template-x86_64.AppImage.cache/usr/share/win32`).
actually, after you install the software in `D drive`, you will find that the `D drive` is setup to be outside of`$WINEPREFIX`:

```bash
## directory list
myapp-template-x86_64.AppImage.cache/usr/share/drive_d
myapp-template-x86_64.AppImage.cache/usr/share/win32
myapp-template-x86_64.AppImage.cache/usr/share/win64
```

if you want to clear the wine prefix but do not want to remove the files in `D drive`, just remove the wine prefix then run :

```bash
myapp-template-x86_64.AppImage --test-winetricks
```

to rebuild the `$WINEPREFIX`.

other drives' entries will be removed everytime after the process is ended.

#### 5. generate exeinfo_profile

run:

```bash
myapp-template-x86_64.AppImage --exeinfo-gen
```

you can set below two options in this dialog:

1) choose the .exe file to be launch;
2) choose the location where the software/game will save config files in it. (this option may only use for standalone games, such as RPG games or novel games. after set this option, you can save a full-achieved savedata in `myapp-template-x86_64.AppImage/usr/share/drive_d/savedata/` then use `--savedata` arg option to load the full-achieved savedata. you can set this option later if you do not know where is the target location.)

then it will generate a config file:
`myapp-template-x86_64.AppImage.cache/usr/share/exeinfo_profile`

no need to modify AppRun script to setup the .exe path.

```bash
# TODO: kdialog bug, --ok-label and --cancel-label not effect, cannot change the text on button. now using "ok" button to replace "go", and using "cancel" button for "save & close".
# TODO: need to add zenity support.
```

#### 6. run and test software

after generate the exeinfo_profile, just run:

```bash
./myapp-template-x86_64.AppImage &
```

then it will read the information from exeinfo_profile and launch the software.
please do not use Ctrl+C to exit software because it takes some seconds to stop `unionfs` and remove temp files.
if the software encounter error and exit, you may need to use `kill` or `killall` command to kill the process.

furthermore, you can run AppRun script directly from AppDir, for example:

(please exit the .exe first, if you already launch software/game at the previous step.)
run:

```bash
./myapp-template-x86_64.AppImage --appimage-extract	# extract a copy of template from .appimage package
```

now you get the files extracted in directory   `squashfs-root/`
then:

```bash
mv squashfs-root myapp-template
mv myapp-template-x86_64.AppImage.cache myapp-template.cache	# match the name with myapp-template/ directory.
mv myapp-template.cache/* myapp-template/
```

after move all files into `myapp-template/`, you get an empty `myapp-template.cache/` directory.

try to run:

```bash
myapp-template/AppRun &
```

now you can check the `myapp-template.cache/` directory again, to confirm what files was touched/modified by the .exe application.

#### 7. bundle the application

before bundle your application, you may want to remove some unnecessary file.

```bash
# please stop the application/game first
rm -rf myapp-template/home	#will be create everytime, no need to bundle into appimage
# please also check other directories
```

you may also need to modify the *.desktop file and *.png file:

```bash
mv myapp-template/myapp-template.desktop myapp-template/other-name.desktop
mv myapp-template/myapp-template.png myapp-template/other-name.png
vim myapp-template/other-name.desktop	# then modify the content of *.desktop file
```

for more information, please refer below project to learn about how to bundle your *.appimage:

[AppImageKit](https://github.com/AppImage/AppImageKit)  
[Wine_Appimage](https://github.com/Hackerl/Wine_Appimage)  
[Create metadata](https://www.freedesktop.org/software/appstream/metainfocreator/#/guiapp)  

now you can run:

```bash
ARCH=x86_64 ./appimagetool.AppImage myapp-template/
```

to bundle your .appimage file.


