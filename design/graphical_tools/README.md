# 多元素框选与合并功能 - 总结

## ✅ 已完成的工作

### 1. 设计文档输出

已创建完整的设计文档到 `design/graphical_tools/` 目录：

#### 📄 multi-select-merge-design.md (完整设计文档)

**包含内容**:
- ✅ 需求概述
- ✅ 技术架构设计（状态管理、工具实现、组件设计）
- ✅ 合并工具逻辑（离屏渲染、包围盒计算）
- ✅ **文件上传 API（基于现有 /files/preupload 接口）**
- ✅ 完整流程图
- ✅ 文件清单
- ✅ 测试场景
- ✅ 注意事项和优化建议

**关键设计决策**:
1. 使用 `selectedIds` 数组管理多选状态
2. 框选逻辑在 `MouseAction.ts` 中实现
3. 合并工具栏定位在选中区域顶部
4. **使用现有的 OSS 文件上传流程**
5. 合并后删除所有原元素

#### 📄 implementation-guide.md (实现指南)

**包含内容**:
- ✅ 核心流程说明
- ✅ 代码示例和关键代码位置
- ✅ 后端接口详细说明
- ✅ 实现优先级（Phase 1-3）
- ✅ 测试要点
- ✅ 注意事项（坐标转换、哈希计算、OSS 上传）

### 2. 文件上传 API 实现

**已创建文件**: `web/src/lib/file-api.ts`

**实现的 API**:
```typescript
fileAPI = {
  preUpload( projectId, fileName, fileCategory, fileFormat, sizeBytes, hash )
  uploadToOSS( uploadUrl, file, contentType )
  getDownloadUrl( fileId )
  calculateHash( blob )
}
```

**关键特性**:
- ✅ 调用现有的 `POST /api/v1/files/preupload` 接口
- ✅ 获取 OSS 上传 URL
- ✅ 直接上传到 OSS（PUT 方法）
- ✅ 计算 SHA256 哈希用于文件验证
- ✅ 生成后端下载 URL

## 🎯 核心功能设计

### 功能 1: 框选多个元素

```
鼠标按下 → 创建选择框 → 鼠标移动 → 更新选择框 → 鼠标释放 → 检测元素 → 更新 selectedIds
```

**状态扩展**:
```typescript
interface WorkspaceState {
  selectedIds: string[];           // 多选 ID 数组
  selectionBox: {...} | null;      // 选择框
  isSelecting: boolean;            // 是否正在选择
}
```

### 功能 2: 显示合并工具栏

```
选择状态变化 → 计算包围盒 → 转换为屏幕坐标 → 定位工具栏
```

**定位逻辑**:
```typescript
const boundingBox = calculateBoundingBox(selectedElements);
const centerX = boundingBox.x + boundingBox.width / 2;
const topY = boundingBox.y;

// 转换为屏幕坐标
const screenX = centerX * scale + stagePos.x;
const screenY = topY * scale + stagePos.y;
```

### 功能 3: 合并元素（基于现有文件系统）

**完整流程**:

```
1. 收集选中的元素 ID
   ↓
2. mergeElements() - 离屏渲染
   - 计算包围盒
   - 创建临时 Konva Stage
   - 渲染所有元素
   - 生成 DataURL 和 Blob
   ↓
3. 计算文件哈希
   - crypto.subtle.digest('SHA-256', blob)
   ↓
4. 预上传（使用现有接口）
   - POST /api/v1/files/preupload
   - 返回 uploadUrl, fileId, contentType
   ↓
5. 上传到 OSS
   - PUT {uploadUrl}
   - 使用返回的 contentType
   ↓
6. 生成下载 URL
   - GET /api/v1/files/:id/download
   ↓
7. 更新元素列表
   - 删除所有原元素
   - 添加新 ImageElement（src = downloadUrl）
   ↓
8. 选中新元素，隐藏工具栏
```

## 📋 待实现的文件

### 新增文件（3 个）

1. ✅ `web/src/lib/file-api.ts` - **已完成**
2. ⏳ `web/src/components/Workspace/editor/tools/shared/MergeToolbar.tsx`
3. ⏳ `web/src/components/Workspace/editor/utils/mergeUtils.ts`

### 修改文件（6 个）

1. ⏳ `web/src/store/useWorkspaceStore.ts`
2. ⏳ `web/src/components/Workspace/editor/tools/select/MouseAction.ts`
3. ⏳ `web/src/components/Workspace/EditorStage.tsx`
4. ⏳ `web/src/components/Workspace/CanvasArea.tsx`
5. ⏳ `web/src/i18n/locales/zh.json`
6. ⏳ `web/src/i18n/locales/en.json`

## 🔧 关键技术点

### 1. 离屏渲染

使用 Konva 的 Stage.toDataURL() 进行离屏渲染：

```typescript
const stage = new Konva.Stage({
  width: boundingBox.width,
  height: boundingBox.height,
});

const layer = new Konva.Layer();
stage.add(layer);

// 添加所有选中的元素
selectedElements.forEach(el => {
  const node = createKonvaNode(el, boundingBox);
  if (node) layer.add(node);
});

layer.draw();
const dataURL = stage.toDataURL({ pixelRatio: 2 });
```

### 2. 包围盒计算

```typescript
function calculateBoundingBox(elements: BaseElement<any>[]) {
  let minX = Infinity, minY = Infinity;
  let maxX = -Infinity, maxY = -Infinity;
  
  elements.forEach(el => {
    minX = Math.min(minX, el.x);
    minY = Math.min(minY, el.y);
    maxX = Math.max(maxX, el.x + el.width);
    maxY = Math.max(maxY, el.y + el.height);
  });
  
  return {
    x: minX,
    y: minY,
    width: maxX - minX,
    height: maxY - minY,
  };
}
```

### 3. 文件哈希计算

使用 Web Crypto API：

```typescript
async function calculateHash(blob: Blob): Promise<string> {
  const arrayBuffer = await blob.arrayBuffer();
  const hashBuffer = await crypto.subtle.digest('SHA-256', arrayBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
```

### 4. OSS 上传流程

```typescript
// Step 1: 预上传获取 URL
const preUploadResp = await fileAPI.preUpload(
  projectId,
  fileName,
  'image',
  'png',
  blob.size,
  hash
);

// Step 2: 上传到 OSS
const success = await fileAPI.uploadToOSS(
  preUploadResp.uploadUrl,
  blob,
  preUploadResp.contentType
);

// Step 3: 生成下载 URL
const downloadUrl = fileAPI.getDownloadUrl(preUploadResp.fileId);
```

## 📊 实现进度

```
总体进度：10%

Phase 1: 基础功能
  ✅ file-api.ts 创建完成
  ⏳ mergeUtils.ts (0%)
  ⏳ useWorkspaceStore.ts 扩展 (0%)
  ⏳ MouseAction.ts 框选逻辑 (0%)

Phase 2: UI 集成
  ⏳ MergeToolbar.tsx (0%)
  ⏳ CanvasArea.tsx 集成 (0%)
  ⏳ EditorStage.tsx 选择框渲染 (0%)

Phase 3: 完善功能
  ⏳ 国际化文本 (0%)
  ⏳ 下载功能 (0%)
  ⏳ 错误处理 (0%)
```

## 🎯 下一步行动

### 立即执行

1. **实现 mergeUtils.ts** - 合并核心逻辑
2. **扩展 useWorkspaceStore.ts** - 添加多选状态和合并操作
3. **实现 MouseAction.ts** - 框选逻辑

### 随后执行

4. **创建 MergeToolbar.tsx** - 工具栏组件
5. **集成到 CanvasArea.tsx** - 监听选择、显示工具栏
6. **修改 EditorStage.tsx** - 渲染选择框

### 最后完善

7. **添加国际化文本**
8. **实现下载功能**
9. **完善错误处理**

## ⚠️ 重要注意事项

### 1. 坐标系统

始终考虑 stage 的缩放和平移：

```typescript
// 画布坐标 = (屏幕坐标 - stage 位置) / 缩放
const canvasPos = {
  x: (screenX - stagePos.x) / scale,
  y: (screenY - stagePos.y) / scale
};
```

### 2. 文件上传必须使用后端返回的 ContentType

```typescript
// ❌ 错误：使用默认类型
headers: { 'Content-Type': 'image/png' }

// ✅ 正确：使用后端返回的类型
headers: { 'Content-Type': preUploadResp.contentType }
```

### 3. 合并操作的事务性

合并失败时需要回滚：

```typescript
try {
  const originalElements = [...elements];
  
  // 执行合并...
  
  // 成功：更新元素
  setElements(newElements);
} catch (error) {
  // 失败：回滚（可选）
  console.error('合并失败:', error);
  throw error;
}
```

### 4. 性能考虑

- 限制合并元素数量（建议最多 100 个）
- 使用 2 倍分辨率平衡质量和性能
- 大图片异步上传
- 考虑压缩图片质量（0.8-0.9）

## 📚 参考资源

### 设计文档

- [完整设计文档](./multi-select-merge-design.md)
- [实现指南](./implementation-guide.md)

### 后端接口

- [API 定义](../../service/sparkx.api) - 查看 `/files/preupload` 接口
- [上传测试示例](../../service/tests/api/file_upload_test.go)

### 相关代码

- [file-api.ts](../../web/src/lib/file-api.ts) - 已实现
- [sparkx-api.ts](../../web/src/lib/sparkx-api.ts) - 基础 API 封装

## 📞 需要帮助？

如有问题，请查阅：

1. 设计文档中的详细说明
2. 后端 API 测试代码
3. Konva.js 官方文档：https://konvajs.org/

---

**文档状态**: ✅ 设计完成  
**创建日期**: 2026-02-24  
**实现进度**: 10%  
**下一步**: 实现 mergeUtils.ts 和 MouseAction.ts
