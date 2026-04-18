# gen_server 完全教程

## 目录

1. [概述](#1-概述)
2. [从零开始：纯 Erlang 进程实现 Client-Server](#2-从零开始纯-erlang-进程实现-client-server)
3. [抽象通用模式：自定义 Generic Server](#3-抽象通用模式自定义-generic-server)
4. [OTP gen_server 行为模式](#4-otp-gen_server-行为模式)
5. [gen_server 回调函数详解](#5-gen_server-回调函数详解)
6. [进阶用法](#6-进阶用法)
7. [进程注册方式](#7-进程注册方式)
8. [分布式节点通信](#8-分布式节点通信)
9. [最佳实践与常见陷阱](#9-最佳实践与常见陷阱)
10. [快速参考](#10-快速参考)

---

## 1. 概述

### 什么是 gen_server？

`gen_server` 是 OTP 框架中最核心的行为模式（behavior）之一。它将 Erlang 中常见的
客户端-服务器（Client-Server）模式抽象为一个通用的库模块，开发者只需实现回调函数
即可获得一个健壮的并发服务器。

### 为什么需要 gen_server？

在 Erlang 中，许多不同的进程虽然解决的是不同的问题，但却遵循着相似的设计模式：

```
┌─────────────┐                    ┌─────────────┐
│   Client    │  ── request ──>    │   Server    │
│             │  <── reply ───     │  (process)  │
└─────────────┘                    └─────────────┘
```

这些模式包括：
- 启动和初始化服务器进程
- 发送同步/异步请求
- 维护进程状态
- 处理错误和终止
- 热代码升级

OTP 将这些通用部分提取出来，封装为 `gen_server` 行为模式库。

### 架构图

```
┌──────────────────────────────────────────────────────┐
│                    gen_server                         │
│  ┌────────────────────────────────────────────────┐  │
│  │           Generic Part (OTP Library)            │  │
│  │  - Process spawning & registration              │  │
│  │  - Message receiving loop                       │  │
│  │  - Timeout handling                             │  │
│  │  - Error handling & crash reports               │  │
│  │  - sys module integration                       │  │
│  │  - Hot code upgrade support                     │  │
│  └────────────────────────────────────────────────┘  │
│                        │                              │
│                   Callbacks                           │
│                        │                              │
│  ┌────────────────────────────────────────────────┐  │
│  │          Specific Part (Your Module)            │  │
│  │  - init/1           (initialization)            │  │
│  │  - handle_call/3    (sync requests)             │  │
│  │  - handle_cast/2    (async requests)            │  │
│  │  - handle_info/2    (other messages)            │  │
│  │  - terminate/2      (cleanup)                   │  │
│  │  - code_change/3    (hot upgrade)               │  │
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

---

## 2. 从零开始：纯 Erlang 进程实现 Client-Server

> 源码文件：`src/frequency_raw.erl`

在使用 gen_server 之前，我们先用纯 Erlang 进程实现一个频率分配服务器，理解底层原理。

### 2.1 问题描述

模拟一个移动通信基站的频率分配器：
- 有一组可用频率 `[10, 11, 12, 13, 14, 15]`
- 客户端可以申请（allocate）一个频率
- 使用完毕后归还（deallocate）频率

### 2.2 代码结构

```erlang
-module(frequency_raw).
-export([start/0, stop/0, allocate/0, deallocate/1]).
-export([init/0, demo/0]).

%% Start: spawn a process and register it
start() ->
    register(frequency_raw, spawn(frequency_raw, init, [])).

%% Client sends request and waits for reply
call(Message) ->
    frequency_raw ! {request, self(), Message},
    receive
        {reply, Reply} -> Reply
    end.

%% Server main loop
loop(Frequencies) ->
    receive
        {request, Pid, allocate} ->
            {NewFrequencies, Reply} = allocate(Frequencies, Pid),
            reply(Pid, Reply),
            loop(NewFrequencies);
        {request, Pid, {deallocate, Freq}} ->
            NewFrequencies = deallocate(Frequencies, Freq),
            reply(Pid, ok),
            loop(NewFrequencies);
        {request, Pid, stop} ->
            reply(Pid, ok)
    end.
```

### 2.3 运行演示

```bash
$ cd src && make run_raw
```

输出：
```
Allocated frequency: 10
Allocated frequency: 11
Deallocated frequency: 10
Re-allocated frequency: 10
Server stopped.
```

### 2.4 问题分析

这个实现虽然能工作，但存在以下问题：

| 问题 | 说明 |
|------|------|
| 代码耦合 | 通用的消息收发逻辑和业务逻辑混在一起 |
| 无错误处理 | 服务器崩溃时客户端会永远阻塞 |
| 无超时机制 | 没有请求超时保护 |
| 不可重用 | 每个服务器都要重写消息循环 |
| 无调试支持 | 没有 sys 模块集成 |

---

## 3. 抽象通用模式：自定义 Generic Server

> 源码文件：`src/my_server.erl` + `src/frequency_generic.erl`

### 3.1 分离通用与专用代码

将代码分为两部分：

```
┌─────────────────────┐     ┌─────────────────────┐
│   my_server.erl     │     │ frequency_generic.erl│
│   (Generic Part)    │     │   (Specific Part)    │
│                     │     │                      │
│  start/2            │     │  init/1              │
│  stop/1             │◄────│  handle/2            │
│  call/2             │     │  terminate/1         │
│  loop/2             │     │                      │
└─────────────────────┘     └──────────────────────┘
```

### 3.2 通用服务器模块 (my_server.erl)

```erlang
-module(my_server).
-export([start/2, stop/1, call/2]).

start(Name, Mod) ->
    register(Name, spawn(my_server, init, [Name, Mod])).

call(Name, Msg) ->
    Name ! {request, self(), Msg},
    receive {reply, Reply} -> Reply end.

%% Generic loop - dispatches to callback module
loop(Mod, State) ->
    receive
        {request, From, Msg} ->
            {NewState, Reply} = Mod:handle(Msg, State),
            reply(From, Reply),
            loop(Mod, NewState);
        {stop, From} ->
            Reply = Mod:terminate(State),
            reply(From, Reply)
    end.
```

### 3.3 专用回调模块 (frequency_generic.erl)

```erlang
-module(frequency_generic).

%% Callback: initialize state
init(_Args) ->
    {get_frequencies(), []}.

%% Callback: handle requests
handle({allocate, Pid}, Frequencies) ->
    allocate(Frequencies, Pid);
handle({deallocate, Freq}, Frequencies) ->
    {deallocate(Frequencies, Freq), ok}.

%% Callback: cleanup
terminate(Frequencies) ->
    io:format("Terminating. State: ~p~n", [Frequencies]),
    ok.
```

### 3.4 运行演示

```bash
$ make run_generic
```

输出：
```
Allocated: 10
Allocated: 11
Deallocated: 10
Frequency server terminating. State: {[10,12,13,14,15],[{11,<0.9.0>}]}
```

### 3.5 这就是 OTP 行为模式的本质！

> **理解了这个分离过程，就理解了 Erlang 的行为模式。**
> 本质上就是把代码分为通用的和专用的两部分，然后把通用的部分打包为可重用的库。
> —— 《Erlang and OTP in Action》

---

## 4. OTP gen_server 行为模式

> 源码文件：`src/frequency_otp.erl`

### 4.1 从自定义到 OTP

OTP 的 `gen_server` 就是我们 `my_server` 的工业级版本，额外提供了：

| 特性 | my_server | gen_server |
|------|-----------|------------|
| 同步调用 (call) | ✅ | ✅ |
| 异步调用 (cast) | ❌ | ✅ |
| 超时机制 | ❌ | ✅ |
| 错误处理 | ❌ | ✅ |
| sys 模块集成 | ❌ | ✅ |
| 热代码升级 | ❌ | ✅ |
| 进程链接 | ❌ | ✅ |
| format_status | ❌ | ✅ |

### 4.2 声明行为模式

```erlang
-module(frequency_otp).
-behaviour(gen_server).  %% 声明使用 gen_server 行为模式
```

### 4.3 启动服务器

```erlang
%% start_link: 启动并链接到调用进程
start_link() ->
    gen_server:start_link({local, frequency_otp}, ?MODULE, [], []).
%%                        ^^^^^^^^^^^^^^^^^^^    ^^^^^^  ^^  ^^
%%                        注册方式               回调模块 参数 选项
```

启动函数对比：

| 函数 | 链接 | 用途 |
|------|------|------|
| `start_link/3,4` | ✅ | 生产环境，配合 supervisor |
| `start/3,4` | ❌ | 开发测试，独立运行 |

### 4.4 客户端 API

```erlang
%% 同步调用 - 等待服务器回复
allocate() ->
    gen_server:call(frequency_otp, {allocate, self()}).

%% 异步调用 - 发送后立即返回
deallocate(Frequency) ->
    gen_server:cast(frequency_otp, {deallocate, Frequency}).

%% 异步停止
stop() ->
    gen_server:cast(frequency_otp, stop).
```

### 4.5 消息流转图

```
                    gen_server:call(Name, Request)
  Client ─────────────────────────────────────────────> gen_server
    │                                                      │
    │                                              handle_call(Request,
    │                                                From, State)
    │                                                      │
    │                                              {reply, Reply,
    │                                                NewState}
    │ <─────────────────────────────────────────────────── │
    │              Reply                                   │
    │                                                      │
                    gen_server:cast(Name, Msg)
  Client ─────────────────────────────────────────────> gen_server
    │  (no reply)                                          │
    │                                              handle_cast(Msg,
    │                                                State)
    │                                                      │
    │                                              {noreply, NewState}
    │                                                      │
    │                                                      │
                    Pid ! SomeMessage
  Anyone ─────────────────────────────────────────────> gen_server
                                                           │
                                                   handle_info(Msg,
                                                     State)
                                                           │
                                                   {noreply, NewState}
```

### 4.6 运行演示

```bash
$ make run_otp
```

输出：
```
=== OTP gen_server Frequency Server Demo ===

[frequency_otp] Server initialized. PID=<0.83.0>
Server started. PID=<0.83.0>

[frequency_otp] Received info message: <<"Hello, this is a plain message">>
Allocated: 10
Allocated: 11
Allocated: 12
Deallocated: 11
Re-allocated: 11

Server status: {status,<0.83.0>,
                   {module,gen_server},
                   [[{'$initial_call',{frequency_otp,init,1}},
                     {'$ancestors',[<0.9.0>]}],
                    running,<0.9.0>,[],
                    [{header,"Status for generic server frequency_otp"},
                     {data,[{"Status",running},
                            {"Parent",<0.9.0>},
                            {"Logged events",[]}]},
                     {data,[{"State",
                             {{available,[13,14,15]},
                              {allocated,[{11,<0.9.0>},
                                          {12,<0.9.0>},
                                          {10,<0.9.0>}]}}}]}]]}

Stopping server...
[frequency_otp] Terminating. Reason=normal
  Free frequencies: [13,14,15]
  Allocated frequencies: [{11,<0.9.0>},{12,<0.9.0>},{10,<0.9.0>}]

=== Demo Complete ===
```

---

## 5. gen_server 回调函数详解

### 5.1 init/1

```erlang
init(Args) ->
    {ok, State}              %% 正常启动
  | {ok, State, Timeout}     %% 启动并设置超时
  | {ok, State, hibernate}   %% 启动并休眠（节省内存）
  | {stop, Reason}           %% 启动失败
  | ignore                   %% 忽略启动
```

示例：
```erlang
init(_Args) ->
    Frequencies = {get_frequencies(), []},
    {ok, Frequencies}.
```

### 5.2 handle_call/3

处理 `gen_server:call/2,3` 发来的同步请求。

```erlang
handle_call(Request, From, State) ->
    {reply, Reply, NewState}              %% 回复并继续
  | {reply, Reply, NewState, Timeout}     %% 回复，设超时
  | {reply, Reply, NewState, hibernate}   %% 回复，休眠
  | {noreply, NewState}                   %% 不回复（需手动 reply）
  | {noreply, NewState, Timeout}          %% 不回复，设超时
  | {stop, Reason, Reply, NewState}       %% 回复后停止
  | {stop, Reason, NewState}              %% 停止（不回复）
```

`From` 参数是 `{Pid, Tag}` 元组，可用于 `gen_server:reply/2`。

### 5.3 handle_cast/2

处理 `gen_server:cast/2` 发来的异步请求。

```erlang
handle_cast(Msg, State) ->
    {noreply, NewState}              %% 继续
  | {noreply, NewState, Timeout}     %% 继续，设超时
  | {noreply, NewState, hibernate}   %% 继续，休眠
  | {stop, Reason, NewState}         %% 停止
```

### 5.4 handle_info/2

处理所有非 call/cast 的消息（如 `Pid ! Msg`、系统消息等）。

```erlang
handle_info(Info, State) ->
    {noreply, NewState}              %% 继续
  | {noreply, NewState, Timeout}     %% 继续，设超时
  | {stop, Reason, NewState}         %% 停止
```

常见的 Info 消息：
- `timeout` - 超时触发
- `{'EXIT', Pid, Reason}` - 链接进程退出
- `{'DOWN', Ref, process, Pid, Reason}` - 监视的进程退出
- 任何用 `!` 发送的普通消息

### 5.5 terminate/2

服务器即将终止时调用。

```erlang
terminate(Reason, State) ->
    ok.  %% 返回值被忽略
```

**注意**：只有在以下情况下 `terminate/2` 才会被调用：
- 回调函数返回 `{stop, ...}`
- 进程收到 EXIT 信号且设置了 `process_flag(trap_exit, true)`

### 5.6 code_change/3

热代码升级时调用。

```erlang
code_change(OldVsn, State, Extra) ->
    {ok, NewState}.
```

### 5.7 format_status/2 (可选)

自定义 `sys:get_status/1` 的输出，可用于隐藏敏感信息。

```erlang
format_status(_Opt, [_ProcDict, {Available, Allocated}]) ->
    {data, [{"State", {{available, Available},
                       {allocated, Allocated}}}]}.
```

---

## 6. 进阶用法

### 6.1 显式回复 (gen_server:reply/2)

> 源码文件：`src/frequency_reply.erl`

通常 `handle_call` 通过 `{reply, Reply, NewState}` 回复客户端。但有时你需要：
- 先回复客户端，再做耗时操作
- 在不同的进程中回复
- 条件性回复

```erlang
handle_call({allocate, Pid}, From, Frequencies) ->
    {NewFrequencies, Reply} = allocate(Frequencies, Pid),
    %% Explicitly reply - client unblocks immediately
    gen_server:reply(From, Reply),
    %% Do post-reply work (client already got the response)
    io:format("Post-reply work: From=~p~n", [From]),
    %% Return noreply since we already replied
    {noreply, NewFrequencies}.
```

```bash
$ make run_reply
```

输出：
```
=== Explicit Reply Demo ===

[frequency_reply] Post-reply work: From={<0.9.0>,
                                         [alias|#Ref<...>]}
Client got reply: 10
[frequency_reply] Post-reply work: From={<0.9.0>,
                                         [alias|#Ref<...>]}
Client got reply: 11
[frequency_reply] Terminating: normal

=== Demo Complete ===
```

### 6.2 超时机制 (Timeout)

> 源码文件：`src/timeout_demo.erl`

gen_server 支持在 init 和各个 handle_* 回调中设置超时：

```erlang
%% init 中设置超时
init(Timeout) ->
    {ok, #{timeout => Timeout, count => 0}, Timeout}.
%%                                          ^^^^^^^^
%%                                          超时毫秒数

%% 超时触发时调用 handle_info
handle_info(timeout, #{timeout := Timeout, count := Count} = State) ->
    io:format("Timeout #~p fired!~n", [Count + 1]),
    {noreply, State#{count := Count + 1}, Timeout}.
%%                                        ^^^^^^^^
%%                                        重新设置超时
```

**重要**：每次收到任何消息都会重置超时计时器！

```bash
$ make run_timeout
```

输出（约15秒）：
```
=== Timeout Demo ===

Starting server with 2-second timeout...
Waiting 5 seconds for timeouts...
[timeout_demo] Timeout #1 fired at second :XX
[timeout_demo] Timeout #2 fired at second :XX

Sending ping (resets timer)...
[timeout_demo] Ping received! Timer reset.
[timeout_demo] Timeout #3 fired at second :XX

Pausing timeout...
[timeout_demo] Paused. No more timeouts.
Waiting 4 seconds (no timeout should fire)...

Resuming timeout...
[timeout_demo] Resumed with timeout=2000 ms
[timeout_demo] Timeout #4 fired at second :XX

=== Demo Complete ===
```

### 6.3 Call 超时与 start_link vs start

> 源码文件：`src/call_timeout_demo.erl`

#### gen_server:call 的超时

```erlang
%% 默认 5 秒超时
gen_server:call(Server, Request).

%% 自定义超时
gen_server:call(Server, Request, Timeout).

%% 永不超时
gen_server:call(Server, Request, infinity).
```

**关键点**：超时时，**客户端崩溃**，但**服务器继续运行**！

#### start_link vs start

| | start_link | start |
|---|---|---|
| 链接 | ✅ 与调用者链接 | ❌ 不链接 |
| 调用者崩溃 | 服务器也崩溃 | 服务器不受影响 |
| 服务器崩溃 | 调用者收到 EXIT | 调用者不受影响 |
| 用途 | 生产环境 (配合 supervisor) | 开发测试 |

```bash
$ make run_call_timeout
```

输出：
```
=== Call Timeout Demo ===

--- Demo 1: Normal call (1 second sleep, default 5s timeout) ---
[call_timeout] Server started. PID=<0.83.0>
[call_timeout] Sleeping 1000 ms...
[call_timeout] Woke up after 1000 ms
Call succeeded!

--- Demo 2: Custom timeout (2s sleep, 1s timeout) ---
[call_timeout] Server started. PID=<0.84.0>
[call_timeout] Sleeping 2000 ms...
Caught timeout! Client crashed but server is alive.
Server still running? true

--- Demo 3: Server still works after client timeout ---
[call_timeout] Sleeping 100 ms...
[call_timeout] Woke up after 100 ms
Server responded normally!

=== Demo Complete ===
```

---

## 7. 进程注册方式

> 源码文件：`src/kv_store.erl`

gen_server 支持多种进程注册方式：

### 7.1 本地注册 {local, Name}

```erlang
gen_server:start_link({local, my_server}, ?MODULE, [], []).
%% 只在当前节点可见
%% 通过名字调用: gen_server:call(my_server, Request)
```

### 7.2 全局注册 {global, Name}

```erlang
gen_server:start_link({global, my_server}, ?MODULE, [], []).
%% 在所有连接的节点上可见
%% 通过全局名调用: gen_server:call({global, my_server}, Request)
```

### 7.3 不注册（使用 PID）

```erlang
{ok, Pid} = gen_server:start_link(?MODULE, [], []).
%% 只能通过 PID 调用: gen_server:call(Pid, Request)
%% 可以启动多个实例！
```

### 7.4 远程节点调用 {Name, Node}

```erlang
%% 调用远程节点上的本地注册进程
gen_server:call({my_server, 'node1@hostname'}, Request).
```

### 7.5 server_ref 完整类型

```erlang
server_ref() =
    pid()                                    %% 直接用 PID
  | atom()                                   %% 本地注册名
  | {Name :: atom(), Node :: atom()}         %% 远程节点的本地注册名
  | {global, GlobalName :: term()}           %% 全局注册名
  | {via, RegMod :: module(), ViaName :: term()}  %% 自定义注册模块
```

```bash
$ make run_kv_local
$ make run_kv_unnamed
```

---

## 8. 分布式节点通信

> 源码文件：`src/distributed_demo.erl`

### 8.1 本地 PID vs 远程 PID

这是理解分布式 Erlang 的关键：

```
本地进程 PID:  <0.89.0>      ← 第一个数字是 0
远程进程 PID:  <9914.89.0>   ← 第一个数字 > 0，表示远程节点
```

### 8.2 实际演示

**Terminal 1 (node1)：启动服务器**
```bash
$ cd src
$ erl -sname node1 -setcookie demo
(node1@HOSTNAME)1> distributed_demo:start_link().
[distributed_demo] Started on node='node1@HOSTNAME', PID=<0.89.0>
{ok,<0.89.0>}
(node1@HOSTNAME)2> distributed_demo:store(greeting, hello_from_node1).
ok
```

**Terminal 2 (node2)：连接并远程调用**
```bash
$ cd src
$ erl -sname node2 -setcookie demo
(node2@HOSTNAME)1> net_adm:ping('node1@HOSTNAME').
pong
(node2@HOSTNAME)2> distributed_demo:remote_get_info('node1@HOSTNAME').
```

实际运行结果：
```
#{caller_node => 'distnode2@ERICKSUN-MC1',
  caller_pid => <0.9.0>,
  connected_nodes => ['distnode2@ERICKSUN-MC1'],
  is_remote_call => true,
  server_node => 'distnode1@ERICKSUN-MC1',
  server_pid => <9914.89.0>,        ← 注意！远程 PID
  uptime_seconds => 1}
```

### 8.3 PID 差异图解

```
  Node1 (distnode1@ERICKSUN-MC1)          Node2 (distnode2@ERICKSUN-MC1)
  ┌─────────────────────────┐             ┌─────────────────────────┐
  │                         │             │                         │
  │  Server PID: <0.89.0>   │◄── call ───│  看到的 PID: <9914.89.0>│
  │  (本地视角: 0开头)       │── reply ──►│  (远程视角: 9914开头)    │
  │                         │             │                         │
  │  Caller PID: <9914.9.0> │             │  Caller PID: <0.9.0>   │
  │  (远程视角: 9914开头)    │             │  (本地视角: 0开头)      │
  │                         │             │                         │
  └─────────────────────────┘             └─────────────────────────┘
```

### 8.4 全局注册的分布式场景

```bash
# Terminal 1
$ erl -sname apple -setcookie test
(apple@host)1> kv_store:start_link_global().
{ok,<0.89.0>}

# Terminal 2
$ erl -sname pear -setcookie test
(pear@host)1> net_adm:ping('apple@host').
pong
(pear@host)2> global:whereis_name(kv_store_global).
<9435.89.0>                    %% 远程 PID！
(pear@host)3> kv_store:put_global(key1, value1).
ok
(pear@host)4> kv_store:get_all_global().
#{key1 => value1}

# 再次启动会失败（全局唯一）
(pear@host)5> kv_store:start_link_global().
{error,{already_started,<9435.89.0>}}
```

### 8.5 monitor_node 监视远程节点

```erlang
%% Monitor a remote node
monitor_node(Node, true),
{server, Node} ! {self(), Msg},
receive
    {ok, Resp} ->
        monitor_node(Node, false),
        handle_response(Resp);
    {nodedown, Node} ->
        handle_node_down()
end.
```

---

## 9. 最佳实践与常见陷阱

### 9.1 最佳实践

1. **始终使用 start_link**：在生产环境中，gen_server 应该始终通过 supervisor 启动，使用 `start_link`。

2. **保持 handle_call 快速**：默认 5 秒超时，长时间操作应该用 cast 或 spawn 子进程。

3. **合理使用 call vs cast**：
   - `call`：需要返回值、需要确认操作完成
   - `cast`：不需要返回值、fire-and-forget

4. **handle_info 处理未知消息**：总是添加一个 catch-all 子句。

5. **terminate 中做清理**：释放资源、关闭连接等。

6. **使用 format_status 隐藏敏感信息**：密码、token 等不应出现在崩溃日志中。

### 9.2 常见陷阱

#### 陷阱 1：在 shell 中使用 start_link

```erlang
%% Shell 进程和 gen_server 链接
%% 如果 gen_server 崩溃，shell 也会崩溃（然后重启）
1> gen_server:start_link({local, my}, my_mod, [], []).
{ok,<0.83.0>}
2> gen_server:call(my, crash).
** exception exit: ...
3> self().
<0.88.0>   %% Shell 进程已经变了！
```

#### 陷阱 2：call 超时后的残留消息

```erlang
%% 客户端超时后，服务器的回复仍然会发送
%% 这个回复会留在客户端的消息队列中
try
    gen_server:call(Server, Request, 1000)
catch
    exit:{timeout, _} ->
        %% 服务器可能稍后才回复，消息会留在队列中
        %% 需要 flush 或者使用 alias（OTP 24+）
        ok
end.
```

#### 陷阱 3：在 handle_call 中调用自己

```erlang
%% 死锁！gen_server 是单进程，不能在处理消息时调用自己
handle_call(request1, _From, State) ->
    Result = gen_server:call(self(), request2),  %% DEADLOCK!
    {reply, Result, State}.
```

### 9.3 调试工具

```erlang
%% 获取服务器状态
sys:get_status(ServerRef).

%% 跟踪消息
sys:trace(ServerRef, true).

%% 获取统计信息
sys:statistics(ServerRef, true).
sys:statistics(ServerRef, get).

%% 暂停/恢复
sys:suspend(ServerRef).
sys:resume(ServerRef).
```

---

## 10. 快速参考

### 10.1 启动函数

| 函数 | 链接 | 说明 |
|------|------|------|
| `gen_server:start_link({local,N}, Mod, Args, Opts)` | ✅ | 本地注册+链接 |
| `gen_server:start_link({global,N}, Mod, Args, Opts)` | ✅ | 全局注册+链接 |
| `gen_server:start_link(Mod, Args, Opts)` | ✅ | 不注册+链接 |
| `gen_server:start({local,N}, Mod, Args, Opts)` | ❌ | 本地注册 |
| `gen_server:start({global,N}, Mod, Args, Opts)` | ❌ | 全局注册 |

### 10.2 客户端函数

| 函数 | 类型 | 说明 |
|------|------|------|
| `gen_server:call(Ref, Request)` | 同步 | 默认5秒超时 |
| `gen_server:call(Ref, Request, Timeout)` | 同步 | 自定义超时 |
| `gen_server:cast(Ref, Msg)` | 异步 | 无返回值 |
| `gen_server:reply(From, Reply)` | - | 显式回复 |
| `gen_server:stop(Ref)` | 同步 | 停止服务器 |
| `gen_server:multi_call(Nodes, Name, Req)` | 同步 | 多节点调用 |
| `gen_server:abcast(Nodes, Name, Msg)` | 异步 | 多节点广播 |

### 10.3 回调函数返回值速查

```
init/1:
  {ok, State} | {ok, State, Timeout} | {stop, Reason} | ignore

handle_call/3:
  {reply, Reply, State}
  {reply, Reply, State, Timeout}
  {noreply, State}
  {noreply, State, Timeout}
  {stop, Reason, Reply, State}
  {stop, Reason, State}

handle_cast/2:
  {noreply, State}
  {noreply, State, Timeout}
  {stop, Reason, State}

handle_info/2:
  {noreply, State}
  {noreply, State, Timeout}
  {stop, Reason, State}

terminate/2:
  ok  (return value is ignored)

code_change/3:
  {ok, NewState}
```

### 10.4 源码文件列表

| 文件 | 说明 |
|------|------|
| `src/frequency_raw.erl` | Step 1: 纯 Erlang 进程实现 |
| `src/my_server.erl` | Step 2: 自定义通用服务器 |
| `src/frequency_generic.erl` | Step 2: 使用自定义通用服务器 |
| `src/frequency_otp.erl` | Step 3: OTP gen_server 实现 |
| `src/frequency_reply.erl` | 显式回复 (gen_server:reply) |
| `src/timeout_demo.erl` | 超时机制演示 |
| `src/call_timeout_demo.erl` | Call 超时与 start vs start_link |
| `src/kv_store.erl` | 多种注册方式 (local/global/pid) |
| `src/distributed_demo.erl` | 分布式节点通信 |

### 10.5 Makefile 命令

```bash
make compile          # 编译所有文件
make run_raw          # Step 1: 纯 Erlang 进程
make run_generic      # Step 2: 自定义通用服务器
make run_otp          # Step 3: OTP gen_server
make run_reply        # 显式回复演示
make run_timeout      # 超时演示 (约15秒)
make run_call_timeout # Call 超时演示
make run_kv_local     # KV Store 本地注册
make run_kv_unnamed   # KV Store 无名 (PID)
make run_distributed  # 分布式演示
make run_all          # 运行所有演示
make clean            # 清理编译文件
make help             # 显示帮助
```
