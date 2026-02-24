# 前端图层存储集成指南

## 概述

本文档描述如何在前端使用新增的图层存储管理功能。

## 新增组件和 Hook

### 1. `useWorkspaceSave` Hook

**位置**: `web/src/hooks/useWorkspaceSave.ts`

**功能**:
- 手动保存图层到后端
- 离线队列支持
- 保存状态管理
- 快捷键支持 (Ctrl/Cmd + S)

**使用示例**:

```typescript
import { useWorkspaceSave } from '@/hooks/useWorkspaceSave';

function MyComponent({ projectId }: { projectId: string }) {
  const {
    saveStatus,      // 'idle' | 'saving' | 'saved' | 'error' | 'conflict'
    lastSavedAt,     // Date | null
    errorMessage,    // string | null
    handleSave,      // () => Promise<SaveResult>
    syncOfflineChanges, // () => Promise<void>
  } = useWorkspaceSave(parseInt(projectId));

  return (
    <div>
      <button onClick={handleSave} disabled={saveStatus === 'saving'}>
        {saveStatus === 'saving' ? 'Saving...' : 'Save'}
      </button>
      {lastSavedAt && <span>Last saved: {lastSavedAt.toLocaleString()}</span>}
    </div>
  );
}
```

### 2. `SaveButton` 组件

**位置**: `web/src/components/Workspace/SaveButton.tsx`

**功能**:
- 显示保存状态
- 显示最后保存时间
- 错误提示
- 国际化支持

**使用示例**:

```typescript
import SaveButton from '@/components/Workspace/SaveButton';

function WorkspaceHeader({ onSave, saveStatus, lastSavedAt }) {
  return (
    <div>
      <SaveButton
        saveStatus={saveStatus}
        lastSavedAt={lastSavedAt}
        onSave={onSave}
        errorMessage={null}
      />
    </div>
  );
}
```

### 3. `ConflictDialog` 组件

**位置**: `web/src/components/Workspace/ConflictDialog.tsx`

**功能**:
- 版本冲突检测
- 提供三种解决方案:
  - 使用远程版本
  - 强制保存（覆盖）
  - 下载两个版本对比

**使用示例**:

```typescript
import ConflictDialog from '@/components/Workspace/ConflictDialog';

function CanvasArea() {
  const [showConflict, setShowConflict] = useState(false);

  return (
    <>
      <ConflictDialog
        isOpen={showConflict}
        onClose={() => setShowConflict(false)}
        onUseRemote={() => {
          // Load remote version
          setShowConflict(false);
        }}
        onForceSave={() => {
          // Force save local version
          setShowConflict(false);
        }}
      />
    </>
  );
}
```

### 4. `RecycleBinPanel` 组件

**位置**: `web/src/components/Workspace/RecycleBinPanel.tsx`

**功能**:
- 查看已删除的图层
- 恢复已删除的图层
- 显示删除时间和删除人

**使用示例**:

```typescript
import RecycleBinPanel from '@/components/Workspace/RecycleBinPanel';

function Workspace() {
  const [showRecycleBin, setShowRecycleBin] = useState(false);
  const canvasId = 123; // Get from canvas data

  return (
    <>
      <button onClick={() => setShowRecycleBin(true)}>
        Open Recycle Bin
      </button>
      
      <RecycleBinPanel
        canvasId={canvasId}
        isOpen={showRecycleBin}
        onClose={() => setShowRecycleBin(false)}
        onRestore={(layerId) => {
          console.log('Layer restored:', layerId);
          // Reload layers from backend
        }}
      />
    </>
  );
}
```

### 5. `workspaceAPI` 客户端

**位置**: `web/src/lib/workspace-api.ts`

**功能**:
- 画布管理（获取、创建）
- 图层同步（批量创建/更新）
- 图层管理（更新、删除、恢复）
- 回收站管理

**API 方法**:

```typescript
import { workspaceAPI } from '@/lib/workspace-api';

// 获取画布
const canvasData = await workspaceAPI.getCanvas(projectId);

// 创建画布
const canvasId = await workspaceAPI.createCanvas(projectId, {
  name: 'Main Canvas',
  backgroundColor: '#ffffff',
  metadata: {
    gridSize: 10,
    snapEnabled: true,
  }
});

// 同步图层
const result = await workspaceAPI.syncLayers(projectId, [
  {
    id: 'layer-1',
    layerType: 'rectangle',
    name: 'My Rectangle',
    zIndex: 0,
    x: 100,
    y: 100,
    width: 200,
    height: 100,
    rotation: 0,
    visible: true,
    locked: false,
    properties: {
      color: '#3498db',
      stroke: '#2980b9',
      strokeWidth: 2,
    }
  }
]);

// 更新图层
await workspaceAPI.updateLayer(layerId, {
  x: 150,
  y: 150,
  properties: { color: '#e74c3c' }
});

// 删除图层（软删除）
await workspaceAPI.deleteLayer(layerId);

// 恢复图层
await workspaceAPI.restoreLayer(layerId);

// 获取已删除的图层
const deletedLayers = await workspaceAPI.getDeletedLayers(canvasId, 50);
```

## 集成到 CanvasArea

CanvasArea 组件已经集成了保存功能：

```typescript
// CanvasArea.tsx
import { useWorkspaceSave } from '@/hooks/useWorkspaceSave';
import SaveButton from '@/components/Workspace/SaveButton';
import ConflictDialog from '@/components/Workspace/ConflictDialog';
import RecycleBinPanel from '@/components/Workspace/RecycleBinPanel';

export default function CanvasArea({ projectId, isSidebarCollapsed }) {
  const {
    saveStatus,
    lastSavedAt,
    errorMessage,
    handleSave,
  } = useWorkspaceSave(parseInt(projectId));

  return (
    <div>
      {/* Top-right save button */}
      <div className="absolute top-4 right-4">
        <SaveButton
          saveStatus={saveStatus}
          lastSavedAt={lastSavedAt}
          onSave={handleSave}
          errorMessage={errorMessage}
        />
      </div>

      {/* Canvas content */}
      <EditorStage ... />

      {/* Conflict and recycle bin dialogs */}
      <ConflictDialog ... />
      <RecycleBinPanel ... />
    </div>
  );
}
```

## 快捷键

- **Ctrl/Cmd + S**: 手动保存
- **Ctrl/Cmd + Z**: 撤销（内存级，zundo 实现）
- **Ctrl/Cmd + Y**: 重做（内存级，zundo 实现）

## 保存策略

### 手动保存

用户需要手动触发保存操作，保存当前所有图层状态到后端。

**优势**:
- 减少不必要的网络请求
- 避免后端存储冗余历史数据
- 用户明确知道何时保存
- 支持离线编辑

### 离线支持

当网络不可用时，保存操作会自动将数据存入本地队列：

```typescript
// 保存到离线队列
localStorage.setItem('offlineSaveQueue', JSON.stringify(queue));

// 网络恢复后自动同步
window.addEventListener('online', syncOfflineChanges);
```

## 数据转换

### 前端 Element 到后端 Layer

```typescript
const elementToLayer = (element: BaseElement<any>) => {
  const state = element.toState();
  return {
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
      // Extract type-specific properties
      color: state.color,
      text: state.text,
      src: state.src,
      points: state.points,
      // ... etc
    }
  };
};
```

## 测试场景

### 1. 基本保存功能

1. 打开工作空间编辑器
2. 创建/修改图层
3. 点击保存按钮或按 Ctrl/Cmd + S
4. 验证保存状态变化：idle → saving → saved
5. 检查最后保存时间更新

### 2. 离线保存

1. 断开网络连接
2. 修改图层
3. 尝试保存
4. 验证显示"已保存到本地队列"提示
5. 恢复网络连接
6. 验证自动同步离线数据

### 3. 版本冲突

1. 打开两个浏览器窗口，编辑同一项目
2. 在窗口 A 保存修改
3. 在窗口 B 尝试保存
4. 验证显示冲突对话框
5. 测试三种解决方案

### 4. 回收站功能

1. 删除一个图层
2. 点击回收站按钮
3. 验证显示已删除图层列表
4. 点击恢复按钮
5. 验证图层恢复到画布

## 国际化

所有 UI 文本都支持国际化，需要在 i18n 消息文件中添加对应的翻译：

**web/src/i18n/messages/zh-CN.json**:
```json
{
  "workspace": {
    "save": "保存",
    "saving": "保存中...",
    "saved": "已保存",
    "save_error": "保存失败",
    "conflict": "版本冲突",
    "last_saved": "最后保存",
    "just_now": "刚刚",
    "minute_ago": "1 分钟前",
    "minutes_ago": "{count} 分钟前",
    "hour_ago": "1 小时前",
    "hours_ago": "{count} 小时前",
    "conflict_detected": "检测到版本冲突",
    "conflict_description": "其他用户刚刚保存了修改，请选择：",
    "conflict_tip": "使用远程版本将放弃您的修改，强制保存将覆盖其他用户的修改",
    "use_remote_version": "使用远程版本（放弃我的修改）",
    "force_save": "强制保存（覆盖远程版本）",
    "download_both_versions": "下载两个版本对比",
    "recycle_bin": "回收站",
    "recycle_bin_empty": "回收站为空",
    "restore": "恢复",
    "total_deleted": "已删除",
    "close": "关闭",
    "loading": "加载中..."
  }
}
```

**web/src/i18n/messages/en.json**:
```json
{
  "workspace": {
    "save": "Save",
    "saving": "Saving...",
    "saved": "Saved",
    "save_error": "Save Failed",
    "conflict": "Conflict",
    "last_saved": "Last saved",
    "just_now": "Just now",
    "minute_ago": "1 minute ago",
    "minutes_ago": "{count} minutes ago",
    "hour_ago": "1 hour ago",
    "hours_ago": "{count} hours ago",
    "conflict_detected": "Conflict Detected",
    "conflict_description": "Another user just saved changes. Please choose:",
    "conflict_tip": "Using remote version will discard your changes. Force save will overwrite remote changes.",
    "use_remote_version": "Use Remote Version (Discard My Changes)",
    "force_save": "Force Save (Overwrite Remote)",
    "download_both_versions": "Download Both Versions",
    "recycle_bin": "Recycle Bin",
    "recycle_bin_empty": "Recycle bin is empty",
    "restore": "Restore",
    "total_deleted": "Total Deleted",
    "close": "Close",
    "loading": "Loading..."
  }
}
```

## 注意事项

1. **projectId 必须是数字字符串**: 确保传递给 `useWorkspaceSave` 的 projectId 可以转换为整数
2. **网络错误处理**: 保存失败时会自动保存到离线队列
3. **保存状态管理**: 保存时会暂停历史跟踪，避免保存操作被记录到撤销历史
4. **权限控制**: 后端会自动处理 JWT 认证和权限验证
5. **软删除**: 删除操作是软删除，可以通过回收站恢复

## 后续优化

1. **自动保存**: 可以添加定时自动保存功能
2. **实时协作**: 可以集成 WebSocket 实现实时协作编辑
3. **版本对比**: 增强版本对比 UI，支持可视化差异显示
4. **批量操作**: 支持批量删除、批量恢复
5. **搜索过滤**: 回收站支持搜索和过滤功能
