# Erlang Observer UI — 从 Erlang Process 看见 BEAM，再进入 OTP 应用结构

> 与 `presentation.tex` 逐页对应
> 目标受众：Erlang 和 OTP 初学者
> 时长目标：8-12分钟

## 第1页：封面

**标题**：Erlang Observer UI
**副标题**：先看见 Erlang Process，再理解 OTP 如何组织它们

**演讲稿**：
大家好，这一集我们来看 Erlang Observer 的图形界面。我们先不急着讲复杂的 OTP 代码，而是先看见运行中的 Erlang Process。等你能看到这些进程，再理解 application、supervisor 和 worker，就会自然很多。

---

## 第2页：进入 OTP 之前，先看 Erlang Process

**标题**：进入 OTP 之前，先看 Erlang Process

**演讲稿**：
理解 OTP 之前，最好先理解 Erlang Process。Erlang 很多能力都建立在进程模型上，连接、会话、任务和状态，都可以被建模成一个个轻量进程。后面讲 OTP，其实就是讲怎么组织、监督和恢复这些进程。

---

## 第3页：一个 Erlang VM 里可以有很多 Process

**标题**：一个 Erlang VM 里可以有很多 Process

**演讲稿**：
这里要区分操作系统进程和 Erlang 虚拟机里的进程。一个 Erlang 虚拟机本身通常只是操作系统里的一个进程，但它内部可以运行大量 Erlang Process。这也是 Erlang 适合高并发系统的重要原因。

---

## 第4页：它叫 Process，但不是操作系统进程

**标题**：它叫 Process，但不是操作系统进程

**演讲稿**：
Erlang Process 不是操作系统进程，也不是普通线程。它是由 BEAM 虚拟机调度的语言级并发实体，非常轻量。你可以把它类比成协程，但在 Erlang 里，它有更完整的消息、状态和容错语义。

---

## 第5页：为什么说 Erlang Process 很神奇？

**标题**：为什么说 Erlang Process 很神奇？

**演讲稿**：
每个 Erlang Process 都有自己的邮箱、状态、堆、栈和进程标识。进程之间主要靠消息协作，而不是共享内存。这个模型让失败隔离更清晰，也为后面的 supervisor 监督机制打下基础。

---

## 第6页：最神奇的地方：不仅有 Process，而且还能直接看到它

**标题**：最神奇的地方：不仅有 Process，而且还能直接看到它

**演讲稿**：
很多语言都有轻量并发，但 Erlang 特别适合教学的一点是，你可以直接看到运行现场。Observer 能展示进程列表、邮箱、内存、当前函数和调用栈。也就是说，并发不是黑盒，而是可以被观察和分析的对象。

---

## 第7页：Processes：先看见 Erlang process

**标题**：Processes：先看见 Erlang process

**演讲稿**：
这页是 Observer 的 Processes 页面。我们先关注一个事实：worker 最终都会落到具体 Erlang Process 上。内存、消息队列和执行次数这些指标，都能帮助我们判断一个进程是否异常。

---

## 第8页：Process Internals：Messages、Dictionary 和 Stack Trace

**标题**：Process Internals：Messages、Dictionary 和 Stack Trace

**演讲稿**：
进入某个进程之后，可以继续看它的内部信息。Messages 表示还没处理的消息，Stack Trace 能帮助我们判断它卡在哪里。这里的重点不是背字段，而是建立一种排查直觉：问题最终可以落到某个进程的运行现场。

---

## 第9页：Process Data：通过 Table Viewer 看表数据

**标题**：Process Data：通过 Table Viewer 看 ETS 和 DETS

**演讲稿**：
有些进程不仅保存自己的状态，还会拥有表数据。Observer 的表查看器可以帮助我们查看运行时表内容。后面如果某个缓存进程或存储进程有问题，我们就可以从进程继续追到它背后的数据。

---

## 第10页：如果有几十万个 Process，怎么办？

**标题**：如果有几十万个 Process，怎么办？

**演讲稿**：
当系统里有大量进程时，问题就来了：谁来启动它们，谁来重启它们，谁来管理依赖关系？答案不是手写一堆管理代码，而是 OTP。OTP 的 application、supervisor 和 worker，就是为组织这些进程而存在的。

---

## 第11页：Let it crash：不是放任崩溃，而是有人接住

**标题**：Let it crash：不是放任崩溃，而是有人接住

**演讲稿**：
Let it crash 不是让程序随便崩，而是把失败控制在合适的边界里。Process 负责隔离失败，supervisor 负责恢复失败，application 负责组织系统。这样，崩溃就从灾难变成了可管理的恢复流程。

---

## 第12页：启动 demo：用 Observer 观察一个 OTP 应用

**标题**：启动 demo：用 Observer 观察一个 OTP 应用

**演讲稿**：
接下来我们启动一个完整的小型 OTP 应用，然后打开 Observer。这个 demo 里包含 application、supervisor、gen server 和 gen statem。这样我们不是看静态概念，而是看真实运行起来的 OTP 结构。

---

## 第13页：正式进入 OTP：从 Applications 看 Process 如何被组织

**标题**：正式进入 OTP：从 Applications 看 Process 如何被组织

**演讲稿**：
现在我们从 Processes 页面回到 Applications 页面。前面我们已经知道，系统里有很多 Erlang Process。Applications 页面要回答的是：这些进程在 OTP 里是怎么被 application、supervisor 和 worker 组织起来的。

---

## 第14页：full otp app：一个完整 OTP 小工程

**标题**：full otp app：一个完整 OTP 小工程

**演讲稿**：
这个 demo 的目的不是做复杂业务，而是把常见 OTP 组件放在一个运行时环境里。它有一个 application 入口，有顶层 supervisor，也有 worker 和子 supervisor。这样我们可以在 Observer 里一次看清主要结构。

---

## 第15页：OTP 层级：从 Application 组织到 BEAM Process

**标题**：OTP 层级：从 Application 组织到 BEAM Process

**演讲稿**：
这张图把主线串起来：application 组织系统，supervisor 组织和监督子进程，worker 执行业务逻辑。最后，不管是 gen server 还是 gen statem，运行时都会落到 BEAM 管理的 Erlang Process 上。

---

## 第16页：Applications：看 OTP 如何组织运行中的 Process

**标题**：Applications：看 OTP 如何组织运行中的 Process

**演讲稿**：
在 Applications 页面，我们既能看到 Erlang 自带的系统 application，也能看到我们的业务 application。这里不是在看配置文件，而是在看运行中的系统结构。Observer 把 OTP 的组织关系变成了可以点击和展开的对象。

---

## 第17页：full otp app：把代码映射到运行时

**标题**：full otp app：把代码映射到运行时

**演讲稿**：
选中 demo application 后，我们可以看到它的状态、启动信息和依赖关系。更重要的是，它可以继续展开到监督树。这样，代码里的 application 配置，就和运行时的 OTP 结构对应起来了。

---

## 第18页：Supervisor Tree：Applications 页面最重要的能力

**标题**：Supervisor Tree：Applications 页面最重要的能力

**演讲稿**：
这一页是本集最关键的画面。supervisor tree 不是文档里的概念图，而是正在运行的进程关系图。你能看到 root supervisor、子 supervisor 和 worker，也能理解 OTP 为什么能做容错恢复。

---

## 第19页：Nested Supervisor：OTP 可以分层组织系统

**标题**：Nested Supervisor：OTP 可以分层组织系统

**演讲稿**：
实际系统通常不会只有一层 supervisor。子系统可以继续由子 supervisor 管理，比如缓存、存储或连接模块。分层组织的好处是边界更清楚，失败恢复也更容易控制在局部范围内。

---

## 第20页：从 OTP worker 回到具体 Process

**标题**：从 OTP worker 回到具体 Process

**演讲稿**：
现在我们再从 OTP 结构回到具体进程。一个 worker 在代码里可能是 gen server 或 gen statem，但在运行时，它就是一个有状态、有邮箱、有链接关系的 Erlang Process。Observer 帮我们把这两层连接起来。

---

## 第21页：gen server：查看 kv server 进程

**标题**：gen server：查看 kv server 进程

**演讲稿**：
这里我们看一个 gen server 对应的进程。它有进程标识、注册名、链接关系、消息队列、内存和执行指标。请注意，gen server 不是一个抽象对象，它最终就是一个正在运行的进程。

---

## 第22页：State：看见 gen server 的私有状态

**标题**：State：看见 gen server 的私有状态

**演讲稿**：
gen server 的回调函数会返回新的状态，而 Observer 可以让我们直接看到这个状态。教学时这非常有用，因为学生不只是看代码，还能看到回调返回值如何变成运行时状态。

---

## 第23页：gen statem：状态机也能直接观察

**标题**：gen statem：状态机也能直接观察

**演讲稿**：
状态机同样可以被观察。比如交通灯当前是红灯、绿灯还是黄灯，都可以在运行时看到。这样学习 gen statem 时，就不只是理解回调，还能看到状态迁移在系统里真实发生。

---

## 第24页：小结：这条理解路径是什么？

**标题**：小结：这条理解路径是什么？

**演讲稿**：
这一集的主线是：先看见 Erlang Process，再理解为什么需要 OTP 来组织它们。Observer 把 process、application、supervisor 和 worker 这些概念变成了运行时可见的系统。下一步，我们就可以更深入地讲 application 和后面的 OTP 行为模式。
