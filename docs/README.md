# TuckNotes 单页网站

一个可直接用于 GitHub Pages 的静态产品页。无需安装依赖、打包工具、API key 或服务器。

## 本地预览

解压后双击 `index.html` 即可。所有图片、样式和交互都随文件包提供，无外部字体、追踪脚本或 CDN 依赖。

## 上传到 GitHub Pages

推荐将本文件夹内的 `index.html`、`styles.css`、`script.js`、`assets/` 和 `.nojekyll` 一起放入网站仓库根目录，或 TuckNote 仓库的 `docs/` 文件夹。保留相同的相对目录结构。

1. 在 GitHub 仓库打开 **Settings → Pages**。
2. **Source** 选择 **Deploy from a branch**。
3. 选择保存网页的分支，再选 **/(root)** 或 **/docs**。
4. 点击 **Save**，等待 GitHub 显示访问地址。

已有网站时请先保留旧版，再替换同名页面。本次交付没有修改现有 TuckNote app 项目，也没有发布到线上。

GitHub 官方说明：https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

## 页面内容

- 桌面紧凑单屏布局，功能重点与 GitHub 获取入口均整合到首屏；手机上自然纵向排列。
- 小号页脚署名：Designed & built by YL。
- 标题 Think it. / Tuck it.，浅冰蓝说明、淡粉强调和完整小屏幕图标。
- 左侧三句说明轻微左右错落，进入页面时依次浮现。
- 电脑下方为会回应操作的手写提示，点击划线文字即可输入、收起或重新打开。Reset demo 位于电脑右上方。
- 蓝黑白粉配色、现有笑脸便签 App Icon。
- 按约 16:10 屏幕比例绘制的 MacBook 示意模型，使用 macOS Tahoe 浅色原版壁纸，保持明亮的蓝色桌面；无额外贴纸。
- 页面初次打开即展示便签；进入便签再移开鼠标时收起，鼠标再次进入刘海时展开。点击图钉可保持打开。收起后，大号 Hover here 提示及刘海边缘缓慢闪动；减少动态效果模式下保持静态提示。鼠标和键盘编辑时均保持打开，Esc 可收起。
- 点击刘海固定打开，再次点击关闭；图钉控制固定状态；Esc 关闭。
- 可输入的示例便签、四个便签页、任务勾选与进度、明暗主题。Reset demo 恢复初始内容并重新展开便签。
- 手机点击与键盘操作支持；尊重系统减少动态效果设置。
- 演示仅保存当前页面会话中的内容，刷新或 Reset demo 后恢复初始状态；不会传输或持久保存输入。

该网页演示是交互示意，不是原生 App 的逐像素截图，也不是完整 Markdown 编辑器。

## 下载按钮

项目地址根据本地仓库配置设置为 **https://github.com/lyunify/TuckNote**。

未能确认公开安装包地址，因此当前首屏主按钮直接链接到项目 README 的 Development 说明，没有虚构版本号、价格或安装包。

将来发布安装包后，在 `index.html` 中将对应 CTA 的 `href` 改为实际 release 或安装包地址，并相应调整按钮文字。发布前请确认仓库对目标访客可访问。

## 调整内容

- `index.html`：产品文案、导航、CTA 地址。
- `styles.css`：配色、版式、屏幕比例、动画、手机布局。
- `script.js`：示例便签内容及交互。
- `assets/app-icon.png`：直接沿用现有 TuckNote 项目的 AppIcon.png；展示裁切只通过 CSS 完成，原图未修改。
- `assets/macos-tahoe-light.jpg`：macOS Tahoe 浅色壁纸，Apple 原始视觉素材，经缩小以便网页加载。来源：[Basic Apple Guy](https://basicappleguy.com/haberdashery/macos-tahoe)，[原图](https://basicappleguy.com/s/macOS_Tahoe_Light.jpg)。壁纸版权归原权利人所有。

没有使用 NotchNotes 的代码、图片或文案。其网站只用作理解刘海便签展示方式的参考。

## 文件清单

```
tucknotes-site/
  index.html
  styles.css
  script.js
  .nojekyll
  README.md
  assets/
    app-icon.png
    macos-tahoe-light.jpg
    dock-finder.png
    dock-photos.png
    dock-mail.png
    dock-calendar.png
```

### 轻量互动彩蛋

- 勾完当前便签的全部任务，显示 3.2 秒的「Nice, all tucked away!」提示。切换便签、取消勾选、收起或重置会清除提示。
- 便签平滑淡入展开、淡出收起，无回弹；系统启用减少动态效果时取消过渡。

Dock 中的 Finder、照片、邮件和日历图标来自用户提供的图片；文件随网站打包，无需外部加载。

- 新增「＋ Yours」空白便签，可输入最多 500 字符；手写提示「What’s on your mind?」直接打开这张便签。同次试玩中切换标签或收起重开会保留内容，重置和刷新会清空。
- 展开和收起使用 240ms 的平滑过渡，快速重新打开时能连续衔接。

### 输入与试玩步骤

- 输入框的示例文字是提示，聚焦后隐藏，不作为用户内容。按 Enter 或点 Add 会添加一条真正可勾选的内容；Shift+Enter 换行，支持中文输入法。每张便签独立保留草稿与清单，Reset/刷新清空。
- 输入和操作面板期间保持展开；纯悬停离开后等待 650ms，点击外部或手写提示「Shall we tuck it away?」主动收起（钉住时外部点击不收起）。

月亮、太阳与图钉统一使用 18px SVG 图标，按钮尺寸与中心对齐一致。

### 手写互动提示

电脑下方用一条可点击的手写提示代替三步卡片。初次引导输入，写下想法或勾选后引导收起，关闭时引导重新打开。提示会跟随当前便签与面板状态更新；键盘和触屏同样可操作。
