# 网站图标

> 网页项目：`C:\work\tellmenext-web`；线上入口：https://tellmenext.cc/zh/mplus/ 。本仓库只维护游戏插件，旧 `web/` 已于 2026-10-24 移除。网页修改、预览、构建与发布均在 tellmenext-web 项目进行。
> 以下旧网页说明仅为历史记录，不作为当前开发入口。插件数据维护源已迁至 `data/`；`tests/fixtures/protocol/` 仅用于旧格式兼容测试。

2026-10-13。当前使用 `web/assets/nextreminders-logo-v2.png`，原始生成图保留；由内置 ImageGen 工具生成。用户提供的 TMN.exe 图标只用作圆角浅底、连续圆管和柔和阴影的风格参考；新图形为 N 与前进箭头，颜色为冷蓝／青色。首页、页眉、页脚和 favicon 引用同一个本地资源。

生成指令（最终使用版本）：

```text
Use case: logo-brand. Asset type: square application and website brand icon for NextReminders. Use the attached image ONLY as a style reference: a warm off-white rounded-square tile, a single softly rounded continuous tubular symbol, gentle depth and clean diffuse contact shadow. Create a NEW symbol: a distinctive capital N made of smooth connected round tubing, with a small subtle forward arrow termination on its upper-right end to communicate next action. Do not copy the T symbol. Color of the tubular N: tasteful deep azure blue transitioning to cyan and pale ice-blue highlights; no orange, red or pink. White/very light cool-gray matte rounded-square tile, generous radiused corners, very subtle raised form, centered, front-facing orthographic product icon, no scene, no perspective tilt. The tile occupies nearly the whole square frame with transparent exterior corners. Symbol comfortably fills 66 percent of tile and is readable at small website header size. Soft premium friendly design matching the reference icon's simplicity; no chrome metal, no neon glow, no busy details. No text, filenames, captions, mockup, extra elements or watermarks. Actual transparent background outside tile.
```

图像是原始 PNG 的字节副本，保留透明外角；没有用脚本重绘或替换成SVG。网页只缩放显示。原始文件在用户的Codex generated_images目录；实际引用资源已复制到项目内，不依赖该目录。

此前生成的棱角版本 `nextreminders-logo-v1.png` 留作历史候选，当前页面使用V2。
