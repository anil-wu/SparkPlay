# 图层存储功能 - 快速参考

## 核心 API

### 保存图层

```typescript
import { useWorkspaceSave } from '@/hooks/useWorkspaceSave';

const { saveStatus, lastSavedAt, handleSave } = useWorkspaceSave(projectId);
```

### 调用后端 API

```typescript
import { workspaceAPI } from '@/lib/workspace-api';

// 获取画布
const canvas = await workspaceAPI.getCanvas(projectId);

// 同步图层
await workspaceAPI.syncLayers(projectId, layers);

// 删除/恢复
await workspaceAPI.deleteLayer(layerId);
await workspaceAPI.restoreLayer(layerId);
```

## 组件使用

### 保存按钮

```tsx
import SaveButton from '@/components/Workspace/SaveButton';

<SaveButton
  saveStatus={saveStatus}
  lastSavedAt={lastSavedAt}
  onSave={handleSave}
  errorMessage={errorMessage}
/>
```

### 回收站

```tsx
import RecycleBinPanel from '@/components/Workspace/RecycleBinPanel';

<RecycleBinPanel
  canvasId={canvasId}
  isOpen={showRecycleBin}
  onClose={() => setShowRecycleBin(false)}
  onRestore={(layerId) => console.log('Restored:', layerId)}
/>
```

### 冲突对话框

```tsx
import ConflictDialog from '@/components/Workspace/ConflictDialog';

<ConflictDialog
  isOpen={showConflict}
  onClose={() => setShowConflict(false)}
  onUseRemote={() => {/* 使用远程版本 */}}
  onForceSave={() => {/* 强制保存 */}}
/>
```

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl/Cmd + S` | 保存 |
| `Ctrl/Cmd + Z` | 撤销 |
| `Ctrl/Cmd + Y` | 重做 |
| `Delete` | 删除选中元素 |

## 保存状态

```typescript
type SaveStatus = 'idle' | 'saving' | 'saved' | 'error' | 'conflict';
```

- `idle`: 空闲状态
- `saving`: 保存中
- `saved`: 已保存
- `error`: 保存失败
- `conflict`: 版本冲突

## 数据转换

### Element → Layer

```typescript
const elementToLayer = (element: BaseElement<any>) => ({
  id: element.id,
  layerType: element.type,
  name: element.name,
  zIndex: 0,
  x: element.x,
  y: element.y,
  width: element.width,
  height: element.height,
  rotation: element.rotation,
  visible: element.visible,
  locked: element.locked,
  properties: {
    // 根据类型提取属性
    color: (element as ShapeElement).color,
    text: (element as TextElement).text,
    src: (element as ImageElement).src,
    points: (element as DrawElement).points,
  }
});
```

## 离线支持

```typescript
// 自动保存到离线队列
localStorage.setItem('offlineSaveQueue', JSON.stringify(queue));

// 网络恢复后自动同步
window.addEventListener('online', syncOfflineChanges);
```

## 文件结构

```
web/src/
├── lib/
│   ├── workspace-api.ts          # API 客户端
│   └── workspace.test.ts         # 测试示例
├── hooks/
│   └── useWorkspaceSave.ts       # 保存 Hook
├── components/Workspace/
│   ├── SaveButton.tsx            # 保存按钮
│   ├── ConflictDialog.tsx        # 冲突对话框
│   └── RecycleBinPanel.tsx       # 回收站面板
└── store/
    └── useWorkspaceStore.ts      # Zustand store (已有)
```

## 常见问题

### Q: 如何处理保存错误？

```typescript
const { errorMessage, saveStatus } = useWorkspaceSave(projectId);

if (saveStatus === 'error') {
  console.error('Save failed:', errorMessage);
}
```

### Q: 如何获取 projectId？

```typescript
// 从 URL 参数
const searchParams = useSearchParams();
const projectId = searchParams?.get('projectId');

// 或从组件 props
function CanvasArea({ projectId }) {
  // 使用 projectId
}
```

### Q: 离线数据存在哪里？

```typescript
// localStorage: 'offlineSaveQueue'
const queue = JSON.parse(localStorage.getItem('offlineSaveQueue') || '[]');
```

### Q: 如何清空历史？

```typescript
// 清空撤销/重做历史
useWorkspaceStore.temporal.getState().clear();
```

## 国际化键

```json
{
  "workspace": {
    "save": "保存",
    "saving": "保存中...",
    "saved": "已保存",
    "save_error": "保存失败",
    "last_saved": "最后保存",
    "recycle_bin": "回收站",
    "conflict_detected": "检测到版本冲突"
  }
}
```

## 后端 API 端点

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/v1/projects/:projectId/canvas` | GET | 获取画布 |
| `/api/v1/projects/:projectId/canvas` | POST | 创建画布 |
| `/api/v1/projects/:projectId/layers/sync` | POST | 同步图层 |
| `/api/v1/layers/:id` | PUT | 更新图层 |
| `/api/v1/layers/:id` | DELETE | 删除图层 |
| `/api/v1/layers/:id/restore` | POST | 恢复图层 |
| `/api/v1/layers/deleted` | GET | 获取已删除图层 |

## 测试命令

```bash
# 运行测试
npm test -- workspace.test.ts

# 类型检查
npm run typecheck

# 代码检查
npm run lint
```

## 相关文档

- [完整集成指南](./FRONTEND_INTEGRATION_GUIDE.md)
- [实现总结](./IMPLEMENTATION_SUMMARY.md)
- [设计文档](./layer-storage-design.md)
- [API 文档](../../service/sparkx.swagger.json)
