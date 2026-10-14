# v0.6.0

- **Phase 2 全局任务动态与执行历史中心 (Task Mission Control & Execution History)**：
  - **跨实例任务事件中心 (`TaskHistoryView`)**：全新设计任务历史模态面板，实时聚合记录全部多开实例的 Agent 执行状态（已完成、等待确认、执行异常），支持关键词即时搜索（实例名、备注、工作区、任务内容）与分类标签筛选。
  - **任务耗时追踪 (`Telemetry Duration Tracking`)**：自动精确度量每个实例中 Agent 任务从启动到结束的实时耗时（例如 `⏱ 1 分 24 秒`），并在极速切换面板（⌥Space）与缩略图监控墙卡片上实时呈现青色高亮计时胶囊。
  - **一键定位调出与日志查看**：在历史记录卡片中可直接点击「调出并聚焦」，瞬间唤醒对应实例窗口；支持一键直达对应实例的系统日志目录。
  - **历史记录导出与清理**：支持一键将所有任务耗时与状态导出为结构化 Markdown 报告并保存到桌面；支持安全清空历史记录。
  - **菜单栏任务动态快捷菜单**：状态栏托盘菜单中新增「📋 最近任务动态」，动态显示最近 3 条执行记录，支持一键点击直达实例及调出完整历史。
- **实例窗口收起、恢复与启动检测深度修复 (Window Collapse/Restore & Launch Detection Fix)**：
  - **彻底修复收起/恢复失效 Bug**：针对 macOS 跨进程沙箱与 AppKit 限制导致 `NSRunningApplication.hide()` / `unhide()` 返回 false 且无法真正隐藏/恢复 Electron 窗口的底层问题，引入针对 bundle identifier 的 System Events 显隐控制与 `NSWorkspace.openApplication` 激活机制，确保「收起全部」与「调出」100% 可靠生效。
  - **启动冷启动状态检测优化**：引入多阶段 (0.8s / 1.8s) 异步状态校验与 Bundle 路径容错匹配，彻底解决实例已启动但监控台检测滞后或判定为未启动的问题。
  - **防止重复创建窗口**：在激活已有实例时强制声明 `createsNewApplicationInstance = false`，杜绝点击调出时 Electron 偶发创建多余空白窗口。

此管理器更新不会自动升级副本或修改实例数据。
