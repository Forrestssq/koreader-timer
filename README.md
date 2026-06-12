# Timer+ — KOReader Stopwatch & Countdown Plugin / KOReader 计时器插件

A timer plugin for KOReader (Kindle, Kobo, PocketBook, Android, …). It lives in the **Tools** menu and offers a stopwatch and a countdown, each available in fullscreen (portrait / landscape) and background (status bar) modes.

一个 KOReader 计时器插件（支持 Kindle、Kobo、PocketBook、安卓等设备）。入口位于**工具**菜单，提供计时器（秒表）和倒计时两大功能，每种功能均支持全屏（竖屏/横屏）与后台（底部状态栏）两种显示方式。

---

## English

### Installation

1. Copy the `timerplus.koplugin` folder into the `plugins` directory of your KOReader installation, e.g. on Kindle: `koreader/plugins/timerplus.koplugin/`.
2. Restart KOReader.
3. Open the top menu → **Tools** tab → **Timer**.

### Modes

The Timer menu contains 8 entries (each can be hidden via **Settings**):

| Entry | Description |
|---|---|
| Portrait timer | Fullscreen stopwatch |
| Portrait countdown | Fullscreen countdown |
| Background timer | Stopwatch shown in the reader's bottom status bar |
| Background countdown | Countdown shown in the bottom status bar |
| Landscape timer (clockwise) | Fullscreen stopwatch, screen rotated 90° clockwise |
| Landscape timer (counterclockwise) | Fullscreen stopwatch, rotated 90° counterclockwise |
| Landscape countdown (clockwise) | Fullscreen countdown, rotated clockwise |
| Landscape countdown (counterclockwise) | Fullscreen countdown, rotated counterclockwise |

Below a separator there is a **Settings** submenu where you can show/hide each of the 8 entries individually.

### Stopwatch (timer)

* Second precision, starts immediately.
* **Flag** button records lap times (`Flag 3: 12:34 (+01:02)`); the most recent flags are listed on screen.
* **Pause / Resume**, **Reset**, **Close**. Tapping the big time display also toggles pause.
* The previous screen rotation is restored when a landscape mode is closed.

### Countdown

Before starting, a setup dialog lets you pick the duration in several ways:

* **Keyboard**: free-form input with the virtual keyboard — `HH:MM:SS`, `MM:SS`, a bare number (minutes), or suffixed values like `90s`, `45m`, `1.5h`.
* **▲ / ▼ buttons** above and below each of the hour / minute / second digits.
* Tapping a digit group opens a spin picker for that unit.
* **+1 / +3 / +5 / +10 / −1 / −3 / −5 / −10** quick-adjust buttons: the column on the **left of the hours** adjusts hours, the column on the **right of the minutes** adjusts minutes.
* **Presets**: 30 s, 1 min, 3 min, 5 min, 10 min, 20 min, 30 min, 1 h.

While running: **Pause / Resume**, **+1 min**, **Reset**, **Close**. When time is up the screen flashes and a "Time is up!" message appears. The last used duration is remembered.

### Background mode (status bar)

The elapsed / remaining time is appended to the reader's bottom status bar and updates every second. When you start a background mode:

* If the status bar is currently hidden, the plugin tries to **turn it on automatically**. If that fails, it shows instructions: tap the bottom edge of the screen, or enable it via top menu → Settings → Status bar.
* The menu entry shows a checkmark and the current time while running. Tap it again to **Pause / Resume / Flag / Stop**.
* The background timer keeps counting when you switch books. It requires an open book (the file manager has no reader status bar).

### Notes & limitations

* Requires a KOReader version that supports extra status bar content (2021 or newer). If yours doesn't, the plugin will tell you.
* Timekeeping is based on the system clock, so it stays correct across device suspend; however, a countdown cannot wake the device from sleep — the alarm fires on the next wake-up.
* Language follows KOReader's interface language: Chinese UI ⇒ Chinese strings, anything else ⇒ English.

---

## 中文说明

### 安装

1. 将 `timerplus.koplugin` 文件夹复制到 KOReader 安装目录下的 `plugins` 目录中，例如 Kindle 上为 `koreader/plugins/timerplus.koplugin/`。
2. 重启 KOReader。
3. 打开顶部菜单 → **工具**页 → **计时器**。

### 八种模式

计时器二级菜单包含 8 个选项（每一项都可以在“设置”中单独隐藏）：

| 菜单项 | 说明 |
|---|---|
| 竖屏计时器 | 全屏秒表 |
| 竖屏倒计时 | 全屏倒计时 |
| 后台计时器 | 在阅读界面底部状态栏中显示的秒表 |
| 后台倒计时 | 在底部状态栏中显示的倒计时 |
| 横屏计时器（顺时针） | 全屏秒表，屏幕顺时针旋转 90° |
| 横屏计时器（逆时针） | 全屏秒表，屏幕逆时针旋转 90° |
| 横屏倒计时（顺时针） | 全屏倒计时，顺时针旋转 |
| 横屏倒计时（逆时针） | 全屏倒计时，逆时针旋转 |

分割线下方有一个**设置**子菜单，可逐项勾选显示/隐藏上述 8 个选项。

### 计时器（秒表）

* 精确到秒，进入后立即开始计时。
* **标记**按钮记录分段时间（如 `标记 3：12:34（+01:02）`），屏幕上会列出最近的几条标记。
* 支持**暂停/继续**、**重置**、**关闭**；点击大号时间数字也可以暂停/继续。
* 横屏模式关闭后会自动恢复原来的屏幕方向。

### 倒计时

开始前会弹出时长设置面板，支持多种输入方式：

* **键盘输入**：用虚拟键盘自由输入——`时:分:秒`、`分:秒`、纯数字（按分钟），或带后缀的写法如 `90s`、`45m`、`1.5h`。
* 时、分、秒每组数字的上下各有 **▲ / ▼ 按键**，逐一调整。
* 点击数字本身会弹出滚轮选择器。
* **+1 / +3 / +5 / +10 / −1 / −3 / −5 / −10** 快捷调整按钮：位于**小时左侧**的一列调整小时，位于**分钟右侧**的一列调整分钟，各自调节各自的。
* **常用时长**：30秒、1分钟、3分钟、5分钟、10分钟、20分钟、30分钟、1小时。

运行中可**暂停/继续**、**+1 分钟**、**重置**、**关闭**。时间到时屏幕会闪烁并弹出“时间到！”提示。插件会记住上次使用的时长。

### 后台模式（状态栏）

计时/剩余时间会追加显示在阅读界面底部状态栏中，每秒刷新。启动后台模式时：

* 如果底部状态栏当前是隐藏的，插件会**尝试自动开启**；如果自动开启失败，会提示你手动开启：点击屏幕底部边缘，或在顶部菜单 → 设置 → 状态栏中打开。
* 运行期间菜单项会显示对勾和当前时间；再次点击该菜单项可**暂停/继续/标记/停止**。
* 切换书籍时后台计时不会中断。后台模式需要先打开一本书（文件管理器没有阅读状态栏）。

### 注意事项与限制

* 需要支持状态栏附加内容的 KOReader 版本（2021 年及之后的版本）。如果版本过旧，插件会给出提示。
* 计时基于系统时钟，设备休眠唤醒后时间依然准确；但倒计时无法将设备从休眠中唤醒——提醒会在下次唤醒时弹出。
* 界面语言跟随 KOReader 的语言设置：中文界面显示中文，其他语言显示英文。

---

## License / 许可

MIT
