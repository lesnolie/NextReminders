# Rurutia的冷却就绪语音与独立实现

2026-10-12。用户要求首次易伤之后，亡者大军和黑暗突变每次冷却结束都发语音，并指出Rurutia能这样做。以下是公开版的静态证据，不是用户本机版本或本插件LIVE证明。

## 目标身份与REA证据

作者发布页：https://www.curseforge.com/wow/addons/rurutiasa-class 。Project ID1721740，官方文件9104459，RurutiaSA_Class v3.8.7.zip，2026-10-09，声明12.1.5；元数据通过cfwidget按项目编号查得，ZIP从官方ForgeCDN取得。文件893760字节，SHA256 `32abdd56124e5922db5eb3f8f37952d17621cc52c4bb68a95212b64f752e6c3f`，CRC检查通过。

REA open_binary确认ZIP身份，inspect_artifact证据 `ev_39795b2e029ea8fe5b09c5851dc5c7f0a5eb50a7bfc691b9c755f66383a28f13`。其范围是完整中心目录观察，不执行包；58个Lua/TOC文件有明文，因此后续按REA技能使用普通源码工具追踪。原包只保存于.local/artifacts，不进入产品交付，未安装或执行；分析完关闭REA目标。

## 观察到的机制

`Modules/CDMVoice/ReadyRules.lua`418/420分别定义邪DK黑暗突变1233448与亡者大军42650。`Modules/CDMVoice/Core.lua`467～519通过公开isEnabled/isActive/isOnGCD判断技能是否在实际冷却；充能技能使用maxCharges/isActive。521～539先观察冷却并armed，之后观察ready才播放一次；419～447消耗armed并节流播放SoundFile。709～746还订阅TriggerAvailableAlert与OnCooldownDone，用来安排额外检查；749～767查暴雪原生冷却管理器帧。没有由这段代码解密秘密剩余秒数的证据。

## 官方API核对与本插件的差异

来源：https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua 。SpellCooldownInfo的isEnabled/isActive/isOnGCD标记NeverSecret，充能maxCharges/isActive也标记NeverSecret。isOnGCD可nil，且官方注明仅响应SPELL_UPDATE_COOLDOWN时可信；数字startTime/duration没有同等保证。

本插件Ready.State只取公开布尔/最大充能，任何未知/秘密/异常返回nil，不读冷却秒数。Main在SPELL_UPDATE_COOLDOWN中扫描已配置的公开技能ID，不读事件载荷；该上下文内区分公共冷却并记录实际cooling。常规轮询只接受公开inactive作为ready，或公开充能恢复状态，不信任轮询时的isOnGCD。新模块没有挂接暴雪帧，也不需要Rurutia或其语音素材；使用既有游戏文字转语音出口。

这里与TellMeNext METHOD_SELECTION中被拒绝的秘密剩余时间算术不同；没有读取DurationObject/原生alpha或据此分支。公开API字段的使用依据为当前文档和原包源码，不继承TMN或Rurutia的LIVE结论。

## 个人策略及限制

after:ready仅属于第一次的技能行，同一技能最多一个后续来源。首次事件提醒实际用过该技能之后才监听；起手同技能不会提前解锁易伤后的策略。每次观测实际cooling→ready发一次语音，保持ready不重复；成功施法/新实际冷却后可重新触发，首领结束/进入世界/停止全部清理。冷却更新先于施法成功的顺序使用0.5秒内的公开观察接续，避免漏掉本轮起点。

当前充能语义是恢复满充能后提醒，不代表已有一层充能就提醒。物品/饰品/文字不支持此后续模式。网站和游戏预览用手动“模拟冷却结束”，不读取真实冷却，不作LIVE证据；没有可靠公开状态时不会猜固定秒数播报。

STATIC/MOCK覆盖秘密字段、不读数字、GCD与事件上下文、两种事件顺序、首次解锁、重复语音去重、旧协议拒绝新增字段、手动回放和战斗结束清理。游戏LIVE尚未测，需要确认本机接口字段、自然结束/减冷却/重置等实际事件顺序及真实声音。
