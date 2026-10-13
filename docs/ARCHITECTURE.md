# 模块合同与数据边界

0.3.5导入光标：UI.noteCaret为导入EditBox自己的OVERLAY纹理，与原生输入共享ScrollChild坐标／裁剪；空框起点与4单位inset一致，非空位置由OnCursorChanged公开x/y/height驱动。光标宽2、0.5秒闪烁，原生位置更新即重亮；只有聚焦且位置已知时安装OnUpdate，失焦／切页／隐藏清理。不会测量文本宽度、改插入位置或增加保存数据；仅创建时初始化空文本及位置0。保留最近真实布局以兼容Cursor-before-Text顺序。此项取代0.3.3下方“不模拟额外纹理”的历史实现选择；49项STATIC/MOCK，真实像素LIVE待测。

0.3.4新增内置爆发目录：web/burst-spells.json为唯一维护源，sync_spell_catalog.py生成双方静态文件，dataVersion=2026.10.13.1。SpellCatalog.lua在Core之后加载，Get(id)/ForSpec(specID)返回副本，Info(id)优先公开游戏元数据、空／异常／秘密值时回退目录，不读取技能冷却、天赋、血量或事件身份。EventPlans.Action、Display、PreviewUI共用Info；Main的/nr spells只读当前专精。网页picker按当前专精展示中文名、图标、主要／可选标记，显式点选只改当前行，清生成快照；原手填编号兼容。目录不做时点、循环、自动施法、默认策略或跨编号别名。维护、来源和48项验证边界见research/BURST_CATALOG。

2026-10-13网站：index.html为独立工具首页，mplus.html为实际首领生成器。app.mjs加载planner.mjs；drafts.mjs独立拥有旧整包草稿读取、旧单首领迁移、验证后保存和最近选择，沿用原storage键。首领事件／生成协议仍由plan.mjs拥有，after:ready显示为完整解释的开关；所有实际输入变化清空生成快照，保存或生成失败不默默覆盖旧数据。主页和生成器共享品牌图片与石墨／冷蓝样式，外部参考入口只在页脚。新增PNG/JPG等媒体纳入build.py源快照；游戏安装ZIP不加入网站媒体。45项统一STATIC/MOCK与WEB证据见WEB_HOME。

版本：0.3.5-dev；独立插件，不调用 TellMeNext、EXBoss、TimelineReminders 或 Lorrgs 网络 API。当前数据由本项目维护，无原包获取/构建依赖。网站仅大秘境规则生成，团本去Lorrgs复制；WCL命令行工具作为开发参考保留，游戏插件不联网。

0.3.3 UI导入编辑框显式EnableMouse，并在编辑框／面板／滚动框左键按下时SetFocus；OnEditFocusGained/Lost更新外框与输入状态提示，空文本未聚焦时显示Ctrl+V说明。OnCursorChanged使用编辑框给出的y和cursorHeight维持可见范围，内容只在需要时撑高，避免重复改尺寸；不将原生光标模拟成额外纹理。OnTextChanged继续维护文本高度并刷新空提示。Esc、SetPage与导入页OnHide清理焦点；不自动聚焦、不改文本或编号、不自动解析／保存。44项STATIC/MOCK通过；原生光标像素需LIVE核对。

0.3.2 Display的提醒条单独覆盖背景／边框alpha=0.18/0.25，不改变Theme其他面板，不用Frame:SetAlpha降低整个条的可读性；文字加阴影。show/update共享时间文案：remaining>0时ceil秒数，到点或之后为“现在”；hold始终“等待”，不猜未知事件时点。show拿Engine传入的剩余时间立即显示，复用不会短暂沿用旧数字。视觉计时独立于3秒语音倒数开关。提前显示lead不修改target，起手0秒不引入虚构战前倒数。43项STATIC/MOCK通过；游戏新版LIVE未测。

0.3.0：DungeonData为副本目录，与web/dungeons.mjs按编号和顺序校验；首领机制仍由BossData单独拥有。NRDungeon:1包装多份NRPlan:2，不执行编码文本。EventPlans新增ValidateDungeon/ParseDungeon/SaveDungeon/LastDungeon/PauseDungeon/RollbackDungeon/OwnsDungeonEncounter。Save先验证全部首领、事件、专精和难度，再构造副本桶，最后写入；只替换此专精／副本mythic事件键，遗漏首领清除，保存false占位的完整备份。dungeonScopes[specID:dungeonID]记录新包接管状态，备份一并交换；Main只在实际difficulty=8时抑制此范围的旧静态文本，新包事件不会加载到普通史诗。其他专精和副本保留原路径。回滚先验证全部备份再交换；战斗中导入／暂停／回滚均拒绝。

UI识别NRDungeon并展示覆盖范围；保存成功标记lastPlanKind=dungeon。PreviewUI.Open(bundle,choice)先校验后取单首领副本，下一只按钮重新启动独立Preview；预览不写存档。网页生成快照与编辑草稿分开；任意输入变化都清除导出、禁用复制，重新生成后才可使用。0.3.1移除网站Rehearsal和模拟面板，三个下拉框手动选择专精／副本／首领；newDungeon的所有首领默认rows=[]，不继承旧单首领示例。已保存草稿仍恢复，草稿和生成快照独立；切换专精／副本清输出并禁用复制。newPlan旧单首领示例仅保留给历史格式回归，不是网站默认打法。游戏PreviewUI及实战逻辑保持原合同。协议见WEB_PLAN_FORMAT；42项STATIC/MOCK通过，LIVE未测。

0.2.1：Ready.State(spellID,fromCooldownEvent)返回cooling/ready/nil，只读公开布尔与最大充能，不读取秘密时长。isOnGCD仅在SPELL_UPDATE_COOLDOWN里使用，Main扫描配置ID而不取秘密载荷；轮询只接受公开inactive或充能恢复状态。Engine.New(emit,previewDefinition,readyReader)新增可选只读依赖，Preview传未知reader并手动演练。Engine.CooldownUpdate(now)仅由冷却更新事件调用，保留0.5秒内公开观察以处理事件先于施法成功的顺序。

行after="ready"仅第一次的技能行，同一技能一个后续来源。第一次显示的提醒实际用过才创建readyWatches；cooling→ready发show/update、标记postReady，Display沿用TTS播“技能好了”。持续ready不重复，新实际冷却可再次触发；未知不猜测。后续周期不会被旧事件时点校正覆盖，撤回仍清掉对应监听。Stop/ENCOUNTER_END/PLAYER_ENTERING_WORLD清理；手动就绪进入回放记录，不读真实冷却。36项STATIC/MOCK通过，LIVE未测。

0.2.0补充（2026-10-12）：TOC新增EventPlans、BossEvents，游戏内EventUI草稿因网站编辑方向移除。EventPlans将个人策略与BossData信号定义分开，校验和存档按专精、EncounterID和难度隔离；不自动写入预设。Engine:Begin新增最后一个可选eventPlan参数，普通导入合同保持。BossEvents只接公开severity和计时批次/状态，记录事件键、次数、预计时刻和撤回状态；Finished仅代表计时结束，不作为独立机制真值。暂停撤预报并等待Finished，取消/移除撤回；模糊时长匹配不赋予事件身份。Preview使用单独Engine和手动事件操作，不写实战状态。

NRPlan:1协议见WEB_PLAN_FORMAT.md；UI按头部识别，解析/校验后才允许保存，来源编码不执行Lua。事件存档为eventPlans[specID][encounterID:difficulty]，覆盖保留一份previousEventPlans；最近方案类型用于预览/暂停/回滚，不能误改另一类方案。db.enabled=false仅禁止实战提醒加载，不阻止脱战演练。物品在本场开始时解析公开使用技能编号；秘密编号不比较，文字提示只到期或模拟已用退出。当前31项STATIC/MOCK通过，LIVE未测。

加载顺序由 TOC 确定。Core 提供共享命名空间 NR 与公开值/数字校验；Theme 提供独立颜色/控件/窗口样式；BossData 提供声明式首领规则；Import 校验导出文本及绑定；Engine 驱动提醒；Preview 管理独立模拟状态；Display 管理自有框体/语音/发光；PreviewUI 显示播放列表与控制；UI 编辑与保存；Main 负责事件和战斗生命周期。

## 方案

`NR.ParseNote(text, options)` 返回方案或 `nil, error`；`options` 可包含 `encounterID`、`difficulty`（MRT 缺省难度）、`targetDifficulty`（明确选择使用难度）、`personal`。只解析文本，不执行它。文本上限 200 KB、去重后 1～500 条，每行一个技能。

方案字段：`encounterID` 正整数；`difficulty` 为 normal/heroic/mythic；`rows` 为提醒数组；`phaseBindings` 将来源阶段映射到 `pull` 或本地节点编号；`personal` 控制忽略标签/匹配自己；`enabled` 控制加载。

NSRT 另保存 `sourceDifficulty`，作为来源元数据；MRT 不包含该信息，保持缺失。`difficulty` 是实际使用难度，存档键、战斗选择、节点校验及固定预报均按它执行。默认 NSRT 跟随头部、MRT 使用史诗；用户可明确覆盖使用难度。跨难度复用保留原施法秒数，不调用任何时间换算；英雄不复用现有史诗动态识别规则。旧方案无需迁移。

提醒字段：唯一整数 `id`、整数 `spellID`、整数来源 `phase`、相对秒数 `time`、字符串 `tag`。时间只支持 0～3600 秒。来源 P1 必须绑定 pull；来源 P2+ 必须由用户明确选择。动态节点只支持当前数据中存在的史诗/大秘境节点。

`NR.ValidateBindings(plan)` 在保存和开战时都执行。未知节点拒绝整份方案，不能默默把阶段改成开战时间。团本未知动态阶段改用 MRT 静态导出。重复来源阶段号无法恢复每次阶段发生顺序。

`NR.ValidatePlan(plan)` 只验证方案与提醒的数据结构，供脱战演练使用；不会认可任何未知实战节点。两种校验分开，不能用结构校验代替实战绑定。

## 引擎

`NR.Engine.New(emit)` 返回独立实例；`Begin(encounterID,difficulty,plan,settings,now,identity)`、`Tick(now)`、`Cast(spellID,now)`、`Stop()` 管理生命周期。复制方案到本场，不回写用户存档。

`Timeline(kind, info, now)` 仅接收公开 `id/source/duration`。added 为新增，canceled 为取消，removed 清理实例；snapshot 只记录开战前已有计时的来源，不加入阶段判断批次。脚本来源和秘密值不参与识别。新增/取消批次长度 0.3 秒，每只首领有独立阶段间隔守卫。

`Transition(now,logicalPhase)` 顺序增加本地节点，设置该节点起点。阶段提醒以此为时间零点；进入下一节点后旧节点提醒退休，开战相对提醒保持原时钟。

输出事件：show/hide/update/countdown 为提醒行；phase 为识别节点与标签。成功施法只隐藏正在显示的相同技能提醒，未显示的未来提醒不消费。到达时点前 lead 秒显示，时点后 window 秒退休；战斗结束立即停止。

## 播放预览

`NR.Preview.New(emit,clear,blocked)` 创建单独实例，接受输出、显示清理和战斗禁止条件。`Start(plan,settings,identity,wallTime)` 复制输入，在虚拟 0 秒初始化；`Tick(wallTime)` 按墙钟差及倍率推进。Pause/Resume/SetSpeed/Seek/NextPhase/Cast/Stop 控制演练。范围为 0～7200 秒，倍率为 1/2/4。

预览创建独立的 Engine 实例，并显式传入只包含手动节点、空规则的预览定义。该实例按 ValidatePlan 加载虚拟方案；Main 的实战实例未传预览定义，继续只按 ValidateBindings 加载。禁止向 BossData 注入虚拟首领，禁止改原方案 phaseBindings 或 enabled。

已有绑定按节点顺序归组，同节点共同触发。未绑定来源阶段仅在副本中获得手动节点；不代表实时识别已支持。Seek 暂停显示事件输出，按保留的手动阶段/模拟施法操作重建状态，然后只发布跳转时仍有效的提醒；后续操作被丢弃。暂停冻结虚拟时间，恢复重新设置墙钟，不补算暂停时长。

PreviewUI 显示完整列表并复用控件，模拟施法仅消费当前提醒。NR.Display 为预览行加文字标记；真实语音/倒数/发光共用同一出口。停止不活跃预览不会清掉实战显示；真正进入战斗前停止预览并关闭播放窗口。测试命令也走独立预览实例，不写实战日志。

## 显示与配置

0.1.3 Theme 自建扁平 Button/Check/Edit/Panel/Label/Window/Scroll，保留标准按钮文字和启用接口。窗口按屏幕宽和高缩放，只有标题栏可拖动。UI 分导入/设置页，切页保留草稿；阶段绑定有独立滚动区，不限于前 7 个来源阶段。PreviewUI 用分列列表和同一虚拟时间的只读轨道显示；轨道不写入个人方案。主题变化不修改秘密值、调度、SavedVariables 或阶段识别合同。

Display 的提醒条和发光覆盖层归插件所有。原生团框在脱战且非光环限制环境下缓存，名字/单位值均检查是否公开。覆盖层仅在目标框可见且仍有活动提醒引用时显示；不改原生团框属性。

UI 的导入、保存、设置、暂停和回滚在战斗中拒绝；文本/个人模式/使用难度变化，以及 MRT 首领变化后要求重新预览。阶段按钮复用，并捕获各自来源阶段。首领固定时间仅作为预览参考，不生成玩家施法方案。

Main 注册玩家成功施法及公开时间轴事件。战斗开始/进入世界会结束预览。开战先清掉预览和配置窗，重新验证方案，初始化实战引擎，然后读取已有时间轴实例的公开来源。退出战斗/队伍变化时更新团框缓存。

## 更新与归档

`BossData.lua` 为首领数据唯一源，采用独立 dataVersion；旧基线来源保留在研究记录中。原 ZIP 更新器和指纹 manifest 已退役，历史产物仍保留。新时点来自自身实测、公开时长批次记录或 Lorrgs；新的识别节点须补回放证据与游戏验证。

程序与数据写入源码目录，个人方案存于游戏 SavedVariables。构建前快照所有交付输入，运行实际测试（含自有数据合同与事件回放）后再次比对快照；从相同快照归档并逐项核对字节。最终 manifest 只记录实际验证证据，保留 source_review=PENDING、LIVE=NOT_RUN。构建无需下载或读取任何上游 ZIP。
