# 0.3.10-dev：首领事件演练与 LittleWigs 信号

本版修复同一份网站导出在插件演练中缺少事件时间、手动触发后列表不重排的问题。

- 默认开启“自动演练事件（网页参考时间）”。密谋老一首次易伤按 91.5 秒演练；密谋尾王首次猎犬按 12.8 秒演练。只有已维护的事件次数有参考时间，未知次数不会编造。
- 时间轴标注“估计”；这些时间仅用于脱战演练，不参与实战触发。总长度是演练范围，不是击杀时间。
- 关闭该选项可手动触发事件，列表与图标按实际触发后的时点重排。切换模式重建演练并清空手动操作记录，保留当前位置、暂停状态与倍速。
- 密谋老一易伤接收游戏原生 ENCOUNTER_WARNING，以及 LittleWigs 经 BigWigs_Message 发布的 1230304 消息；过滤其他首领和技能，两路重复信号只计一次。未安装 LittleWigs 时保留原生信号。
- 标签说明信号来源；其他尚未核对的机制继续显示“待游戏核对”。

## 来源与边界

网页参考快照：2026-10-21 的 mplus-timelines.json。3101 的 474238 中位时间 111.5 秒，网页易伤偏移 -20 秒，得到 91.5 秒；3105 的 474408 首次时间为 12.8 秒。插件独立保存演练参考，不依赖网页目录运行或打包。

LittleWigs 上游 KystiaManaheart.lua 的 ENCOUNTER_WARNING 使用 severity=1 发出 1230304 消息：
https://github.com/BigWigsMods/LittleWigs/blob/master/Midnight/MurderRow/KystiaManaheart.lua

BigWigs 的公开消息参数由 BossPrototype.lua 定义：
https://github.com/BigWigsMods/BigWigs/blob/master/Core/BossPrototype.lua

实战沿用原有“预警后 1.7 秒”偏移，本版未在游戏中重新测定该偏移。参考时间不能保证实际每场首领战的易伤时间。

## 验证

61 项 Lua 5.1 静态／模拟检查与 7 项时间轴测试通过。新增回归覆盖截图六条技能的时间排序、91.5 秒自动事件、跳转与回退、手动事件重排、未知次数不推算、演练与实战隔离、LittleWigs 消息过滤和双向去重。

LIVE NOT_RUN：未进入游戏验证画面、音效、受保护框体与真实预警偏移。发布物仅放本地 TMN-发布，未安装进游戏，也未上传插件下载。
