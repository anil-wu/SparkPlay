# 平台核心模型（Manifest 驱动 · Final）

本文档定义平台的**核心领域模型与命名规范**，用于统一多技术栈软件工程（Web / Unity / Server / Agent 等）的构建、版本与发布。

---

## 一、核心对象与命名总览

| 层级 | 中文名称 | 英文建议 | 说明 |
|---|---|---|---|
| 顶层 | 项目 | Project | 文件系统命名空间与逻辑容器 |
| 工程 | 软件工程 | Software | 一套可构建的软件工程 |
| 工程描述 | **软件工程 Manifest** | Software Manifest | 描述软件工程事实的文件 |
| 工程版本 | 软件工程版本 | Software Version | 即 Software Manifest 的版本 |
| 构建 | 构建 | Build | 基于某工程版本的派生过程 |
| 构建描述 | **构建 Manifest** | Build Manifest | 描述一次构建结果的文件 |
| 构建版本 | 构建版本 | Build Version | 即 Build Manifest |
| 发布 | 发布 | Release | 指向某构建版本的逻辑引用 |

---

## 二、平台核心模型（正式定义）

### 1. Project（项目）

**定义**：
> Project 是文件系统命名空间，其下包含多个软件工程及其产生的所有文件。

**要点**：
- 不关心技术栈
- 不区分客户端 / 服务端
- 不直接参与构建
- 负责组织与归属

---

### 2. Software（软件工程）

**定义**：
> Software 是 Project 之下的一套可独立构建和运行的软件工程。

**特征**：
- 由文件组成
- 具备明确的工程结构
- 技术栈不同，但抽象一致

---

### 3. 软件工程 Manifest（Software Manifest）

**定义**：
> 软件工程 Manifest 是对一套软件工程的结构、技术栈和构建规则的事实描述文件。

**关键属性**：
- Manifest 是一个**文件**
- 由文件系统统一管理
- 是软件工程的**唯一事实来源（Source of Truth）**

**典型描述内容**：
- 技术栈 / Runtime Profile
- 工程结构约定
- 入口点
- 构建规则
- 依赖信息

---

### 4. 软件工程版本（Software Version）

**定义**：
> 软件工程的版本即软件工程 Manifest 的版本。

**等价表述**：
> 只要 Software Manifest 发生变化，就产生一个新的软件工程版本。

**说明**：
- 不直接对文件集合做版本
- 文件内容以不可变 Blob 形式存在
- 版本锚定在 Manifest 上

---

### 5. Build（构建）

**定义**：
> 构建是基于某一软件工程 Manifest 版本的派生过程。

**输入 / 输出**：
- 输入：Software Manifest 的某一版本
- 输出：构建产物（0..n） + 构建 Manifest
- 构建本身不修改工程版本

---

### 6. 构建 Manifest（Build Manifest）

**定义**：
> 构建 Manifest 是对一次构建结果的结构化描述文件，是构建版本的唯一事实来源。

**系统强约束**：
- 每一次构建 **必须** 产生一个构建 Manifest
- 构建 Manifest **不可变（Immutable）**
- 没有构建 Manifest，即不存在构建版本

**构建产物形态（示例）**：
- 单文件（软件包、可执行文件）
- 多文件结构（dist / bin）
- 镜像（OCI / Docker）
- 任意组合

> 构建产物永远从属于某一 Build Manifest。

---

### 7. Build Version（构建版本）

**定义**：
> 构建版本即构建 Manifest 所描述的那一次构建结果。

**说明**：
- Build Version = Build Manifest
- 是发布、回滚、部署的最小单位

---

### 8. Release（发布）

**定义**：
> 发布是对某一个构建版本（Build Manifest）的选择与引用，而非对文件的复制或修改。

**语义约束**：
- 发布是逻辑操作
- 发布不产生新文件
- 支持快速切换与回滚

---

## 三、完整生命周期示意

```text
Project
 └─ Software
     ├─ software.manifest.json   (v1)
     ├─ software.manifest.json   (v2)  ← 软件工程版本
     │
     ├─ Build
     │   ├─ build.manifest.json  ← 构建版本
     │   ├─ artifacts / image / dist
     │
     ├─ Release → 指向 build.manifest.json
```

---

## 四、平台宪法级规则（强约束）

1. **软件工程的版本只由 Software Manifest 决定**
2. **构建版本只由 Build Manifest 决定**
3. **发布永远只引用 Build Manifest**

---

## 五、一句话总结

> **Project 管理文件与工程，**  
> **Software Manifest 定义工程，**  
> **Build Manifest 定义构建，**  
> **Release 选择结果。**

---

## 六、设计原则

- 文件系统优先（FS-First）
- Manifest 驱动（Manifest-Driven）
- 技术栈无关
- AI / CI / Sandbox 统一友好
