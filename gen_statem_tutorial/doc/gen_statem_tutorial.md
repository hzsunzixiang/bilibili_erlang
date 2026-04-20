# gen_statem 完全教程

## 目录

1. [概述](#1-概述)
2. [gen_statem 架构模型](#2-gen_statem-架构模型)
3. [基本用法：密码锁 (state_functions)](#3-基本用法密码锁-state_functions)
4. [回调模式详解](#4-回调模式详解)
5. [handle_event_function 模式](#5-handle_event_function-模式)
6. [All State Events (公共事件处理)](#6-all-state-events-公共事件处理)
7. [停止 gen_statem](#7-停止-gen_statem)
8. [Event Time-Outs (事件超时)](#8-event-time-outs-事件超时)
9. [State Time-Outs (状态超时)](#9-state-time-outs-状态超时)
10. [Generic Time-Outs (通用超时)](#10-generic-time-outs-通用超时)
11. [Erlang Timers (Erlang 定时器)](#11-erlang-timers-erlang-定时器)
12. [Postponing Events (延迟事件)](#12-postponing-events-延迟事件)
13. [State Enter Actions (状态进入动作)](#13-state-enter-actions-状态进入动作)
14. [Inserted Events (插入事件)](#14-inserted-events-插入事件)
15. [Complex State (复杂状态)](#15-complex-state-复杂状态)
16. [Selective Receive (选择性接收)](#16-selective-receive-选择性接收)
17. [gen_statem vs gen_fsm vs gen_server](#17-gen_statem-vs-gen_fsm-vs-gen_server)
18. [最佳实践与常见陷阱](#18-最佳实践与常见陷阱)
19. [快速参考](#19-快速参考)

---

## 1. 概述

### 什么是 gen_statem？

`gen_statem` 是 OTP 框架中的**通用状态机**行为模式（behavior），是 `gen_fsm` 的替代品（OTP 20+）。
它提供了两种回调模式，支持丰富的状态转换动作，是实现有限状态机的首选方案。

### 核心概念

```
                    ┌─────────────────────────────────┐
  cast(Pid,Msg) ──>│                                  │
  call(Pid,Req) ──>│   gen_statem Process              │
  info messages ──>│   (state machine engine)          │
  timeouts      ──>│                                  │
                    │   Current State: locked           │
                    │   Data: #{code => [a,b,c], ...}  │
                    └─────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
              state_functions    handle_event_function
              locked/3           handle_event/4
              open/3
```

关键特征：
- **两种回调模式**：`state_functions`（每个状态一个函数）和 `handle_event_function`（统一处理函数）
- **丰富的超时机制**：event timeout、state timeout、generic timeout、erlang timer
- **状态进入动作**：`state_enter` 支持在每次状态变化时执行动作
- **事件延迟**：`postpone` 可以将事件推迟到状态变化后再处理
- **插入事件**：`next_event` 可以在当前状态插入新事件
- **复杂状态**：状态可以是任意 term，不限于 atom

### 为什么需要 gen_statem？

典型使用场景：
- **协议实现**：TCP 连接状态机、HTTP 请求处理
- **设备控制**：门锁、电梯、交通灯
- **业务流程**：订单状态、审批流程
- **游戏逻辑**：角色状态、回合制游戏

### gen_statem 替代 gen_fsm

OTP 20 引入 `gen_statem` 替代 `gen_fsm`，主要改进：
- 支持 `handle_event_function` 回调模式
- 更丰富的超时类型（state_timeout, generic timeout）
- 支持 `state_enter` 动作
- 支持 `postpone` 和 `next_event`
- 状态可以是任意 term

---

## 2. gen_statem 架构模型

### 2.1 与 gen_server 的对比

```
┌─────────────────────────────────────────────────────────────────┐
│                        gen_server                                │
│                                                                  │
│   Client ──call/cast──> [Process] ──callback──> Module           │
│                         handle_call/3, handle_cast/2             │
│                         (no explicit state concept)              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        gen_statem                                 │
│                                                                  │
│   Client ──call/cast──> [Process] ──callback──> StateName/3      │
│                         (state machine engine)   or               │
│                         routes by current state   handle_event/4 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 内部结构

```
gen_statem Process
┌──────────────────────────────────────────────────┐
│  gen_statem engine                                │
│                                                   │
│  State = locked                                   │
│  Data  = #{code => [a,b,c], buttons => []}        │
│                                                   │
│  receive                                          │
│    {'$gen_cast', Msg} ->                          │
│      Module:StateName(cast, Msg, Data)            │
│    {'$gen_call', From, Request} ->                │
│      Module:StateName({call,From}, Request, Data) │
│    {timeout, Ref, Msg} ->                         │
│      Module:StateName(info, {timeout,...}, Data)   │
│    state_timeout ->                               │
│      Module:StateName(state_timeout, Content, Data)│
│    Info ->                                        │
│      Module:StateName(info, Info, Data)           │
│  end                                              │
│                                                   │
│  Result: {next_state, NewState, NewData, Actions} │
└──────────────────────────────────────────────────┘
```

### 2.3 事件类型 (EventType)

```erlang
EventType =
    {call, From}        %% gen_statem:call/2,3 - synchronous request
  | cast                %% gen_statem:cast/2 - asynchronous message
  | info                %% Regular Erlang messages (!, send)
  | state_timeout       %% State timeout expired
  | {timeout, Name}     %% Generic named timeout expired
  | timeout             %% Event timeout expired
  | internal            %% Inserted event via next_event action
  | enter               %% State enter call (if state_enter enabled)
```

### 2.4 状态转换流程

```
  Event arrives
       │
       ▼
  ┌─────────────┐     {next_state, NewState, NewData, Actions}
  │ State       │────────────────────────────────────────────>  State Changed?
  │ Callback    │                                                    │
  └─────────────┘                                              ┌─────┴─────┐
                                                               Yes         No
                                                               │           │
                                                          ┌────┴────┐  ┌───┴───┐
                                                          │ Process │  │ Stay  │
                                                          │ postponed│  │ in    │
                                                          │ events  │  │ state │
                                                          └─────────┘  └───────┘
```

---

## 3. 基本用法：密码锁 (state_functions)

> 源码文件：`src/code_lock_state.erl`

### 3.1 完整示例

```erlang
-module(code_lock_state).
-behaviour(gen_statem).

-export([start_link/1, button/1]).
-export([init/1, callback_mode/0, terminate/3]).
-export([locked/3, open/3]).

start_link(Code) ->
    gen_statem:start_link({local, code_lock}, ?MODULE, Code, []).

button(Button) ->
    gen_statem:cast(code_lock, {button, Button}).

init(Code) ->
    do_lock(),
    Data = #{code => Code, length => length(Code), buttons => []},
    {ok, locked, Data}.

callback_mode() ->
    state_functions.

%% State: locked
locked(cast, {button, Button},
       #{code := Code, length := Length, buttons := Buttons} = Data) ->
    NewButtons =
        if length(Buttons) < Length -> Buttons;
           true -> tl(Buttons)
        end ++ [Button],
    if
        NewButtons =:= Code ->
            do_unlock(),
            {next_state, open, Data#{buttons := []},
             [{state_timeout, 10000, lock}]};
        true ->
            {next_state, locked, Data#{buttons := NewButtons}}
    end.

%% State: open
open(state_timeout, lock, Data) ->
    do_lock(),
    {next_state, locked, Data};
open(cast, {button, _}, Data) ->
    {next_state, open, Data}.
```

### 3.2 使用方式

```erlang
%% 1. Start the state machine
{ok, Pid} = code_lock_state:start_link([a, b, c]).

%% 2. Send button events
code_lock_state:button(a).   %% Still locked
code_lock_state:button(b).   %% Still locked
code_lock_state:button(c).   %% Correct code! -> open

%% 3. After 10 seconds, auto-locks
```

### 3.3 状态转换图

```
                  button (wrong code)
                 ┌──────────────────┐
                 │                  │
                 ▼                  │
            ┌─────────┐     button (correct code)     ┌─────────┐
            │         │──────────────────────────────>│         │
            │ locked  │                               │  open   │
            │         │<──────────────────────────────│         │
            └─────────┘     state_timeout (10s)       └─────────┘
                                                           │
                                                           │ button (any)
                                                           └──────┘
```

### 3.4 运行演示

```bash
$ cd src && make run_state
```

---

## 4. 回调模式详解

### 4.1 callback_mode/0

```erlang
callback_mode() ->
    state_functions                          %% Each state = one function
  | handle_event_function                    %% One function handles all
  | [state_functions]                        %% Same as above
  | [handle_event_function]                  %% Same as above
  | [state_functions, state_enter]           %% With state enter calls
  | [handle_event_function, state_enter]     %% With state enter calls
```

### 4.2 state_functions 模式

每个状态对应一个导出函数：

```erlang
callback_mode() -> state_functions.

%% Module:StateName(EventType, EventContent, Data) -> Result
locked(cast, {button, B}, Data) -> ...
locked({call, From}, get_status, Data) -> ...
open(state_timeout, lock, Data) -> ...
open(cast, {button, _}, Data) -> ...
```

### 4.3 handle_event_function 模式

所有事件由一个函数处理：

```erlang
callback_mode() -> handle_event_function.

%% Module:handle_event(EventType, EventContent, State, Data) -> Result
handle_event(cast, {button, B}, locked, Data) -> ...
handle_event(state_timeout, lock, open, Data) -> ...
handle_event({call, From}, get_status, _State, Data) -> ...
```

### 4.4 回调返回值

```erlang
%% State transition
{next_state, NextState, NewData}
{next_state, NextState, NewData, Actions}

%% Stay in current state
{keep_state, NewData}
{keep_state, NewData, Actions}
keep_state_and_data
{keep_state_and_data, Actions}

%% Repeat state enter (only with state_enter)
{repeat_state, NewData}
{repeat_state, NewData, Actions}
repeat_state_and_data
{repeat_state_and_data, Actions}

%% Stop
{stop, Reason}
{stop, Reason, NewData}
{stop_and_reply, Reason, Replies}
{stop_and_reply, Reason, Replies, NewData}
```

### 4.5 Actions (动作)

```erlang
Actions = [Action]
Action =
    postpone                                    %% Postpone current event
  | {postpone, boolean()}
  | {next_event, EventType, EventContent}       %% Insert event
  | {reply, From, Reply}                        %% Reply to call
  | {state_timeout, Time, EventContent}         %% State timeout
  | {state_timeout, update, EventContent}       %% Update state timeout
  | {state_timeout, cancel}                     %% Cancel state timeout
  | {{timeout, Name}, Time, EventContent}       %% Generic timeout
  | {{timeout, Name}, update, EventContent}     %% Update generic timeout
  | {{timeout, Name}, cancel}                   %% Cancel generic timeout
  | {timeout, Time, EventContent}               %% Event timeout (legacy)
  | Time                                        %% Event timeout (integer)
  | hibernate                                   %% Hibernate process
```

---

## 5. handle_event_function 模式

> 源码文件：`src/code_lock_handle_event.erl`

### 5.1 事件优先 vs 状态优先

`handle_event_function` 模式允许两种组织方式：

**事件优先**（先匹配事件类型，再匹配状态）：

```erlang
handle_event(cast, {button, Button}, State, Data) ->
    case State of
        locked -> ...;
        open -> ...
    end;
handle_event(state_timeout, lock, open, Data) -> ...
```

**状态优先**（先匹配状态，再匹配事件）：

```erlang
%% State: locked
handle_event(EventType, EventContent, locked, Data) -> ...;
%% State: open
handle_event(EventType, EventContent, open, Data) -> ...;
%% Common
handle_event({call, From}, Request, _State, Data) -> ...
```

### 5.2 运行演示

```bash
$ make run_handle_event
```

---

## 6. All State Events (公共事件处理)

> 源码文件：`src/code_lock_common.erl`

### 6.1 问题：多个状态共享相同的事件处理

某些事件（如查询操作）在所有状态下都需要处理。

### 6.2 state_functions 模式的解决方案

使用公共处理函数：

```erlang
locked(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

open(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

handle_common({call, From}, code_length, #{code := Code} = Data) ->
    {keep_state, Data, [{reply, From, length(Code)}]}.
```

### 6.3 运行演示

```bash
$ make run_common
```

---

## 7. 停止 gen_statem

> 源码文件：`src/code_lock_stop.erl`

### 7.1 在监督树中

在监督树中，gen_statem 通过 supervisor 的关闭策略停止。
需要在 `init/1` 中设置 `process_flag(trap_exit, true)`。

### 7.2 独立停止

```erlang
%% API function
stop() ->
    gen_statem:stop(code_lock).

%% Or with reason and timeout
gen_statem:stop(code_lock, normal, 5000).
```

### 7.3 terminate/3 回调

```erlang
terminate(Reason, State, Data) ->
    %% Cleanup resources
    State =/= locked andalso do_lock(),
    ok.
```

### 7.4 运行演示

```bash
$ make run_stop
```

---

## 8. Event Time-Outs (事件超时)

> 源码文件：`src/code_lock_event_timeout.erl`

### 8.1 概念

Event timeout 是从 `gen_fsm` 继承的超时机制：
- **任何事件到达都会取消定时器**
- 要么收到事件，要么收到超时，不会同时发生
- 适用于"如果一段时间内没有任何事件，则执行某操作"

### 8.2 使用方式

```erlang
%% Set event timeout via action
{next_state, locked, Data#{buttons := NewButtons}, 20000}
%% Or equivalently:
{next_state, locked, Data#{buttons := NewButtons}, [{timeout, 20000, clear_buttons}]}

%% Handle timeout
locked(timeout, _, Data) ->
    {next_state, locked, Data#{buttons := []}}.
```

### 8.3 运行演示

```bash
$ make run_event_timeout
```

---

## 9. State Time-Outs (状态超时)

### 9.1 概念

State timeout 在**状态变化时自动取消**：
- 每个状态只能有一个 state_timeout
- 状态变化时，之前的 state_timeout 自动取消
- 适用于"进入某状态后，如果超时则转换状态"

### 9.2 使用方式

```erlang
%% Set state timeout when entering open state
locked(cast, {button, Button}, Data) ->
    ...
    {next_state, open, Data#{buttons := []},
     [{state_timeout, 10000, lock}]}.

%% Handle state timeout
open(state_timeout, lock, Data) ->
    do_lock(),
    {next_state, locked, Data}.
```

这是基本示例 `code_lock_state.erl` 中已经使用的超时方式。

---

## 10. Generic Time-Outs (通用超时)

> 源码文件：`src/code_lock_generic_timeout.erl`

### 10.1 概念

Generic timeout 是命名超时，**不会被事件或状态变化自动取消**：
- 可以有多个不同名称的 generic timeout 同时运行
- 只能通过显式设置新值或 cancel 来取消
- 适用于需要跨状态的定时器

### 10.2 使用方式

```erlang
%% Set generic timeout with name 'open'
{next_state, open, Data#{buttons := []},
 [{{timeout, open}, 10000, lock}]}.

%% Handle generic timeout
open({timeout, open}, lock, Data) ->
    do_lock(),
    {next_state, locked, Data}.
```

### 10.3 运行演示

```bash
$ make run_generic_timeout
```

---

## 11. Erlang Timers (Erlang 定时器)

> 源码文件：`src/code_lock_erlang_timer.erl`

### 11.1 概念

使用 `erlang:start_timer/3` 创建的定时器，超时消息作为 `info` 事件到达：
- 最灵活的定时器方式
- 可以通过 `erlang:cancel_timer/1` 取消
- 定时器引用存储在 Data 中

### 11.2 使用方式

```erlang
%% Start timer
Tref = erlang:start_timer(10000, self(), lock),
{next_state, open, Data#{buttons := [], timer => Tref}}.

%% Handle timer message (arrives as info event)
open(info, {timeout, Tref, lock}, #{timer := Tref} = Data) ->
    do_lock(),
    {next_state, locked, maps:remove(timer, Data)}.
```

### 11.3 运行演示

```bash
$ make run_erlang_timer
```

---

## 12. Postponing Events (延迟事件)

> 源码文件：`src/code_lock_postpone.erl`

### 12.1 概念

`postpone` 将当前事件推迟到下一次**状态变化**后重新处理：
- 事件被放回队列头部
- 只有状态变化时，postponed 事件才会被重新投递
- 适用于"当前状态无法处理，但换个状态就能处理"

### 12.2 使用方式

```erlang
%% In open state, postpone button events until locked
open(cast, {button, _}, Data) ->
    {keep_state, Data, [postpone]}.
```

### 12.3 效果

```
State: open
  Event: {button, a} -> postpone (saved)
  Event: {button, b} -> postpone (saved)
  state_timeout -> transition to locked
State: locked
  Replay: {button, a} -> processed!
  Replay: {button, b} -> processed!
```

### 12.4 运行演示

```bash
$ make run_postpone
```

---

## 13. State Enter Actions (状态进入动作)

> 源码文件：`src/code_lock_enter.erl`

### 13.1 概念

启用 `state_enter` 后，每次状态变化时，gen_statem 会调用状态回调，
事件类型为 `(enter, OldState, ...)`：

```erlang
callback_mode() ->
    [state_functions, state_enter].
```

### 13.2 使用方式

```erlang
locked(enter, _OldState, Data) ->
    do_lock(),
    {keep_state, Data#{buttons => []}};
locked(cast, {button, Button}, Data) ->
    ...

open(enter, _OldState, _Data) ->
    do_unlock(),
    {keep_state_and_data, [{state_timeout, 10000, lock}]};
open(state_timeout, lock, Data) ->
    {next_state, locked, Data}.
```

### 13.3 优势

- 将状态初始化逻辑集中在 enter 处理中
- 不需要在 init/1 中手动调用 do_lock()
- 可以用 `repeat_state` 重新触发 enter 动作

### 13.4 运行演示

```bash
$ make run_enter
```

---

## 14. Inserted Events (插入事件)

> 源码文件：`src/code_lock_inserted.erl`

### 14.1 概念

使用 `{next_event, EventType, EventContent}` 动作可以在当前状态插入新事件：
- 插入的事件在下一个事件之前被处理
- 常用于将外部事件转换为内部事件
- `internal` 事件类型只能通过 `next_event` 产生

### 14.2 使用方式：按键的 down/up 事件

```erlang
%% Convert up event to internal button event
handle_common(cast, {up, Button}, Data) ->
    case Data of
        #{button := Button} ->
            {keep_state, maps:remove(button, Data),
             [{next_event, internal, {button, Button}}]};
        #{} ->
            keep_state_and_data
    end.

%% Handle the internal event
locked(internal, {button, Button}, Data) ->
    %% Process button press...
```

### 14.3 运行演示

```bash
$ make run_inserted
```

---

## 15. Complex State (复杂状态)

> 源码文件：`src/code_lock_complex.erl`

### 15.1 概念

在 `handle_event_function` 模式下，状态可以是任意 term，不限于 atom。
例如使用元组 `{StateName, LockButton}` 作为状态：

### 15.2 使用方式

```erlang
init({Code, LockButton}) ->
    Data = #{code => Code, length => length(Code), buttons => []},
    {ok, {locked, LockButton}, Data}.

callback_mode() ->
    [handle_event_function, state_enter].

%% State: {locked, LockButton}
handle_event(enter, _OldState, {locked, _}, Data) ->
    do_lock(),
    {keep_state, Data#{buttons := []}};

%% State: {open, LockButton}
handle_event(cast, {button, LockButton}, {open, LockButton}, Data) ->
    {next_state, {locked, LockButton}, Data};

%% Common: change lock button in any state
handle_event({call, From}, {set_lock_button, NewLB},
             {StateName, OldLB}, Data) ->
    {next_state, {StateName, NewLB}, Data,
     [{reply, From, OldLB}]}.
```

### 15.3 运行演示

```bash
$ make run_complex
```

---

## 16. Selective Receive (选择性接收)

> 源码文件：`src/code_lock_selective.erl`

### 16.1 概念

展示不使用 gen_statem，而是用原生 Erlang 的选择性接收实现状态机。
这是 gen_statem 要解决的底层问题。

### 16.2 原生实现

```erlang
locked(Code, Length, Buttons) ->
    receive
        {button, Button} ->
            NewButtons = ... ++ [Button],
            if
                NewButtons =:= Code ->
                    do_unlock(),
                    open(Code, Length);
                true ->
                    locked(Code, Length, NewButtons)
            end
    end.

open(Code, Length) ->
    receive
    after 10000 ->
        do_lock(),
        locked(Code, Length, [])
    end.
```

### 16.3 运行演示

```bash
$ make run_selective
```

---

## 17. gen_statem vs gen_fsm vs gen_server

### 17.1 对比表

| 特性 | gen_server | gen_fsm (deprecated) | gen_statem |
|------|-----------|---------------------|-----------|
| 状态概念 | 隐式（在 State 中） | 显式（atom 状态名） | 显式（任意 term） |
| 回调模式 | 单一 | state_functions | state_functions / handle_event_function |
| 超时类型 | timeout | timeout | event/state/generic timeout |
| state_enter | ❌ | ❌ | ✅ |
| postpone | ❌ | ❌ | ✅ |
| next_event | ❌ | ❌ | ✅ |
| 复杂状态 | N/A | ❌ (atom only) | ✅ (any term) |

### 17.2 何时用 gen_statem？

- 有明确的**状态转换**逻辑
- 需要**超时**驱动状态变化
- 需要**延迟处理**某些事件
- 需要**状态进入**动作
- 实现**协议**或**流程控制**

### 17.3 何时用 gen_server？

- 简单的**请求-响应**模式
- 没有明确的状态转换
- 主要是**数据管理**（CRUD）

---

## 18. 最佳实践与常见陷阱

### 18.1 最佳实践

1. **优先使用 state_functions**：代码更清晰，每个状态一个函数
2. **使用 state_enter**：将状态初始化逻辑集中管理
3. **善用 postpone**：避免在错误状态下丢弃事件
4. **使用 state_timeout**：比 event timeout 更可预测
5. **trap_exit**：在监督树中使用时设置 `process_flag(trap_exit, true)`

### 18.2 常见陷阱

#### 陷阱 1：忘记处理所有状态的公共事件

```erlang
%% BAD: code_length only works in locked state
locked({call, From}, code_length, Data) ->
    {keep_state, Data, [{reply, From, length(maps:get(code, Data))}]}.
%% open state will crash on code_length call!

%% GOOD: handle in all states
locked(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).
open(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).
```

#### 陷阱 2：postpone 导致无限循环

```erlang
%% BAD: postpone without state change = infinite loop
locked(cast, {button, _}, Data) ->
    {keep_state, Data, [postpone]}.  %% DANGER! Never changes state
```

#### 陷阱 3：混淆超时类型

```erlang
%% event timeout: cancelled by ANY event
{next_state, State, Data, [{timeout, 5000, msg}]}

%% state timeout: cancelled by state CHANGE
{next_state, State, Data, [{state_timeout, 5000, msg}]}

%% generic timeout: only cancelled explicitly
{next_state, State, Data, [{{timeout, name}, 5000, msg}]}
```

#### 陷阱 4：state_enter 中返回 next_state

```erlang
%% BAD: state enter must not change state
locked(enter, _OldState, Data) ->
    {next_state, open, Data}.  %% CRASH!

%% GOOD: use keep_state in enter
locked(enter, _OldState, Data) ->
    {keep_state, Data#{buttons => []}}.
```

---

## 19. 快速参考

### 19.1 启动函数

| 函数 | 说明 |
|------|------|
| `gen_statem:start_link({local,N}, Mod, Args, Opts)` | 启动并本地注册 |
| `gen_statem:start_link({global,N}, Mod, Args, Opts)` | 启动并全局注册 |
| `gen_statem:start_link(Mod, Args, Opts)` | 启动不注册 |
| `gen_statem:start(...)` | 同上但不链接 |
| `gen_statem:stop(Ref)` | 停止状态机 |

### 19.2 消息发送函数

| 函数 | 类型 | 说明 |
|------|------|------|
| `gen_statem:call(Ref, Request)` | 同步 | 发送请求并等待回复 |
| `gen_statem:call(Ref, Request, Timeout)` | 同步 | 带超时 |
| `gen_statem:cast(Ref, Msg)` | 异步 | 发送异步消息 |
| `Ref ! Msg` | 异步 | 发送 info 消息 |

### 19.3 回调函数

```
init/1:
  {ok, State, Data}
  {ok, State, Data, Actions}
  {stop, Reason}
  ignore

callback_mode/0:
  state_functions | handle_event_function
  | [CallbackMode]
  | [CallbackMode, state_enter]

StateName/3 (state_functions mode):
  StateName(EventType, EventContent, Data) -> Result

handle_event/4 (handle_event_function mode):
  handle_event(EventType, EventContent, State, Data) -> Result

terminate/3:
  terminate(Reason, State, Data) -> Ignored

code_change/4:
  code_change(OldVsn, State, Data, Extra) -> {ok, NewState, NewData}
```

### 19.4 超时类型对比

| 超时类型 | 设置方式 | 取消条件 | 事件类型 |
|---------|---------|---------|---------|
| Event timeout | `{timeout, T, Msg}` 或 `T` | 任何事件到达 | `timeout` |
| State timeout | `{state_timeout, T, Msg}` | 状态变化 | `state_timeout` |
| Generic timeout | `{{timeout,Name}, T, Msg}` | 显式取消/更新 | `{timeout,Name}` |
| Erlang timer | `erlang:start_timer/3` | `erlang:cancel_timer/1` | `info` |

### 19.5 源码文件列表

| 文件 | 说明 | 对应章节 |
|------|------|---------|
| `src/code_lock_state.erl` | 基本用法：state_functions 模式 | §3 |
| `src/code_lock_handle_event.erl` | handle_event_function 模式 | §5 |
| `src/code_lock_common.erl` | All State Events (公共事件) | §6 |
| `src/code_lock_stop.erl` | 停止 gen_statem | §7 |
| `src/code_lock_event_timeout.erl` | Event Time-Outs | §8 |
| `src/code_lock_generic_timeout.erl` | Generic Time-Outs | §10 |
| `src/code_lock_erlang_timer.erl` | Erlang Timers | §11 |
| `src/code_lock_postpone.erl` | Postponing Events | §12 |
| `src/code_lock_enter.erl` | State Enter Actions | §13 |
| `src/code_lock_inserted.erl` | Inserted Events (down/up) | §14 |
| `src/code_lock_complex.erl` | Complex State | §15 |
| `src/code_lock_selective.erl` | Selective Receive (原生实现) | §16 |

### 19.6 Makefile 命令

```bash
make compile            # Compile all .erl files
make run_state          # Basic state_functions demo
make run_handle_event   # handle_event_function demo
make run_common         # All State Events demo
make run_stop           # Stop demo
make run_event_timeout  # Event timeout demo
make run_generic_timeout # Generic timeout demo
make run_erlang_timer   # Erlang timer demo
make run_postpone       # Postpone demo
make run_enter          # State enter demo
make run_inserted       # Inserted events demo
make run_complex        # Complex state demo
make run_selective      # Selective receive demo
make run_all            # Run all demos sequentially
make clean              # Remove compiled files
make help               # Show available targets
```
