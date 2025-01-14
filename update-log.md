# Change Log

## 2025-01-14 17:45 更新日志

[//]: # (1.4.0)

```markdown
1. 支持窗口调整大小，适配屏幕更小的设备
2. 修正了部分视图下的拼写错误
3. 对 Helper 进行了进一步的完善

PS: Adobe Downloader 已进入了稳定阶段，大部分情况下均可正常下载
====================

1. Added support for window resizing to better accommodate smaller screens.
2. Fixed spelling errors in certain views.
3. Further improvements made to the Helper functionality.

PS: Adobe Downloader has reached a stable phase and is generally capable of performing downloads under most
conditions.
```

## 2024-11-19 00:55 更新日志

[//]: # (1.3.1)

```markdown
1. 模拟官方 Adobe Creative Cloud 的包依赖下载逻辑
2. 由于上述更新，修复了某些包下载数量仍然不足的问题
3. 修复了当已存在 HDBox 和 IPCBox 的时候，下载 X1a0He CC 组件后，并不会替换掉原来的组件的问题
4. 修复了 Acrobat 产品在暂停和取消时仍处于下载状态的问题
5. 底部增加产品数量显示，居中显示警示标语
6. 增加部分语言选择
7. 优化了版本选择页面的排序展示
8. 优化了产品处理和解析速度，弃用 xml 处理和解析，采用 json 的形式处理

PS: M1 Max上已测试大部份产品正常下载并安装，Intel未测试，有问题请提issues
====================

1. Simulate the package dependency download logic of the official Adobe Creative Cloud
2. Due to the above updates, the problem of insufficient download quantity of some packages has been fixed
3. Fixed when HDBox and IPCBox already exist, the problem that the original components will not be replaced after
   downloading X1a0He CC components
4. Fixed the problem that Acrobat products are still in downloading status when paused and canceled
5. Add product quantity display at the bottom and display warning slogan in the center
6. Add some language selections
7. Optimize the sorting display of the version selection page
8. Optimize product processing and parsing speed, abandon xml processing and parsing, and use json processing

PS: Most products have been tested on M1 Max and downloaded and installed normally, but Intel has not been tested. If
you have any questions, please raise issues
```

## 2024-11-16 14:30 更新日志

[//]: # (1.3.0)

```markdown
1. 新增可选API版本 (v4, v5, v6)【更老的API意味着更长的等待时间】
2. 引入 Privilege Helper 来处理所有需要权限的操作
3. 修改从 Github 下载 Setup 组件功能，改为从官方下载简化版CC，称为 X1a0He CC
4. 调整 CC 组件备份与处理状态检测，分离二者的检测机制
5. 移除了安装日志显示
6. 调整 Setup 组件版本号的获取方式
7. 修复了当任务下载完成后，AppCardView 仍显示下载中的问题
8. 修复了 Intel 架构下，安装时因架构文件错误出现错误代码 107 的问题
9. 修复了当初次或某种情况下安装会导致进度卡住但事实上已经安装完成的问题
10. 修复了文件包下载不完全或不完整的问题
11. 新增重置程序配置，建议该版本先运行一次重置程序

PS: CC 组件的来源均为 Adobe Creative Cloud 官方提取，可随时下载到最新版，但处理可能会失败
====================

1. Added optional API versions (v4, v5, v6) [Older API means longer waiting time]
2. Introduced Privilege Helper to handle all operations that require permissions
3. Modified the function of downloading the Setup component from Github, and changed it to downloading the simplified
   version of CC from the official website, called X1a0He CC
4. Adjusted the detection of CC component backup and processing status, and separated the detection mechanism of the two
5. Removed the installation log display
6. Adjusted the method of obtaining the version number of the Setup component
7. Fixed the problem that AppCardView still shows downloading after the task download is completed
8. Fixed the problem that error code 107 appears during installation due to architecture file errors under Intel
   architecture
9. Fixed the problem that the progress is stuck when installing for the first time or under certain circumstances, but
   in fact the installation has been completed
10. Fixed the problem of incomplete or incomplete file package download
11. Added reset program configuration, it is recommended to run the reset program once in this version

PS: CC components are all from Adobe Creative Cloud official extraction, you can download the latest version at any
time, but the processing may fail
```

## 2024-11-11 21:00 更新日志

[//]: # (1.2.0)

```markdown
1. 调整程序启动时 sheet 的弹出顺序
2. 设置中添加了 Setup 组件的检测和版本号检测，支持在设置中重新备份与处理
3. 调整 Setup 组件的检测，不再需要完整安装 Adobe Creative Cloud
4. 增加了安装前 Setup 组件是否已处理的判断，未处理 Setup 组件，无法使用安装功能
5. 调整 Setup 组件检测弹窗界面
6. 增加从 GitHub 中下载 Setup 组件，无法访问 GitHub 的用户可能会出现无法下载的问题

PS: Setup 组件的来源均为 Adobe Creative Cloud 官方提取，可能存在更新不及时
====================

1. Adjust the order of sheet pop-up when the program starts
2. Added detection of Setup components and version number detection in settings, supporting re-backup and processing in
   settings
3. Adjusted detection of Setup components, no longer requiring full installation of Adobe Creative Cloud
4. Added judgment of whether Setup components have been processed before installation. If Setup components are not
   processed, the installation function cannot be used
5. Adjusted the pop-up interface of Setup component detection
6. Added downloading of Setup components from GitHub. Users who cannot access GitHub may encounter problems with
   download failure

PS: The sources of Setup components are all extracted from Adobe Creative Cloud, so they may not be updated in time.
```

<img width="562" alt="image" src="https://github.com/user-attachments/assets/47159318-a7b0-46db-b6af-4e8926a6733c">

<img width="630" alt="image" src="https://github.com/user-attachments/assets/9dbec07d-d280-4107-b6cf-5ad7cab8158e">

<img width="880" alt="image" src="https://github.com/user-attachments/assets/5d1fcd81-7ac6-41db-a8d3-5ff2c116056e">

## 2024-11-09 23:00 更新日志

[//]: # (1.1.0)

```markdown
1. 修复了初次启动程序时，默认下载目录为 "Downloads" 导致提示 你不能存储文件“ILST”，因为该宗卷是只读宗卷 的问题
2. 新的实现取代了 windowResizability 以适应 macOS 12.0+（可能）
3. 新增下载记录持久化功能(M1 Max macOS 15上测试正常，未测试其他机型)

PS: 此版本改动略大，如有bugs，请及时提出
====================

1. Fixed the issue that when launching the program for the first time, the default directory is "Downloads", which
   causes a download error message
2. New implementation replaces windowResizability to adapt to macOS 12.0+ (Maybe)
3. Added task record persistence(Tested normally on M1 Max macOS 15, other models not tested)

PS: This version has been slightly changed. If there are any bugs, please report them in time.
```

## 2024-11-07 21:10 更新日志

[//]: # (1.0.1)

```markdown
1. 修复了当系统版本低于 macOS 14.6 时无法打开程序的问题，现已支持 macOS 13.0 以上
2. 增加 Sparkle 用于检测更新
3. 当默认目录为 未选择 时，将 下载 文件夹作为默认目录
4. 当通过 Adobe Downloader 安装遇到权限问题时，提供终端命令让用户自行安装
5. 调整了文件已存在的 UI 显示
6. 修复了在任务下载中，已下载包与总包数量不更新的问题

====================

1. Support macOS 13.0 and above
2. Added Sparkle for checking update
3. When the default directory is not selected, the Downloads folder will be used as the default directory
4. When installing via Adobe Downloader and encountering permission issues, provide terminal commands to allow users to
   install by themselves
5. Adjusted the UI display of existing files
6. Fixed the issue where the number of downloaded packages and total packages was not updated during task download
```

<img width="1064" alt="image" src="https://github.com/user-attachments/assets/84f3f1de-a429-45ca-9b29-948234b4fcdb">

<img width="530" alt="image" src="https://github.com/user-attachments/assets/7a22ea27-449b-42cf-8142-fce1215c5d12">

<img width="427" alt="image" src="https://github.com/user-attachments/assets/403b20db-4014-4645-8833-3616390b17fb">

<img width="880" alt="image" src="https://github.com/user-attachments/assets/b6b04cd9-bfdf-4cdd-b14c-6dcd48b376a7">

## 2024-11-06 15:50 更新日志

```markdown
1. 增加程序首次启动时的默认配置设定与提示
2. 增加可选架构下载，请在设置中进行选择
3. 修复了版本已存在检测错误的问题 (仅检测文件是否存在，并不会检测是否完整)
4. 移除主界面的语言选择和目录选择，移动到了设置中
5. 版本选择页面增加架构提示
6. 移除了安装程序的机制，现在不会再生成安装程序
7. 增加了Adobe Creative Cloud安装检测，未安装前无法使用

====================

1. Added default configuration settings and prompts when the program is started for the first time
2. Added optional architecture downloads, please select in settings
3. Fixed the problem of version detection error (only checks whether the file exists, not whether it is complete)
4. Removed the language selection and directory selection on the main interface and moved them to settings
5. Added architecture prompts on the version selection page
6. Removed the installer mechanism, and now no installer will be generated
7. Added Adobe Creative Cloud installation detection, which cannot be used before installation
```

## 2024-11-05 21:15 更新日志

```markdown
1. 增加Intel机型的Setup处理，感谢@aronychen

====================

1. Added Setup processing for Intel chips, thanks @aronychen
```

----

## 2024-11-05 15:05 更新日志

```markdown
1. 初始化仓库

====================

1. Init repo
```