# observer_cli_snapshot.escript 使用说明

本文单独说明 `full_otp_app/scripts/observer_cli_snapshot.escript` 这个脚本的用途、参数和实现原理。

这个脚本用于演示：`observer_cli` 看到的很多运行时数据，并不是只能通过 TUI 获取；Erlang/OTP 本身提供了大量 runtime introspection API，可以直接在 Erlang 代码中采集系统、application、process、ETS 等信息。

---

## 1. 脚本位置

脚本位于 demo 应用目录下：

```text
bilibili_erlang/observer/full_otp_app/scripts/observer_cli_snapshot.escript
```

它是一个 `escript`，可以直接执行：

```bash
cd bilibili_erlang/observer/full_otp_app
scripts/observer_cli_snapshot.escript
```

---

## 2. 它解决什么问题

`observer_cli` 可以在终端里实时展示 BEAM 节点状态，例如：

- 系统信息
- application 列表和聚合指标
- 进程列表
- ETS 表信息

`observer_cli_snapshot.escript` 不实现终端 TUI，也不做周期刷新，而是采集一次快照数据并打印出来。

可以把关系理解为：

```text
observer_cli
  = Erlang runtime API / recon
    + 周期采样
    + 排序
    + 分页
    + 终端 UI

observer_cli_snapshot.escript
  = Erlang runtime API
    + 一次性采样
    + 文本输出
```

所以这个脚本更适合教学：它把 `observer_cli` 背后的数据来源拆开，让学习者看到运行时信息是如何通过 Erlang API 获取的。

---

## 3. 使用方式一：不带参数

在 demo 目录下执行：

```bash
cd bilibili_erlang/observer/full_otp_app
scripts/observer_cli_snapshot.escript
```

这种方式会启动脚本自己的 Erlang VM，并观察这个 VM 本身。

输出里通常能看到：

```text
== Local Node ==
node: nonode@nohost
```

这说明当前脚本自己的 VM 没有分布式节点名。

这个模式主要用于验证脚本是否能运行，不是用来观察正在运行的 `full_otp_app` demo application。

---

## 4. 使用方式二：连接正在运行的 demo 节点

如果要观察 `rebar3 shell --sname application_demo` 启动的 demo 节点，需要使用远程模式。

先启动 demo：

```bash
cd bilibili_erlang/observer/full_otp_app
rebar3 shell --sname application_demo
```

在 Erlang shell 中查看当前节点名：

```erlang
node().
```

可能输出：

```erlang
'application_demo@ERICKSUN-MC1'
```

再查看 cookie：

```erlang
erlang:get_cookie().
```

然后在另一个终端执行：

```bash
cd bilibili_erlang/observer/full_otp_app
scripts/observer_cli_snapshot.escript application_demo@ERICKSUN-MC1 COOKIE
```

这里的参数含义是：

| 参数 | 含义 |
|------|------|
| `application_demo@ERICKSUN-MC1` | 目标 Erlang node 名字 |
| `COOKIE` | 目标 Erlang node 的 cookie |

注意：这里的参数不是 macOS / Linux 里的 BEAM 进程 PID，而是 Erlang 分布式节点名。

也就是说，不是这样用：

```bash
scripts/observer_cli_snapshot.escript 12345
```

如果 `12345` 是 OS 进程号，脚本不会识别。Erlang 远程观察通常通过 distributed Erlang node 做 RPC，而不是通过 OS PID。

---

## 5. 为什么参数是 node name，不是 BEAM 进程 PID

Erlang 分布式通信的基本单位是 node。

一个运行中的 BEAM VM 如果用 `--sname` 或 `--name` 启动，就会拥有一个 Erlang node name，例如：

```text
application_demo@ERICKSUN-MC1
```

脚本连接远程 VM 的流程是：

```text
observer_cli_snapshot.escript
  -> 启动临时 helper node
      -> 设置相同 cookie
          -> net_adm:ping(TargetNode)
              -> rpc:call(TargetNode, ...)
                  -> 在目标 node 上执行 Erlang runtime API
```

所以远程模式生效需要满足三个条件：

```text
目标 VM 必须用 --sname 或 --name 启动
脚本使用相同 cookie
两个节点之间能通过 distributed Erlang 连接
```

如果目标 shell 是普通 `rebar3 shell`，没有带 `--sname` 或 `--name`，那它就是：

```text
nonode@nohost
```

这种 VM 没有可被外部节点连接的分布式 node name，因此外部脚本无法按 node 名远程连接。

---

## 6. 脚本入口逻辑

脚本入口是 `main/1`：

```erlang
main([]) ->
    print_snapshot(node());
main([TargetNodeText, CookieText]) ->
    TargetNode = list_to_atom(TargetNodeText),
    Cookie = list_to_atom(CookieText),
    start_helper_node(TargetNode, Cookie),
    case net_adm:ping(TargetNode) of
        pong ->
            print_remote_snapshot(TargetNode);
        pang ->
            io:format("Could not connect to ~p. Check node name and cookie.~n", [TargetNode]),
            halt(1)
    end;
main(_) ->
    io:format("Usage: observer_cli_snapshot.escript [TargetNode Cookie]~n", []),
    halt(1).
```

它支持两种参数形式：

| 调用方式 | 行为 |
|----------|------|
| `scripts/observer_cli_snapshot.escript` | 观察脚本自己的 VM |
| `scripts/observer_cli_snapshot.escript TargetNode Cookie` | 连接远程 Erlang node，并观察目标 VM |

---

## 7. 远程 helper node 是什么

远程模式下，脚本自身也必须先变成一个 Erlang 分布式节点，才能连接目标节点。

相关函数是：

```erlang
start_helper_node(TargetNode, Cookie) ->
    NameType = name_type(TargetNode),
    HelperName = helper_name(NameType),
    case net_kernel:start([HelperName, NameType]) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok;
        {error, Reason} ->
            io:format("Could not start helper distributed node: ~p~n", [Reason]),
            halt(1)
    end,
    erlang:set_cookie(node(), Cookie).
```

这里做了两件事：

1. 用 `net_kernel:start/1` 启动一个临时 helper node。
2. 用 `erlang:set_cookie/2` 设置和目标 node 相同的 cookie。

之后才能通过 `net_adm:ping/1` 测试连接，并通过 `rpc:call/4` 在目标节点上执行函数。

---

## 8. 脚本采集哪些数据

脚本的快照入口是：

```erlang
collect_snapshot() ->
    {ok, #{
        system => system_info(),
        applications => application_info(),
        top_processes => top_processes(memory, 15),
        ets_tables => ets_info(15)
    }}.

collect_remote_snapshot(Node) ->
    {ok, #{
        system => remote_system_info(Node),
        applications => remote_application_info(Node),
        top_processes => remote_top_processes(Node, memory, 15),
        ets_tables => remote_ets_info(Node, 15)
    }}.
```

它采集四类信息：

```text
== System ==
== Applications ==
== Top Processes By Memory ==
== ETS Tables By Memory Words ==
```

---

## 9. System 信息来自哪里

本地模式调用：

```erlang
erlang:system_info/1
erlang:memory/0
```

远程模式通过 RPC 调用目标节点上的同类函数：

```erlang
rpc_call(Node, erlang, system_info, [otp_release])
rpc_call(Node, erlang, memory, [])
```

采集字段包括：

- OTP release
- process count / process limit
- port count / port limit
- atom count / atom limit
- memory

---

## 10. Application 信息如何聚合

脚本用这些 API 获取 application 信息：

```erlang
application:which_applications/0
application:loaded_applications/0
application:info/0
```

其中：

- `application:which_applications/0` 返回已经启动的 application。
- `application:loaded_applications/0` 返回已经加载的 application。
- `application:info/0` 可获取 application 与 group leader 相关的信息。

脚本会遍历所有 Erlang process，然后根据 `group_leader` 将进程近似归属到某个 application，并聚合：

- process count
- memory
- reductions
- message queue length
- status
- version

这和 `observer_cli` App 页面非常接近：它不是展示 supervisor tree，而是展示 application 维度的资源统计。

---

## 11. Process 信息如何排序

脚本通过：

```erlang
erlang:processes/0
erlang:process_info/2
```

获取进程列表和进程字段。

当前脚本按 memory 取前 15 个进程：

```erlang
top_processes(memory, 15)
```

每个进程采集字段包括：

- registered name
- memory
- reductions
- message_queue_len
- current_function

输出区域是：

```text
== Top Processes By Memory ==
```

---

## 12. ETS 信息如何获取

脚本通过：

```erlang
ets:all/0
ets:info/1
```

获取当前节点中的 ETS 表，并按 `memory` 字段排序，取前 15 个。

输出字段包括：

- table name
- size
- memory words
- type
- owner

输出区域是：

```text
== ETS Tables By Memory Words ==
```

---

## 13. 远程 RPC 封装

远程调用统一通过 `rpc_call/4`：

```erlang
rpc_call(Node, Module, Function, Args) ->
    case rpc:call(Node, Module, Function, Args) of
        {badrpc, Reason} ->
            io:format("RPC failed: ~p:~p/~p on ~p: ~p~n", [Module, Function, length(Args), Node, Reason]),
            halt(1);
        Result ->
            Result
    end.
```

这个函数的作用是：

1. 在目标 node 上执行指定函数。
2. 如果 RPC 失败，打印错误并退出。
3. 如果成功，返回目标 node 上的函数结果。

这也是脚本能够观察远程 VM 的核心。

---

## 14. 和 Observer / observer_cli 的关系

三者关系可以这样理解：

```text
Observer GUI
  -> 图形化观察结构
  -> 适合教学截图、application tree、process details、State tab

observer_cli
  -> 终端实时观察指标
  -> 适合 SSH、服务器、容器环境

observer_cli_snapshot.escript
  -> 用 Erlang API 一次性采集同类指标
  -> 适合解释 observer_cli 背后的数据来源
```

这个脚本不是要替代 `observer_cli`，而是用于说明：BEAM VM 的运行时信息可以通过 Erlang API 直接获取。

---

## 15. 常见问题

### 15.1 为什么本地模式看不到 full_otp_app？

因为不带参数时，脚本启动的是自己的 VM，不是 `rebar3 shell --sname application_demo` 那个 VM。

要观察 demo 节点，必须使用远程模式：

```bash
scripts/observer_cli_snapshot.escript application_demo@ERICKSUN-MC1 COOKIE
```

### 15.2 为什么连接失败？

常见原因：

- 目标 shell 没有用 `--sname` 或 `--name` 启动。
- node name 写错。
- cookie 不一致。
- 两个 node 之间网络不通。
- 使用了 long name / short name 不匹配的节点命名方式。

### 15.3 这个脚本依赖 observer_cli 吗？

不依赖。

它直接调用 Erlang/OTP runtime API，不需要启动 `observer_cli` TUI。

### 15.4 这个脚本依赖 recon 吗？

当前版本不依赖 `recon`。

`observer_cli` 自身会使用 `recon` 等工具增强诊断能力，但这个教学脚本为了保持简单，主要使用 Erlang/OTP 标准库 API。
