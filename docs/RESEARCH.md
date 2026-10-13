# 逆向与导入依据

调查日期：2026-10-12。区分原包源码事实、当前实现、游戏未知。

## 本地原包

输入 `TimelineReminders.zip`，版本 v453，SHA256 `2e3c5c80a0c7e83ecd171acf79dd2a1c99828ebdff8e483305317e1d1b31814a`。246 个 Lua 文件可直接阅读；没有加密或 Lua 字节码。未运行上游 Lua。原包内容不随本项目分发。

关键文件：
- `Display/MidnightPhaseChanger.lua`：最近 0.3 秒新增/取消事件，区分游戏和脚本来源，使用公开时长构造阶段信号。
- `Display/Region.lua`：监听个人成功施法以提前停止对应提醒。
- `GlowUnitFrames.lua`：团框缓存及发光机制。
- `TimelineData/Midnight/` 中对应首领 Lua：声明阶段和固定事件表，部分有 `GetFakeEvent`。

密谋小径 Kystia（3101）：取消至少 2 个游戏计时进入间歇阶段，新增至少 3 个返回正常阶段，5 秒防重复；易伤预设在转阶段后 2 秒开始，持续 20 秒。用户“易伤后 3～13 秒”的 EXBoss 实测不能直接等同该阶段起点。

Lithiel（3105）：放狗 474408 是固定预报，开战后 11.2、68.3、125.5、182.5、239.7、296.7 秒；作者注明打断造成漂移，没有直接判断 EXBoss 事件 38。

Writhing Coil（3457）：25/10 秒新增计时组合进入下一轮；Merektha（2125）：新增至少 5 个进入下一轮；Avatar（2127）：新增约 15 或 32.5 秒计时交替阶段，2 秒守卫；Sentinel（3208）：50/25/13/7 秒组合进入下一轮。前三者之外守卫为 5 秒。Coil 未确认对应 EXBoss P2，Merektha 未确认对应 702。

Ulatek（3492）：没有动态阶段识别；心脏相关 1286860 为固定表，英雄施法开始 129/278.1/567.2 秒，史诗 139/288/583 秒；施法 6.5 秒，随后易伤 20 秒。

以上是源码结构和表格事实。用户认为心脏固定时间符合当前游戏；NextReminders 的独立识别/显示仍未 LIVE 验证。

## Lorrgs 官方导出

[前端 CopyNoteWindow.tsx](https://github.com/gitarrg/lorrgs-frontend/blob/main/src/components/CopyNoteWindow.tsx) 按玩家和技能筛选生成 MRT/NSRT。MRT 可以输出开战时间或阶段相对时间；NSRT 带 EncounterID/Difficulty/Name 头部，行含 ph/time/tag/spellid，按可用阶段计算相对秒数。

导出阶段来自日志，需要核对实际起点。初始真实阶段可能用另一个编号，允许用户显式绑定开战；编号本身不证明和本地实时节点相同。同编号多轮合并时本版不重建轮次。NSRT 的动态时间始终启用；无可用阶段时才回退开战。

前端存在复制额度和验证码流程。使用网站正式提供的导出入口，不改网站、不绕过限制。[后端项目](https://github.com/gitarrg/lorrgs) 是另一套统计服务；本版无需接其 API。

## 游戏公开字段与语音

[暴雪生成接口定义镜像：EncounterTimelineDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterTimelineDocumentation.lua) 将事件 id/source/duration/maxQueueDuration 标注 NeverSecret，spellID/name 等可受保护；GetEventState 提供状态。NextReminders 只向阶段引擎传公开实例编号、来源和时长，遇到秘密值拒绝参与判断。

[VoiceChatDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/VoiceChatDocumentation.lua) 的 SpeakText 接收声音编号、文字、速率、音量和允许重叠参数；本版用游戏可用声音读技能与倒数，不包含第三方语音包。发光通过自有覆盖层完成，不修改暴雪团框设置。实际声音可用性、字体和受保护框体行为仍需游戏实测。

## 历史更新调查（0.1.2 起已取代）

原包 CHANGELOG 指向的 `https://github.com/bart-dev-wow/TimelineReminders` 在调查时返回 404，没有可靠的公开下载入口；无法据此确认仓库一定私有。新版原包应由用户从原有正规渠道取得。

独立插件只接受兼容契约内的固定数字数据变化。采集引擎、基础转换、首领目录、阶段定义或识别规则变化就拒绝自动应用。不能用更新时间表替代新机制的源码复核。个人施法安排是另一个数据来源，必须重新从 Lorrgs 导入。

以上描述 0.1.0～0.1.1 的更新路线。用户现明确选择不再获取原插件，0.1.2 已移除 ZIP 更新器/指纹 manifest 和外部原包测试依赖；按自身实测、公开事件记录与 Lorrgs 独立维护 BossData。此前调查和旧版产物仅保留历史，不构成当前获取原包的要求。
