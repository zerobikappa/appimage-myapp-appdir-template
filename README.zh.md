# appimage-myapp-appdir-template

[English](https://github.com/zerobikappa/appimage-myapp-appdir-template/blob/main/README.md) - [简体中文](https://github.com/zerobikappa/appimage-myapp-appdir-template/blob/main/README.zh.md)

这是我自己用的appimage包的启动脚本，专门是用来启动wine游戏的。

---

## 构建

#### 1. 将git仓库克隆到本地

```bash
git clone https://github.com/zerobikappa/appimage-myapp-appdir-template
```

#### 2. 移除没用的文件

有些文件并不需要打包进appimage里，我单独写了一个脚本清除这些文件，直接运行即可。

```bash
./appimage-myapp-appdir-template/.remove-appdir-git.sh
```

#### 3. 更新 winetricks 脚本（可选）

我下载了 [winetricks](https://github.com/Winetricks/winetricks) 脚本放在了这个仓库里。如果它太旧用不了的话，建议去下载最新的版本。

```bash
wget -c "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -O appimage-myapp-appdir-template/usr/bin/winetricks
chmod u+x appimage-myapp-appdir-template/usr/bin/winetricks
```

#### 4. 更新 unionfs-fuse（可选）

我在这个仓库里放了 [unionfs-fuse](https://github.com/rpodgorny/unionfs-fuse) 的可执行文件（该文件来自 Ubuntu 18.04 LTS 发行版仓库里的 unionfs-fuse_1.0-1ubuntu2_amd64.deb 软件包），应该足够兼容大部分的发行版，如果用不了的话，你可以从你的发行版仓库里下载并安装`unionfs-fuse`。在这个软件包里实际上只有其中的`unionfs`可执行文件是必需的，其余的只是一些调试组件。

```bash
# 以 Ubuntu 为例
sudo apt-get install -y unionfs-fuse
cp -fv /usr/bin/unionfs appimage-myapp-appdir-template/usr/bin
```

#### 5. 下载 AppimageTool

项目地址: [AppImageKit](https://github.com/AppImage/AppImageKit)

```bash
wget -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O  appimagetool.AppImage
chmod u+x appimagetool.AppImage
```

#### 6. 构建 myapp-template.AppImage

```bash
ARCH=x86_64 ./appimagetool.AppImage -n appimage-myapp-appdir-template
rm -rf appimage-myapp-appdir-template
```

现在你得到了一个名为 `myapp-template-x86_64.AppImage` 的可执行文件。

```bash
ls
###>>>
myapp-template-x86_64.AppImage
```

---

## 使用方法

接下来我会说一下如何将一个windows游戏打包进appimage里

#### 1. 安装 wine

理所当然的，首先你要确保你已经安装了`wine`，没有`wine`怎么在linux下运行windows软件？哦，如果你有`proton`，那也可以。不过在最初安装游戏的时候，我还是更喜欢用`wine`。因为直接用`wine`生成的 prefix 是最干净的，不带任何额外配置。至于如何使用`proton`配合这个脚本，可以看下面的FAQ。

```bash
# 以 ubuntu 为例
sudo apt-get wine
```

#### 2. 新建一个 *.cache 目录（可选）

如果你不手动新建一个`appimage名字.cache`的目录，那么这个目录会在`/tmp/`目录里生成（`/tmp/appimage名字.cache`），存储在里面的文件会在电脑重启后消失。
另外，如果你对 appipmage 有所了解，那么你应该也知道，在appimage包后面带上`--appimage-portable-home`和`--appimage-portable-config`这两个选项，可以分别建立`appimage名字.home`和`appimage名字.config`这两个目录。不过在我的脚本里，这两个目录是会被忽略的。我并不喜欢分开两个目录来存资料，所以我改为了用一个`appimage名字.cache`目录来包含以上两个目录。
`$HOME`家目录会被重定向到`appimage名字.cache/home/public_user`目录。 `$XDG_CONFIG_HOME`配置目录会被重定向到`appimage.cache/home/public_user/.config`目录。

```bash
./myapp-template-x86_64.AppImage --portable-cache
```

当你运行以上命令后，你会看到在appimage包的同级目录里新建了一个`myapp-template-x86_64.AppImage.cache`目录。

```bash
ls
###>>>
myapp-template-x86_64.AppImage
myapp-template-x86_64.AppImage.cache/
```

#### 3. 打开测试 winetricks

运行以下命令

```bash
./myapp-template-x86_64.AppImage -t
# or
./myapp-template-x86_64.AppImage --test-winetricks
```

这个命令会通过启动脚本启动winetricks。同时如果在`appimage名字.cache`目录里没有找到 prefix 容器目录，那么也会新建一个新的wineprefix容器。默认使用64位wine（`WINEARCH=win64`）。如果你要使用32位wine，那就在命令行里加上环境变量`WINEARCH=win32`，如下所示：

```bash
## 默认新建 win64 prefix
./myapp-template-x86_64.AppImage -t
# 或者运行
./myapp-template-x86_64.AppImage --test-winetricks

## 新建 win32 prefix
WINEARCH=win32 ./myapp-template-x86_64.AppImage -t
# 或者运行
WINEARCH=win32 ./myapp-template-x86_64.AppImage --test-winetricks
```

`win32`和`win64`容器是分开不同目录的，可以随意调戏随意删除。

#### 4. 安装游戏

在上一个步骤里，如果你成功打开了`winetricks`的图形界面，那么你可以「选择默认的wine容器」>「运行资源管理器」，然后安装游戏。
请留意，在我的模板里，我只建立了一个D盘用于安装软件，请**不要**把游戏安装在其他盘里，其他的盘符都是你电脑的本地盘符。另外如果你要把游戏安装在C盘里，那也**可以**，但**不推荐**。因为如果你把游戏安装在C盘里，当你删除prefix时，就连同游戏文件一并删除了。而且，安装在C盘里的游戏文件也无法跟其他prefix通用，不能随意调戏。
你可能想问为啥装在D盘就没事……因为我将D盘搬到prefix外面了：

```bash
## 安装完游戏后，你可能会看到以下目录
myapp-template-x86_64.AppImage.cache/usr/share/myapp/drive_d/
myapp-template-x86_64.AppImage.cache/usr/share/myapp/myapp_prefix/wine.win64/pfx/
myapp-template-x86_64.AppImage.cache/usr/share/myapp/myapp_prefix/wine.win32/pfx/
```

不同的prefix容器共用一个D盘，如果你想清除prefix容器，只需要将pfx目录删除，然后重新运行：

```bash
myapp-template-x86_64.AppImage --test-winetricks
```

就可以重新建立`$WINEPREFIX`了。
补充说明，每次运行结束后，脚本会自动清除容器里其他盘符的软链接（E盘~Z盘），只留下C盘和D盘。

#### 5. 生成 exeinfo_profile 信息文件

运行以下命令：

```bash
myapp-template-x86_64.AppImage --exeinfo-gen
```

在打开的对话框里，你可以设定以下参数：

1) 选择启动游戏的 .exe 文件；
2) 选择这个游戏的存档的存储位置；（这个参数专为单机游戏而设。如果你有这个游戏的**全通关**或**全CG收集**存档，那么可以放置一份存档到appimage包里的`usr/share/myapp/myapp_savedata/`目录，运行时带上`--savedata`选项，脚本会复制这份全通关存档到你设置的游戏存档目录，临时覆盖你原本的存档，让你一进入游戏里就是全通关的状态。这个功能，嗯，懂的都懂。如果你不确认这个游戏是在哪里保存存档的话，可以稍后才设置这个参数）
3) 选择这个游戏的语言；（设定这个参数的原因有两个。其一是不同语言的windows系统采用的字符集不同。其二是有些游戏不同语言的 .exe 文件不一样，例如点击 A.exe 文件是打开英文版游戏，点击另一个 B.exe 文件会打开中文版游戏。至于为什么会有这样的情况，懂的都懂。）

最终会生成以下配置文件
`myapp-template-x86_64.AppImage.cache/usr/share/myapp/myapp_exeinfo/exeinfo_profile`

基本不需要你去修改AppRun脚本。

#### 6. 运行、调试游戏

生成了 .exe 文件的路径配置信息后，运行以下命令：

```bash
./myapp-template-x86_64.AppImage &
```

这时启动脚本会读取 exeinfo_profile 文件里的配置信息，然后启动游戏。
请不要用 Ctrl+C 来强退游戏。因为游戏结束运行后，脚本还需要一点时间来解除`unionfs`的挂载，以及清除临时文件。
如果软件遭遇不正常退出，你可能需要使用`kill`和`killall`命令来停止`wine`和解除`unionfs`的挂载。

更进一步来说，你可以在`$APPDIR`目录里直接运行`AppRun`脚本。以现在的情况为例，
（如果你的游戏正在打开，请先退出游戏）
运行以下命令：

```bash
# 从appimage包里释放一份模板
./myapp-template-x86_64.AppImage --appimage-extract
```

现在你应该能看到生成了一个`squashfs-root/`目录。
然后运行：

```bash
mv squashfs-root myapp-template
mv myapp-template-x86_64.AppImage.cache myapp-template.cache	# 这是为了让缓存目录的名字对应上
mv myapp-template.cache/* myapp-template/
```

TODO: 写到这里，之后继续。

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


