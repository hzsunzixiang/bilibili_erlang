# 第4集：Application（二）library application：代码库也是 OTP 应用

> 与后续幻灯片逐页对应
> 目标受众：已经看过第 3 集 runtime application 的 OTP 初学者
> 时长目标：8-10 分钟

---

## 第1页：封面

**标题**：Application（二）library application
**副标题**：没有独立进程树，也仍然是 OTP application

**演讲稿**：
大家好，这一集继续讲 application。上一集我们讲的是 runtime application：它启动后会创建 supervisor 和 worker process，在 Observer 里能看到一棵运行时进程树。

这一集我们讲另一种 application：library application。它看起来更“安静”：通常没有独立进程，没有 top supervisor，也没有 application callback module。但它仍然是 OTP application 的一部分。

---

## 第2页：回顾两种正规叫法

**标题**：runtime application vs library application

**演讲稿**：
先回顾一下上一集的命名。

本系列采用这组叫法：

```text
runtime application
  又称 active application / process-owning application

library application
  又称 passive application / code-only application
```

runtime application 强调运行时进程所有权。它启动后会拥有 supervision tree。

library application 强调代码提供能力。它主要提供模块、函数和元数据，被其他 application 调用或依赖。

这两者不是“真 application”和“假 application”的区别。它们都是 OTP application，只是运行时形态不同。

---

## 第3页：library application 的核心特征

**标题**：library application：提供能力，不启动服务

**演讲稿**：
library application 的核心特征可以概括成一句话：它提供代码能力，但通常不拥有自己的长期运行进程。

它通常具备这些特点：

- 有 application resource file，也就是 `.app` 文件。
- 提供若干模块和函数。
- 可以被其他 application 声明为 dependency。
- 通常没有 `mod` 字段。
- 通常没有 application callback module。
- 通常不会启动 top supervisor。

所以 library application 更像一个被 OTP 管理和打包的代码库。

---

## 第4页：为什么 library 也叫 application

**标题**：为什么代码库也叫 application？

**演讲稿**：
很多人第一次听到 library application 会疑惑：既然它没有独立进程，为什么还叫 application？

原因是 OTP application 不只是“运行中的服务”，它也是 release、依赖、版本、模块集合和元数据的管理单元。

一个 library application 可以声明：

- 自己的名字。
- 版本号。
- 包含哪些模块。
- 依赖哪些 application。
- 描述、许可证、链接等元数据。

这些信息对构建工具、release 工具、代码加载和依赖管理都很重要。

---

## 第5页：以 math 为例

**标题**：例子：Erlang 数学库 `math`

**演讲稿**：
这一集我们用 Erlang 自带的数学库 `math` 作为例子。

`math` 模块提供常见数学函数，比如：

```erlang
math:sqrt(9).
math:sin(3.1415926).
math:pow(2, 10).
math:log(10).
```

调用这些函数时，我们不会想到“启动一个数学服务进程”。这就是 library application 的典型感觉：它提供函数能力，而不是提供一个长期运行的服务。

这里要注意：用户日常直接接触到的是 `math` 模块；它所在的 OTP 组件会以 application 的形式参与系统组织和发布。

---

## 第6页：和 runtime application 的第一处不同

**标题**：不同点一：没有自己的 supervisor tree

**演讲稿**：
第一处不同：library application 通常没有自己的 supervisor tree。

runtime application 的结构像这样：

```text
full_otp_app
  -> full_otp_app_app:start/2
      -> full_otp_app_sup
          -> kv_server
          -> traffic_light
```

library application 更像这样：

```text
library application
  -> module_a:function/1
  -> module_b:function/2
  -> module_c:function/3
```

它被调用时执行函数，但不会因为“作为 application 存在”就自动创建一棵进程树。

---

## 第7页：和 runtime application 的第二处不同

**标题**：不同点二：通常没有 `mod` 字段

**演讲稿**：
runtime application 的 `.app` 文件里通常有 `mod` 字段，用来指定启动 callback。

例如上一集的 demo：

```erlang
{mod, {full_otp_app_app, []}}
```

library application 通常没有这个字段。没有 `mod` 字段意味着：application controller 没有一个 callback module 需要调用，也就不会进入 `start/2` 再启动 top supervisor 的流程。

所以判断一个 application 是否是 runtime application，一个直观线索就是看它有没有启动 callback，以及启动后是否创建自己的 supervision tree。

---

## 第8页：和 runtime application 的第三处不同

**标题**：不同点三：在列表中存在，但不一定有树

**演讲稿**：
第三处不同，也是这一集最适合用 Observer 展示的地方：library application 可能会出现在 application 列表里，但你不会看到像 runtime application 那样完整展开的进程树。

这很正常。

application 列表回答的是：当前系统中有哪些 application 被加载或启动、哪些组件参与了运行环境。

supervision tree 回答的是：哪些 application 拥有自己的运行时进程结构。

library application 在前一个问题里有存在感，但在后一个问题里通常很安静。

**截图提示**：
人工截图时，可以在 Observer Applications 页面里对比：

- `full_otp_app`：能展开 supervision tree。
- library 类组件：在 application 列表中存在，但没有对应的业务进程树。

---

## 第9页：用 shell 演示 math

**标题**：Shell 演示：调用的是函数，不是服务

**演讲稿**：
现在用 shell 做一个最简单的演示。

```erlang
1> math:sqrt(9).
3.0

2> math:pow(2, 10).
1024.0

3> math:sin(math:pi()).
1.2246467991473532e-16
```

这些调用没有启动一个 `math_server`，也没有创建一个叫 `math_sup` 的 supervisor。

函数调用结束以后，结果直接返回。这和上一集的 `full_otp_app` 完全不同：`full_otp_app` 启动后会留下长期运行的 supervisor 和 worker process。

---

## 第10页：library application 的价值

**标题**：library application 的价值在哪里？

**演讲稿**：
library application 的价值不在于管理进程，而在于管理代码能力。

它让一组模块成为可声明、可依赖、可版本化、可发布的 OTP 单元。

对大型 Erlang 系统来说，这非常重要。因为一个 release 不是把所有 `.beam` 文件随便丢到一起，而是由多个 application 组成。每个 application 都有自己的元数据和依赖关系。

runtime application 负责“跑起来”；library application 负责“提供能力”。

---

## 第11页：library application 不是工具模块目录

**标题**：不要把 library application 降级成普通目录

**演讲稿**：
这里也要避免另一个误解：library application 不只是一个普通工具模块目录。

普通目录只是文件组织方式；library application 是 OTP release 认识的 application 单元。

它可以被写进依赖列表，可以被工具链编译、打包、加载，也可以有自己的版本和元信息。

所以在工程层面，library application 仍然很正式。它只是没有自己的运行时进程树。

---

## 第12页：什么时候做成 library application

**标题**：什么时候选择 library application？

**演讲稿**：
什么时候适合做成 library application？

典型场景包括：

- 通用算法库。
- 编码解码工具。
- 协议解析模块。
- 业务领域的纯函数工具集。
- 被多个 runtime application 共享的公共代码。
- 不需要长期进程、不需要 supervision tree 的基础能力。

如果一个组件只是提供函数能力，不需要自己维护状态进程，就更适合做成 library application。

---

## 第13页：什么时候不应该做成 library application

**标题**：如果拥有进程，就不要伪装成 library

**演讲稿**：
反过来说，如果一个组件需要长期运行进程，就不应该简单地伪装成 library。

比如它需要：

- 维护连接池。
- 持有缓存状态。
- 定时执行后台任务。
- 监听端口。
- 消费消息队列。
- 监督一组 worker。

这些都说明它有运行时生命期。这个时候更适合设计成 runtime application，把启动入口和 supervision tree 明确表达出来。

---

## 第14页：两种 application 对比

**标题**：runtime vs library 总对比

**演讲稿**：
我们用一张表总结两种 application：

| 对比项 | runtime application | library application |
|--------|---------------------|---------------------|
| 正规别名 | active / process-owning application | passive / code-only application |
| 是否有 `.app` 文件 | 有 | 有 |
| 是否通常有 `mod` 字段 | 有 | 通常没有 |
| 是否有 callback module | 通常有 | 通常没有 |
| 是否启动 top supervisor | 通常会 | 通常不会 |
| 是否拥有长期进程 | 通常拥有 | 通常不拥有 |
| Observer 中的表现 | 可看到 supervision tree | 可能只在 application 列表中出现 |
| 典型用途 | 服务、后台任务、状态进程、连接池 | 数学库、工具库、协议库、公共模块 |

这张表是本集的核心复习材料。

---

## 第15页：和 Observer 主线对齐

**标题**：Observer 看到的差异，本质是运行时差异

**演讲稿**：
现在我们把两集 application 和前两集 Observer 串起来。

Observer 不是在教我们背术语，它是在展示运行时事实。

如果一个 application 是 runtime application，我们会看到它启动出来的 supervisor 和 worker。

如果一个 application 是 library application，我们可能只在 application 列表、依赖关系或代码加载层面感知到它，而不会看到一棵属于它的业务进程树。

这就是为什么先学 Observer 再学 application 会更自然：我们先看到现象，再解释结构。

---

## 第16页：结尾总结

**标题**：小结：两种 application，两个维度

**演讲稿**：
这一集我们讲了第二类 application：library application。

它的特点是：

- 主要提供模块和函数。
- 通常没有独立进程。
- 通常没有 application callback module。
- 通常不会启动 top supervisor。
- 仍然可以作为 OTP application 被依赖、版本化、打包和发布。
- 在 application 列表中可能存在，但不一定有可展开的 supervision tree。

到这里，两种 application 就完整了：

```text
runtime application：负责把系统跑起来
library application：负责给系统提供代码能力
```

后面再讲 supervisor、gen_server、gen_statem 时，我们主要讨论的是 runtime application 启动出来的那棵进程树。也就是说，从下一集开始，我们会沿着这棵树继续往下走，进入 supervisor。

---

## 截图与素材清单

| 素材 | 建议内容 | 用途 |
|------|----------|------|
| library_math_shell.png | shell 中调用 `math:sqrt/1`、`math:pow/2` | 展示函数调用而不是服务进程 |
| library_application_list.png | Observer Applications 列表中展示 library 类组件 | 展示 library application 也可能出现在列表中 |
| runtime_vs_library_observer.png | `full_otp_app` 与 library 类组件对比 | 展示一个有 supervision tree，一个没有业务进程树 |
| runtime_vs_library_table.png | 两类 application 对比表 | 用于总结页 |
| application_dependency_view.png | `.app` 文件中 dependencies 示例 | 展示 library application 的依赖价值 |

---

## 本集核心表达

```text
不是所有 OTP application 都拥有进程树。

runtime application
  -> 有启动入口
  -> 启动 supervisor
  -> 拥有长期运行的 process

library application
  -> 提供模块和函数
  -> 通常没有独立进程
  -> 仍然是 release 和依赖管理中的正式 application 单元

两者都是 application，区别在于运行时形态。
```
