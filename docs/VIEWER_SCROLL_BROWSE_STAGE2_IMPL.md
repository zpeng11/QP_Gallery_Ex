# Viewer Scroll Browse Stage2 实施说明

## 已实现范围
- 在 `viewer` 布局中新增连续流容器：
  - `@id/container` (`ScrollView`)
  - `@id/items` (`LinearLayout`)
- 当 `viewer_scroll_browse=true` 时：
  - 隐藏原单图 `PictureView` 与过渡层 `showing`。
  - 动态构建纵向图片流（按相册顺序添加图片项）。
  - 通过滚动中心点计算“当前焦点图”。
  - 将焦点图同步回原有 viewer 状态（当前索引/当前 URI/当前类型），并继续使用原有解码链路驱动动作菜单目标。
- `as` / `dp` 两条 viewer 入口都已接入同一策略。

## 主要改动文件
- `decoded/res/layout/viewer.xml`
- `decoded/smali/com/alensw/ui/c/as.smali`
- `decoded/smali/com/alensw/ui/c/dp.smali`
- `decoded/smali/com/alensw/ui/c/as_scroll_touch.smali` (new)
- `decoded/smali/com/alensw/ui/c/dp_scroll_touch.smali` (new)
- `patches/viewer-scroll-browse-stage2.patch`
- `patches/series`

## 行为说明
- 开关关闭：保持 stage1 及历史单图行为。
- 开关开启：进入连续流浏览，滚动时实时更新焦点图，并让详情/分享/删除等操作作用于当前焦点图。

## 当前约束
- 当前实现优先保证功能落地与兼容，尚未引入窗口复用与分层预加载。
- 连续流中的图片项使用 `ImageView + setImageURI`，焦点图通过原 `PictureView` 解码链路维持动作一致性。
- 后续可继续演进：窗口化复用、焦点缩放状态保留、滚动性能优化。
