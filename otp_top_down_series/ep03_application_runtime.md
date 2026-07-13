# 第3集：Application（一）runtime application：OTP 系统的启动边界

> 与后续幻灯片逐页对应
> 目标受众：已经看过 Observer UI 和 observer_cli 两集、掌握 Erlang 基础语法的 OTP 初学者
> 时长目标：8-12 分钟

---

## 第1页：封面

**标题**：Application（一）runtime application
**副标题**：OTP 系统的启动边界

**演讲稿**：
大家好，这一集开始我们正式进入 OTP 主线。前两集我们先用 Observer 和 observer_cli 看见了运行中的 BEAM 系统：里面有 application，有 supervision tree，也有一个个 Erlang process。现在我们回到第一个核心概念：application。

这一集先讲第一类 application：runtime application。它是有启动入口、有运行时进程树、可以被 start 和 stop 管理的 OTP 应用。

---

## 第2页：Application 有两种正规叫法

**标题**：两种 application：runtime 与 library

**演讲稿**：
在 Erlang/OTP 里，application 这个词很容易让人误解。它不一定代表“一个正在跑的服务”。按照业界和 OTP 文档里常见的区分，我们可以把 application 分成两类：runtime application 和 library application。

runtime application 也常被叫作 active application，或者 process-owning application。它启动后会创建自己的进程，比如 supervisor 和 worker。

library application 也常被叫作 passive application，或者 code-only application。它主要提供模块和函数，本身通常不启动独立进程。

这两类都是真正的 OTP application，都会有 application resource file，也就是 `.app` 文件。差别在于：它们是否拥有自己的运行时进程结构。

---

## 第3页：runtime application 的特征

**标题**：runtime application：有自己的运行时结构

**演讲稿**：
runtime application 的核心特征是：启动 application 时，会通过 application callback module 启动一棵 supervision tree。

典型结构是这样的：

```text
runtime application
  -> application callback module
      -> top supervisor
          -> worker process
          -> child supervisor
          -> more worker process
```

我们之前在 Observer 里看到的 `full_otp_app`，就是 runtime application。它启动后不是只加载几个模块，而是真的创建了一批长期运行的 Erlang process。

---

## 第4页：library application 的特征

**标题**：library application：提供代码，不拥有进程树

**演讲稿**：
另一类是 library application。它也会出现在 application 列表里，也有 `.app` 文件，也可以作为 dependency 被别的 application 使用。

但它通常没有 application callback module，也没有自己的 top supervisor。它的职责是提供可调用的模块和函数。

比如 Erlang 自带的 `stdlib`、`crypto` 里的很多能力，都经常以库的方式被业务 application 使用。下一集我们会用 `math` 这个数学库作为例子，专门讲 library application。

---

## 第5页：为什么先讲 runtime application

**标题**：先讲 runtime，因为它连接 Observer 里的进程树

**演讲稿**：
这一集先讲 runtime application，因为它正好连接前两集的观察结果。

在 Observer 的 Applications 页面里，我们看到的不只是一个名字，而是一棵树。这个树的根，通常就是 runtime application 启动出来的 top supervisor。

所以 runtime application 是理解 OTP 系统运行形态的第一个入口：它不是业务逻辑本身，但它定义了系统如何启动、如何停止、以及启动以后谁负责管理进程树。

---

## 第6页：Application 使用上反而最简单

**标题**：复杂在实现，简单在使用

**演讲稿**：
这里有一个很重要的反直觉点：application 的实现机制很复杂，但是使用上可能是 OTP 里最简单的一类能力。

为什么？因为用户入口非常单一。

对使用者来说，通常只需要关心配置文件和启动命令：项目里有 `.app.src` 或 `.app` 文件，构建工具把它整理好，然后启动 application。

相比 `gen_server` 需要理解多种 callback，`supervisor` 需要理解 child spec 和 restart strategy，application 对普通使用者来说经常只是：声明元数据、声明依赖、声明启动模块，然后一条命令启动。

---

## 第7页：工具已经包装了大部分细节

**标题**：rebar3 和 erlang.mk 已经把入口包装好了

**演讲稿**：
application 使用简单，还有一个原因：现代 Erlang 项目通常不会让你手写所有底层步骤。

`rebar3` 可以生成应用骨架、编译 `.app.src`、启动 shell、自动启动配置里的 application。

`erlang.mk` 也提供了类似能力：项目结构、依赖、编译、release 构建，都会围绕 OTP application 来组织。

所以学习 application 的时候，我们既要理解它背后的原理，也要知道真实开发里很多步骤已经被工具包装好了。

**演示提示**：
这里适合人工截图：

```bash
rebar3 new app demo_runtime_app
rebar3 shell
```

也可以展示现有 demo 的启动命令：

```bash
cd bilibili_erlang/observer/full_otp_app
rebar3 shell --sname application_demo
```

---

## 第8页：runtime application 的最小入口

**标题**：真正入口：`.app` 文件里的 `mod`

**演讲稿**：
runtime application 的入口通常写在 `.app` 文件的 `mod` 字段里。

以 `full_otp_app` 为例：

```erlang
{application, full_otp_app,
 [{mod, {full_otp_app_app, []}},
  {applications, [kernel, stdlib, observer_cli, recon]}]}.
```

这里的重点不是语法，而是含义：

`full_otp_app` 这个 application 启动时，会调用 `full_otp_app_app` 这个模块里的 application callback。

`applications` 字段声明了它依赖哪些 application。也就是说，启动自己之前，需要先保证这些依赖已经可用。

---

## 第9页：application callback module 做什么

**标题**：callback module 通常只启动 top supervisor

**演讲稿**：
接下来看看 application callback module。

典型代码非常短：

```erlang
-module(full_otp_app_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    full_otp_app_sup:start_link().

stop(_State) ->
    ok.
```

这段代码说明了 runtime application 的常见分工：application callback module 不负责写业务逻辑，也不负责管理所有 worker。它只是把系统交给 top supervisor。

真正长期运行的，是 supervisor 和 supervisor 启动出来的 worker process。

---

## 第10页：为什么说原理不要求背下来

**标题**：知道原理，但不要求背实现

**演讲稿**：
这里我们给出原理，是为了让你看懂 Observer 里发生了什么，但不要求你一开始背下 application controller 的内部实现。

可以先形成这个心智模型：

```text
application:start(App)
  -> application controller 读取 App 的 resource file
  -> 确认依赖 application
  -> 找到 mod 字段
  -> 调用 callback_module:start/2
  -> callback module 启动 top supervisor
  -> supervisor 启动 children
```

真实实现比这个复杂，里面涉及 application controller、application master、启动类型、依赖处理和错误处理。但对入门阶段来说，这张图已经足够解释大多数现象。

---

## 第11页：Observer 中看到的是什么

**标题**：Observer 看到的是启动后的运行结果

**演讲稿**：
现在回到 Observer。我们在 Applications 页面选中 `full_otp_app`，能看到它下面有 `full_otp_app_sup`，再往下有 `kv_server`、`event_bus`、`traffic_light` 和 `data_store_sup`。

这不是 Observer 自己猜出来的结构，而是 runtime application 启动后真实存在的进程树。

换句话说：`.app` 文件给出 application 的入口，callback module 启动 top supervisor，supervisor 再启动 children。Observer 展示的是这条链路运行完成之后的结果。

**截图提示**：
使用 `images/Applications_app.png` 展示 application 被选中后的总览。
使用 `images/Applications_app_supervisor.png` 展示展开后的 top supervisor tree。

---

## 第12页：runtime application 的应用场景

**标题**：什么时候需要 runtime application

**演讲稿**：
什么时候我们需要 runtime application？只要你的应用需要拥有长期运行的进程，通常就应该是 runtime application。

典型场景包括：

- Web 服务或 TCP 服务。
- 后台任务调度器。
- 消息队列消费者。
- 数据缓存或连接池。
- 状态机服务。
- 需要 supervision tree 管理的一组 worker。

这些系统的共同点是：启动以后有自己的生命期，有进程需要被监督，有状态需要被维护，有错误需要被恢复。

---

## 第13页：runtime application 不是 main 函数

**标题**：不要把 application 当成 main 函数

**演讲稿**：
很多初学者会把 application callback module 想成 Erlang 里的 `main` 函数。这个理解只对了一小部分。

runtime application 的重点不是“从这里开始执行业务逻辑”，而是“从这里建立运行时结构”。

更准确地说：

```text
main 函数思维：启动后执行一段逻辑
OTP application 思维：启动后建立一棵可监督的进程树
```

这就是 Erlang/OTP 和普通脚本程序很不一样的地方。

---

## 第14页：用命令行观察 runtime application

**标题**：命令行也能验证 application 状态

**演讲稿**：
除了 Observer UI，我们也可以用 Erlang shell 查看 application 状态。

常用命令包括：

```erlang
application:which_applications().
application:ensure_all_started(full_otp_app).
application:stop(full_otp_app).
supervisor:which_children(full_otp_app_sup).
```

这里建议现场演示：先启动 demo，再查看 application 列表，然后查看 supervisor children。

这样观众会看到：图形界面、observer_cli、Erlang shell API，观察的是同一个运行时系统。

---

## 第15页：runtime application 的命名规则

**标题**：正规命名：表达运行时所有权

**演讲稿**：
回到开头的命名问题。为了讲得正规，本系列会使用这组叫法：

```text
runtime application
  又称 active application / process-owning application

library application
  又称 passive application / code-only application
```

runtime application 这个名字强调：它不仅提供代码，还拥有运行时进程结构。

process-owning application 这个名字更直白：它拥有 supervisor 和 worker 这些 process。

active application 这个名字强调：它启动后会主动运行。

后面我们会优先使用 runtime application 这个说法，因为它最适合和 Observer 里的运行时结构对应。

---

## 第16页：本集小结

**标题**：小结：runtime application 是启动边界

**演讲稿**：
这一集我们讲了 application 的第一种类型：runtime application。

它的特点是：

- 有 application resource file，也就是 `.app` 文件。
- 通常有 application callback module。
- `mod` 字段指定启动入口。
- `start/2` 通常启动 top supervisor。
- 启动后会拥有自己的 supervision tree 和 worker process。
- 在 Observer 的 Applications 页面中，可以看到它的运行时结构。

最重要的一句话是：runtime application 是 OTP 系统的启动边界，但真正长期工作的，是它启动出来的 supervisor 和 worker process。

下一集我们讲另一种 application：library application。它也会出现在 application 列表里，但它通常没有独立进程树。我们会用 Erlang 数学库 `math` 做例子，看看它和 runtime application 到底哪里不同。

---

## 截图与素材清单

| 素材 | 建议内容 | 用途 |
|------|----------|------|
| runtime_app_rebar_new.png | `rebar3 new app demo_runtime_app` 命令 | 展示工具一键生成 application 骨架 |
| runtime_app_rebar_shell.png | `rebar3 shell --sname application_demo` | 展示启动 runtime application |
| runtime_app_app_file.png | `.app.src` 或 `.app` 文件 | 展示 `mod` 和 `applications` 字段 |
| runtime_app_callback.png | application callback module | 展示 `start/2` 启动 top supervisor |
| runtime_app_observer_app.png | Observer 选中 `full_otp_app` | 展示 runtime application |
| runtime_app_observer_tree.png | Observer 展开 supervision tree | 展示启动后的进程树 |
| runtime_app_shell_api.png | `application:which_applications/0` 与 `supervisor:which_children/1` | 展示命令行验证 |

---

## 本集核心表达

```text
application 的实现机制很复杂，
但对使用者来说入口很单一：

.app 配置
  -> application callback
      -> top supervisor
          -> supervision tree

工具链已经把大部分创建、编译和启动细节包装好了。
学习 application，不是为了背内部实现，
而是为了看懂 OTP 系统从哪里启动、启动以后在 Observer 里为什么是一棵树。
```
