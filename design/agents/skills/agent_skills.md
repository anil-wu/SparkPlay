# Agent Skills 系统设计文档

## 1. 概述

本文档描述了 Agent Skills 系统的完整设计方案。Skills 系统为 Agent 提供了可扩展的、模块化的专业技能能力，使 Agent 能够针对特定领域任务采用最佳实践。

### 1.1 设计目标

- **可扩展性**: 支持动态添加新技能，无需修改核心代码
- **模块化**: 每个技能独立封装，包含完整的指令和资源
- **上下文感知**: 基于文件路径和任务上下文自动发现相关技能
- **按需加载**: 仅在需要时加载技能指令，减少内存占用
- **与 ADK 集成**: 遵循 Google ADK 框架规范，使用原生 `google.adk.tools.skill_toolset.SkillToolset`

### 1.2 核心概念

| 术语 | 定义 |
|------|------|
| **Skill** | 一个独立的技能单元，包含元数据、指令和资源 |
| **SKILL.md** | 技能定义文件，包含 frontmatter 元数据和 markdown 指令 |
| **Skill Loader** | 技能加载器，从文件系统加载技能到内存 |
| **SkillToolset** | Google ADK 原生工具集，提供 `load_skill` 和 `load_skill_resource` 工具 |

### 1.3 技术选型

**采用 Google ADK 原生 `SkillToolset`**，原因：

1. ✅ **官方支持**: Google 官方维护，兼容性好
2. ✅ **开箱即用**: 已实现 `load_skill` 和 `load_skill_resource` 工具
3. ✅ **自动注入**: `process_llm_request` 自动将技能列表注入系统指令
4. ✅ **标准化**: 遵循 ADK 技能规范，技能可复用

**自研组件**:
- `SkillLoader`: 从文件系统加载技能
- `SkillRegistry`: 技能注册表（可选，用于动态管理）

### 1.2 核心概念

| 术语 | 定义 |
|------|------|
| **Skill** | 一个独立的技能单元，包含元数据、指令和资源 |
| **SKILL.md** | 技能定义文件，包含 frontmatter 元数据和 markdown 指令 |
| **Skill Discovery** | 基于目标路径扫描发现可用技能的机制 |
| **Skill Registry** | 技能注册表，管理技能的加载和查询 |
| **Skill Toolset** | ADK 工具集，提供技能发现和加载工具 |

---

## 2. 系统架构

### 2.1 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        phaser_agent (Root)                       │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    SkillToolset                              ││
│  │  ┌─────────────────┐  ┌─────────────────┐                   ││
│  │  │ discover_skills │  │   load_skill    │                   ││
│  │  └─────────────────┘  └─────────────────┘                   ││
│  └─────────────────────────────────────────────────────────────┘│
│                              ↓                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    SkillRegistry                             ││
│  │         - 技能缓存管理                                       ││
│  │         - 技能查询接口                                       ││
│  │         - 按需加载                                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                              ↓                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    SkillDiscovery                            ││
│  │         - 扫描 skills/ 目录                                  ││
│  │         - 解析 SKILL.md                                      ││
│  │         - 文件路径模式匹配                                   ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    skills_data/                                  │
│  ├── phaser-game/                                               │
│  │   ├── SKILL.md                                               │
│  │   ├── references/                                            │
│  │   └── assets/                                                │
│  ├── typescript/                                                │
│  └── web-build/                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 组件职责

| 组件 | 职责 |
|------|------|
| **SkillToolset** | ADK 工具集，提供 `discover_skills` 和 `load_skill` 工具 |
| **SkillRegistry** | 单例注册表，管理技能生命周期和缓存 |
| **SkillDiscovery** | 文件系统扫描和模式匹配 |
| **SkillParser** | SKILL.md 解析 (frontmatter + body) |

---

## 3. 数据模型

### 3.1 SkillFrontmatter

技能元数据，从 SKILL.md 的 YAML frontmatter 解析。

```python
class SkillFrontmatter(BaseModel):
    """技能元数据"""
    name: str                          # 技能名称 (kebab-case)
    version: str = "1.0.0"             # 版本号
    description: str                   # 技能描述
    file_patterns: list[str] = []      # 关联文件模式
    triggers: list[str] = []           # 触发关键词
    priority: int = 10                 # 优先级 (越小越优先)
    dependencies: list[str] = []       # 依赖的其他技能
    allowed_tools: list[str] = []      # 允许使用的工具
```

### 3.2 SkillResources

技能资源容器。

```python
class SkillResources(BaseModel):
    """技能资源"""
    references: dict[str, str] = {}    # 参考文档
    assets: dict[str, str] = {}        # 资产文件
    scripts: dict[str, str] = {}       # 脚本文件
```

### 3.3 Skill

完整技能定义。

```python
class Skill(BaseModel):
    """完整技能"""
    frontmatter: SkillFrontmatter
    instructions: str                  # SKILL.md 主体内容
    resources: SkillResources
    skill_path: str                    # 技能目录路径
    
    @property
    def name(self) -> str:
        return self.frontmatter.name
    
    @property
    def description(self) -> str:
        return self.frontmatter.description
```

---

## 4. 技能目录结构

### 4.1 标准结构

```
skills_data/
└── <skill-name>/
    ├── SKILL.md              # 必需：技能定义
    ├── references/           # 可选：参考文档
    │   ├── <doc>.md
    │   └── ...
    ├── assets/               # 可选：资产文件
    │   ├── <template>.ts
    │   └── ...
    └── scripts/              # 可选：脚本文件
        ├── <script>.sh
        └── ...
```

### 4.2 SKILL.md 格式

```markdown
---
name: phaser-game
version: 1.0.0
description: Phaser 游戏开发技能，用于创建和管理 Phaser 游戏项目
file_patterns:
  - "**/*.ts"
  - "**/phaser*.js"
  - "**/game/**/*.ts"
triggers:
  - "创建游戏场景"
  - "添加精灵"
  - "游戏动画"
priority: 5
dependencies:
  - typescript
allowed_tools:
  - read_file
  - write_file
  - edit_file
  - run_npm
---

# Phaser 游戏开发技能

## 概述
此技能帮助你开发基于 Phaser 框架的 HTML5 游戏。

## 使用场景
- 创建新的游戏场景
- 添加精灵和动画
- 处理用户输入
- 管理游戏状态

## 工作流程

### 1. 创建场景
使用 `assets/scene-template.ts` 作为起点...

### 2. 添加精灵
...

## 最佳实践
- 始终在 preload 中加载资源
- 使用对象池管理频繁创建的对象
```

### 4.3 示例技能

#### 4.3.1 Phaser 游戏技能

```
skills_data/phaser-game/
├── SKILL.md
├── references/
│   ├── phaser-api-docs.md
│   └── game-architecture.md
└── assets/
    ├── scene-template.ts
    ├── sprite-config.json
    └── animation-helper.ts
```

#### 4.3.2 TypeScript 技能

```
skills_data/typescript/
├── SKILL.md
└── references/
    ├── ts-patterns.md
    └── tsconfig-best-practices.md
```

#### 4.3.3 Web 构建技能

```
skills_data/web-build/
├── SKILL.md
└── assets/
    ├── vite-config.ts
    └── webpack-config.js
```

---

## 5. 核心组件实现

### 5.1 SkillParser

SKILL.md 解析器。

```python
# skills/parser.py

import re
import yaml
from pathlib import Path
from typing import Tuple

class SkillParser:
    """SKILL.md 文件解析器"""
    
    FRONTMATTER_PATTERN = re.compile(r'^---\s*\n(.*?)\n---\s*\n(.*)', re.DOTALL)
    
    @classmethod
    def parse(cls, skill_md_path: Path) -> Tuple[dict, str]:
        """
        解析 SKILL.md 文件
        
        Args:
            skill_md_path: SKILL.md 文件路径
        
        Returns:
            (frontmatter_dict, body_content)
        """
        content = skill_md_path.read_text(encoding='utf-8')
        match = cls.FRONTMATTER_PATTERN.match(content)
        
        if not match:
            # 无 frontmatter，返回空元数据和完整内容
            return {}, content.strip()
        
        frontmatter_yaml = match.group(1)
        body = match.group(2).strip()
        
        frontmatter = yaml.safe_load(frontmatter_yaml) or {}
        
        return frontmatter, body
    
    @classmethod
    def validate(cls, frontmatter: dict) -> list[str]:
        """验证 frontmatter 必填字段"""
        errors = []
        
        if not frontmatter.get('name'):
            errors.append("缺少必填字段：name")
        
        if not frontmatter.get('description'):
            errors.append("缺少必填字段：description")
        
        name = frontmatter.get('name', '')
        if not re.match(r'^[a-z0-9]+(-[a-z0-9]+)*$', name):
            errors.append(f"name 格式不正确，应为 kebab-case: {name}")
        
        return errors
```

### 5.2 SkillDiscovery

技能发现服务。

```python
# skills/discovery.py

from pathlib import Path
from typing import Optional
import fnmatch

from .models import Skill, SkillFrontmatter
from .parser import SkillParser

class SkillDiscovery:
    """技能发现服务 - 基于目标文件路径扫描可用技能"""
    
    def __init__(self, skills_root: str):
        self.skills_root = Path(skills_root)
        self._skill_cache: dict[str, Skill] = {}
    
    def discover_skills(self, target_path: str) -> list[Skill]:
        """
        根据目标文件路径发现相关技能
        
        Args:
            target_path: 目标文件路径 (相对于工作区)
        
        Returns:
            匹配的技能列表 (按优先级排序)
        """
        matched_skills = []
        
        if not self.skills_root.exists():
            return []
        
        for skill_dir in self.skills_root.iterdir():
            if not skill_dir.is_dir():
                continue
            
            skill = self._load_skill(skill_dir)
            if not skill:
                continue
            
            # 检查文件模式匹配
            if self._matches_patterns(target_path, skill.frontmatter.file_patterns):
                matched_skills.append(skill)
        
        # 按优先级排序
        matched_skills.sort(key=lambda s: s.frontmatter.priority)
        return matched_skills
    
    def list_all_skills(self) -> list[Skill]:
        """列出所有可用技能"""
        skills = []
        
        if not self.skills_root.exists():
            return []
        
        for skill_dir in self.skills_root.iterdir():
            if not skill_dir.is_dir():
                continue
            
            skill = self._load_skill(skill_dir)
            if skill:
                skills.append(skill)
        
        return skills
    
    def _matches_patterns(self, path: str, patterns: list[str]) -> bool:
        """检查路径是否匹配任一模式"""
        if not patterns:
            return True  # 无模式限制则默认匹配
        
        for pattern in patterns:
            if fnmatch.fnmatch(path, pattern):
                return True
            if fnmatch.fnmatch(path.lower(), pattern.lower()):
                return True
        return False
    
    def _load_skill(self, skill_dir: Path) -> Optional[Skill]:
        """加载技能定义"""
        # 检查缓存
        cache_key = str(skill_dir)
        if cache_key in self._skill_cache:
            return self._skill_cache[cache_key]
        
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            return None
        
        try:
            # 解析 SKILL.md
            frontmatter_dict, body = SkillParser.parse(skill_md)
            
            # 验证
            errors = SkillParser.validate(frontmatter_dict)
            if errors:
                print(f"Skill validation errors in {skill_dir}: {errors}")
                return None
            
            # 加载资源
            resources = self._load_resources(skill_dir)
            
            # 创建技能对象
            skill = Skill(
                frontmatter=SkillFrontmatter(**frontmatter_dict),
                instructions=body,
                resources=resources,
                skill_path=str(skill_dir)
            )
            
            # 缓存
            self._skill_cache[cache_key] = skill
            return skill
            
        except Exception as e:
            print(f"Error loading skill from {skill_dir}: {e}")
            return None
    
    def _load_resources(self, skill_dir: Path) -> 'SkillResources':
        """加载技能资源"""
        from .models import SkillResources
        
        resources = SkillResources()
        
        # 加载 references/
        refs_dir = skill_dir / "references"
        if refs_dir.exists():
            for ref_file in refs_dir.glob("**/*.md"):
                rel_path = ref_file.relative_to(refs_dir)
                resources.references[str(rel_path)] = ref_file.read_text(encoding='utf-8')
        
        # 加载 assets/
        assets_dir = skill_dir / "assets"
        if assets_dir.exists():
            for asset_file in assets_dir.glob("**/*"):
                if asset_file.is_file():
                    rel_path = asset_file.relative_to(assets_dir)
                    resources.assets[str(rel_path)] = asset_file.read_text(encoding='utf-8')
        
        # 加载 scripts/
        scripts_dir = skill_dir / "scripts"
        if scripts_dir.exists():
            for script_file in scripts_dir.glob("**/*"):
                if script_file.is_file():
                    rel_path = script_file.relative_to(scripts_dir)
                    resources.scripts[str(rel_path)] = script_file.read_text(encoding='utf-8')
        
        return resources
```

### 5.3 SkillRegistry

技能注册表 (单例模式)。

```python
# skills/registry.py

from typing import Optional
from pathlib import Path

from .models import Skill, SkillFrontmatter
from .discovery import SkillDiscovery

class SkillRegistry:
    """技能注册表 - 管理技能的注册、查询和缓存"""
    
    _instance: Optional["SkillRegistry"] = None
    
    def __init__(self, skills_root: str):
        self.skills_root = Path(skills_root)
        self._skills: dict[str, Skill] = {}
        self._discovery = SkillDiscovery(skills_root)
    
    @classmethod
    def get_instance(cls, skills_root: str = None) -> "SkillRegistry":
        """获取单例实例"""
        if cls._instance is None:
            if skills_root is None:
                raise ValueError("skills_root required for first initialization")
            cls._instance = cls(skills_root)
        return cls._instance
    
    @classmethod
    def reset(cls):
        """重置单例 (用于测试)"""
        cls._instance = None
    
    def register_skill(self, skill: Skill) -> None:
        """注册技能"""
        self._skills[skill.frontmatter.name] = skill
    
    def get_skill(self, name: str) -> Optional[Skill]:
        """获取技能"""
        if name not in self._skills:
            self._load_skill_by_name(name)
        return self._skills.get(name)
    
    def list_skills(self) -> list[SkillFrontmatter]:
        """列出所有技能元数据"""
        self._ensure_loaded()
        return [s.frontmatter for s in self._skills.values()]
    
    def discover_for_path(self, target_path: str) -> list[Skill]:
        """为指定路径发现技能"""
        return self._discovery.discover_skills(target_path)
    
    def _load_skill_by_name(self, name: str) -> None:
        """按名称加载技能"""
        skill_dir = self.skills_root / name
        if not skill_dir.exists():
            return
        
        skill = self._discovery._load_skill(skill_dir)
        if skill:
            self._skills[name] = skill
    
    def _ensure_loaded(self) -> None:
        """确保所有技能已加载"""
        if not self._skills:
            for skill in self._discovery.list_all_skills():
                self._skills[skill.frontmatter.name] = skill
```

### 5.4 SkillToolset

ADK 工具集集成。

```python
# skills/skill_toolset.py

from google.adk.tools.base_toolset import BaseToolset
from google.adk.tools.base_tool import BaseTool
from google.adk.agents.readonly_context import ReadonlyContext
from google.adk.tools.tool_context import ToolContext
from typing import Any, Optional

from .registry import SkillRegistry
from .models import Skill

class DiscoverSkillsTool(BaseTool):
    """技能发现工具"""
    
    def __init__(self, registry: SkillRegistry):
        super().__init__(
            name="discover_skills",
            description="根据文件路径或关键词发现可用的技能",
        )
        self._registry = registry
    
    def _get_declaration(self) -> Any:
        from google.genai import types
        return types.FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters_json_schema={
                "type": "object",
                "properties": {
                    "target_path": {
                        "type": "string",
                        "description": "目标文件路径（用于匹配 file_patterns）",
                    },
                    "keywords": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "触发关键词列表（用于匹配 triggers，可选）",
                    },
                },
                "required": [],
            },
        )
    
    async def run_async(
        self,
        *,
        args: dict[str, Any],
        tool_context: ToolContext,
    ) -> Any:
        target_path = args.get("target_path", "")
        keywords = args.get("keywords", [])
        
        # 基于文件路径发现
        if target_path:
            skills = self._registry.discover_for_path(target_path)
        # 基于关键词发现（未来扩展）
        elif keywords:
            skills = self._registry.discover_by_keywords(keywords)
        else:
            # 返回所有技能
            skills = self._registry.list_all_skills()
        
        if not skills:
            return {
                "status": "success",
                "skills": [],
                "hint": "未找到匹配的技能，可尝试使用 load_skill 直接加载已知技能",
            }
        
        return {
            "status": "success",
            "skills": [
                {
                    "name": s.frontmatter.name,
                    "description": s.frontmatter.description,
                    "priority": s.frontmatter.priority,
                    "triggers": s.frontmatter.triggers,
                    "file_patterns": s.frontmatter.file_patterns,
                }
                for s in skills
            ],
            "hint": "使用 load_skill(name='<技能名>') 加载完整指令",
        }


class LoadSkillTool(BaseTool):
    """技能加载工具"""
    
    def __init__(self, registry: SkillRegistry):
        super().__init__(
            name="load_skill",
            description="加载指定技能的完整指令和资源",
        )
        self._registry = registry
    
    def _get_declaration(self) -> Any:
        from google.genai import types
        return types.FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters_json_schema={
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "技能名称",
                    },
                    "include_resources": {
                        "type": "boolean",
                        "description": "是否包含资源列表 (默认 false)",
                        "default": False,
                    },
                },
                "required": ["name"],
            },
        )
    
    async def run_async(
        self,
        *,
        args: dict[str, Any],
        tool_context: ToolContext,
    ) -> Any:
        skill_name = args.get("name")
        include_resources = args.get("include_resources", False)
        
        if not skill_name:
            return {
                "status": "error",
                "message": "技能名称是必填参数",
                "error_code": "MISSING_SKILL_NAME",
            }
        
        skill = self._registry.get_skill(skill_name)
        
        if not skill:
            return {
                "status": "error",
                "message": f"技能 '{skill_name}' 未找到",
                "error_code": "SKILL_NOT_FOUND",
            }
        
        result = {
            "status": "success",
            "skill_name": skill_name,
            "version": skill.frontmatter.version,
            "description": skill.frontmatter.description,
            "instructions": skill.instructions,
            "allowed_tools": skill.frontmatter.allowed_tools,
        }
        
        if include_resources:
            result["resources"] = {
                "references": list(skill.resources.references.keys()),
                "assets": list(skill.resources.assets.keys()),
                "scripts": list(skill.resources.scripts.keys()),
            }
        
        return result


class LoadSkillResourceTool(BaseTool):
    """技能资源加载工具"""
    
    def __init__(self, registry: SkillRegistry):
        super().__init__(
            name="load_skill_resource",
            description="加载技能的特定资源文件",
        )
        self._registry = registry
    
    def _get_declaration(self) -> Any:
        from google.genai import types
        return types.FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters_json_schema={
                "type": "object",
                "properties": {
                    "skill_name": {
                        "type": "string",
                        "description": "技能名称",
                    },
                    "resource_type": {
                        "type": "string",
                        "enum": ["references", "assets", "scripts"],
                        "description": "资源类型",
                    },
                    "resource_path": {
                        "type": "string",
                        "description": "资源文件路径 (相对于资源目录)",
                    },
                },
                "required": ["skill_name", "resource_type", "resource_path"],
            },
        )
    
    async def run_async(
        self,
        *,
        args: dict[str, Any],
        tool_context: ToolContext,
    ) -> Any:
        skill_name = args.get("skill_name")
        resource_type = args.get("resource_type")
        resource_path = args.get("resource_path")
        
        if not all([skill_name, resource_type, resource_path]):
            return {
                "status": "error",
                "message": "skill_name, resource_type, resource_path 都是必填参数",
                "error_code": "MISSING_PARAMETER",
            }
        
        skill = self._registry.get_skill(skill_name)
        if not skill:
            return {
                "status": "error",
                "message": f"技能 '{skill_name}' 未找到",
                "error_code": "SKILL_NOT_FOUND",
            }
        
        resources = skill.resources
        content = None
        
        if resource_type == "references":
            content = resources.references.get(resource_path)
        elif resource_type == "assets":
            content = resources.assets.get(resource_path)
        elif resource_type == "scripts":
            content = resources.scripts.get(resource_path)
        
        if content is None:
            return {
                "status": "error",
                "message": f"资源 '{resource_path}' 在技能 '{skill_name}' 中未找到",
                "error_code": "RESOURCE_NOT_FOUND",
            }
        
        return {
            "status": "success",
            "skill_name": skill_name,
            "resource_type": resource_type,
            "resource_path": resource_path,
            "content": content,
        }


class SkillToolset(BaseToolset):
    """技能工具集"""
    
    def __init__(self, skills_root: str = "skills_data"):
        """
        初始化技能工具集
        
        Args:
            skills_root: 技能库根目录路径（绝对路径或相对于项目根目录）
                        例如："skills_data" 或 "/absolute/path/to/skills"
        """
        self._skills_root = skills_root
        self._registry = SkillRegistry.get_instance(skills_root)
        self._tools = [
            DiscoverSkillsTool(self._registry),
            LoadSkillTool(self._registry),
            LoadSkillResourceTool(self._registry),
        ]
    
    async def get_tools(
        self,
        readonly_context: ReadonlyContext | None = None,
    ) -> list[BaseTool]:
        """返回工具列表"""
        return self._tools
    
    async def process_llm_request(
        self,
        *,
        tool_context: ToolContext,
        llm_request: Any,
    ) -> None:
        """
        将可用技能列表注入系统指令
        
        这是关键步骤，使 Agent 知道有哪些技能可用
        """
        skills = self._registry.list_skills()
        
        # 格式化为 XML 风格列表
        skills_xml = self._format_skills_xml(skills)
        
        skill_instruction = f"""
你可以使用专门的 'skills' 来帮助你完成复杂任务。每个技能包含特定领域的最佳实践和指令。

## 可用技能列表:

{skills_xml}

## 技能使用流程:

1. **发现技能**: 使用 `discover_skills(target_path="...")` 根据文件路径发现相关技能
2. **加载技能**: 使用 `load_skill(name="<技能名>")` 加载完整指令
3. **查看资源**: 使用 `load_skill_resource(...)` 查看技能的参考文档或模板
4. **执行任务**: 严格按照技能指令执行任务

## 重要提示:

- 如果某个技能与当前任务相关，**必须**先使用 `load_skill` 加载完整指令
- 技能指令中列出的步骤必须按顺序完成
- 技能可能依赖其他技能，注意检查 `dependencies` 字段
- 仅使用技能 `allowed_tools` 中列出的工具
"""
        
        llm_request.append_instructions([skill_instruction])
    
    def _format_skills_xml(self, skills: list['SkillFrontmatter']) -> str:
        """格式化技能列表为 XML 风格"""
        lines = []
        for skill in sorted(skills, key=lambda s: s.priority):
            lines.append(f"<skill>")
            lines.append(f"  <name>{skill.name}</name>")
            lines.append(f"  <version>{skill.version}</version>")
            lines.append(f"  <description>{skill.description}</description>")
            if skill.triggers:
                lines.append(f"  <triggers>{', '.join(skill.triggers)}</triggers>")
            if skill.file_patterns:
                lines.append(f"  <file_patterns>{', '.join(skill.file_patterns)}</file_patterns>")
            lines.append(f"</skill>")
        return "\n".join(lines)
```

---

## 6. 与 Agent 集成

### 6.1 修改 agent.py

在根 Agent 创建时添加 SkillToolset。

```python
# agent.py

from google.adk.agents.llm_agent import Agent
from google.adk.models.lite_llm import LiteLlm

# 新增导入
from skills.skill_toolset import SkillToolset

def create_root_agent(
    agent_model_configs: Mapping[str, Any],
) -> Agent:
    # ... 现有代码 ...
    
    # 创建子 Agent
    sub_agents = [
        project_manager_agent,
        coder_agent, 
        verifier_agent, 
        build_agent,
        # ...
    ]
    
    # 创建技能工具集
    skill_toolset = SkillToolset(
        skills_root="skills_data"  # 技能目录
    )
    
    return Agent(
        model=_litellm_from_agent_config("phaser_agent", agent_model_configs),
        name="phaser_agent",
        description=_prompt_value("phaser_agent", agent_prompt_configs, "description"),
        instruction=_prompt_value("phaser_agent", agent_prompt_configs, "instruction"),
        sub_agents=sub_agents,
        toolsets=[skill_toolset],  # 添加技能工具集
    )
```

### 6.2 工具上下文（可选）

Skills 系统**不依赖** `tool_context.state` 中的任何键。技能库路径在 `SkillToolset` 初始化时已确定。

如果需要根据项目动态切换技能库，可以在创建 `SkillToolset` 时从 `tool_context.state` 读取：

```python
# 在 agent.py 中
async def create_skill_toolset(tool_context: ToolContext):
    # 从上下文获取自定义技能库路径（可选）
    custom_skills_root = tool_context.state.get("custom_skills_root")
    
    if custom_skills_root:
        return SkillToolset(skills_root=custom_skills_root)
    else:
        return SkillToolset(skills_root="skills_data")
```

---

## 7. 执行流程

### 7.1 完整流程图

```
用户请求："帮我创建一个 Phaser 游戏场景"
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 1. Agent 接收请求                                            │
│    - 解析用户意图                                            │
│    - 识别关键词："Phaser"、"创建"、"场景"                    │
└─────────────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. 技能发现 (可选)                                           │
│    Agent 调用：discover_skills(                              │
│        target_path="src/scenes/GameScene.ts",               │
│        keywords=["创建游戏场景", "Phaser"]                   │
│    )                                                        │
│    返回：[phaser-game (priority=5), typescript (priority=10)]│
└─────────────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. 技能选择                                                  │
│    Agent 根据以下因素选择:                                   │
│    - 技能描述匹配度                                          │
│    - 优先级 (越小越优先)                                     │
│    - triggers 关键词匹配                                    │
│    选择：phaser-game                                        │
└─────────────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. 技能加载                                                  │
│    Agent 调用：load_skill(name="phaser-game")               │
│    返回:                                                     │
│    - instructions: 完整指令文本                              │
│    - allowed_tools: [read_file, write_file, ...]            │
│    - resources: {references: [...], assets: [...]}          │
└─────────────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. 技能执行                                                  │
│    Agent 按照指令执行:                                       │
│    a) 读取 assets/scene-template.ts                          │
│    b) 创建新文件 src/scenes/MyScene.ts                       │
│    c) 添加 Phaser Scene 代码                                 │
│    d) 更新 manifest.json                                     │
└─────────────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. 结果验证                                                  │
│    verifier_agent 检查:                                     │
│    - 代码是否符合 TypeScript 规范                            │
│    - 是否遵循 Phaser 最佳实践                                │
│    - 文件是否保存到正确位置                                  │
└─────────────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. 返回结果给用户                                            │
│    - 成功消息                                                │
│    - 创建的文件路径                                          │
│    - 后续建议                                                │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 代码执行示例

```python
# 示例：Agent 内部逻辑

async def handle_user_request(user_query: str, tool_context: ToolContext):
    # 步骤 1: 发现技能
    discovery_result = await discover_skills.run_async(
        args={
            "target_path": "src/scenes/GameScene.ts",
            "keywords": ["创建游戏场景", "Phaser"]
        },
        tool_context=tool_context,
    )
    
    if discovery_result["skills"]:
        # 步骤 2: 选择最佳技能
        best_skill = discovery_result["skills"][0]  # 已按优先级排序
        
        # 步骤 3: 加载技能
        skill_data = await load_skill.run_async(
            args={"name": best_skill["name"], "include_resources": True},
            tool_context=tool_context,
        )
        
        # 步骤 4: 按照技能指令执行
        instructions = skill_data["instructions"]
        # ... 解析并执行指令 ...
        
        # 步骤 5: 如需资源，加载资源
        if needs_template:
            resource = await load_skill_resource.run_async(
                args={
                    "skill_name": best_skill["name"],
                    "resource_type": "assets",
                    "resource_path": "scene-template.ts",
                },
                tool_context=tool_context,
            )
            template_content = resource["content"]
            # ... 使用模板 ...
```

---

## 8. 文件结构

### 8.1 完整目录树

```
agents/phaser_agent/
├── skills/                           # 新增：技能系统模块
│   ├── __init__.py
│   ├── models.py                     # 数据模型
│   ├── parser.py                     # SKILL.md 解析器
│   ├── discovery.py                  # 技能发现
│   ├── registry.py                   # 技能注册表
│   └── skill_toolset.py              # ADK 工具集集成
│
├── skills_data/                      # 新增：技能数据目录
│   ├── phaser-game/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── phaser-api-docs.md
│   │   │   └── game-architecture.md
│   │   └── assets/
│   │       ├── scene-template.ts
│   │       ├── sprite-config.json
│   │       └── animation-helper.ts
│   │
│   ├── typescript/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── ts-patterns.md
│   │       └── tsconfig-best-practices.md
│   │
│   └── web-build/
│       ├── SKILL.md
│       └── assets/
│           ├── vite-config.ts
│           └── webpack-config.js
│
├── tools/                            # 现有工具
│   ├── filesystem.py
│   ├── commands.py
│   ├── work_space_manager.py
│   └── ...
│
├── agents/                           # 现有子 Agent
│   ├── coder_agent.py
│   ├── verifier_agent.py
│   ├── debugger_agent.py
│   └── ...
│
├── agent.py                          # 修改：添加 SkillToolset
└── config.py
```

### 8.2 模块依赖关系

```
agent.py
    ↓
SkillToolset
    ↓
SkillRegistry (单例)
    ↓
SkillDiscovery
    ↓
SkillParser
    ↓
文件系统 (skills_data/)
```

---

## 9. 配置与部署

### 9.1 环境变量

```bash
# .env 或环境变量配置

# 技能目录路径 (可选，默认为 skills_data)
SPARKX_SKILLS_ROOT="skills_data"

# 是否启用技能系统 (可选，默认为 true)
SPARKX_ENABLE_SKILLS="true"
```

### 9.2 配置文件

```yaml
# config/skills.yaml

skills:
  root_path: "skills_data"
  auto_discover: true
  cache_enabled: true
  cache_ttl_seconds: 3600
  
  # 默认技能列表 (可选，用于预加载)
  default_skills:
    - phaser-game
    - typescript
    - web-build
```

---

## 10. 测试策略

### 10.1 单元测试

```python
# tests/test_skills.py

import pytest
from pathlib import Path
from skills.parser import SkillParser
from skills.discovery import SkillDiscovery
from skills.registry import SkillRegistry

class TestSkillParser:
    def test_parse_with_frontmatter(self, tmp_path):
        skill_md = tmp_path / "SKILL.md"
        skill_md.write_text("""---
name: test-skill
version: 1.0.0
description: Test skill
---

# Test Instructions
This is test content.
""")
        
        frontmatter, body = SkillParser.parse(skill_md)
        
        assert frontmatter["name"] == "test-skill"
        assert frontmatter["version"] == "1.0.0"
        assert "Test Instructions" in body
    
    def test_parse_without_frontmatter(self, tmp_path):
        skill_md = tmp_path / "SKILL.md"
        skill_md.write_text("# Just content without frontmatter")
        
        frontmatter, body = SkillParser.parse(skill_md)
        
        assert frontmatter == {}
        assert "Just content" in body
    
    def test_validate_missing_name(self):
        errors = SkillParser.validate({"description": "Test"})
        assert "name" in str(errors)

class TestSkillDiscovery:
    def test_discover_skills_by_pattern(self, tmp_path):
        # 创建测试技能
        skill_dir = tmp_path / "test-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("""---
name: test-skill
description: Test
file_patterns:
  - "**/*.ts"
---
Instructions
""")
        
        discovery = SkillDiscovery(str(tmp_path))
        skills = discovery.discover_skills("src/main.ts")
        
        assert len(skills) == 1
        assert skills[0].frontmatter.name == "test-skill"
    
    def test_discover_skills_no_match(self, tmp_path):
        skill_dir = tmp_path / "test-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("""---
name: test-skill
description: Test
file_patterns:
  - "**/*.py"
---
Instructions
""")
        
        discovery = SkillDiscovery(str(tmp_path))
        skills = discovery.discover_skills("src/main.ts")
        
        assert len(skills) == 0

class TestSkillRegistry:
    def test_singleton_pattern(self, tmp_path):
        SkillRegistry.reset()
        
        registry1 = SkillRegistry.get_instance(str(tmp_path))
        registry2 = SkillRegistry.get_instance()
        
        assert registry1 is registry2
    
    def test_get_skill(self, tmp_path):
        SkillRegistry.reset()
        
        # 创建测试技能
        skill_dir = tmp_path / "my-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("""---
name: my-skill
description: My test skill
---
Instructions
""")
        
        registry = SkillRegistry.get_instance(str(tmp_path))
        skill = registry.get_skill("my-skill")
        
        assert skill is not None
        assert skill.instructions == "Instructions"
```

### 10.2 集成测试

```python
# tests/test_skill_integration.py

import pytest
from skills.skill_toolset import SkillToolset, DiscoverSkillsTool, LoadSkillTool

class TestSkillToolsetIntegration:
    @pytest.fixture
    def toolset(self, tmp_path):
        # 创建测试技能
        skill_dir = tmp_path / "test-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("""---
name: test-skill
description: Test skill for integration
file_patterns:
  - "**/*.ts"
---
Test instructions
""")
        
        return SkillToolset(skills_root=str(tmp_path))
    
    async def test_discover_skills_tool(self, toolset):
        discover_tool = toolset._tools[0]
        
        result = await discover_tool.run_async(
            args={"target_path": "src/test.ts"},
            tool_context=MockToolContext(),
        )
        
        assert result["status"] == "success"
        assert len(result["skills"]) > 0
    
    async def test_load_skill_tool(self, toolset):
        load_tool = toolset._tools[1]
        
        result = await load_tool.run_async(
            args={"name": "test-skill"},
            tool_context=MockToolContext(),
        )
        
        assert result["status"] == "success"
        assert result["instructions"] == "Test instructions"
    
    async def test_process_llm_request(self, toolset):
        llm_request = MockLlmRequest()
        tool_context = MockToolContext()
        
        await toolset.process_llm_request(
            tool_context=tool_context,
            llm_request=llm_request,
        )
        
        # 验证系统指令已添加
        assert len(llm_request.instructions) > 0
        assert "skills" in llm_request.instructions[0].lower()
```

---

## 11. 性能优化

### 11.1 缓存策略

```python
# skills/cache.py

from typing import Optional
from datetime import datetime, timedelta

class SkillCache:
    """技能缓存管理"""
    
    def __init__(self, ttl_seconds: int = 3600):
        self._cache: dict[str, tuple[Any, datetime]] = {}
        self._ttl = timedelta(seconds=ttl_seconds)
    
    def get(self, key: str) -> Optional[Any]:
        """获取缓存项"""
        if key not in self._cache:
            return None
        
        value, expiry = self._cache[key]
        if datetime.now() > expiry:
            del self._cache[key]
            return None
        
        return value
    
    def set(self, key: str, value: Any) -> None:
        """设置缓存项"""
        expiry = datetime.now() + self._ttl
        self._cache[key] = (value, expiry)
    
    def clear(self) -> None:
        """清空缓存"""
        self._cache.clear()
    
    def cleanup_expired(self) -> int:
        """清理过期项，返回清理数量"""
        now = datetime.now()
        expired_keys = [
            key for key, (_, expiry) in self._cache.items()
            if now > expiry
        ]
        
        for key in expired_keys:
            del self._cache[key]
        
        return len(expired_keys)
```

### 11.2 懒加载

```python
# skills/registry.py (增强版)

class SkillRegistry:
    def __init__(self, skills_root: str):
        # ...
        self._lazy_load = True  # 启用懒加载
    
    def get_skill(self, name: str) -> Optional[Skill]:
        """懒加载技能"""
        if name not in self._skills:
            # 仅在请求时加载
            self._load_skill_by_name(name)
        return self._skills.get(name)
    
    def preload_skills(self, skill_names: list[str]) -> None:
        """预加载指定技能"""
        for name in skill_names:
            if name not in self._skills:
                self._load_skill_by_name(name)
```

---

## 12. 安全考虑

### 12.1 路径安全

```python
# skills/discovery.py (增强版)

class SkillDiscovery:
    def _load_skill(self, skill_dir: Path) -> Optional[Skill]:
        # 防止路径遍历攻击
        skill_dir = skill_dir.resolve()
        
        if not str(skill_dir).startswith(str(self.skills_root.resolve())):
            print(f"Security warning: Attempted to load skill outside skills root: {skill_dir}")
            return None
        
        # ... 继续加载 ...
```

### 12.2 工具权限控制

```python
# skills/skill_toolset.py (增强版)

class LoadSkillTool(BaseTool):
    async def run_async(self, args: dict, tool_context: ToolContext) -> Any:
        skill = self._registry.get_skill(args["name"])
        
        # 检查 allowed_tools
        allowed = skill.frontmatter.allowed_tools
        if allowed:
            # 验证当前上下文允许使用这些工具
            available_tools = tool_context.available_tools
            for required_tool in allowed:
                if required_tool not in available_tools:
                    return {
                        "status": "error",
                        "message": f"技能需要工具 '{required_tool}' 但不可用",
                        "error_code": "TOOL_NOT_AVAILABLE",
                    }
        
        # ... 继续加载 ...
```

---

## 13. 扩展点

### 13.1 自定义发现策略

```python
# skills/discovery.py

class SkillDiscovery:
    def __init__(self, skills_root: str, strategy: 'DiscoveryStrategy' = None):
        self.strategy = strategy or FilePatternStrategy()
    
    def discover_skills(self, target_path: str) -> list[Skill]:
        return self.strategy.match(target_path, self.list_all_skills())

class DiscoveryStrategy(ABC):
    @abstractmethod
    def match(self, target_path: str, skills: list[Skill]) -> list[Skill]:
        pass

class FilePatternStrategy(DiscoveryStrategy):
    def match(self, target_path: str, skills: list[Skill]) -> list[Skill]:
        # 基于文件模式匹配
        # ...
        pass

class KeywordStrategy(DiscoveryStrategy):
    def match(self, target_path: str, skills: list[Skill]) -> list[Skill]:
        # 基于关键词匹配
        # ...
        pass
```

### 13.2 远程技能加载

```python
# skills/remote.py

class RemoteSkillLoader:
    """从远程仓库加载技能"""
    
    def __init__(self, repo_url: str):
        self.repo_url = repo_url
    
    async def fetch_skill(self, skill_name: str) -> Optional[Skill]:
        """从远程获取技能"""
        # 1. 下载技能目录
        # 2. 解析 SKILL.md
        # 3. 缓存到本地
        # 4. 返回 Skill 对象
        pass
```

---

## 14. 故障排查

### 14.1 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 技能未加载 | SKILL.md 格式错误 | 检查 frontmatter YAML 语法 |
| 技能不匹配 | file_patterns 配置不当 | 调整 glob 模式 |
| 资源加载失败 | 路径错误 | 检查资源路径相对于资源目录 |
| 缓存未更新 | TTL 过长 | 减少 cache_ttl_seconds 或手动清理 |

### 14.2 调试日志

```python
# 启用调试日志
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("skills")

# 在关键位置添加日志
logger.debug(f"Loading skill from {skill_dir}")
logger.info(f"Discovered {len(skills)} skills for {target_path}")
```

---

## 15. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0.0 | 2026-02-19 | 初始版本 |

---

## 16. 参考文档

- [Google ADK Toolset 文档](https://adk.wiki/tools/toolsets/)
- [Google ADK Skills 文档](https://adk.wiki/skills/)
- [LiteLLM 文档](https://docs.litellm.ai/)
- [Phaser 框架文档](https://phaser.io/docs)
