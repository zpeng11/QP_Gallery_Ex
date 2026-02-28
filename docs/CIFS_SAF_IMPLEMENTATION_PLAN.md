# CIFS SAF 相册接入规划

## 目标
通过 `CIFS DocumentProvider`（SAF 提供者）把远程目录接入 QuickPic 的相册能力，满足以下体验：
- 在 `Settings -> Albums -> Included folders` 中可直接唤起 SAF 目录选择器。
- 在 `Settings -> Albums -> Excluded folders` 中也可直接唤起 SAF 目录选择器。
- 可把 `content://...` 的 CIFS 树 URI 持久保存到“包含目录”配置。
- 可把 `content://...` 的 CIFS 树 URI 持久保存到“排除目录”配置。
- 不影响现有本地文件系统扫描与浏览。
- 后续逐步演进到“与本机目录一致的相册浏览形态”。

## 当前状态（已完成）
当前仓库已落地 **阶段 1 + 阶段 2** 并可编译安装：
- 新增 Included/Excluded folders 的 SAF 入口：在开启 `external_files` 时，`Add` 走 `ACTION_OPEN_DOCUMENT_TREE`。
- 选择目录后执行 `takePersistableUriPermission`，并把 `treeUri.toString()` 写入原目录列表。
- 兼容修复：扫描器仅把以 `/` 开头的本地路径纳入 include/exclude 匹配，避免 `content://` 条目污染本地扫描。
- 兼容修复：公共起始目录推导时忽略非本地路径，避免文件浏览默认路径异常。
- 阶段 2 新增：Included/Excluded 列表支持单击 `content://` 条目直接进入文档目录浏览。
- 阶段 2 新增：运行时 URI 标准化（`tree/.../document/...` -> `document/...`），并在 `UriFile` 入口统一接入。

对应补丁：
- `patches/saf-included-folders-stage1.patch`
- `patches/saf-included-folders-stage2-open-and-uri-normalize.patch`

## 架构判断
现有代码分成两条主路径：
- 本地路径扫描链：`com.alensw.a.e(File)` + `com.alensw.a.v` + `MediaStore _data`。
- 文档提供者链：`DocumentRoot/DocumentFolder/DocumentFile` + `com.alensw.a.av(QueryCursorTask)` + `com.alensw.ui.c.z`。

结论：
- 第一阶段不应把 `content://` 强行塞进本地扫描链核心类型，否则容易引入大量行为回归。
- 正确方向是“配置层接 SAF + 浏览层复用 DocumentFolder + 聚合层统一展示”。

## 分阶段实施计划

### 阶段 1（已完成）
目标：用户可在 Included/Excluded folders 增加 SAF 目录且不破坏本地扫描。
- 设置页触发 SAF 目录选择。
- 目录授权持久化。
- 路径匹配与默认目录推导对 `content://` 做隔离。

验收：
- Included/Excluded 列表可出现 `content://`。
- 本地相册扫描数量与性能未明显回退。

### 阶段 2（已完成）
目标：可从设置中的 SAF 目录直接进入“文档目录浏览”。
- 复用现有 `DocumentFolder`，不新增 `SafRoot/SafFolder` 模型。
- 在 `Included folders` 与 `Excluded folders` 列表项中，为 `content://` 条目增加“单击打开”动作。
- 打开时走 `com.alensw.ui.c.z` 页面渲染，复用 `QueryCursorTask` / `DocumentFolder`。
- 对 `tree/document/document` 形态做运行时 URI 兼容与标准化，配置存储保持原始 tree 字符串不改写。
- 在 `UriFile` 内容 URI 入口统一执行标准化，确保递归目录扫描、相册缩略图与图片打开加载链路都走同一 SAF 语义。

验收：
- 可浏览 CIFS provider 下的子目录与媒体文件。
- 预览、滑动查看、返回栈可用。
- 递归目录扫描可继续进入深层子目录。
- 缩略图加载与图片打开在 `tree` / `document` 两种 URI 输入下行为一致。

### 阶段 3
目标：SAF 相册与本地相册在首页统一呈现。
- 建立“本地目录 + SAF 根目录”的聚合索引层。
- 封面、数量、时间戳统一字段映射。
- 排序/搜索策略统一，但区分 capability（读写、移动、删除）。

验收：
- 首页可同时显示本地与 SAF 相册。
- 排序、搜索、封面刷新可用。

### 阶段 4
目标：体验打磨与稳定性。
- 离线/网络抖动容错（重试、超时、空态、错误提示）。
- 权限失效检测与重授权入口。
- 缓存策略（缩略图、目录元数据）与内存上限治理。

验收：
- CIFS 不可达时 UI 不阻塞。
- 权限被系统回收后可引导恢复。

## 关键风险与对策
- 风险：`content://` 与现有路径字符串算法混用导致过滤异常。
  - 对策：路径匹配前先分流，仅本地路径参与旧算法。
- 风险：provider 元数据不全（无 `datetaken`/`_size`）。
  - 对策：回退 `last_modified`，并在 UI 标识“估算值”。
- 风险：网络延迟导致列表阻塞。
  - 对策：所有 provider 查询保持异步并可取消。
- 风险：同一 URI 重复添加。
  - 对策：配置层统一规范化 URI（authority + treeDocumentId）后去重。

## 测试建议
- 功能测试：
  - 添加 CIFS URI、重启应用后仍可见。
  - 删除条目、重复添加、取消选择器。
  - 单击 Included/Excluded 中 `content://` 条目，可直接进入 SAF 文档目录页。
- 回归测试：
  - 本地 Albums 扫描数量与排序不变。
  - Included/Excluded 纯本地路径行为不变。
  - 本地路径条目单击不应触发 SAF 打开逻辑。
- 稳定性测试：
  - provider 离线、鉴权过期、慢网络。
  - Android 11/12/13 上 SAF 授权行为一致性。
  - `tree/.../document/...` 与 `document/...` 两种 URI 均可稳定打开、缩略图可见、图片可预览。

## 变更边界
阶段 1 修改文件：
- `decoded/smali/com/alensw/ui/activity/PathListActivity.smali`
- `decoded/smali/com/alensw/a/v.smali`
- `decoded/smali/com/alensw/a/o.smali`

阶段 2 修改文件：
- `decoded/smali/com/alensw/ui/activity/PathListActivity.smali`
- `decoded/smali/com/alensw/ui/activity/bn.smali`
- `decoded/smali/com/alensw/b/j/a.smali`
- `decoded/smali/com/alensw/bean/UriFile.smali`

对应可复用补丁已加入 `patches/series`，可通过既有流水线重放。
