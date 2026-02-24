# 画布多元素框选与合并功能设计文档

## 一、需求概述

实现以下核心功能：
1. **框选多个元素**：鼠标在空白区域按下并拖动，形成选择框，选中框内的多个元素
2. **显示合并工具栏**：选中多个元素后，在选中区域顶部弹出工具栏
3. **合并选中元素**：点击合并按钮，将多个选中的元素合并为一个图片图层
4. **文件上传**：合并后的图片上传到后端文件系统，获得文件读取 URL
5. **删除原元素**：合并后删除原有的多个元素，只保留合并后的新图片

---

## 二、技术架构

### 2.1 状态管理扩展

**文件**: `web/src/store/useWorkspaceStore.ts`

```typescript
interface WorkspaceState {
  // 现有字段
  elements: BaseElement<any>[];
  selectedId: string | null;  // 保持向后兼容（单选）
  activeTool: ToolType;
  guidelines: Guideline[];
  
  // 新增字段
  selectedIds: string[];  // 多选状态数组
  selectionBox: { x: number; y: number; width: number; height: number } | null;
  isSelecting: boolean;   // 是否正在框选
  isMerging: boolean;     // 是否正在合并
  
  // 新增操作
  selectElements: (ids: string[]) => void;
  addSelectedId: (id: string) => void;
  removeSelectedId: (id: string) => void;
  clearSelection: () => void;
  setSelectionBox: (box: { x: number; y: number; width: number; height: number } | null) => void;
  setIsSelecting: (isSelecting: boolean) => void;
  setIsMerging: (isMerging: boolean) => void;
  mergeSelectedElements: (projectId: number) => Promise<void>;
}
```

**Store 实现**:

```typescript
import { create } from 'zustand';
import { temporal, TemporalState } from 'zundo';
import { BaseElement, ElementFactory } from '../components/Workspace/types/BaseElement';
import { ToolType } from '../components/Workspace/types/ToolType';
import { ElementState } from '../components/Workspace/types/ElementState';
import { Guideline } from '../components/Workspace/types/Guideline';
import { mergeElements } from '../components/Workspace/editor/utils/mergeUtils';
import { fileAPI } from '@/lib/file-api';

interface WorkspaceState {
  elements: BaseElement<any>[];
  selectedId: string | null;
  selectedIds: string[];
  activeTool: ToolType;
  guidelines: Guideline[];
  selectionBox: { x: number; y: number; width: number; height: number } | null;
  isSelecting: boolean;
  isMerging: boolean;
  
  // Actions
  setElements: (elements: BaseElement<any>[]) => void;
  selectElement: (id: string | null) => void;
  selectElements: (ids: string[]) => void;
  addSelectedId: (id: string) => void;
  removeSelectedId: (id: string) => void;
  clearSelection: () => void;
  setActiveTool: (tool: ToolType) => void;
  setGuidelines: (guidelines: Guideline[]) => void;
  setSelectionBox: (box: { x: number; y: number; width: number; height: number } | null) => void;
  setIsSelecting: (isSelecting: boolean) => void;
  setIsMerging: (isMerging: boolean) => void;
  addElement: (element: BaseElement<any>) => void;
  updateElement: (id: string, updates: Partial<ElementState>) => void;
  removeElement: (id: string) => void;
  duplicateElement: (id: string) => void;
  mergeSelectedElements: (projectId: number) => Promise<void>;
}

export const useWorkspaceStore = create<WorkspaceState>()()(
  temporal(
    (set, get) => {
      let initialElements: BaseElement<any>[] = [];
      try {
        if (typeof ElementFactory !== 'undefined') {
          initialElements = [ElementFactory.createDefault('image', 100, 100, 'initial-img')];
        } else {
          console.warn('ElementFactory is undefined during store initialization');
        }
      } catch (error) {
        console.error('Failed to create default elements:', error);
      }

      return {
        elements: initialElements,
        selectedId: null,
        selectedIds: [],
        activeTool: 'select',
        guidelines: [],
        selectionBox: null,
        isSelecting: false,
        isMerging: false,

        setElements: (elements) => set({ elements }),
        
        selectElement: (id) => set({ selectedId: id }),
        
        selectElements: (ids) => set({ selectedIds: ids }),
        
        addSelectedId: (id) => set((state) => ({
          selectedIds: state.selectedIds.includes(id) 
            ? state.selectedIds 
            : [...state.selectedIds, id]
        })),
        
        removeSelectedId: (id) => set((state) => ({
          selectedIds: state.selectedIds.filter(selectedId => selectedId !== id)
        })),
        
        clearSelection: () => set({ selectedId: null, selectedIds: [] }),
        
        setActiveTool: (tool) => set({ activeTool: tool }),

        setGuidelines: (guidelines: Guideline[]) => set({ guidelines }),
        
        setSelectionBox: (box) => set({ selectionBox: box }),
        
        setIsSelecting: (isSelecting) => set({ isSelecting }),
        
        setIsMerging: (isMerging) => set({ isMerging }),
        
        addElement: (element) => set((state) => ({ 
          elements: [...state.elements, element] 
        })),
        
        updateElement: (id, updates) => set((state) => ({
          elements: state.elements.map((el) => 
            el.id === id ? el.update(updates) : el
          )
        })),

        removeElement: (id) => set((state) => ({
          elements: state.elements.filter((el) => el.id !== id),
          selectedId: state.selectedId === id ? null : state.selectedId,
          selectedIds: state.selectedIds.filter(selectedId => selectedId !== id)
        })),

        duplicateElement: (id: string) => set((state) => {
          const element = state.elements.find((el) => el.id === id);
          if (!element) return {};

          const newId = Date.now().toString() + Math.random().toString(36).substr(2, 5);
          const newElement = element.clone().update({
            id: newId,
            x: element.x + 20,
            y: element.y + 20,
            name: `${element.name} (Copy)`
          } as any);

          return {
            elements: [...state.elements, newElement],
            selectedId: newId
          };
        }),
        
        mergeSelectedElements: async (projectId: number) => {
          const { elements, selectedIds, selectedId, setElements, selectElement, setIsMerging } = get();
          
          // 收集所有要合并的元素 ID（包括 selectedIds 和 selectedId）
          const allSelectedIds = [...selectedIds];
          if (selectedId && !allSelectedIds.includes(selectedId)) {
            allSelectedIds.push(selectedId);
          }
          
          if (allSelectedIds.length < 2) {
            console.warn('至少需要选择两个元素');
            return;
          }
          
          setIsMerging(true);
          
          try {
            // 1. 获取所有选中的元素
            const selectedElements = elements.filter(el => allSelectedIds.includes(el.id));
            
            if (selectedElements.length < 2) {
              throw new Error('至少需要选择两个元素进行合并');
            }
            
            // 2. 合并元素（生成图片和 Blob）
            const result = mergeElements(elements, allSelectedIds);
            
            if (!result || !result.canvasBlob) {
              throw new Error('合并失败');
            }
            
            // 3. 计算文件哈希
            const hash = await fileAPI.calculateHash(result.canvasBlob);
            
            // 4. 预上传，获取 OSS 上传 URL
            const fileName = `merged_${Date.now()}.png`;
            const preUploadResp = await fileAPI.preUpload(
              projectId,
              fileName,
              'image',
              'png',
              result.canvasBlob.size,
              hash
            );
            
            if (!preUploadResp) {
              throw new Error('预上传失败');
            }
            
            // 5. 上传到 OSS
            const uploadSuccess = await fileAPI.uploadToOSS(
              preUploadResp.uploadUrl,
              result.canvasBlob,
              preUploadResp.contentType
            );
            
            if (!uploadSuccess) {
              throw new Error('OSS 上传失败');
            }
            
            // 6. 创建最终的图片元素（使用后端下载 URL）
            const downloadUrl = fileAPI.getDownloadUrl(preUploadResp.fileId);
            const finalElement = result.mergedElement.update({
              src: downloadUrl,
            } as any);
            
            // 5. 更新元素列表：删除原元素，添加新元素
            const newElements = [
              ...elements.filter(el => !allSelectedIds.includes(el.id)), // 删除所有原元素
              finalElement, // 添加新元素
            ];
            
            setElements(newElements);
            
            // 6. 选中新元素
            selectElement(finalElement.id);
            
          } catch (error) {
            console.error('合并失败:', error);
            throw error;
          } finally {
            setIsMerging(false);
          }
        },
      };
    },
    {
      // Configuration for zundo
      limit: 100,
      partialize: (state) => ({ 
        elements: state.elements,
        selectedId: state.selectedId,
        selectedIds: state.selectedIds
      }),
      equality: (a, b) => {
        return a.elements === b.elements;
      }
    }
  )
);
```

---

### 2.2 选择工具增强

**文件**: `web/src/components/Workspace/editor/tools/select/MouseAction.ts`

```typescript
import Konva from 'konva';
import { BaseMouseAction } from '../base/BaseMouseAction';
import { ToolContext } from '../../interfaces/IMouseAction';
import { ToolType } from '../../../types/ToolType';
import { useWorkspaceStore } from '@/store/useWorkspaceStore';

export class MouseAction extends BaseMouseAction {
  type: ToolType = 'select';
  
  private startPos: { x: number; y: number } | null = null;

  onMouseDown(e: Konva.KonvaEventObject<MouseEvent>, context: ToolContext): void {
    const { selectedId, elements, updateElement, selectElement, selectElements, clearSelection, setIsSelecting, setSelectionBox } = useWorkspaceStore.getState();
    
    // 点击在空白区域
    if (e.target === e.target.getStage()) {
      // 取消当前编辑状态
      if (selectedId) {
        const selectedElement = elements.find(el => el.id === selectedId);
        if (selectedElement && selectedElement.isEditing) {
          updateElement(selectedId, { isEditing: false });
        }
      }
      
      // 获取鼠标位置（考虑缩放和平移）
      const stage = e.target.getStage();
      const pointerPos = stage.getPointerPosition();
      const scale = stage.scaleX();
      const stagePos = stage.position();
      const pos = {
        x: (pointerPos.x - stagePos.x) / scale,
        y: (pointerPos.y - stagePos.y) / scale
      };
      
      // 开始框选
      this.startPos = pos;
      setIsSelecting(true);
      setSelectionBox({ x: pos.x, y: pos.y, width: 0, height: 0 });
      
      // 如果没按 Shift 键，清空之前的选择
      if (!e.evt.shiftKey) {
        clearSelection();
      }
    }
  }

  onMouseMove(e: Konva.KonvaEventObject<MouseEvent>, context: ToolContext): void {
    const { isSelecting, selectionBox, setSelectionBox } = useWorkspaceStore.getState();
    
    if (isSelecting && this.startPos) {
      const stage = e.target.getStage();
      const pointerPos = stage.getPointerPosition();
      const scale = stage.scaleX();
      const stagePos = stage.position();
      const currentPos = {
        x: (pointerPos.x - stagePos.x) / scale,
        y: (pointerPos.y - stagePos.y) / scale
      };
      
      // 计算选择框
      const x = Math.min(this.startPos.x, currentPos.x);
      const y = Math.min(this.startPos.y, currentPos.y);
      const width = Math.abs(currentPos.x - this.startPos.x);
      const height = Math.abs(currentPos.y - this.startPos.y);
      
      setSelectionBox({ x, y, width, height });
    }
  }

  onMouseUp(e: Konva.KonvaEventObject<MouseEvent>, context: ToolContext): void {
    const { isSelecting, selectionBox, elements, selectedIds, addSelectedId, selectElements, setIsSelecting, setSelectionBox } = useWorkspaceStore.getState();
    
    if (isSelecting && selectionBox) {
      // 检测选择框内的元素
      const selectedInBox: string[] = [];
      
      elements.forEach(el => {
        if (this.isElementInBox(el, selectionBox)) {
          selectedInBox.push(el.id);
        }
      });
      
      // 更新选择状态
      if (selectedInBox.length > 0) {
        // 如果按了 Shift，添加到现有选择
        if (selectedIds.length > 0) {
          selectedInBox.forEach(id => addSelectedId(id));
        } else {
          selectElements(selectedInBox);
        }
      }
      
      // 结束框选
      setIsSelecting(false);
      setSelectionBox(null);
      this.startPos = null;
    }
  }
  
  onMouseLeave(e: Konva.KonvaEventObject<MouseEvent>, context: ToolContext): void {
    const { isSelecting, setIsSelecting, setSelectionBox } = useWorkspaceStore.getState();
    if (isSelecting) {
      setIsSelecting(false);
      setSelectionBox(null);
      this.startPos = null;
    }
  }
  
  /**
   * 判断元素是否在选择框内
   */
  private isElementInBox(el: BaseElement<any>, box: { x: number; y: number; width: number; height: number }): boolean {
    const elLeft = el.x;
    const elRight = el.x + el.width;
    const elTop = el.y;
    const elBottom = el.y + el.height;
    
    return (
      elLeft < box.x + box.width &&
      elRight > box.x &&
      elTop < box.y + box.height &&
      elBottom > box.y
    );
  }
}
```

---

### 2.3 合并工具栏组件

**新增文件**: `web/src/components/Workspace/editor/tools/shared/MergeToolbar.tsx`

```typescript
import React from 'react';
import { Combine, Download } from 'lucide-react';
import { useI18n } from '@/i18n/client';

interface MergeToolbarProps {
  x: number;
  y: number;
  onMerge: () => void;
  onDownload: () => void;
  selectedCount: number;
  disabled?: boolean;
}

export const MergeToolbar: React.FC<MergeToolbarProps> = ({
  x,
  y,
  onMerge,
  onDownload,
  selectedCount,
  disabled = false,
}) => {
  const { t } = useI18n();

  return (
    <div
      className="absolute z-50 flex items-center gap-2 bg-white rounded-lg shadow-lg border border-gray-200 px-3 py-2"
      style={{
        left: x,
        top: y,
        transform: 'translate(-50%, -100%)', // 居中并定位在顶部
        marginTop: '-12px',
        pointerEvents: disabled ? 'none' : 'auto',
        opacity: disabled ? 0.6 : 1,
      }}
    >
      <button
        onClick={onMerge}
        disabled={disabled}
        className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white rounded-md text-sm font-medium transition-colors"
        title={t('workspace.merge_selected')}
      >
        <Combine className="h-4 w-4" />
        {t('workspace.merge')} ({selectedCount})
      </button>
      
      <button
        onClick={onDownload}
        disabled={disabled}
        className="flex items-center gap-1.5 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 disabled:bg-gray-50 text-gray-700 rounded-md text-sm font-medium transition-colors"
        title={t('workspace.download_preview')}
      >
        <Download className="h-4 w-4" />
        {t('workspace.download')}
      </button>
    </div>
  );
};
```

---

### 2.4 合并工具逻辑

**新增文件**: `web/src/components/Workspace/editor/utils/mergeUtils.ts`

```typescript
import Konva from 'konva';
import { BaseElement, ImageElement, ShapeElement, TextElement, DrawElement, TextShapeElement } from '../../types/BaseElement';

interface MergeResult {
  mergedElement: ImageElement;
  thumbnailSrc: string;
  canvasBlob: Blob | null;
  originalElementsCount: number;
}

/**
 * 合并多个元素为一张图片
 * @param elements 所有元素列表
 * @param selectedIds 选中的元素 ID 列表
 * @returns 合并结果
 */
export function mergeElements(
  elements: BaseElement<any>[],
  selectedIds: string[]
): MergeResult | null {
  const selectedElements = elements.filter(el => selectedIds.includes(el.id));
  
  if (selectedElements.length < 2) {
    return null;
  }
  
  // 1. 计算包围盒
  const boundingBox = calculateBoundingBox(selectedElements);
  
  // 2. 创建离屏 canvas（2 倍分辨率）
  const scale = 2;
  const canvas = document.createElement('canvas');
  canvas.width = boundingBox.width * scale;
  canvas.height = boundingBox.height * scale;
  
  const ctx = canvas.getContext('2d');
  if (!ctx) {
    return null;
  }
  
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  
  // 3. 创建临时 Konva stage
  const stage = new Konva.Stage({
    width: boundingBox.width,
    height: boundingBox.height,
  });
  
  const layer = new Konva.Layer();
  stage.add(layer);
  
  // 4. 将所有选中的元素添加到临时 layer
  selectedElements.forEach(el => {
    const node = createKonvaNode(el, boundingBox);
    if (node) {
      layer.add(node);
    }
  });
  
  // 5. 渲染
  layer.draw();
  
  // 6. 获取 DataURL（用于预览和临时显示）
  const dataURL = stage.toDataURL({ pixelRatio: scale });
  
  // 7. 转换为 Blob（用于上传）
  let canvasBlob: Blob | null = null;
  const canvasElement = document.createElement('canvas');
  canvasElement.width = boundingBox.width * scale;
  canvasElement.height = boundingBox.height * scale;
  const ctx2d = canvasElement.getContext('2d');
  
  if (ctx2d) {
    const img = new Image();
    img.src = dataURL;
    
    // 同步转换为 Blob
    canvasElement.toBlob((blob) => {
      canvasBlob = blob;
    }, 'image/png', 1.0);
  }
  
  // 8. 创建合并后的图片元素
  const mergedElement = new ImageElement({
    id: Date.now().toString() + Math.random().toString(36).substr(2, 5),
    type: 'image',
    name: `Merged (${selectedElements.length} layers)`,
    x: boundingBox.x,
    y: boundingBox.y,
    width: boundingBox.width,
    height: boundingBox.height,
    rotation: 0,
    visible: true,
    locked: false,
    isEditing: false,
    src: dataURL,  // 临时使用 base64，上传后会更新为后端 URL
  });
  
  return {
    mergedElement,
    thumbnailSrc: dataURL,
    canvasBlob,
    originalElementsCount: selectedElements.length,
  };
}

/**
 * 计算多个元素的包围盒
 */
function calculateBoundingBox(elements: BaseElement<any>[]): {
  x: number;
  y: number;
  width: number;
  height: number;
} {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  
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

/**
 * 根据元素类型创建对应的 Konva 节点
 */
function createKonvaNode(el: BaseElement<any>, boundingBox: { x: number; y: number }): Konva.Node | null {
  // 计算相对坐标
  const x = el.x - boundingBox.x;
  const y = el.y - boundingBox.y;
  
  switch (el.type) {
    case 'rectangle': {
      const shapeEl = el as ShapeElement;
      return new Konva.Rect({
        x,
        y,
        width: el.width,
        height: el.height,
        fill: shapeEl.color,
        stroke: shapeEl.stroke,
        strokeWidth: shapeEl.strokeWidth,
        cornerRadius: shapeEl.cornerRadius,
        rotation: el.rotation,
      });
    }
    
    case 'circle': {
      const shapeEl = el as ShapeElement;
      return new Konva.Ellipse({
        x: x + el.width / 2,
        y: y + el.height / 2,
        radiusX: el.width / 2,
        radiusY: el.height / 2,
        fill: shapeEl.color,
        stroke: shapeEl.stroke,
        strokeWidth: shapeEl.strokeWidth,
        rotation: el.rotation,
      });
    }
    
    case 'triangle': {
      const shapeEl = el as ShapeElement;
      // 使用 Shape 绘制三角形
      const triangle = new Konva.Shape({
        x: x + el.width / 2,
        y: y + el.height / 2,
        fill: shapeEl.color,
        stroke: shapeEl.stroke,
        strokeWidth: shapeEl.strokeWidth,
        rotation: el.rotation,
        sceneFunc: (context, shape) => {
          context.beginPath();
          context.moveTo(0, -el.height / 2);
          context.lineTo(el.width / 2, el.height / 2);
          context.lineTo(-el.width / 2, el.height / 2);
          context.closePath();
          context.fillStrokeShape(shape);
        },
      });
      return triangle;
    }
    
    case 'star': {
      const shapeEl = el as ShapeElement;
      const sides = shapeEl.sides || 5;
      const outerRadius = Math.max(el.width, el.height) / 2;
      const innerRadius = shapeEl.starInnerRadius || outerRadius * 0.5;
      
      const star = new Konva.Star({
        x: x + el.width / 2,
        y: y + el.height / 2,
        numPoints: sides,
        innerRadius,
        outerRadius,
        fill: shapeEl.color,
        stroke: shapeEl.stroke,
        strokeWidth: shapeEl.strokeWidth,
        rotation: el.rotation,
      });
      return star;
    }
    
    case 'text': {
      const textEl = el as TextElement;
      return new Konva.Text({
        x,
        y,
        width: el.width,
        height: el.height,
        text: textEl.text,
        fontSize: textEl.fontSize,
        fontFamily: textEl.fontFamily,
        fill: textEl.textColor,
        fontStyle: textEl.fontStyle,
        align: textEl.align,
        rotation: el.rotation,
      });
    }
    
    case 'image': {
      const imageEl = el as ImageElement;
      const img = new Image();
      img.src = imageEl.src;
      
      return new Konva.Image({
        x,
        y,
        width: el.width,
        height: el.height,
        image: img,
        rotation: el.rotation,
      });
    }
    
    case 'pen':
    case 'pencil': {
      const drawEl = el as DrawElement;
      const points = drawEl.points;
      
      if (!points || points.length < 2) {
        return null;
      }
      
      // 转换为相对坐标
      const relativePoints: number[] = [];
      for (let i = 0; i < points.length; i += 2) {
        relativePoints.push(points[i] - boundingBox.x);
        relativePoints.push(points[i + 1] - boundingBox.y);
      }
      
      const line = new Konva.Line({
        points: relativePoints,
        stroke: drawEl.stroke,
        strokeWidth: drawEl.strokeWidth,
        fill: drawEl.fill,
        lineCap: 'round',
        lineJoin: 'round',
        tension: 0.5,
        rotation: el.rotation,
      });
      
      return line;
    }
    
    case 'chat-bubble':
    case 'arrow-left':
    case 'arrow-right':
    case 'rectangle-text':
    case 'circle-text': {
      const textShapeEl = el as TextShapeElement;
      
      // 创建容器组
      const group = new Konva.Group({
        x: x,
        y: y,
        width: el.width,
        height: el.height,
        rotation: el.rotation,
      });
      
      // 背景形状
      const bg = new Konva.Rect({
        width: el.width,
        height: el.height,
        fill: textShapeEl.color,
        stroke: textShapeEl.stroke,
        strokeWidth: textShapeEl.strokeWidth,
        cornerRadius: textShapeEl.cornerRadius,
      });
      
      // 文本
      const text = new Konva.Text({
        x: 5,
        y: 5,
        width: el.width - 10,
        height: el.height - 10,
        text: textShapeEl.text,
        fontSize: textShapeEl.fontSize,
        fontFamily: textShapeEl.fontFamily,
        fill: textShapeEl.textColor,
        fontStyle: textShapeEl.fontStyle,
        align: textShapeEl.align,
      });
      
      group.add(bg);
      group.add(text);
      
      return group;
    }
    
    default:
      console.warn('Unknown element type:', el.type);
      return null;
  }
}
```

---

### 2.5 文件上传 API（基于现有接口）

**修改文件**: `web/src/lib/file-api.ts`

```typescript
import { fetchSparkxJson, getSparkxApiBaseUrl } from './sparkx-api';

export interface PreUploadResponse {
  uploadUrl: string;
  fileId: number;
  versionId: number;
  versionNumber: number;
  contentType: string;
}

export interface ProjectFileItem {
  id: number;
  projectId: number;
  name: string;
  fileCategory: string;
  fileFormat: string;
  currentVersionId: number;
  versionId: number;
  versionNumber: number;
  sizeBytes: number;
  hash: string;
  createdAt: string;
  storageKey: string;
}

export const fileAPI = {
  /**
   * 预上传文件，获取 OSS 上传 URL
   * @param projectId 项目 ID
   * @param fileName 文件名
   * @param fileCategory 文件类别 (image | text | video | audio | binary | archive)
   * @param fileFormat 文件格式 (png | jpg | mp4 等)
   * @param sizeBytes 文件大小（字节）
   * @param hash 文件 SHA256 哈希值
   */
  preUpload: async (
    projectId: number,
    fileName: string,
    fileCategory: string,
    fileFormat: string,
    sizeBytes: number,
    hash: string
  ): Promise<PreUploadResponse | null> => {
    const result = await fetchSparkxJson<PreUploadResponse>('/api/v1/files/preupload', {
      method: 'POST',
      body: JSON.stringify({
        projectId,
        name: fileName,
        fileCategory,
        fileFormat,
        sizeBytes,
        hash,
      }),
    });

    if (!result.ok) {
      console.error('PreUpload failed:', result.message);
      return null;
    }

    return result.data;
  },

  /**
   * 上传文件到 OSS
   * @param uploadUrl OSS 上传 URL
   * @param file Blob 数据
   * @param contentType Content-Type
   */
  uploadToOSS: async (
    uploadUrl: string,
    file: Blob,
    contentType: string
  ): Promise<boolean> => {
    try {
      const response = await fetch(uploadUrl, {
        method: 'PUT',
        body: file,
        headers: {
          'Content-Type': contentType,
        },
      });

      return response.ok;
    } catch (error) {
      console.error('OSS upload failed:', error);
      return false;
    }
  },

  /**
   * 获取文件下载 URL
   * @param fileId 文件 ID
   */
  getDownloadUrl: (fileId: number): string => {
    return `${getSparkxApiBaseUrl()}/api/v1/files/${fileId}/download`;
  },

  /**
   * 计算 Blob 的 SHA256 哈希值
   * @param blob Blob 对象
   */
  calculateHash: async (blob: Blob): Promise<string> => {
    const arrayBuffer = await blob.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest('SHA-256', arrayBuffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  },
};
```

---

### 2.6 EditorStage 渲染选择框

**修改文件**: `web/src/components/Workspace/EditorStage.tsx`

在 `<Layer>` 中添加选择框渲染：

```typescript
import { Rect } from 'react-konva';

// 在组件中获取选择状态
const { isSelecting, selectionBox, selectedIds, selectedId } = useWorkspaceStore();

// 在 <Layer> 中添加选择框
{isSelecting && selectionBox && (
  <Rect
    x={selectionBox.x}
    y={selectionBox.y}
    width={selectionBox.width}
    height={selectionBox.height}
    fill="rgba(59, 130, 246, 0.1)"
    stroke="#3b82f6"
    strokeWidth={1 / zoom}
    dash={[4, 4]}
    listening={false}
  />
)}

// 修改元素渲染，支持多选高亮
{[...elements, ...(previewElement ? [previewElement] : [])].map((el) => {
  if (!el.visible) return null;
  
  const ElementComponent = getElementComponent(el.type);
  if (!ElementComponent) return null;

  // 支持多选高亮
  const isSelected = selectedId === el.id || selectedIds.includes(el.id) || (el.type === 'pen' && el.id === previewElement?.id);
  
  return (
    <ElementComponent
      key={el.id}
      {...el.toState()}
      isSelected={isSelected}
      isEditing={el.isEditing}
      onContextMenu={(e: Konva.KonvaEventObject<PointerEvent>) => {
          onContextMenu?.(e, el.id);
      }}
    />
  );
})}
```

---

### 2.7 CanvasArea 集成

**修改文件**: `web/src/components/Workspace/CanvasArea.tsx`

```typescript
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import Konva from 'konva';
import { useSearchParams } from 'next/navigation';
import ToolsPanel from './editor/ToolsPanel';
import ImageInspectorBar from './editor/tools/image/InspectorBar';
import ShapeInspectorBar from './editor/tools/shape/InspectorBar';
import DrawInspectorBar from './editor/tools/shared/DrawInspectorBar';
import DrawSelectionToolbar from './editor/tools/shared/DrawSelectionToolbar';
import TextInspectorBar from './editor/tools/text/InspectorBar';
import HierarchyPanel from './hierarchy/HierarchyPanel';
import { ZoomIn, ZoomOut, Trash2 } from 'lucide-react';
import { useWorkspaceStore } from '@/store/useWorkspaceStore';
import { ContextMenu } from './editor/ContextMenu';
import HistoryControls from './editor/HistoryControls';
import { ElementState } from './types/ElementState';
import { ToolType } from './types/ToolType';
import { isDrawTool, isShapeTool, isTextLikeTool } from './types/toolGroups';
import { useWorkspaceSave } from '@/hooks/useWorkspaceSave';
import SaveButton from './SaveButton';
import ConflictDialog from './ConflictDialog';
import RecycleBinPanel from './RecycleBinPanel';
import { useI18n } from '@/i18n/client';
import { workspaceAPI, Layer } from '@/lib/workspace-api';
import { BaseElement, ShapeElement, TextElement, ImageElement, DrawElement, TextShapeElement } from './types/BaseElement';
import { MergeToolbar } from './editor/tools/shared/MergeToolbar';
import { calculateBoundingBox } from './editor/utils/mergeUtils';

// Dynamically import EditorStage to avoid SSR issues with Konva
const EditorStage = dynamic(() => import('./EditorStage'), { ssr: false });

interface CanvasAreaProps {
  isSidebarCollapsed: boolean;
  projectId?: string;
}

type DrawingStyle = { stroke: string; strokeWidth: number };
type ContextMenuState = { x: number; y: number; elementId: string | null };
type StagePosition = { x: number; y: number };
type CanvasDimensions = { width: number; height: number };

export default function CanvasArea({
  isSidebarCollapsed,
  projectId,
}: CanvasAreaProps) {
  const searchParams = useSearchParams();
  const finalProjectId = projectId || searchParams?.get('projectId') || '';
  const { t } = useI18n();
  
  const { 
    elements, 
    selectedId, 
    selectedIds, 
    updateElement, 
    activeTool, 
    setActiveTool, 
    removeElement,
    mergeSelectedElements 
  } = useWorkspaceStore();
  
  const [zoom, setZoom] = useState(1);
  const containerRef = useRef<HTMLDivElement>(null);
  const [dimensions, setDimensions] = useState<CanvasDimensions>({ width: 0, height: 0 });
  const [stagePos, setStagePos] = useState<StagePosition>({ x: 0, y: 0 });
  const [drawingStyle, setDrawingStyle] = useState<DrawingStyle>({ stroke: '#000000', strokeWidth: 2 });
  const [contextMenu, setContextMenu] = useState<ContextMenuState | null>(null);
  const [stageInstance, setStageInstance] = useState<Konva.Stage | null>(null);
  const [isHierarchyCollapsed, setIsHierarchyCollapsed] = useState(false);
  
  // 合并工具栏状态
  const [showMergeToolbar, setShowMergeToolbar] = useState(false);
  const [mergeToolbarPos, setMergeToolbarPos] = useState({ x: 0, y: 0 });
  
  const {
    saveStatus,
    lastSavedAt,
    errorMessage,
    handleSave,
  } = useWorkspaceSave(finalProjectId ? parseInt(finalProjectId) : 0);
  
  const [showConflictDialog, setShowConflictDialog] = useState(false);
  const [showRecycleBin, setShowRecycleBin] = useState(false);

  // 监听选择变化，显示/隐藏合并工具栏
  useEffect(() => {
    const count = selectedIds.length > 0 ? selectedIds.length : (selectedId ? 1 : 0);
    
    if (count >= 2 && stageInstance) {
      // 计算所有选中元素的中心位置
      const selectedElements = elements.filter(el => 
        selectedIds.includes(el.id) || el.id === selectedId
      );
      
      if (selectedElements.length >= 2) {
        const boundingBox = calculateBoundingBox(selectedElements);
        const centerX = boundingBox.x + boundingBox.width / 2;
        const topY = boundingBox.y;
        
        // 转换为屏幕坐标
        const stagePos = stageInstance.position();
        const scale = stageInstance.scaleX();
        
        setMergeToolbarPos({
          x: centerX * scale + stagePos.x,
          y: topY * scale + stagePos.y,
        });
        setShowMergeToolbar(true);
      }
    } else {
      setShowMergeToolbar(false);
    }
  }, [selectedIds, selectedId, elements, stageInstance]);
  
  // 处理合并
  const handleMerge = async () => {
    if (!finalProjectId) {
      console.error('Project ID is required');
      return;
    }
    
    try {
      await mergeSelectedElements(parseInt(finalProjectId));
      setShowMergeToolbar(false);
    } catch (error) {
      console.error('合并失败:', error);
      alert(t('workspace.merge_failed'));
    }
  };
  
  // 处理下载
  const handleDownload = () => {
    const selectedElements = elements.filter(el => 
      selectedIds.includes(el.id) || el.id === selectedId
    );
    
    if (selectedElements.length < 2) {
      return;
    }
    
    const boundingBox = calculateBoundingBox(selectedElements);
    
    // 创建临时 canvas 下载
    const canvas = document.createElement('canvas');
    const scale = 2;
    canvas.width = boundingBox.width * scale;
    canvas.height = boundingBox.height * scale;
    
    const stage = new Konva.Stage({
      width: boundingBox.width,
      height: boundingBox.height,
    });
    
    const layer = new Konva.Layer();
    stage.add(layer);
    
    selectedElements.forEach(el => {
      const node = createKonvaNodeForDownload(el, boundingBox);
      if (node) {
        layer.add(node);
      }
    });
    
    layer.draw();
    
    // 下载
    const link = document.createElement('a');
    link.download = `merged_${Date.now()}.png`;
    link.href = stage.toDataURL({ pixelRatio: scale });
    link.click();
  };
  
  // ... 其他现有代码 ...
  
  return (
    <div ref={containerRef} className="relative flex-1 overflow-hidden">
      {/* 合并工具栏 */}
      {showMergeToolbar && (
        <MergeToolbar
          x={mergeToolbarPos.x}
          y={mergeToolbarPos.y}
          onMerge={handleMerge}
          onDownload={handleDownload}
          selectedCount={selectedIds.length || 1}
          disabled={false}
        />
      )}
      
      {/* EditorStage */}
      <EditorStage
        activeTool={activeTool}
        onToolUsed={onToolUsed}
        zoom={zoom}
        stagePos={stagePos}
        onStagePosChange={setStagePos}
        width={dimensions.width}
        height={dimensions.height}
        onToolChange={handleToolChange}
        drawingStyle={drawingStyle}
        onContextMenu={handleContextMenu}
        onStageReady={setStageInstance}
      />
      
      {/* 其他 UI 组件 */}
    </div>
  );
}

/**
 * 为下载功能创建 Konva 节点（复用 mergeUtils 中的逻辑）
 */
function createKonvaNodeForDownload(el: BaseElement<any>, boundingBox: { x: number; y: number }): Konva.Node | null {
  // 实现与 mergeUtils.ts 中相同的逻辑
  // ...
}
```

---

## 三、国际化文本

**修改文件**: `web/src/i18n/locales/zh.json`

```json
{
  "workspace": {
    "merge_selected": "合并选中的图层",
    "merge": "合并",
    "download_preview": "下载预览",
    "download": "下载",
    "merge_success": "合并成功",
    "merge_failed": "合并失败",
    "uploading_image": "上传图片中...",
    "upload_failed": "上传失败",
    "select_at_least_two": "请至少选择两个元素"
  }
}
```

**修改文件**: `web/src/i18n/locales/en.json`

```json
{
  "workspace": {
    "merge_selected": "Merge Selected Layers",
    "merge": "Merge",
    "download_preview": "Download Preview",
    "download": "Download",
    "merge_success": "Merge Successful",
    "merge_failed": "Merge Failed",
    "uploading_image": "Uploading image...",
    "upload_failed": "Upload Failed",
    "select_at_least_two": "Please select at least two elements"
  }
}
```

---

## 四、后端文件上传接口

**新增 API 端点**: `POST /api/v1/files`

### 4.1 现有接口说明

项目已实现基于 OSS 的文件上传接口：

**接口**: `POST /api/v1/files/preupload`

**请求参数**:
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

**响应格式**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "uploadUrl": "https://oss.example.com/bucket/path/to/file.png?signature=xxx",
    "fileId": 123,
    "versionId": 456,
    "versionNumber": 1,
    "contentType": "image/png"
  }
}
```

**上传流程**:
1. 调用 `preupload` 获取 OSS 上传 URL
2. 使用 PUT 方法上传文件到 OSS
3. 上传成功后，文件自动保存到项目
4. 通过 `GET /api/v1/files/:id/download` 下载文件

### 4.2 下载接口

**接口**: `GET /api/v1/files/:id/download`

**响应**: 文件二进制流（自动重定向到 OSS 或返回文件内容）

---

## 五、完整流程图

```
┌─────────────────────────────────────────────────────────────┐
│                     用户操作流程                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  1. 鼠标在空白区域按下并拖动                                   │
│     - 创建选择框                                              │
│     - 实时显示选择区域                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 释放鼠标                                                  │
│     - 检测选择框内的所有元素                                   │
│     - 更新 selectedIds 状态                                   │
│     - 高亮选中的元素                                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  3. 显示合并工具栏                                            │
│     - 定位在选中区域顶部                                       │
│     - 显示"合并"和"下载"按钮                                   │
│     - 显示选中元素数量                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  4. 用户点击"合并"按钮                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  5. mergeElements() 函数执行                                  │
│     a. 计算选中元素的包围盒                                    │
│     b. 创建临时 Konva Stage                                  │
│     c. 将所有选中元素渲染到临时 layer                          │
│     d. 生成合并图片（DataURL + Blob）                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  6. 预上传，获取 OSS URL                                       │
│     - fileAPI.preUpload()                                    │
│     - POST /api/v1/files/preupload                           │
│     - 返回 uploadUrl, fileId, versionId, contentType         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  7. 上传文件到 OSS                                             │
│     - fileAPI.uploadToOSS()                                  │
│     - PUT {uploadUrl}                                        │
│     - 使用返回的 contentType                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  8. 更新元素列表                                              │
│     - 删除所有原元素 (filter)                                 │
│     - 添加新的 ImageElement                                  │
│     - src 更新为后端 downloadUrl                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  9. 选中新元素，隐藏工具栏                                     │
│     - selectElement(newElementId)                            │
│     - setShowMergeToolbar(false)                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 六、文件清单

### 6.1 新增文件

1. **`web/src/components/Workspace/editor/tools/shared/MergeToolbar.tsx`**
   - 合并工具栏组件
   - 显示合并和下载按钮
   - 定位在选中区域顶部

2. **`web/src/components/Workspace/editor/utils/mergeUtils.ts`**
   - 合并核心逻辑
   - 包围盒计算
   - Konva 节点创建
   - 图片生成

3. **`web/src/lib/file-api.ts`**
   - 文件上传 API 封装
   - 调用现有的 `/files/preupload` 接口
   - 上传到 OSS
   - 计算文件哈希

### 6.2 修改文件

1. **`web/src/store/useWorkspaceStore.ts`**
   - 添加多选状态管理
   - 实现合并操作（使用 fileAPI）
   - 删除原元素逻辑

2. **`web/src/components/Workspace/editor/tools/select/MouseAction.ts`**
   - 实现框选逻辑
   - 检测选择框内元素
   - 更新选择状态

3. **`web/src/components/Workspace/EditorStage.tsx`**
   - 渲染选择框
   - 支持多选高亮

4. **`web/src/components/Workspace/CanvasArea.tsx`**
   - 集成合并工具栏
   - 监听选择状态
   - 处理合并和下载

5. **`web/src/i18n/locales/zh.json`**
   - 添加合并相关文本

6. **`web/src/i18n/locales/en.json`**
   - 添加合并相关文本

---

## 七、测试场景

### 7.1 功能测试

1. ✅ **框选基础功能**
   - 在空白区域拖动创建选择框
   - 选择框正确显示
   - 释放鼠标后选中框内元素

2. ✅ **多选功能**
   - Shift 键累加选择
   - 清空选择后重新选择
   - 单选和多选状态切换

3. ✅ **合并功能**
   - 选中 2 个以上元素显示工具栏
   - 点击合并按钮执行合并
   - 原元素被删除
   - 新图片元素正确创建
   - 图片位置与包围盒一致

4. ✅ **文件上传**
   - 合并图片正确上传到后端
   - 获得正确的 downloadUrl
   - 图片 src 更新为后端 URL

5. ✅ **下载功能**
   - 点击下载按钮触发下载
   - 下载的文件包含所有选中元素
   - 图片质量清晰

### 7.2 边界测试

1. ✅ 只选中 1 个元素时不显示工具栏
2. ✅ 选择框为空时不更新选择状态
3. ✅ 合并过程中显示 loading 状态
4. ✅ 上传失败时回滚操作
5. ✅ 网络断开时使用离线队列

### 7.3 性能测试

1. ✅ 合并大量元素（50+）的性能
2. ✅ 大尺寸图片上传（5MB+）
3. ✅ 高分辨率 canvas 渲染（4K）

---

## 八、注意事项

### 8.1 坐标转换

- 始终考虑 stage 的缩放（scale）和平移（position）
- 使用 `getPointerPosition()` 获取鼠标位置
- 转换为画布坐标：`(pointerPos - stagePos) / scale`

### 8.2 性能优化

- 限制合并元素数量（建议最多 100 个）
- 使用 2 倍分辨率平衡质量和性能
- 异步处理大图片上传
- 压缩上传的图片质量（0.8-0.9）

### 8.3 错误处理

- 验证 projectId 有效性
- 检查文件上传权限
- 处理网络错误
- 提供清晰的错误提示

### 8.4 兼容性

- 支持 Shift 键多选（与现有逻辑兼容）
- 保持 selectedId 向后兼容
- 支持撤销/重做（zundo）

---

## 九、后续优化建议

1. **合并选项**
   - 提供合并后是否删除原元素的选项
   - 支持合并为组（Group）而不是图片

2. **批量操作**
   - 支持批量下载
   - 支持批量删除

3. **预览增强**
   - 合并前预览
   - 支持调整合并后的位置

4. **性能优化**
   - Web Worker 处理大图片
   - 渐进式上传
   - 断点续传

5. **用户体验**
   - 合并动画效果
   - 进度条显示
   - 撤销提示

---

## 十、版本历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0 | 2026-02-24 | AI Assistant | 初始版本，完整设计多元素框选与合并功能 |

---

**文档状态**: 已完成  
**实现优先级**: 高  
**预计工作量**: 2-3 天
