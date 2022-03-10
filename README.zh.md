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
3) 选择这个游戏的语言；（设定这个参数的原因有两个。其一是不同语言的windows系统采用的字符集不同，有些游戏需要用特定语言的字符集打开。其二是有些游戏不同语言的 .exe 文件不一样，例如点击 A.exe 文件是打开英文版游戏，点击另一个 B.exe 文件会打开中文版游戏。至于为什么会有这样的情况，懂的都懂。如果你打包的游戏有其中一种情况，那你就需要设定这项参数。）

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
mv squashfs-root myproject
mv myapp-template-x86_64.AppImage.cache myproject.cache	# 这是为了让缓存目录的名字对应上
mv myproject.cache/* myproject/
```

将所有的文件从缓存目录`myproject.cache/`转移到项目目录`myproject/`后，你得到了一个空的缓存目录`myproject.cache/`

试一下运行：

```bash
myproject/AppRun &
```

然后再查看一下缓存目录`myproject.cache`内部，你可以清晰看到软件运行过程中有哪些文件是被修改过的。

#### 7. 打包游戏为 appimage

打包成 appimage 之前，你可能会想到把一些不必要的文件删除掉。

```bash
# 请先退出游戏，然后才运行以下命令
# 伪家目录的缓存每次都会生成，一般情况下没必要打包进去。
rm -rf myproject.cache/home
# 另外也检查一下其他的目录，把不需要的文件删了
```

检查过没问题了，就将缓存目录里剩余的，你认为有必要的文件，转移到项目目录里。也就是将两者合并在一起：

```bash
mv myproject.cache/* myproject/
```

然后你可能需要修改一下 *.desktop 文件和 *.png 文件：

```bash
mv myproject/myapp-template.desktop myproject/游戏的名字.desktop
mv myproject/myapp-template.png myproject/游戏的名字.png
# 修改 *.desktop 文件的内容
vim myproject/游戏的名字.desktop
```

更多有关信息，你可以查看以下项目，学习一下如何打包你的appimage包：

[AppImageKit](https://github.com/AppImage/AppImageKit)
[Wine_Appimage](https://github.com/Hackerl/Wine_Appimage)
[Create metadata](https://www.freedesktop.org/software/appstream/metainfocreator/#/guiapp)

准备好了吗，现在用刚刚下载的appimagetool，来打包你的项目目录：

```bash
ARCH=x86_64 ./appimagetool.AppImage myproject/
```

这样你就得到你的appimage包了。

## FAQ - 常见问题

<details>

<summary>1.我真的有必要构建一个myapp-template.AppImage包吗？</summary>

——不好意思，真的***完全没必要***。

一开始把干净的模板打包成一个appimage包，只是把这个模板做一个离线备份。之后你只要把myapp-template.AppImage放在你的`$PATH`里，然后运行：

```bash
myapp-template.AppImage --appimage-extract
```

这样就可以在你的`$PWD`（当前位置）里释放一份干净的模板，相当于新建一个项目目录。
如果你不构建myapp-template.AppImage，那你完全可以这样做：

```bash
# 克隆仓库到本地
git clone https://github.com/zerobikappa/appimage-myapp-appdir-template
# 删除不必要的文件
./appimage-myapp-appdir-template/.remove-appdir-git.sh
# 更改你的项目目录的名字
mv appimage-myapp-appdir-template myproject
```

这样你同样可以得到一份干净的模板。

</details>

<details>

<summary>2.我可以使用proton代替wine吗？</summary>

——可以，你在运行的时候加上`--proton`选项就可以了。不过有以下几点限制：

+ 只能是通过steam下载安装的proton。这个脚本现在暂时只会从`~/.steam/steam/steamapps/common/`和`~/.local/share/Steam/steamapps/common/`这两个路径搜索proton。如果你用的是你自己或第三方编译的proton，那这个脚本暂时不会支持。
+ 不支持指定proton版本。这个脚本使用proton时，会自动搜索本地已安装的版本里最新的稳定版proton（目录名带有数字的），如果找不到稳定版的话，则会找一下有没有安装实验版proton（目录名带有「Experimental」的）。随着wine版本的更新，proton的总体趋势总是会朝着功能性和兼容性越来越完善的方向发展的。如果你要打包的软件目前只有指定的旧版本proton才能运行的话，我更推荐你尝试找出原因，然后上报给proton项目组，让proton发展得越来越好。
+ 暂时不支持32位的prefix。steam本身是不支持32位的linux系统的。不过连steam proton也只会建立64位的wineprefix，这点我就觉得很奇怪——明明proton的dist目录里是有32位wine的可执行文件的。看了一下网上的评论是要进行一些魔改才能建立32位的proton prefix。但是例如替换proton脚本里的变量名，又或者把wine64可执行文件的文件名改掉——我不是太想用这些方法——就算万不得已，也尽量还是不想更改用户本地的原有文件。况且我想玩的游戏里还暂时没有只能在32位prefix里才能运行的游戏。所以这个功能暂时放一放。

</details>

<details>

<summary>3.游戏遇到错误卡住了，按Ctrl+C也无法退出，怎么办？</summary>

——按以下顺序找出进程，手动kill掉。
打包调试时，推荐使用命令行运行，而不是双击运行。
当你用命令行运行时，你应该会看到终端输出了类似以下的信息：

```bash
# 终端的一些输出
APPDIR=/current/appdir/path/foo
WINEPREFIX=/tmp/foo.unionfs/usr/share/myapp/myapp_prefix/wine.win64/pfx
PID_MYAPPSTORGE=1234567
PID_HOMESTORGE=1234568
(...)
```

那么你可以另外开一个终端，复制这些关键变量来中止进程。以上面的输出内容为例子，按以下顺序中止进程：

```bash
# 强制中止wine进程
export WINEPREFIX=/tmp/foo.unionfs/usr/share/myapp/myapp_prefix/wine.win64/pfx
wineserver -k
# 解除unionfs的挂载
export PID_MYAPPSTORGE=1234567
kill -9 $PID_MYAPPSTORGE
export PID_HOMESTORGE=1234568
kill -9 $PID_HOMESTORGE
```

接下来你就可以回到你原本的终端，按 Ctrl+C 中止脚本了。中止脚本后再删除掉 unionfs 挂载的临时目录（路径你可以在上方变量`$WINEPREFIX`里找到）：

```bash
rm -rf /tmp/foo.unionfs
```

程序崩溃这种情况不一定少，毕竟现阶段还有大把的游戏无法在wine或proton上运行。愿你想玩的游戏都能正常运行。

</details>

<details>

<summary>4.我发现游戏安装时会在prefix里释放注册表，我只能连同整个prefix也打包进去吗？</summary>

——只导出注册表的更改部分，打包进去。
有些软件的安装很简单，甚至不需要你安装，直接复制到D盘就可以了。但有些软件安装后会在C盘里释放一些谜之注册表，如果你删除掉prefix，然后重新建立prefix，你会发现软件无法运行。对于这样的情况，参考以下方法。

假设你当前的位置有以下目录：

```bash
# 文件列表
myproject/
myproject.cache/
```

打开 winetricks，它会同时新建一个prefix：

```bash
myproject/AppRun --test-winetricks
```

关掉winetricks，然后你会看到新的prefix已经建立了而且包含有干净的注册表存档：

```bash
# 文件列表
myproject/
myproject.cache/
myproject.cache/usr/share/myapp/myapp_prefix/wine.win64/pfx/system.reg
myproject.cache/usr/share/myapp/myapp_prefix/wine.win64/pfx/user.reg
myproject.cache/usr/share/myapp/myapp_prefix/wine.win64/pfx/userdef.reg
```

备份这些注册表存档：

```bash
cp myproject.cache/usr/share/myapp/myapp_prefix/wine.win64/pfx/{system.reg,user.reg,userdef.reg} .
mv system.reg system.reg1
mv user.reg user.reg1
mv userdef.reg userdef.reg1
```

再次用`--test-winetricks`选项打开winetricks，安装软件。然后关掉winetricks，用同样的方法备份出system.reg2、user.reg2、userdef.reg2。

```bash
# 文件列表
myproject/
myproject.cache/
system.reg1
system.reg2
user.reg1
user.reg2
userdef.reg1
userdef.reg2
```

你可以用diff、vimdiff等工具，对照出软件安装前后新增了那些注册表。然后……再次打开winetricks，进入注册表工具导出那些注册表。请务必使用winetricks里的注册表工具导出注册表，而不是单纯地使用文本编辑器复制粘贴。否则导出的注册表文字编码不对的话是没办法正常生效的。另外，也不是所有的新增注册表都是由安装软件产生的。一些字体相关的注册表，或者一些音频相关的注册表（例如MMDevice）就是wine本身更新产生的注册表，这些与游戏软件不相关的注册表是每次启动wine的时候都会自动更新的，不需要打包进去。

假如你已经导出了一个注册表补丁「patch.reg」文件（名字不重要，但后缀必须为「.reg」），将该文件放入我设定的补丁目录里`myproject/usr/share/myapp/myapp_patch_reg/`。这样每次启动游戏时启动脚本就会自动将注册表补丁导入到prefix里。如此一来就不用把prefix也打包进appimage里了。

</details>

（更多FAQ有待补充）


