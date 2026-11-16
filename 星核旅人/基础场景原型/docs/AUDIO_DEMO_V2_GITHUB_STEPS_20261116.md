# 把当前工程逐步上传到已有GitHub仓库

本文件只提供操作步骤；Agent没有替你暂存、提交、拉取、变基或推送。

## 0. 先确认备份范围与素材许可

- 实际Git根目录是 **`D:\godot game`**，不是`星核旅人`或`基础场景原型`；当前分支`master`。
- 已有远端`origin`：`https://github.com/aqiqiq1/starcore-traveler`。不用重新建仓库，不要再执行`git init`，不在工程里嵌套新`.git`。
- 仓库根还放着其他项目、ZIP和素材库，本轮**不要用根目录`git add .`或`git add -A`**。
- 主角/Golem的原始许可仍待核。新增音效的许可记录不能替代全工程许可核查。若仓库公开，先核清这些原资产是否允许公开源码分发；无法确认时暂停公开推送，先做本地副本备份。Private也不改变许可，只是避免误公开，不能当绕过许可的方法。
- 本地保留的参考游戏视频/下载源包/截图/试听页在`previews`或`screenshots`，当前`.gitignore`已排除；**不要`git add -f`强行上传这些文件**。已采用音效及许可应在运行目录`assets`与`ASSET_CREDITS.md`内，不依赖被忽略的参考目录。
- GitHub仓库可见性本轮未核实（公开API访问403），请在GitHub网页Settings核对，不假定Public或Private。

## 1. 打开PowerShell并查看状态

```powershell
Set-Location 'D:\godot game'
git rev-parse --show-toplevel
git branch --show-current
git remote -v
git status --short
```

预期根是`D:/godot game`、分支`master`、origin是上面的地址。未提交的近期第三关/音频文件出现在这里是正常的，不要点“丢弃全部”。

## 2. 只暂存本工程

确认许可与暂存范围后执行：

```powershell
git add -- '星核旅人/基础场景原型' '星核旅人/.gitignore'
git diff --cached --stat
git -c core.quotepath=false diff --cached --name-only
```

- 这会包含本次音频和此前尚未提交的第三关代码/运行素材/文档/测试，**不会**包含旁边其他项目。
- 检查列表没有`.godot`、`.env`、密钥、`export_credentials.cfg`、参考视频、ZIP、素材库或其他项目。
- 这个工程里5份旧测试日志曾被测试覆盖，该证据缺口已在报告保留；若列表包含它们，应理解为当前输出，不当作旧测试原始记录。不要为消除警告而丢弃整个工程。
- `git add`只建立暂存，不会上传。若发现某条文件不该提交，用下面方式**只取消暂存**：

```powershell
git restore --staged -- '这里填刚才列表中的具体路径'
```

这不删除工作区文件。不要把它误换成`git restore .`或`git reset --hard`。

## 3. 做一次本地提交

```powershell
git commit -m 'Complete demo level flow and integrate audio trial'
git status --short
```

提交后再继续同步。若提示作者身份未配置，在**确认显示的是你希望公开的身份**后，仅为此仓库配置：

```powershell
git config user.name '你的GitHub显示名称'
git config user.email '你选择的邮箱或GitHub提供的noreply邮箱'
```

然后重试commit；不要把示例文字原样当个人身份，也不需要改全局配置。

## 4. 先同步远端，再推送

```powershell
git fetch origin
git rebase origin/master
```

这里先commit，正是为了解决你遇到的`cannot rebase: You have unstaged changes`。

- 如果还报未暂存修改，先`git status --short`看**具体文件**；不要反复点同步。可能是提交后Godot/测试又生成了修改，或仓库根还有其他已跟踪项目的修改。先停止测试、保存文件，再决定本地提交还是仅对指定路径stash，不能一口气stash整个父目录。
- 如果你取消暂存了某些已跟踪文件（例如日志），它们仍可能阻止rebase。保留这些文件、报告具体路径，再选择如何暂存备份；不要为了同步直接丢弃。
- 如果有冲突，先停下阅读`git status`。解决后只`git add -- '具体冲突文件'`，再`git rebase --continue`。若不知道如何选版本，使用`git rebase --abort`返回变基前状态，再询问；不要盲选“全部使用远端”、不要强推。

变基成功后：

```powershell
git push origin master
```

GitHub需要登录时用Git Credential Manager/浏览器正常登录；不要把密码或token写进项目文件、远端URL或发给Agent。**不需要`--force`。**

## 5. 网页确认这次确实上传了

打开`https://github.com/aqiqiq1/starcore-traveler`：

1. 看最新commit是否是刚才那条，分支是否`master`。
2. 看`星核旅人/基础场景原型/scenes/level_03.tscn`与新音频运行目录、许可/credits是否存在。
3. 确认没有误传其他项目、缓存或参考视频。BGM若只是试听候选且未采用，本来就不在运行目录，不应误称已上传配乐。
4. 新机器clone后用Godot 4.7.2导入`星核旅人/基础场景原型/project.godot`，等导入完成，再F6正式场景检查。**上传工程不等于已经导出可双击exe。**

## 常见情况

- **`LF will be replaced by CRLF`**：行尾提示，不是文件丢失；先看diff，不要为消警告整仓重写行尾。
- **文件过大/超过100MiB**：普通GitHub推送可能拒绝单个大文件。不要强推或在之后commit里简单删掉了事（大文件仍在待推送历史中）；先报告路径，确认排除或另行配置Git LFS。参考视频、整包ZIP本来就不应提交。
- **`non-fast-forward`**：说明远端有新提交。先fetch/rebase并处理冲突，别`push --force`覆盖远端。
- **试听页没出现在GitHub**：现有`.gitignore`有意忽略`previews`。正式采用的声音必须另有runtime副本与随工程保留的许可说明；试听页面仍可在本地双击打开。
