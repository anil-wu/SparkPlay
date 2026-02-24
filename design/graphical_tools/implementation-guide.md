# 多元素框选与合并功能 - 实现说明

## 概述

本文档说明如何使用现有的文件上传接口实现画布多元素框选与合并功能。

## 核心流程

### 1. 框选多个元素

```
用户操作 → MouseAction.ts → useWorkspaceStore
```

**关键代码位置**:
- `web/src/components/Workspace/editor/tools/select/MouseAction.ts`
  - `onMouseDown()`: 开始框选，创建选择框
  - `onMouseMove()`: 更新选择框大小
  - `onMouseUp()`: 检测框内元素，更新 selectedIds

**状态管理**:
```typescript
interface WorkspaceState {
  selectedIds: string[];  // 多选 ID 数组
  selectionBox: { x, y, width, height } | null;
  isSelecting: boolean;
}
```

### 2. 显示合并工具栏

```
选择状态变化 → useEffect → MergeToolbar 定位
```

**关键代码位置**:
- `web/src/components/Workspace/CanvasArea.tsx`
  - 监听 `selectedIds` 和 `selectedId` 变化
  - 计算选中元素的包围盒
  - 定位工具栏在包围盒顶部居中

**工具栏组件**:
- `web/src/components/Workspace/editor/tools/shared/MergeToolbar.tsx`
  - 合并按钮
  - 下载按钮
  - 显示选中元素数量

### 3. 合并元素（核心流程）

```
用户点击合并 → mergeSelectedElements → mergeElements → fileAPI → 更新元素
```

#### 步骤 1: 收集选中的元素

```typescript
const allSelectedIds = [...selectedIds];
if (selectedId && !allSelectedIds.includes(selectedId)) {
  allSelectedIds.push(selectedId);
}

const selectedElements = elements.filter(el => allSelectedIds.includes(el.id));
```

#### 步骤 2: 合并为图片

```typescript
const result = mergeElements(elements, allSelectedIds);
```

**mergeElements 函数** (`mergeUtils.ts`):
1. 计算所有选中元素的包围盒
2. 创建临时 Konva Stage（离屏渲染）
3. 将所有元素添加到临时 layer
4. 渲染并生成 DataURL（预览用）
5. 转换为 Blob（上传用）

#### 步骤 3: 上传到 OSS（使用现有接口）

```typescript
// 3.1 计算文件哈希
const hash = await fileAPI.calculateHash(result.canvasBlob);

// 3.2 预上传，获取 OSS URL
const preUploadResp = await fileAPI.preUpload(
  projectId,
  fileName,
  'image',
  'png',
  result.canvasBlob.size,
  hash
);

// 3.3 上传到 OSS
const uploadSuccess = await fileAPI.uploadToOSS(
  preUploadResp.uploadUrl,
  result.canvasBlob,
  preUploadResp.contentType
);

// 3.4 获取下载 URL
const downloadUrl = fileAPI.getDownloadUrl(preUploadResp.fileId);
```

**fileAPI 实现** (`web/src/lib/file-api.ts`):
- `preUpload()`: 调用 `POST /api/v1/files/preupload`
- `uploadToOSS()`: PUT 上传到返回的 uploadUrl
- `calculateHash()`: 计算 SHA256 哈希
- `getDownloadUrl()`: 生成下载 URL

#### 步骤 4: 更新元素列表

```typescript
// 删除所有原元素，添加新元素
const newElements = [
  ...elements.filter(el => !allSelectedIds.includes(el.id)),
  finalElement.update({ src: downloadUrl })
];

setElements(newElements);
selectElement(finalElement.id);
```

## 后端接口说明

### POST /api/v1/files/preupload

**请求**:
```json
{
  "projectId": 123,
  "name": "merged_1708765432.png",
  "fileCategory": "image",
  "fileFormat": "png",
  "sizeBytes": 102400,
  "hash": "a1b2c3d4e5f6..."
}
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "uploadUrl": "https://oss.example.com/...",
    "fileId": 123,
    "versionId": 456,
    "versionNumber": 1,
    "contentType": "image/png"
  }
}
```

### PUT {uploadUrl}

上传文件到 OSS，使用响应中的 `contentType`。

### GET /api/v1/files/:id/download

下载文件接口，返回文件二进制流。

## 文件清单

### 新增文件

1. ✅ `web/src/lib/file-api.ts` - 文件上传 API
2. ⏳ `web/src/components/Workspace/editor/tools/shared/MergeToolbar.tsx` - 合并工具栏
3. ⏳ `web/src/components/Workspace/editor/utils/mergeUtils.ts` - 合并工具函数

### 修改文件

1. ⏳ `web/src/store/useWorkspaceStore.ts` - 添加多选状态和合并操作
2. ⏳ `web/src/components/Workspace/editor/tools/select/MouseAction.ts` - 实现框选逻辑
3. ⏳ `web/src/components/Workspace/EditorStage.tsx` - 渲染选择框
4. ⏳ `web/src/components/Workspace/CanvasArea.tsx` - 集成工具栏
5. ⏳ `web/src/i18n/locales/zh.json` - 国际化文本
6. ⏳ `web/src/i18n/locales/en.json` - 国际化文本

## 实现优先级

### Phase 1: 基础功能（高优先级）

1. ✅ 创建 `file-api.ts`
2. ⏳ 实现 `MouseAction.ts` 框选逻辑
3. ⏳ 实现 `mergeUtils.ts` 合并逻辑
4. ⏳ 修改 `useWorkspaceStore.ts` 添加状态和合并操作

### Phase 2: UI 集成（中优先级）

5. ⏳ 创建 `MergeToolbar.tsx` 组件
6. ⏳ 在 `CanvasArea.tsx` 中集成工具栏
7. ⏳ 在 `EditorStage.tsx` 中渲染选择框

### Phase 3: 完善功能（低优先级）

8. ⏳ 添加国际化文本
9. ⏳ 实现下载功能
10. ⏳ 添加错误处理和加载状态

## 测试要点

### 功能测试

- [ ] 框选 2 个以上元素
- [ ] 工具栏正确显示在顶部
- [ ] 合并后原元素被删除
- [ ] 新图片使用后端 URL
- [ ] 文件成功上传到 OSS

### 边界测试

- [ ] 只选 1 个元素时不显示工具栏
- [ ] 选择框为空时不更新选择
- [ ] 上传失败时回滚操作
- [ ] 网络错误处理

### 性能测试

- [ ] 合并大量元素（50+）
- [ ] 大尺寸图片上传（5MB+）
- [ ] 高分辨率渲染（4K）

## 注意事项

### 1. 坐标转换

始终考虑 stage 的缩放和平移：
```typescript
const pos = {
  x: (pointerPos.x - stagePos.x) / scale,
  y: (pointerPos.y - stagePos.y) / scale
};
```

### 2. 文件哈希计算

使用 Web Crypto API：
```typescript
const hashBuffer = await crypto.subtle.digest('SHA-256', arrayBuffer);
const hashArray = Array.from(new Uint8Array(hashBuffer));
const hash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
```

### 3. OSS 上传

必须使用后端返回的 `contentType`：
```typescript
headers: {
  'Content-Type': preUploadResp.contentType
}
```

### 4. 错误处理

所有异步操作都要添加 try-catch：
```typescript
try {
  await mergeSelectedElements(projectId);
} catch (error) {
  console.error('合并失败:', error);
  alert(t('workspace.merge_failed'));
}
```

## 后续优化

1. **合并选项**
   - 提供"保留原元素"选项
   - 支持合并为组（Group）

2. **性能优化**
   - Web Worker 处理大图片
   - 渐进式上传
   - 压缩图片质量

3. **用户体验**
   - 合并动画效果
   - 进度条显示
   - 撤销提示

## 参考文档

- [设计文档](./multi-select-merge-design.md)
- [后端 API 文档](../../service/sparkx.api)
- [文件上传测试](../../service/tests/api/file_upload_test.go)

---

**文档状态**: 草稿  
**更新日期**: 2026-02-24  
**实现进度**: 10% (file-api.ts 已完成)
