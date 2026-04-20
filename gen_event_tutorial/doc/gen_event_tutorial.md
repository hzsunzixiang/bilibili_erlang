# gen_event 完全教程

## 目录

1. [概述](#1-概述)
2. [gen_event 架构模型](#2-gen_event-架构模型)
3. [基本用法：事件日志器](#3-基本用法事件日志器)
4. [回调函数详解](#4-回调函数详解)
5. [多处理器模式](#5-多处理器模式)
6. [处理器热替换 (swap_handler)](#6-处理器热替换-swap_handler)
7. [监督处理器 (add_sup_handler)](#7-监督处理器-add_sup_handler)
8. [实战案例：告警系统](#8-实战案例告警系统)
9. [gen_event vs gen_server](#9-gen_event-vs-gen_server)
10. [最佳实践与常见陷阱](#10-最佳实践与常见陷阱)
11. [快速参考](#11-快速参考)

---

## 1. 概述

### 什么是 gen_event？

`gen_event` 是 OTP 框架中的事件处理行为模式（behavior）。它实现了一个**事件管理器**
（Event Manager），可以动态地添加、删除和替换**事件处理器**（Event Handler）。

### 核心概念

与 `gen_server` 的一对一模型不同，`gen_event` 是一对多的**发布-订阅**模型：

```
                    ┌─────────────────────┐
  Event Source 1 ──>│                     │──> Handler A (logger)
  Event Source 2 ──>│   Event Manager     │──> Handler B (counter)
  Event Source 3 ──>│   (one process)     │──> Handler C (alarm)
                    │                     │──> Handler D (email)
                    └─────────────────────┘
```

关键特征：
- **一个进程，多个处理器**：Event Manager 是一个进程，所有 Handler 运行在同一进程中
- **动态添加/删除**：Handler 可以在运行时动态安装和卸载
- **热替换**：可以用 `swap_handler` 在不丢失状态的情况下替换 Handler
- **广播语义**：一个事件会被所有已安装的 Handler 处理

### 为什么需要 gen_event？

典型使用场景：
- **日志系统**：不同的 Handler 将日志写到不同目的地（文件、控制台、远程服务器）
- **告警系统**：OTP 的 `alarm_handler` 就是基于 gen_event
- **监控统计**：事件计数、性能指标收集
- **插件系统**：运行时动态加载/卸载功能模块

### gen_event 在 OTP 中的应用

OTP 自身大量使用 gen_event：
- `error_logger` / `logger` - 错误日志系统
- `alarm_handler` - SASL 告警处理
- Supervisor 的事件通知

---

## 2. gen_event 架构模型

### 2.1 与 gen_server 的对比

```
┌─────────────────────────────────────────────────────────────────┐
│                        gen_server                                │
│                                                                  │
│   Client ──call/cast──> [Process] ──callback──> Module           │
│                         (1 process, 1 callback module)           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        gen_event                                  │
│                                                                  │
│   Source ──notify──> [Process] ──callback──> Module A (State A)  │
│                                ──callback──> Module B (State B)  │
│                                ──callback──> Module C (State C)  │
│                         (1 process, N callback modules)          │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 内部结构

```
Event Manager Process
┌──────────────────────────────────────────────────┐
│  gen_event loop                                   │
│                                                   │
│  Handlers = [                                     │
│    {Module_A, Id_A, State_A, Supervised_A},       │
│    {Module_B, Id_B, State_B, Supervised_B},       │
│    {Module_C, Id_C, State_C, Supervised_C}        │
│  ]                                                │
│                                                   │
│  receive                                          │
│    {notify, Event} ->                             │
│      for each Handler:                            │
│        Handler:handle_event(Event, State)         │
│    {call, Handler, Request} ->                    │
│      Handler:handle_call(Request, State)          │
│    Info ->                                        │
│      for each Handler:                            │
│        Handler:handle_info(Info, State)           │
│  end                                              │
└──────────────────────────────────────────────────┘
```

### 2.3 Handler 标识

Handler 可以用两种方式标识：

```erlang
%% 方式1: 只用模块名 (同一模块只能添加一个实例)
gen_event:add_handler(Mgr, my_handler, Args).

%% 方式2: {Module, Id} 元组 (同一模块可以添加多个实例)
gen_event:add_handler(Mgr, {my_handler, instance1}, Args).
gen_event:add_handler(Mgr, {my_handler, instance2}, Args).
```

### 2.4 消息流转

```
                    notify(Mgr, Event)
  Source ─────────────────────────────────────────> Event Manager
                                                        │
                                              ┌─────────┼─────────┐
                                              ▼         ▼         ▼
                                          Handler A  Handler B  Handler C
                                          handle_event handle_event handle_event
                                              │         │         │
                                          {ok,State} {ok,State} {ok,State}


                    call(Mgr, Handler, Request)
  Client ─────────────────────────────────────────> Event Manager
                                                        │
                                                        ▼
                                                    Handler B (only)
                                                    handle_call
                                                        │
                                                    {ok, Reply, State}
  Client <──────────────────────────────────────────────┘
              Reply
```

---

## 3. 基本用法：事件日志器

> 源码文件：`src/event_logger.erl`

### 3.1 完整示例

```erlang
-module(event_logger).
-behaviour(gen_event).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%% init/1 - Initialize handler state
init({stdout}) ->
    {ok, #{output => stdout, count => 0}};
init({file, Filename}) ->
    {ok, Fd} = file:open(Filename, [write, append]),
    {ok, #{output => {file, Fd}, count => 0}}.

%% handle_event/2 - Handle async events
handle_event({Level, Message}, #{output := Output, count := Count} = State) ->
    Line = io_lib:format("[~p] ~s~n", [Level, Message]),
    write_output(Output, Line),
    {ok, State#{count := Count + 1}};
handle_event(_Event, State) ->
    {ok, State}.

%% handle_call/2 - Handle sync requests
handle_call(get_count, #{count := Count} = State) ->
    {ok, Count, State}.

%% terminate/2 - Cleanup
terminate(_Reason, #{output := {file, Fd}}) ->
    file:close(Fd), ok;
terminate(_Reason, _State) ->
    ok.
```

### 3.2 使用方式

```erlang
%% 1. Start event manager
{ok, Mgr} = gen_event:start_link({local, my_event_mgr}).

%% 2. Add handler
ok = gen_event:add_handler(my_event_mgr, event_logger, {stdout}).

%% 3. Send events (async - all handlers receive)
gen_event:notify(my_event_mgr, {info, "System started"}).
gen_event:notify(my_event_mgr, {error, "Connection lost"}).

%% 4. sync_notify - blocks until all handlers have processed
gen_event:sync_notify(my_event_mgr, {info, "Sync event"}).

%% 5. Query specific handler (sync)
{ok, Count} = gen_event:call(my_event_mgr, event_logger, get_count).

%% 6. Remove handler
gen_event:delete_handler(my_event_mgr, event_logger, normal).

%% 7. Stop event manager
gen_event:stop(my_event_mgr).
```

### 3.3 运行演示

```bash
$ cd src && make run_logger
```

---

## 4. 回调函数详解

### 4.1 init/1

```erlang
init(Args) ->
    {ok, State}           %% Normal initialization
  | {ok, State, hibernate} %% Init and hibernate
  | {error, Reason}       %% Initialization failed
```

**注意**：与 gen_server 不同，init 失败不会导致 Event Manager 崩溃，
只是该 Handler 不会被安装。

### 4.2 handle_event/2

处理 `notify/2` 和 `sync_notify/2` 发来的事件。

```erlang
handle_event(Event, State) ->
    {ok, NewState}                %% Continue
  | {ok, NewState, hibernate}     %% Continue, hibernate
  | {swap_handler, Args1, NewState, Handler2, Args2}  %% Swap to new handler
  | remove_handler                %% Remove this handler
```

**关键**：所有已安装的 Handler 都会收到每个事件。

### 4.3 handle_call/2

处理 `gen_event:call/3,4` 发来的同步请求。只有指定的 Handler 会收到。

```erlang
handle_call(Request, State) ->
    {ok, Reply, NewState}              %% Reply and continue
  | {ok, Reply, NewState, hibernate}   %% Reply, continue, hibernate
  | {swap_handler, Reply, Args1, NewState, Handler2, Args2}  %% Swap
  | {remove_handler, Reply}            %% Reply and remove
```

### 4.4 handle_info/2

处理发送到 Event Manager 进程的其他消息。所有 Handler 都会收到。

```erlang
handle_info(Info, State) ->
    {ok, NewState}                %% Continue
  | {ok, NewState, hibernate}     %% Continue, hibernate
  | {swap_handler, Args1, NewState, Handler2, Args2}  %% Swap
  | remove_handler                %% Remove this handler
```

### 4.5 terminate/2

Handler 被删除或 Event Manager 停止时调用。

```erlang
terminate(Reason, State) ->
    term().  %% Return value depends on context
```

**Reason 的值**：
- `stop` - Event Manager 正在停止
- `{stop, Reason}` - Event Manager 被要求停止
- `normal` / 自定义 - `delete_handler` 传入的 Args
- `{error, Term}` - Handler 回调返回了错误值
- `{error, {'EXIT', Reason}}` - Handler 回调崩溃

**重要**：当用于 `swap_handler` 时，terminate 的返回值会传递给新 Handler 的 init。

### 4.6 code_change/3

```erlang
code_change(OldVsn, State, Extra) ->
    {ok, NewState}.
```

---

## 5. 多处理器模式

> 源码文件：`src/multi_handler_demo.erl`

### 5.1 同一模块的多个实例

使用 `{Module, Id}` 形式可以安装同一模块的多个实例：

```erlang
%% Add 3 instances of the same handler module
ok = gen_event:add_handler(Mgr, {my_handler, error_filter},
                           #{level => error}).
ok = gen_event:add_handler(Mgr, {my_handler, all_events},
                           #{level => all}).
ok = gen_event:add_handler(Mgr, {my_handler, warning_filter},
                           #{level => warning}).

%% Query specific instance
{ok, Count} = gen_event:call(Mgr, {my_handler, error_filter}, get_count).

%% Delete specific instance
gen_event:delete_handler(Mgr, {my_handler, error_filter}, normal).
```

### 5.2 运行演示

```bash
$ make run_multi
```

---

## 6. 处理器热替换 (swap_handler)

> 源码文件：`src/swap_handler_demo.erl`

### 6.1 swap_handler 机制

`swap_handler` 允许在不丢失状态的情况下替换 Handler：

```
Old Handler                              New Handler
    │                                        │
    ▼                                        │
terminate({swap_to, stdout}, State)          │
    │                                        │
    │── returns TransferData ──────────────> │
    │                                        ▼
    │                              init({NewArgs, TransferData})
    │                                        │
    │                                        ▼
    │                              {ok, NewState}
```

### 6.2 使用方式

```erlang
%% Swap: old handler -> new handler
gen_event:swap_handler(
    Manager,
    {OldHandler, Args1},    %% OldHandler:terminate(Args1, State) -> TransferData
    {NewHandler, Args2}     %% NewHandler:init({Args2, TransferData}) -> {ok, NewState}
).
```

### 6.3 实际应用场景

- 日志输出从文件切换到控制台（保留计数器等状态）
- 升级 Handler 版本（保留业务状态）
- OTP 的 `alarm_handler` 就是通过 swap 来替换默认处理器

```erlang
%% OTP alarm_handler 的典型用法
gen_event:swap_handler(
    alarm_handler,
    {alarm_handler, swap},           %% Remove default handler
    {my_alarm_handler, MyArgs}       %% Install custom handler
).
```

### 6.4 运行演示

```bash
$ make run_swap
```

---

## 7. 监督处理器 (add_sup_handler)

> 源码文件：`src/sup_handler_demo.erl`

### 7.1 问题：Handler 崩溃怎么办？

普通 `add_handler` 添加的 Handler 如果崩溃，会被静默移除，没有任何通知。
这在生产环境中是不可接受的。

### 7.2 add_sup_handler 的作用

`add_sup_handler` 将 Handler 与调用进程关联：

```erlang
%% Add supervised handler
gen_event:add_sup_handler(Manager, Handler, Args).
```

当 Handler 被移除（无论是崩溃还是正常删除），调用进程会收到消息：

```erlang
{gen_event_EXIT, Handler, Reason}
```

### 7.3 崩溃恢复模式

```erlang
watcher_loop(Manager) ->
    receive
        {gen_event_EXIT, my_handler, Reason} ->
            io:format("Handler crashed: ~p, re-adding...~n", [Reason]),
            gen_event:add_sup_handler(Manager, my_handler, []),
            watcher_loop(Manager)
    end.
```

### 7.4 add_sup_handler vs add_handler

| 特性 | add_handler | add_sup_handler |
|------|-------------|-----------------|
| Handler 崩溃通知 | ❌ 静默移除 | ✅ 发送 gen_event_EXIT |
| 调用进程退出 | Handler 不受影响 | Handler 被移除 |
| 适用场景 | 临时/测试 | 生产环境 |

### 7.5 运行演示

```bash
$ make run_sup
```

---

## 8. 实战案例：告警系统

> 源码文件：`src/alarm_system.erl`

### 8.1 设计

一个类似 OTP `alarm_handler` 的告警管理系统：

```
                    ┌─────────────────────┐
  set_alarm() ─────>│                     │
  clear_alarm() ───>│   alarm_mgr         │──> alarm_system handler
  get_alarms() ────>│   (gen_event)       │      (maintains alarm list)
                    └─────────────────────┘
```

### 8.2 API 设计

```erlang
%% Start the alarm manager
alarm_system:start_link().

%% Set an alarm
alarm_system:set_alarm(cpu_high, "CPU usage above 90%").

%% Clear an alarm
alarm_system:clear_alarm(cpu_high).

%% Get all active alarms
{ok, Alarms} = alarm_system:get_alarms().
```

### 8.3 运行演示

```bash
$ make run_alarm
```

---

## 9. gen_event vs gen_server

### 9.1 何时用 gen_event？

| 场景 | gen_server | gen_event |
|------|-----------|-----------|
| 请求-响应模式 | ✅ | ❌ |
| 事件广播 | ❌ | ✅ |
| 动态订阅者 | ❌ | ✅ |
| 单一状态管理 | ✅ | ❌ |
| 多处理器/插件 | ❌ | ✅ |
| 处理器热替换 | ❌ | ✅ |

### 9.2 关键区别

```
gen_server:                          gen_event:
┌──────────┐                         ┌──────────┐
│ 1 process │                         │ 1 process │
│ 1 module  │                         │ N modules │
│ 1 state   │                         │ N states  │
│ call/cast │                         │ notify    │
└──────────┘                         └──────────┘
```

### 9.3 注意事项

- gen_event 的所有 Handler 运行在**同一个进程**中
- 一个 Handler 的长时间操作会阻塞其他 Handler
- 一个 Handler 崩溃不会影响其他 Handler（会被移除）
- `notify` 是异步的，`sync_notify` 会等待所有 Handler 处理完毕

---

## 10. 最佳实践与常见陷阱

### 10.1 最佳实践

1. **使用 add_sup_handler**：生产环境中始终使用监督处理器
2. **Handler 保持轻量**：避免在 handle_event 中做耗时操作
3. **处理未知事件**：总是添加 catch-all 子句
4. **利用 swap_handler**：需要升级 Handler 时使用，而非 delete + add
5. **notify vs sync_notify**：
   - `notify`：fire-and-forget，高吞吐
   - `sync_notify`：需要确保事件被处理完毕时使用

### 10.2 常见陷阱

#### 陷阱 1：Handler 崩溃被静默吞掉

```erlang
%% BAD: handler crashes silently
gen_event:add_handler(Mgr, my_handler, []).

%% GOOD: get notified on crash
gen_event:add_sup_handler(Mgr, my_handler, []).
```

#### 陷阱 2：阻塞其他 Handler

```erlang
%% BAD: blocks all other handlers
handle_event(Event, State) ->
    timer:sleep(5000),  %% All handlers are blocked!
    {ok, State}.

%% GOOD: spawn for heavy work
handle_event(Event, State) ->
    spawn(fun() -> heavy_processing(Event) end),
    {ok, State}.
```

#### 陷阱 3：忘记 swap_handler 的 terminate 返回值

```erlang
%% terminate must return transfer data when swapping
terminate({swap_to, _}, State) ->
    State;  %% This becomes TransferData for new handler's init
terminate(_Reason, _State) ->
    ok.     %% Normal termination
```

#### 陷阱 4：call 错误的 Handler ID

```erlang
%% If handler was added as {Module, Id}:
gen_event:add_handler(Mgr, {my_mod, inst1}, []).

%% Must use same form to call:
gen_event:call(Mgr, {my_mod, inst1}, request).  %% Correct
gen_event:call(Mgr, my_mod, request).           %% WRONG! bad_module error
```

---

## 11. 快速参考

### 11.1 Event Manager 函数

| 函数 | 说明 |
|------|------|
| `gen_event:start_link({local,N})` | 启动并本地注册 |
| `gen_event:start_link({global,N})` | 启动并全局注册 |
| `gen_event:start_link()` | 启动不注册 |
| `gen_event:start(...)` | 同上但不链接 |
| `gen_event:stop(Ref)` | 停止 Event Manager |

### 11.2 Handler 管理函数

| 函数 | 说明 |
|------|------|
| `add_handler(Mgr, Handler, Args)` | 添加 Handler |
| `add_sup_handler(Mgr, Handler, Args)` | 添加监督 Handler |
| `delete_handler(Mgr, Handler, Args)` | 删除 Handler |
| `swap_handler(Mgr, {H1,A1}, {H2,A2})` | 替换 Handler |
| `swap_sup_handler(Mgr, {H1,A1}, {H2,A2})` | 替换为监督 Handler |
| `which_handlers(Mgr)` | 列出所有 Handler |

### 11.3 事件发送函数

| 函数 | 类型 | 说明 |
|------|------|------|
| `notify(Mgr, Event)` | 异步 | 发送事件，立即返回 |
| `sync_notify(Mgr, Event)` | 同步 | 等待所有 Handler 处理完 |
| `call(Mgr, Handler, Request)` | 同步 | 向指定 Handler 发请求 |
| `call(Mgr, Handler, Request, Timeout)` | 同步 | 带超时 |

### 11.4 回调函数返回值速查

```
init/1:
  {ok, State} | {ok, State, hibernate} | {error, Reason}

handle_event/2:
  {ok, State}
  {ok, State, hibernate}
  {swap_handler, Args1, State, Handler2, Args2}
  remove_handler

handle_call/2:
  {ok, Reply, State}
  {ok, Reply, State, hibernate}
  {swap_handler, Reply, Args1, State, Handler2, Args2}
  {remove_handler, Reply}

handle_info/2:
  {ok, State}
  {ok, State, hibernate}
  {swap_handler, Args1, State, Handler2, Args2}
  remove_handler

terminate/2:
  term()  (return value used as TransferData in swap)

code_change/3:
  {ok, NewState}
```

### 11.5 源码文件列表

| 文件 | 说明 |
|------|------|
| `src/event_logger.erl` | 基本用法：事件日志器 |
| `src/event_counter.erl` | ETS 事件计数器 |
| `src/multi_handler_demo.erl` | 多处理器（同模块多实例） |
| `src/swap_handler_demo.erl` | 处理器热替换 |
| `src/alarm_system.erl` | 实战：告警管理系统 |
| `src/sup_handler_demo.erl` | 监督处理器与崩溃恢复 |

### 11.6 Makefile 命令

```bash
make compile     # Compile all .erl files
make run_logger  # Event logger demo (basic usage)
make run_counter # Event counter demo (ETS + handle_call)
make run_multi   # Multiple handlers demo
make run_swap    # Swap handler demo (hot-swap)
make run_alarm   # Alarm system demo (practical example)
make run_sup     # Supervised handler demo (add_sup_handler)
make run_all     # Run all demos sequentially
make clean       # Remove compiled files
make help        # Show available targets
```
