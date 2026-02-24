# Web 工作空间图层存储设计方案

## 一、概述

本文档描述 Web 工作空间（Workspace）中的图层（Layer/Element）数据如何存储到后端 API Service 的完整设计方案。

### 1.1 背景

当前前端工作空间使用 Konva.js 作为画布引擎，通过 Zustand 管理图层状态。每个图层（Element）包含位置、样式、属性等信息，需要持久化到后端以便：
- 跨会话恢复项目
- 多用户协作
- 与 AI Agent 共享上下文

### 1.2 设计目标

- **完整性**：保存所有图层数据和画布配置
- **简洁性**：只存储当前状态，暂不实现版本控制
- **增量同步**：仅上传变更部分，减少带宽
- **AI 可读**：结构化数据便于 Agent 理解和修改

---

## 二、前端数据结构

### 2.1 核心数据模型

#### BaseElement（基础图层）

```typescript
interface BaseElementState {
  id: string;                    // 唯一标识
  type: ToolType;                // 图层类型
  name: string;                  // 图层名称
  x: number;                     // X 坐标
  y: number;                     // Y 坐标
  width: number;                 // 宽度
  height: number;                // 高度
  rotation: number;              // 旋转角度
  visible: boolean;              // 可见性
  locked: boolean;               // 锁定状态
  isEditing: boolean;            // 编辑中状态
}
```

#### 具体图层类型

1. **ImageElement**（图片图层）
```typescript
interface ImageState extends BaseElementState {
  type: 'image';
  src: string;                   // 图片 URL 或 Base64
}
```

2. **ShapeElement**（形状图层）
```typescript
interface ShapeState extends BaseElementState {
  type: 'rectangle' | 'circle' | 'triangle' | 'star';
  color: string;                 // 填充颜色
  stroke: string;                // 描边颜色
  strokeWidth: number;           // 描边宽度
  strokeStyle: string;           // 描边样式
  cornerRadius: number;          // 圆角半径
  sides?: number;                // 边数（多边形）
  starInnerRadius?: number;      // 内半径（星形）
}
```

3. **TextElement**（文本图层）
```typescript
interface TextState extends BaseElementState {
  type: 'text';
  text: string;                  // 文本内容
  fontSize: number;              // 字号
  fontFamily: string;            // 字体
  textColor: string;             // 文字颜色
  fontStyle: string;             // 字体样式
  align: string;                 // 对齐方式
  lineHeight: number;            // 行高
  letterSpacing: number;         // 字间距
  textDecoration: string;        // 文本装饰
  textTransform: string;         // 文本转换
}
```

4. **TextShapeElement**（文本形状复合图层）
```typescript
interface TextShapeState extends BaseElementState {
  type: 'chat-bubble' | 'arrow-left' | 'arrow-right' | 'rectangle-text' | 'circle-text';
  // Shape 属性
  color: string;
  stroke: string;
  strokeWidth: number;
  cornerRadius: number;
  // Text 属性
  text: string;
  fontSize: number;
  fontFamily: string;
  textColor: string;
  textStroke: string;
  textStrokeWidth: number;
  fontStyle: string;
  align: string;
  lineHeight: number;
  letterSpacing: number;
  textDecoration: string;
  textTransform: string;
}
```

5. **DrawElement**（手绘图层）
```typescript
interface DrawState extends BaseElementState {
  type: 'pencil' | 'pen';
  points: number[];              // 路径点数组 [x1, y1, x2, y2, ...]
  stroke: string;
  strokeWidth: number;
  fill: string;
}
```

### 2.2 画布状态

```typescript
interface CanvasState {
  elements: BaseElement<any>[];  // 图层列表
  selectedId: string | null;     // 选中图层 ID
  activeTool: ToolType;          // 当前工具
}
```

---

## 三、后端数据模型设计

### 3.1 数据库表设计

#### 10. workspace_canvas（工作空间画布）

```sql
CREATE TABLE `workspace_canvas` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `project_id` BIGINT UNSIGNED NOT NULL,
  `name` VARCHAR(128) NOT NULL DEFAULT 'Main Canvas',
  `background_color` VARCHAR(32) NOT NULL DEFAULT '#ffffff',
  `metadata` JSON,  -- 画布元数据（网格、参考线等）
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_by` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_project_canvas` (`project_id`),  -- 一个项目一个画布
  KEY `idx_workspace_canvas_project_id` (`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**字段说明**：
- `project_id`：关联项目 ID（唯一索引，一个项目只有一个画布）
- `name`：画布名称
- `background_color`：画布背景颜色
- `metadata`：JSON 格式，存储画布元数据（网格大小、是否启用吸附等）

---

#### 11. workspace_layer（工作空间图层）

```sql
CREATE TABLE `workspace_layer` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `canvas_id` BIGINT UNSIGNED NOT NULL,
  
  -- 基础信息
  `layer_type` ENUM('image', 'rectangle', 'circle', 'triangle', 'star', 'text', 'chat-bubble', 'arrow-left', 'arrow-right', 'rectangle-text', 'circle-text', 'pencil', 'pen') NOT NULL,
  `name` VARCHAR(256) NOT NULL,
  
  -- 变换属性（公共）
  `z_index` INT NOT NULL DEFAULT 0,
  `position_x` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `position_y` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `width` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `height` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `rotation` DECIMAL(6,2) NOT NULL DEFAULT 0,
  
  -- 状态属性（公共）
  `visible` BOOLEAN NOT NULL DEFAULT TRUE,
  `locked` BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- 软删除标记
  `deleted` BOOLEAN NOT NULL DEFAULT FALSE,
  `deleted_at` TIMESTAMP NULL DEFAULT NULL,
  `deleted_by` BIGINT UNSIGNED,
  
  -- 私有数据
  `properties` JSON NOT NULL,  -- 类型特有的属性
  
  -- 关联
  `file_id` BIGINT UNSIGNED,   -- 关联文件 ID（图片等）
  
  -- 审计
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_by` BIGINT UNSIGNED NOT NULL,
  
  PRIMARY KEY (`id`),
  KEY `idx_workspace_layer_canvas_id` (`canvas_id`),
  KEY `idx_workspace_layer_z_index` (`z_index`),
  KEY `idx_workspace_layer_type` (`layer_type`),
  KEY `idx_workspace_layer_deleted` (`deleted`, `deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**字段说明**：
- `canvas_id`：关联画布 ID
- `layer_type`：图层类型（ENUM）
- `name`：图层名称
- `z_index`：图层顺序（0 在最底层，数字越大越靠上）
- `position_x/position_y`：位置坐标
- `width/height`：尺寸
- `rotation`：旋转角度
- `visible`：是否可见
- `locked`：是否锁定
- **`deleted`**：软删除标记（false=正常，true=已删除）
- **`deleted_at`**：删除时间（NULL=未删除）
- **`deleted_by`**：删除人 ID（NULL=未删除）
- `properties`：JSON 格式，存储类型特有的属性（颜色、文本内容等）
- `file_id`：关联的文件 ID（仅图片等需要文件的图层）

---

### 3.2 数据关系

```
users (用户)
   │
   └──→ projects (项目)
             │
             └──→ workspace_canvas (画布 - 1 个)
                       │
                       └──→ workspace_layer (图层 - N 个)
                                 │
                                 └──→ files (文件 - 图片等)
```

**关系说明**：
- 一个项目 = 一个画布（UNIQUE 约束）
- 一个画布 = N 个图层
- 每个图层 = 一个图形元素

---

### 3.3 图层属性分类

#### 公共字段（表字段）

所有图层类型都有的通用属性：

| 字段 | 类型 | 说明 |
|------|------|------|
| `layer_type` | ENUM | 图层类型 |
| `name` | VARCHAR | 图层名称 |
| `z_index` | INT | 图层顺序 |
| `position_x` | DECIMAL | X 坐标 |
| `position_y` | DECIMAL | Y 坐标 |
| `width` | DECIMAL | 宽度 |
| `height` | DECIMAL | 高度 |
| `rotation` | DECIMAL | 旋转角度 |
| `visible` | BOOLEAN | 可见性 |
| `locked` | BOOLEAN | 锁定状态 |

#### 私有字段（properties JSON）

特定类型图层独有的属性：

**Image 类型**：
```json
{
  "src": "/api/v1/files/1001/download",
  "opacity": 1,
  "blendMode": "source-over"
}
```

**Shape 类型**（rectangle/circle/triangle/star）：
```json
{
  "color": "#3498db",
  "stroke": "#2980b9",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "cornerRadius": 8
}
```

**Text 类型**：
```json
{
  "text": "游戏标题",
  "fontSize": 48,
  "fontFamily": "Arial",
  "textColor": "#000000",
  "fontStyle": "bold",
  "align": "center",
  "lineHeight": 1.2,
  "letterSpacing": 0
}
```

**TextShape 类型**（chat-bubble/arrow-left/rectangle-text/circle-text/arrow-right）：
```json
{
  "color": "#f1c40f",
  "stroke": "#f39c12",
  "strokeWidth": 2,
  "cornerRadius": 10,
  "text": "你好，世界！",
  "fontSize": 24,
  "fontFamily": "Arial",
  "textColor": "#2c3e50",
  "textStroke": "transparent",
  "textStrokeWidth": 0,
  "align": "left"
}
```

**Draw 类型**（pencil/pen）：
```json
{
  "points": [50, 50, 55, 52, 60, 55, 65, 58, 70, 60],
  "stroke": "#9b59b6",
  "strokeWidth": 3,
  "fill": "transparent",
  "tension": 0.5
}
```

---

## 四、API 接口设计

### 4.1 画布管理接口

#### GET /api/v1/projects/:projectId/canvas

获取项目的画布和所有图层（**自动过滤已删除的图层**）

**查询逻辑**：
```sql
-- 查询时自动过滤 deleted = TRUE 的图层
SELECT * FROM workspace_layer 
WHERE canvas_id = ? AND deleted = FALSE
ORDER BY z_index ASC;
```

**响应**：
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "canvas": {
      "id": 1,
      "name": "Main Canvas",
      "backgroundColor": "#ffffff",
      "metadata": {
        "gridSize": 10,
        "snapEnabled": true
      }
    },
    "layers": [
      {
        "id": 1,
        "type": "image",
        "name": "背景",
        "zIndex": 0,
        "x": 0,
        "y": 0,
        "width": 1920,
        "height": 1080,
        "rotation": 0,
        "visible": true,
        "locked": false,
        "properties": {
          "src": "/api/v1/files/1001/download"
        }
      },
      {
        "id": 2,
        "type": "rectangle",
        "name": "按钮",
        "zIndex": 1,
        "x": 100,
        "y": 100,
        "width": 200,
        "height": 60,
        "rotation": 0,
        "visible": true,
        "locked": false,
        "properties": {
          "color": "#3498db",
          "stroke": "#2980b9",
          "strokeWidth": 2
        }
      }
    ]
  }
}
```

---

#### POST /api/v1/projects/:projectId/canvas

创建或更新画布

**请求体**：
```json
{
  "name": "Main Canvas",
  "backgroundColor": "#ffffff",
  "metadata": {
    "gridSize": 10,
    "snapEnabled": true
  }
}
```

**响应**：
```json
{
  "code": 200,
  "data": {
    "canvasId": 1
  }
}
```

---

### 4.2 图层管理接口

#### POST /api/v1/canvas/:canvasId/layers

批量创建/更新图层

**请求体**：
```json
{
  "layers": [
    {
      "id": "local-001",
      "type": "image",
      "name": "背景",
      "zIndex": 0,
      "x": 0,
      "y": 0,
      "width": 1920,
      "height": 1080,
      "rotation": 0,
      "visible": true,
      "locked": false,
      "properties": {
        "src": "/api/v1/files/1001/download"
      }
    },
    {
      "id": "local-002",
      "type": "rectangle",
      "name": "按钮",
      "zIndex": 1,
      "x": 100,
      "y": 100,
      "width": 200,
      "height": 60,
      "rotation": 0,
      "visible": true,
      "locked": false,
      "properties": {
        "color": "#3498db"
      }
    }
  ]
}
```

**响应**：
```json
{
  "code": 200,
  "data": {
    "uploaded": 2,
    "updated": 0,
    "skipped": 0,
    "layerMapping": {
      "local-001": 1,
      "local-002": 2
    }
  }
}
```

---

#### PUT /api/v1/layers/:id

更新单个图层

**请求体**：
```json
{
  "name": "新按钮",
  "x": 150,
  "y": 150,
  "rotation": 15,
  "properties": {
    "color": "#e74c3c"
  }
}
```

---

#### DELETE /api/v1/layers/:id

软删除图层（标记为已删除，不物理删除）

**请求参数**：
```
DELETE /api/v1/layers/123
```

**执行逻辑**：
```sql
UPDATE workspace_layer 
SET 
  deleted = TRUE,
  deleted_at = CURRENT_TIMESTAMP,
  deleted_by = {current_user_id}
WHERE id = 123 AND deleted = FALSE;
```

**响应**：
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "layerId": 123,
    "deleted": true,
    "deletedAt": "2024-01-15T10:30:00Z"
  }
}
```

**注意**：
- ✅ 软删除后，图层仍然存在于数据库
- ✅ 前端查询时默认过滤 `deleted = FALSE` 的图层
- ✅ 支持恢复操作（见下方）

---

#### POST /api/v1/layers/:id/restore

恢复已删除的图层

**请求参数**：
```
POST /api/v1/layers/123/restore
```

**执行逻辑**：
```sql
UPDATE workspace_layer 
SET 
  deleted = FALSE,
  deleted_at = NULL,
  deleted_by = NULL,
  updated_at = CURRENT_TIMESTAMP
WHERE id = 123 AND deleted = TRUE;
```

**响应**：
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "layerId": 123,
    "restored": true,
    "restoredAt": "2024-01-15T10:35:00Z"
  }
}
```

**使用场景**：
- 用户误删图层后恢复
- 回收站功能
- 管理员审计

---

#### GET /api/v1/layers/deleted

获取已删除的图层列表（回收站）

**请求参数**：
```
GET /api/v1/layers/deleted?canvasId=1&limit=50
```

**响应**：
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "deletedLayers": [
      {
        "id": 123,
        "name": "按钮",
        "type": "rectangle",
        "deletedAt": "2024-01-15T10:30:00Z",
        "deletedBy": 1001
      }
    ],
    "total": 1
  }
}
```

**权限**：
- 仅项目成员可查看
- 仅删除者或管理员可恢复

---

## 五、同步策略

### 5.1 设计原则

**前端历史与后端持久化分离**：
- **前端**：使用 zundo 实现撤销/重做（内存级，快速）
- **后端**：只保存当前状态（持久化，跨会话恢复）
- **同步时机**：仅在用户手动保存时触发，避免同步中间状态

**优势**：
- ✅ 减少不必要的网络请求
- ✅ 避免后端存储冗余历史数据
- ✅ 用户明确知道何时保存
- ✅ 支持离线编辑（保存时检查网络）

---

### 5.2 手动保存实现

#### 基础实现

```typescript
// 用户点击"保存"按钮
const handleSave = async () => {
  try {
    const state = useWorkspaceStore.getState();
    const canvas = await api.canvas.get(projectId);
    
    if (!canvas) {
      // 画布不存在，先创建
      canvas = await api.canvas.create(projectId, {
        name: 'Main Canvas',
        backgroundColor: '#ffffff'
      });
    }
    
    // 同步所有图层
    const result = await api.layers.sync(canvas.id, {
      layers: state.elements.map(el => el.toState())
    });
    
    // 显示保存成功提示
    toast.success(`保存成功：${result.uploaded} 个图层`);
    
  } catch (error) {
    if (error.name === 'NetworkError') {
      // 网络错误，保存到本地
      saveToOfflineQueue(state.elements);
      toast.warning('网络不可用，已保存到本地队列');
    } else {
      toast.error('保存失败，请重试');
      throw error;
    }
  }
};
```

---

### 5.3 保存时暂停历史跟踪

**问题**：保存操作本身不应该被记录到历史中

**解决方案**：
```typescript
const handleSave = async () => {
  const temporalStore = useWorkspaceStore.temporal.getState();
  
  try {
    // 暂停历史跟踪（避免保存操作被记录）
    temporalStore.pause();
    
    const state = useWorkspaceStore.getState();
    const canvas = await api.canvas.get(projectId);
    
    await api.layers.sync(canvas.id, {
      layers: state.elements.map(el => el.toState())
    });
    
    // 可选：清空历史，释放内存
    // temporalStore.clear();
    
  } finally {
    // 恢复历史跟踪
    temporalStore.resume();
  }
};
```

---

### 5.4 快捷键支持

```typescript
// Ctrl/Cmd + S 保存
useEffect(() => {
  const handleKeyDown = (e: KeyboardEvent) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault();
      handleSave();
    }
  };
  
  window.addEventListener('keydown', handleKeyDown);
  return () => window.removeEventListener('keydown', handleKeyDown);
}, []);
```

---

### 5.5 保存状态指示器

```typescript
const [saveStatus, setSaveStatus] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle');

const handleSave = async () => {
  setSaveStatus('saving');
  
  try {
    await api.layers.sync(canvasId, elements);
    setSaveStatus('saved');
    
    // 2 秒后恢复 idle 状态
    setTimeout(() => setSaveStatus('idle'), 2000);
    
  } catch (error) {
    setSaveStatus('error');
    throw error;
  }
};

// UI 显示
<button onClick={handleSave} disabled={saveStatus === 'saving'}>
  {saveStatus === 'idle' && '保存'}
  {saveStatus === 'saving' && '保存中...'}
  {saveStatus === 'saved' && '已保存 ✓'}
  {saveStatus === 'error' && '保存失败 ✗'}
</button>
```

---

### 5.6 离线支持

```typescript
interface OfflineLayerOperation {
  type: 'sync';
  canvasId: number;
  layers: ElementState[];
  timestamp: number;
}

// 保存到离线队列
const saveToOfflineQueue = (layers: ElementState[]) => {
  const operation: OfflineLayerOperation = {
    type: 'sync',
    canvasId: canvasId,
    layers: layers.map(el => el.toState()),
    timestamp: Date.now()
  };
  
  const queue = getOfflineQueue();
  queue.push(operation);
  localStorage.setItem('offlineQueue', JSON.stringify(queue));
};

// 恢复网络后同步
const syncOfflineChanges = async () => {
  const queue = getOfflineQueue();
  if (queue.length === 0) return;
  
  try {
    for (const op of queue) {
      await api.layers.sync(op.canvasId, { layers: op.layers });
    }
    
    // 清空队列
    localStorage.removeItem('offlineQueue');
    toast.success('离线数据已同步到服务器');
    
  } catch (error) {
    toast.error('离线数据同步失败，请检查网络');
  }
};

// 监听网络状态
window.addEventListener('online', syncOfflineChanges);
```

---

### 5.7 版本冲突处理

**场景**：多用户同时编辑，后保存的用户可能覆盖先保存的用户

**解决方案**：
```typescript
// 后端返回当前版本哈希
interface CanvasResponse {
  canvas: {
    id: number;
    data_hash: string;  // SHA256(图层数据)
    updated_at: string;
  };
  layers: Layer[];
}

// 保存时带上期望的版本哈希
const handleSave = async () => {
  const state = useWorkspaceStore.getState();
  const canvas = await api.canvas.get(projectId);
  
  try {
    const result = await api.layers.sync(canvas.id, {
      layers: state.elements.map(el => el.toState()),
      expected_hash: canvas.data_hash  // 乐观锁
    });
    
  } catch (error) {
    if (error.status === 409) {
      // 版本冲突，提示用户
      showConflictDialog({
        remoteData: error.remoteData,
        localData: state.elements
      });
    }
  }
};
```

**冲突处理 UI**：
```typescript
const ConflictDialog = ({ remoteData, localData }) => {
  return (
    <Dialog>
      <DialogTitle>检测到版本冲突</DialogTitle>
      <p>其他用户刚刚保存了修改，请选择：</p>
      
      <div className="flex gap-4">
        <Button onClick={() => applyRemote(remoteData)}>
          使用远程版本（放弃我的修改）
        </Button>
        <Button onClick={() => forceSave(localData)}>
          强制保存（覆盖远程版本）
        </Button>
        <Button onClick={() => downloadBoth(remoteData, localData)}>
          下载两个版本对比
        </Button>
      </div>
    </Dialog>
  );
};
```

---

## 五、软删除实现细节

### 5.8 软删除的优势

**1. 数据安全性**
- ✅ 防止误删导致数据永久丢失
- ✅ 支持恢复操作（回收站）
- ✅ 保留审计信息（谁、何时删除）

**2. 数据一致性**
- ✅ 避免外键约束问题（如 file_id 关联）
- ✅ 保持图层 ID 连续性
- ✅ 历史记录完整性

**3. 业务灵活性**
- ✅ 支持回收站功能
- ✅ 支持批量恢复
- ✅ 支持管理员审计

---

### 5.9 软删除的注意事项

**1. 查询时必须过滤**
```typescript
// 后端查询（GORM 示例）
func (m *workspaceLayerModel) FindByCanvasId(ctx context.Context, canvasId int64) ([]*WorkspaceLayer, error) {
  var layers []*WorkspaceLayer
  err := m.modelCtx(ctx).Where("deleted = FALSE AND canvas_id = ?", canvasId).Find(&layers).Error
  return layers, err
}

// 前端查询时也需要过滤
const visibleLayers = layers.filter(layer => !layer.deleted);
```

**2. 批量同步时的处理**
```typescript
// 同步时，前端发送所有图层（包括标记删除的）
const handleSave = async () => {
  const state = useWorkspaceStore.getState();
  
  // 分离正常图层和已删除图层
  const activeLayers = state.elements.filter(el => !el.deleted);
  const deletedLayers = state.elements.filter(el => el.deleted);
  
  await api.layers.sync(canvasId, {
    layers: activeLayers.map(el => el.toState()),
    deletedLayerIds: deletedLayers.map(el => el.id)  // 告知后端哪些图层已删除
  });
};
```

**3. 物理删除的时机**
```sql
-- 定期清理 30 天前的软删除数据（可选）
DELETE FROM workspace_layer 
WHERE deleted = TRUE 
  AND deleted_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
```

**4. 级联删除的处理**
```typescript
// 如果图层关联了文件，需要考虑文件处理
const handleDeleteLayer = async (layerId: string) => {
  const layer = getLayer(layerId);
  
  // 标记为软删除
  updateElement(layerId, { deleted: true });
  
  // 如果有关联文件，文件暂时保留
  // 可以在回收站清空时再删除文件
  if (layer.properties.fileId) {
    // 标记文件为待删除（不立即删除）
    await api.files.markForDeletion(layer.properties.fileId);
  }
};
```

**5. 回收站 UI 实现**
```typescript
const RecycleBinPanel = () => {
  const [deletedLayers, setDeletedLayers] = useState([]);
  
  useEffect(() => {
    const fetchDeletedLayers = async () => {
      const data = await api.layers.getDeleted({ canvasId, limit: 50 });
      setDeletedLayers(data.deletedLayers);
    };
    fetchDeletedLayers();
  }, []);
  
  const handleRestore = async (layerId: string) => {
    await api.layers.restore(layerId);
    // 从回收站列表移除
    setDeletedLayers(prev => prev.filter(l => l.id !== layerId));
  };
  
  const handlePermanentDelete = async (layerId: string) => {
    // 物理删除（谨慎使用）
    await api.layers.permanentDelete(layerId);
    setDeletedLayers(prev => prev.filter(l => l.id !== layerId));
  };
  
  return (
    <Panel title="回收站">
      {deletedLayers.map(layer => (
        <LayerItem key={layer.id} layer={layer}>
          <Button onClick={() => handleRestore(layer.id)}>恢复</Button>
          <Button onClick={() => handlePermanentDelete(layer.id)}>永久删除</Button>
        </LayerItem>
      ))}
    </Panel>
  );
};
```

---

## 六、与 AI Agent 集成

### 6.1 Agent 读取画布

```python
async def get_canvas_context(tool_context):
    """获取画布上下文供 Agent 使用"""
    project_id = tool_context.state.get('project_id')
    
    # 获取画布数据
    canvas_data = await api.get_canvas(project_id)
    
    # 转换为 Agent 可读的格式
    return {
        "canvas": {
            "id": canvas_data.id,
            "name": canvas_data.name,
            "backgroundColor": canvas_data.backgroundColor,
            "metadata": canvas_data.metadata
        },
        "layers": [
            {
                "id": layer.id,
                "type": layer.type,
                "name": layer.name,
                "position": {"x": layer.x, "y": layer.y},
                "size": {"width": layer.width, "height": layer.height},
                "rotation": layer.rotation,
                "visible": layer.visible,
                "locked": layer.locked,
                "properties": layer.properties
            }
            for layer in canvas_data.layers
        ]
    }
```

---

### 6.2 Agent 修改图层

```python
async def update_layer(tool_context, layer_id, updates):
    """Agent 修改图层"""
    # 验证更新
    validated_updates = validate_layer_updates(updates)
    
    # 调用 API
    result = await api.update_layer(layer_id, validated_updates)
    
    return {
        "success": True,
        "layer_id": layer_id,
        "updated_fields": list(validated_updates.keys())
    }
```

---

### 6.3 Agent 创建图层

```python
async def create_layer(tool_context, layer_config):
    """Agent 创建新图层"""
    canvas_id = tool_context.state.get('canvas_id')
    
    # 标准化图层数据
    layer_data = normalize_layer(layer_config)
    
    # 调用 API
    result = await api.create_layer(canvas_id, layer_data)
    
    return {
        "success": True,
        "layer_id": result.id,
        "message": f"Created {layer_config['type']} layer"
    }
```

---

## 七、实现计划

### 阶段 1：数据库迁移（Week 1）

- [ ] 创建数据库表（workspace_canvas, workspace_layer）
- [ ] 添加 GORM 模型定义
- [ ] 编写迁移脚本

### 阶段 2：后端 API 实现（Week 2）

- [ ] 实现画布管理接口
- [ ] 实现图层管理接口
- [ ] 添加 JWT 认证和权限校验
- [ ] 编写单元测试

### 阶段 3：前端集成（Week 3）

- [ ] 创建 API 客户端封装
- [ ] 实现同步逻辑（实时/手动）
- [ ] 集成到 Workspace 组件

### 阶段 4：Agent 工具集成（Week 4）

- [ ] 创建 canvas_manager 工具集
- [ ] 实现 get_canvas_context 工具
- [ ] 实现 update_layer 工具
- [ ] 实现 create_layer 工具
- [ ] 编写 Agent 使用文档

### 阶段 5：测试与优化（Week 5）

- [ ] 端到端测试
- [ ] 性能优化（大批量图层）
- [ ] 离线同步测试

---

## 八、技术注意事项

### 8.1 性能优化

1. **批量操作**：合并多个小操作
2. **分页加载**：大型画布分层加载
3. **缓存策略**：使用 ETag/Last-Modified

### 8.2 安全考虑

1. **认证**：所有接口需要 JWT 认证
2. **授权**：验证项目成员权限
3. **输入验证**：严格校验图层数据格式
4. **XSS 防护**：文本内容转义

### 8.3 数据一致性

1. **事务处理**：批量操作使用事务
2. **审计日志**：记录所有变更操作

---

## 九、参考文档

- [SparkX_Table_Design.02_Users_Projects.md](../SparkX_Table_Design.02_Users_Projects.md) - 用户与项目表设计
- [SparkX_Table_Design.03_File_System.md](../SparkX_Table_Design.03_File_System.md) - 文件系统表设计
- [Agent_Design.md](../Agent_Design.md) - Agent 架构设计
- [workspace_manager_agent_tools.md](./agents/workspace_manager_agent_tools.md) - Workspace Manager 工具设计
