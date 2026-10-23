# 精简交接：NextReminders

更新：2026-10-12。本文件用于压缩上下文后恢复工作，不代表正式验收通过。

## 恢复后的最新状态（优先于下文旧快照）

- 0.3.6-dev（2026-10-23）：团本以 Lorrgs NSRT 为准，阶段识别复用 BigWigs 公开消息，手填转阶段时间兜底。WCL 已复核 28 只大秘境与 10 只团本：7 只团本有 phaseTransitions 直接证据；乌拉特克确认 P1→P2→P2.5→P3，Kith'ix 确认 P1→P2，均已补入 stages。下一步只需游戏内实测 stage 消息，重点是 3470／3429／3492／3513；详见 research/BIGWIGS_STAGES、WCL_PHASE_AUDIT。

- 0.1.3-dev 最新：用户要求参考原插件逆向改善UI；只读既有明文LiquidUI/Interface代码，无新原包获取。独立Theme.lua重建，导入/设置分页，双栏检查、滚动阶段绑定、播放轨道/游标/分列状态/技能图标，预览提醒临时TOP并恢复CENTER。21项STATIC/MOCK PASS，三个浏览器视觉样稿截图及docs/ui-preview.html可直接查看，非游戏截图，LIVE未测、source_review=PENDING。最新包0.1.3，旧版包/日志manifest备份保留。临时交互预览地址http://127.0.0.1:50620/ui-preview.html（本地Python会话3299，关闭后可重新用http.server启动docs目录）；长期文件仍为docs/ui-preview.html。
- 0.1.2-dev 最新决定：用户不再获取 TimelineReminders，继续独立开发。当前已删除 tools/update_data.py、data-source.json 和原包测试依赖；BossData 改用独立 dataVersion=2026.10.12.1，历史基线/旧 ZIP 保留。新增 Preview.lua/PreviewUI.lua，整份导出方案可脱战播放、暂停、1/2/4 倍速、跳转、手动阶段及模拟施法；未知团本阶段也可演练，仍不允许当成实战支持。独立引擎不改存档/实战日志，战斗时退出。最新统一入口20项PASS；安装和源码包更新为0.1.2-dev，未游戏实测/安装/发布，待Advisor验收。后续以PROJECT_STATE/ARCHITECTURE/DEVELOPMENT/manifest为准，下文上游获取和旧版未完成事项仅历史，不再适用。
- 最新版本为 0.1.1-dev：史诗 Lorrgs 文本可明确选择用于英雄。NSRT 来源难度保留，目标难度单独选择，秒数不换算；英雄仍不启用史诗动态识别规则。新增解析/UI/实际战斗生命周期测试后统一入口 19 项 PASS；最新两个包文件名为 0.1.1-dev。0.1.0 两个 ZIP 与对应旧 manifest/checks 备份保留。
- 独立插件开发预览已实现，README、ARCHITECTURE、ERROR_LOG、RESEARCH、PROJECT_STATE 均已补齐。
- 下文“必须继续处理的事项”1～7 已完成执行者自检：测试命令、独立阶段按钮/复用、更新合同、真实验证后打包、安装/更新说明均已修正。
- 最新统一入口为 `python tests/check.py`，17 项全部 PASS；`python tools/build.py` 真正运行此入口后产生两个包，源码与归档逐项核对。另已在隔离目录验证无效 Main.lua 导致构建失败且无产物。
- 当前安装包 `dist/NextReminders-0.1.0-dev.zip`；源码工具包 `dist/NextReminders-source-0.1.0-dev.zip`；验证日志和完整哈希为 `dist/checks.log`、`dist/manifest.json`。
- 已补开战已有计时快照，修复初始事件未订阅导致取消识别遗漏；快照不产生新增信号。
- 来源 P2+ 可手动绑定开战，但不猜测；动态规则仅用于史诗/大秘境。MRT 专精标签也能匹配自己。
- 团框缓存支持一人多个原生框，跟随可见性并按提醒引用清理；中文逗号整体规范化避免破坏 UTF-8 名字。
- 更新仅允许支持的固定数字变化，动态文件/阶段/接线、目录、基础转换变化全部拒绝；应用失败回滚已 MOCK 验证。
- 执行者自检完成，待 Advisor 验收；LIVE NOT_RUN。没有自行调用其他模型验收，没有安装游戏、提交、发布或修改 TellMeNext。
- 后续先读 `docs/PROJECT_STATE.md` 与 manifest；需 Advisor 检查实际产物并进行游戏验证。用户的新指令决定下一步，不自动安装或发布。

## 用户已确定的目标

制作独立魔兽世界插件，包含：
- 玩家使用对应技能后自动撤销当前提醒。
- 语音、倒数，以及指定玩家的团框发光。
- 通过游戏公开的首领时间轴信息识别阶段；不读取或解密秘密值。
- 从 Lorrgs 网站正式导出文本，粘贴到游戏插件导入。
- 程序、首领数据与个人方案分开保存，方便更新首领数据。

用户已明确选择“独立插件”和“导出文本后粘贴”，无需重复询问。

## 位置与工作约束

- 新项目：`C:\work\NextReminders`。原会话工作目录为 `C:\work\TellMeNext`。
- 本任务未修改 TellMeNext；2.07 原包与历史提交保持原样。
- 保留用户无关改动；常规可逆步骤自行完成。
- 项目角色约束：执行者自行调查、实现与测试，不自行召其他模型做常规审查或验收。交付标记“执行者自检完成，待 Advisor 验收”；`source_review` 为 `PENDING`。
- STATIC、MOCK、LIVE 分开报告，不把模拟验证称为游戏实测。
- 此交接不增加安装、发布或其他新授权。

## 已实现文件

插件位于 `NextReminders/`，版本 `0.1.0-dev`：
- `Core.lua`：基础数据、设置、秘密值检查与数字校验。
- `BossData.lua`：7 个首领的独立声明式数据与阶段规则。
- `Import.lua`：Lorrgs 的 MRT/NSRT 文本解析、校验与阶段绑定。
- `Engine.lua`：提醒调度、施法撤提醒、公开事件批次识别、阶段与战斗起始时间管理。
- `Display.lua`：提醒条、游戏原生文字转语音、倒数、可选音效；暴雪原生团框缓存及独立发光覆盖层。
- `UI.lua`：`/nr` 配置、粘贴导入、预览、手动阶段绑定、保存、最近方案暂停与回滚。
- `Main.lua`：战斗与公开时间轴事件、玩家成功施法、SavedVariables 和测试命令。
- `NextReminders.toc`：Interface 120007/120100，SavedVariables `NextRemindersDB`。

工具与测试：
- `tools/update_data.py`：本地上游 ZIP 预览/应用；不执行上游 Lua。核对识别函数及公共阶段引擎指纹，变化则拒绝自动更新。只更新已支持数据，保留个人方案。
- `data-source.json`：上游版本、ZIP 哈希、识别指纹基线。
- `tools/build.py`：打包与内容一致性检查；尚未实际运行。
- `tests/check.py`：Lupa 的 Lua 5.1 真实代码 MOCK 测试，包含解析、调度、秘密值拒绝、阶段、主事件、UI 保存校验和更新器拒绝路径。
- `LICENSE`：本项目 MIT。

最近一次自检：9 项测试全部通过；Lua 文件通过 Lua 5.1 加载检查。此后未完成游戏 LIVE 验证、正式审查、安装或打包。测试使用 Lupa 2.8，并依赖下述本地上游 ZIP。

## 必须继续处理的事项

1. 已发现但尚未修复：`Engine.Begin` 新增方案校验后，`/nr test` 的 encounterID=0 会被拒绝，导致演示无提醒。修正内部演示并增加针对命令链路的测试。
2. 检查 UI 多阶段按钮的 Lua 5.1 闭包绑定，必要时为每个按钮显式保存阶段变量。覆盖多个阶段按钮的实际点击测试。
3. 更新器当前核对函数指纹，但还应防止上游阶段定义/首领目录发生变化而漏判。采取可验证的保守拒绝机制；不能在无法确认兼容时自动应用。
4. `build.py` 当前将 STATIC/MOCK PASS 写死，改为真实运行测试或绑定当前版本的真实验证证据。不能凭打包成功宣称测试通过。
5. 补 README、安装/导入/更新说明及有来源的研究记录。明确当前只支持暴雪原生团框，第三方团框未适配。
6. 明确个人导入的施法时间不会随首领数据更新自动调整，需要重新导入；阶段绑定也不能把 WCL 阶段号直接等同本地阶段号。
7. 完成自检后再打包，交付仍保留 Advisor 待验收和 LIVE 未测标记。勿宣称所有首领阶段识别均已支持。

## 上游逆向证据与支持范围

用户原包：`C:\Users\leslie\Downloads\General\WoW\TimelineReminders.zip`，v453。

ZIP SHA256：`2e3c5c80a0c7e83ecd171acf79dd2a1c99828ebdff8e483305317e1d1b31814a`。

提取的 Lua/XML/TOC：`C:\Users\leslie\AppData\Local\Temp\TimelineReminders-source-bejy7kzo\TimelineReminders`。246 个 Lua 文件是可读源码，没有加密或 Lua 字节码。

原插件用公开事件的 id/source/duration/status 和短时间内事件新增/取消数量识别阶段；遇到秘密值跳过，不解密秘密血量。上述机制属于原包源码事实，游戏实际可靠性需 LIVE 验证。

| 首领 | encounterID | 原包判断 |
| --- | --- | --- |
| 密谋小径老一 Kystia | 3101 | 0.3 秒内取消至少 2 个事件进入间歇阶段；新增至少 3 个返回正常阶段；5 秒防重复。易伤预设为转阶段后 2 秒开始，持续 20 秒。 |
| 密谋小径老四 Lithiel | 3105 | 固定时间，放狗约开战后 11.2、68.3、125.5、182.5、239.7、296.7 秒；原作者注明打断会造成漂移。 |
| 毒牙祭坛老二 Writhing Coil | 3457 | 0.3 秒内出现时长 25 和 10 秒的事件进入下一轮；5 秒防重复。不能证明等同用户 EXBoss 的 P2。 |
| 塞塔里斯神庙老二 Merektha | 2125 | 0.3 秒内新增至少 5 个事件进入下一轮；5 秒防重复。没有直接判断事件 702。 |
| 塞塔里斯神庙老四 Avatar | 2127 | 新增时长约 15 或 32.5 秒的事件切换阶段；2 秒防重复。既有固定预报，也有公开事件阶段识别。 |
| 纳洛拉克洞穴老二 Sentinel | 3208 | 25、50、13、7 秒时长事件组合进入下一轮；5 秒防重复。小怪时间不能单独证明应留爆发。 |
| 团本 8 号乌拉特克 Ulatek | 3492 | 已有 P1→P2→P2.5→P3；分别绑定 BigWigs stage 1／2／2.5／3，WCL 三份击杀确认。心脏相关 Rage of the Shackled 仍是独立机制，施法 6.5 秒，随后易伤 20 秒；英雄约 129、278.1、567.2 秒，史诗约 139、288、583 秒。 |

用户的 EXBoss 规则：老一易伤后 3～13 秒与老四事件 38 后 0～10 秒已游戏实测；Coil P2 未实测；Merektha 事件 702 依据较弱（21/32 记录）；Avatar 未定；Sentinel 开打交即可（20/20 高手记录）。不可将这些事件号与原插件阶段直接混同。

2026-10-12 检查：原包提到的 `https://github.com/bart-dev-wow/TimelineReminders` 返回 404。只能说当时没有可用公开源码入口，不能断言其一定为私有。定期更新从用户正规渠道取得新 ZIP；识别代码变化需人工复核。

## Lorrgs 格式与来源

- 前端导出实现：<https://github.com/gitarrg/lorrgs-frontend/blob/main/src/components/CopyNoteWindow.tsx>
- 后端：<https://github.com/gitarrg/lorrgs>
- MRT 示例：`{time:02:15.5} - Name {spell:51271}`；动态阶段可包含 `,p2`。
- NSRT 示例头：`EncounterID:3492;Difficulty:Heroic;Name:Ula'tek;`
- NSRT 示例行：`ph:1;time:135.5;tag:TopPlayer;spellid:51271;`
- ph:1 以开战为起点；后续是 Warcraft Logs 的阶段号，必须明确绑定本插件支持的阶段起点。未知阶段拒绝启用，不猜测。
- 第一版默认将导入施法作为自己的提醒；可明确选择团队提醒。
- 采用网站正式导出，不绕过验证码、复制额度或付费限制。游戏插件不直接联网请求网站。

## REA 已配置，无需重装

技能：`C:\Users\leslie\.codex\skills\reverse-engineer-anything`，调用名 `$reverse-engineer-anything`；slash 输入 `/reverse` 后从列表选技能。

REA 6.4.0：`C:\Users\leslie\.codex\tools\rea\node_modules\rea-agents`。使用 Codex Node 24.19.0，系统 Node 22.18.0 不兼容。MCP 已配置并完成 initialize/tools/list/binary_session 验证；170 个工具。分析已是可读 Lua 的普通逻辑时不必强行调用 REA。

## 本次上下文问题

曾报提示词约 345047 tokens，超过模型 272000 上限。会话已触发上下文压缩，本文件保留进度。若再出现，使用 `/compact`；仍失败则开新对话，发送：

> 继续 C:\work\NextReminders 的独立插件任务，先读 docs\HANDOFF.md，按“必须继续处理的事项”完成开发。不要修改 TellMeNext 原包。
