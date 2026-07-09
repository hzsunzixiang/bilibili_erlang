# Erlang/OTP 自顶向下教程规划

> 目标：面向已经掌握 Erlang 基础语法、想系统理解 OTP 工程结构的学习者。这个系列不从 `gen_server` 回调函数开始，而是从一个完整应用的运行形态开始：先看见 application、supervisor、进程树和运行时状态，再逐步拆解 application、supervisor、gen_server、gen_statem。

---

## 一、课程定位

这个系列解决的问题是：

1. Erlang 项目启动以后，系统里到底跑了什么？
2. application、supervisor、worker process 之间是什么关系？
3. 为什么 OTP 不是一组孤立模块，而是一套运行时工程结构？
4. 如何用 Observer 和 observer_cli 把 OTP 系统可视化？
5. 如何从可视化结果反推代码结构？

学习顺序采用自顶向下：

```text
Application
  -> Supervisor Tree
      -> Worker Process
          -> gen_server
          -> gen_statem
```

这样安排的原因是：初学者如果直接进入 `gen_server:init/1`、`handle_call/3`、`handle_cast/2`，很容易只记住回调函数列表，却不知道这些进程为什么存在、由谁启动、崩溃后由谁恢复、如何被观察和调试。

---

## 二、总学习路线

| 集数 | 标题 | 核心内容 | 目标目录 |
|------|------|----------|----------|
| 00 | OTP 可视化入口：Observer 和 observer_cli | 先看运行中的 Erlang 系统；建立 application、进程、监督树的第一印象 | `observer_tutorial/` |
| 01 | Application：OTP 系统的启动边界 | `.app` 文件、application callback、启动 supervisor | `application_tutorial/` |
| 02 | Supervisor：让进程按树形结构运行 | child spec、restart strategy、supervision tree | `supervisor_tutorial/` |
| 03 | gen_server：长期运行的状态进程 | call/cast/info、状态、同步与异步请求 | `gen_server_tutorial/` |
| 04 | gen_statem：显式状态机进程 | 状态、事件、状态转换、协议和业务流程建模 | `gen_statem_tutorial/` |
| 05 | 串起来：从代码到 Observer 再回到代码 | 运行完整 demo，用 Observer 对照 application、supervisor、worker | `full_otp_app/` |

---

## 三、第 00 集：先看见 Erlang 系统

### 3.1 为什么先讲 Observer

Erlang 很有特色的一点是：运行时不是黑盒。

启动一个 OTP 应用以后，我们可以直接看到：

- 当前节点有哪些 application。
- 每个 application 下面有哪些 supervisor。
- supervisor 下面启动了哪些 worker。
- 每个进程的 Pid、注册名、当前函数、内存、消息队列长度、reductions。
- 双击进程以后，可以查看进程信息、消息、字典、调用栈、状态。
- ETS 表可以通过 Table Viewer 查看。

这比单纯讲代码更直观。先让学习者看到“系统已经是一棵活的进程树”，后面讲 application 和 supervisor 才有抓手。

### 3.2 GUI 工具：Observer

在 Erlang shell 中启动：

```erlang
observer:start().
```

建议演示页面：

| 页面 | 演示重点 |
|------|----------|
| System | 当前节点、调度器、内存、进程数量的整体状态 |
| Applications | application 列表和 supervision tree |
| Processes | 所有进程列表，重点看 Pid、Name、Reds、Memory、MsgQ、Current Function |
| Process Information | 双击进程后查看 initial call、current function、links、monitors |
| Messages | 查看进程消息队列 |
| Dictionary | 查看进程字典 |
| Stack Trace | 查看当前调用栈 |
| State | 查看 OTP behaviour 进程状态 |
| Table Viewer | 查看 ETS/DETS 表 |

这一集不追求讲完所有按钮，只讲一个主线：

```text
Applications tab
  -> 选中自己的 application
  -> 看到 supervisor tree
  -> 切到 Processes tab
  -> 找到对应 worker process
  -> 双击进程
  -> 查看 Process Information / State
```

### 3.3 命令行工具：observer_cli

Observer 依赖图形环境，远程服务器、容器、SSH 环境里不一定能打开。命令行方式可以使用 observer_cli。

安装方式取决于项目工具链，常见方式是作为 rebar3 依赖或 escript 使用。课程里不需要把安装细节展开太长，重点讲它的价值：

- 在终端里查看节点运行状态。
- 查看进程列表和内存占用。
- 查看 application、scheduler、ETS、网络等信息。
- 适合远程排查线上节点。

建议表达：

```text
Observer 更适合本地教学和可视化理解。
observer_cli 更适合服务器和命令行环境。
两者目的相同：让我们观察正在运行的 BEAM 系统。
```

### 3.4 第 00 集截图清单

建议手工截图，不建议一开始做 GUI 自动点击脚本。

| 截图 | 内容 | 用途 |
|------|------|------|
| observer_01_system.png | System 页面 | 展示 BEAM 节点整体运行状态 |
| observer_02_applications.png | Applications 页面 | 展示 application 列表 |
| observer_03_supervision_tree.png | 选中 demo application | 展示 supervisor tree |
| observer_04_processes.png | Processes 页面 | 展示进程列表 |
| observer_05_process_info.png | 双击 worker 进程 | 展示进程详情 |
| observer_06_process_state.png | State tab | 展示 OTP 进程状态 |
| observer_07_table_viewer.png | Table Viewer | 如果 demo 使用 ETS/DETS，用于展示表 |
| observer_08_observer_cli.png | observer_cli 终端界面 | 对比 GUI 和命令行观察方式 |

---

## 四、第 01 集：Application

### 4.1 本集目标

让学习者理解：application 是 OTP 系统的启动边界，不只是一个配置文件。

需要讲清楚：

- `.app` 文件描述应用元数据。
- `application` behaviour 提供启动和停止回调。
- `start/2` 通常启动顶层 supervisor。
- application 启动后，真正长期运行的是 supervisor 和 worker process。
- Observer 的 Applications 页面可以看到 application 对应的运行结构。

### 4.2 推荐讲解顺序

1. 从 Observer Applications 页面看到 `full_otp_app`。
2. 回到代码，看 `.app.src` 或 `.app` 文件。
3. 看 application callback module。
4. 解释 `start(_Type, _Args) -> supervisor:start_link(...)`。
5. 回到 Observer，看 supervisor tree 已经出现。

### 4.3 关键观念

application 不是“业务逻辑入口函数”，而是 OTP release 里一个可启动、可停止、可管理的应用单元。

---

## 五、第 02 集：Supervisor

### 5.1 本集目标

让学习者理解：supervisor 负责启动、组织和恢复子进程。

需要讲清楚：

- supervisor 本身也是一个进程。
- child spec 描述子进程怎么启动、怎么重启、是什么类型。
- restart strategy 决定一个 child 崩溃后如何影响兄弟进程。
- supervision tree 是 Erlang 容错思想的核心结构。

### 5.2 推荐讲解顺序

1. 从 Observer 看到 supervisor tree。
2. 对照 `supervisor:init/1` 返回值。
3. 讲 child spec 的 `id`、`start`、`restart`、`shutdown`、`type`、`modules`。
4. 人为让 worker 崩溃。
5. 回到 Observer，观察 Pid 变化和 supervisor 恢复行为。

### 5.3 关键观念

Supervisor 不是 try/catch。它不负责阻止错误发生，而是定义错误发生以后如何恢复系统结构。

---

## 六、第 03 集：gen_server

### 6.1 本集目标

让学习者理解：gen_server 是最常用的长期运行状态进程。

需要讲清楚：

- 它是一个 worker process。
- 它通常由 supervisor 启动。
- `init/1` 初始化状态。
- `handle_call/3` 处理同步请求。
- `handle_cast/2` 处理异步请求。
- `handle_info/2` 处理普通消息。
- `State` 是进程内部状态，不是全局变量。
- Observer 可以查看进程的 current function、message queue、state。

### 6.2 推荐讲解顺序

1. 从 supervisor tree 里找到一个 worker。
2. 在 Processes 页面找到对应进程。
3. 双击进程，查看 Process Information。
4. 切到 State 页面，看 gen_server 状态。
5. 回到代码讲 `gen_server` callback。
6. 用 `gen_server:call/2` 和 `gen_server:cast/2` 触发状态变化。
7. 再回到 Observer 验证状态变化。

### 6.3 关键观念

gen_server 不是“类”，也不是“线程封装”。它是一个有标准消息协议、标准调试接口、标准生命周期的 OTP 进程。

---

## 七、第 04 集：gen_statem

### 7.1 本集目标

让学习者理解：gen_statem 适合显式状态机，而不是所有状态进程都塞进 gen_server。

需要讲清楚：

- gen_server 适合一般状态服务。
- gen_statem 适合状态转换本身就是业务核心的场景。
- 状态机有当前状态、事件、状态数据、转换动作。
- `state_functions` 和 `handle_event_function` 是两种组织方式。
- timeout、postpone、next_event 等机制是状态机表达能力的一部分。

### 7.2 推荐讲解顺序

1. 用交通灯、门锁或连接协议引入状态机。
2. 在 Observer 里看到它仍然是一个普通 BEAM 进程。
3. 回到代码讲 `callback_mode/0`。
4. 演示状态转换。
5. 在 Observer State 页面查看当前状态和数据。
6. 对比 gen_server：什么时候该用 gen_server，什么时候该用 gen_statem。

### 7.3 关键观念

gen_statem 的重点不是“比 gen_server 更高级”，而是当业务天然有状态转换图时，它能让代码结构更贴近问题本身。

---

## 八、最终串联 Demo

建议准备一个完整 OTP demo，名字可以叫 `full_otp_app`。

### 8.1 Demo 结构

```text
full_otp_app
  -> full_otp_sup
      -> kv_server        gen_server
      -> traffic_light    gen_statem
      -> event_bus        可选 gen_event 或 gen_server
      -> data_store       可选 ETS/DETS 管理进程
```

### 8.2 演示主线

1. `rebar3 shell --sname application_demo` 启动节点。
2. `application:ensure_all_started(full_otp_app).` 启动应用。
3. `observer:start().` 打开 Observer。
4. Applications 页面查看 `full_otp_app`。
5. 展开 supervision tree。
6. Processes 页面找到 `kv_server` 或 `traffic_light`。
7. 双击进程查看 Process Information。
8. 操作业务 API，让状态变化。
9. 回到 Observer 查看 State。
10. 使用 observer_cli 做命令行对照。

### 8.3 课程闭环

这一集要让学习者形成一个完整闭环：

```text
代码定义 application
  -> application 启动 supervisor
      -> supervisor 启动 worker
          -> worker 使用 gen_server/gen_statem 实现行为
              -> Observer 观察运行中的进程结构和状态
```

---

## 九、后续文档拆分建议

当前文档作为总纲。后续可以逐步拆成：

```text
bilibili_erlang/
  otp_top_down_tutorial_plan.md
  observer_tutorial/
    doc/
      observer_tutorial.md
      images/
    src/
  application_tutorial/
    doc/
    src/
  supervisor_tutorial/
    doc/
    src/
  gen_server_tutorial/
    doc/
    src/
  gen_statem_tutorial/
    doc/
    src/
  full_otp_app/
    doc/
    src/
```

---

## 十、制作建议

### 10.1 先写 Markdown

先写 Markdown 是合理的。这个阶段重点是把讲解主线、代码顺序、截图清单定下来。等内容稳定后，再转换成 beamer TeX。

### 10.2 Observer 截图策略

建议手工操作、窗口截图：

- GUI 教程截图重视清晰和可控，手工更稳。
- 不建议一开始做自动点击脚本。
- 可以固定窗口大小和截图命名。
- 后期如果截图很多，再考虑用 `screencapture` 半自动保存。

### 10.3 每集都保留三个视角

每集建议固定三段式：

```text
先看运行时现象
  -> 再看代码结构
      -> 最后回到 Observer 验证
```

这样可以避免 OTP 教程变成回调函数背诵。
