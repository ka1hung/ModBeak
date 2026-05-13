# mbtool GUI 設計需求書

> 給設計師(或 Claude Design)用的 UI 重設計簡報。本文件描述**現有 app 中所有需要的功能、畫面、元件**,不規定具體配色、尺寸或圖示樣式 — 那是設計師要重新決定的。
>
> 設計目標(來自產品擁有者):**畫面清晰、容易識別、現代化、專業**。icon 也要全部重新設計。

---

## 1. 產品概要

**mbtool** 是一款給工業自動化工程師使用的桌面工具,用來測試 Modbus 設備(PLC、變頻器、IO 模組、智慧電表、ESP32 等)。同類產品包含 ModScan、Modbus Poll、QModMaster。

- **平台**:Windows / macOS / Linux 桌面 + 平板(現場 commissioning 用)
- **使用情境**:工程師在現場或辦公室,連到設備、即時讀寫暫存器、觀察數值變化、診斷通訊問題
- **支援傳輸**:Modbus **TCP**(乙太網路)+ Modbus **RTU**(RS-232 / RS-485 over USB serial)

---

## 2. 使用者畫像與痛點

### 2.1 典型使用者

- 控制工程師、PLC 工程師、設備整合商、現場除錯人員
- 年齡 25–55,長期面對 SCADA / HMI / 數值表格,對「資料密度高、資訊一目了然」的介面有強烈偏好
- 通常在**雙螢幕或大螢幕環境**工作,習慣同時開多個工具視窗,有時也會在工廠用 10" 平板做現場 commissioning
- 對美感的容忍度高,**但不能影響資訊辨識**;反感過度動畫、過大留白、藏在選單裡的功能

### 2.2 競品痛點與本工具的回應

| 痛點(ModScan 等) | mbtool 的回應 |
|---|---|
| 只能在 Windows 跑 | 跨平台、UI 一致 |
| 介面停留在 90 年代,字體小、配色刺眼 | 現代字體 + 工業風配色(深色為主) |
| 一個視窗只能看一塊區域 | MDI workspace — 多個 watch 視窗可任意拖曳 / 縮放 / cascade / tile |
| 看不到原始封包 | 內建 Comm view 顯示 TX/RX hex + 解析的 FC 摘要 |
| 設定無法版控 | 設定檔可匯出 / 匯入 JSON |
| 切換資料格式麻煩 | 整張表共用一個 format,表頭下拉即時切換 |
| 寫入要逐筆輸入,難按 | 雙擊 cell 跳出 popup;FC03+binary 用 16 格 checkbox;FC01 coil tap 直接 toggle 並有 optimistic UI |

---

## 3. 設計目標

優先順序(高到低):

1. **清晰** — 每個位址、數值、狀態要在一臂遠就讀得到。
2. **容易識別** — 連線狀態、TX/RX 方向、錯誤嚴重度、bit/coil 開關都要有獨立視覺處理。需要 colour-blind safe(不能只靠紅綠區分)。
3. **現代 + 專業** — 控制工程師會願意在主管面前打開的工具。避免 Material 3 那種卡通圓潤 / 漸層 / fake skeuomorphism。
4. **資訊密度** — 螢幕上要能同時看到數十個即時數值、多個面板、加上封包 log。每一個 pixel 都要有用,沒有為了美觀犧牲密度的空間。
5. **Icon 全部重設計** — 目前用的是 Material 圖示,風格不夠統一也不夠專業。參考 §10 的 icon 需求清單。

---

## 4. 整體架構

```
┌────────────────────────────────────────────────────────────────┐
│  Top toolbar  (檔案操作、+ Device、+ Watch、layout 快捷)         │
├──────────────┬─────────────────────────────────────────────────┤
│              │  Device header  (名稱 · transport · address)     │
│   Sidebar    ├─────────────────────────────────────────────────┤
│              │  Watches toolbar  (layout 按鈕 · + new watch)    │
│  - Devices   ├─────────────────────────────────────────────────┤
│  - Watches   │                                                 │
│              │       MDI watch workspace                       │
│              │   (多個獨立可拖曳 / 縮放的 watch pane)            │
│              │                                                 │
│              ├─────────────────────────────────────────────────┤
│              │   Minimised strip (有 pane 被最小化時才出現)      │
└──────────────┴─────────────────────────────────────────────────┘
```

**窄螢幕(< 600 px)**:sidebar 收進 hamburger drawer,Import/Export 收進 overflow 選單,cell 高度增加約 15 % 給觸控用。

---

## 5. 畫面清單(每個都要設計)

### 5.1 Top toolbar
- 品牌 mark + app 名
- 主要按鈕:`+ Device`、`+ Watch`
- 次要(窄螢幕收進 overflow):`Import config`、`Export config`

### 5.2 Sidebar — Device / Watch 樹

樹狀結構,**雙重用途**:選取(讓右邊面板顯示對應內容)+ 管理。

- **區段標頭**:`DEVICES` 標籤
- **Device row**(一行):
  - 連線狀態 dot
  - 裝置名稱
  - Transport chip(`TCP` / `RTU`)+ address line:
    - TCP: `192.168.1.10:502`
    - RTU: `COM3 @ 9600 8N1`
  - 展開 / 收合 caret(沒 watch 時 disabled)
  - 更多選單(`⋮`):Connect / Disconnect / Edit / Remove
  - **選取狀態**:明顯標示(左側 accent bar 或填色)
- **Watch row**(縮排在 device 下):
  - FC 標籤 + 位址範圍,例如 `FC03 · 100–109`
  - Format 標籤(`UInt16` / `Hex` / `Bool` 等)
  - 更多選單(`⋮`):Edit / Remove
- **+ New watch** 入口(展開的 device 底下)
- **空狀態**:`No devices. Click + Device to add one.`

### 5.3 Device header(右上)

選到一個 device 時顯示在 workspace 上方。

- 裝置名稱(大字)
- 連線指示器(dot + 文字標籤:`OFFLINE / CONNECTING / ONLINE / ERROR`)
- Transport chip + 完整 address line
- 最後一次連線錯誤訊息(紅字 inline,只有失敗時顯示)
- 右側:**單一主要按鈕** `Connect` 或 `Disconnect`(隨狀態切換,connecting 時 disabled)

### 5.4 Watches toolbar
- 標題 `WATCHES (N)`
- Quick-layout 按鈕(套用到當前可見的 watch panes):
  - Cascade(預設,層疊偏移)
  - Tile rows(水平條)
  - Tile columns(垂直條)
  - Grid(類正方格)
  - Show all(把最小化 / 隱藏的還原)
  - Close all
  - Reset counters(歸零 OK / ERR / Avg 統計)
- `+ New watch` 按鈕

### 5.5 MDI workspace

多個 **watch pane** 當成獨立子視窗。

- 最小尺寸 ≈ 280 × 140 px,預設 ≈ 420 × 280 px
- 自繪 window chrome:title bar 可拖曳、右下角可縮放、minimise / maximise / close
- 點到的 pane 自動置頂(z-order)
- 最小化的 pane 集中在底部 strip,點圖示還原、X 關閉
- **空狀態**:`No watches on this device yet. Click "+ New watch" to add one.`

### 5.6 Watch pane — 產品核心

一個視窗 = 一個 watch spec 的即時資料。三個 view tab。

#### 5.6.1 Pane header
- 小型連線 dot
- 標題:`<device name> · <FC label> · <start–end addr> · <poll interval>ms`
- View 切換:**Table | Comm | Errors**(Errors 有 badge / count 當 > 0)
- 圖示按鈕:**Edit**(快速開 Edit Watch 對話框)、**Split**、**Close**

#### 5.6.2 Format bar(只 Table view 才有)
- `Format` 標籤 + 暫存器解讀方式下拉(見 §6 列表)
- 如果選 `ASCII`:多出一個 `chars/row` 數字欄位
- FC01 / FC02(bit / coil):format 鎖定成 `Bool`,只讀
- 右側:輪詢活動指示燈(小 dot + 標籤)

#### 5.6.3 Table view — 高密度位址 / 數值網格

**這是產品的招牌畫面 — 必須在數百個 cell 的情況下還是好看 + 好讀。**

- Cell 採 **column-major** 流向:上到下、再往右換欄。橫向超出時水平捲動。
- 每個 cell 顯示 `[address] [value]`,address 在左、淡色,value 在右、強調、monospace、右對齊。
- Cell 寬度依 format 調整:
  - 緊湊 format(u16 / i16 / hex / bool):~110–130 px
  - 寬 format(bin / u32 / i32 / f32 / ascii):~150–250 px
- Cell 高度:桌面薄(~22 px)、觸控厚(~36 px)
- **FC01 / FC02**(bool):每個 cell 是 **bool pill**("TRUE" / "FALSE"),不是文字。點一下立即翻轉(optimistic UI),寫入中時降低不透明度直到 echo 回來。
- 狀態變體:
  - `Waiting for first poll…`(剛連線、還沒第一筆資料)
  - `Read error: <message>`(整批讀失敗)
  - 未連線提示(圖示 + 標籤 + 連線指引,**會依 pane 大小調整密度** — tiny/compact/full 三種)

#### 5.6.4 Comm view — 原始封包 log(Wireshark 風)

每個 device 一份,所有 watches 共用。

- 欄位:`time`(HH:MM:SS.mmm)、`direction`(TX / RX)、`frame summary`、`hex payload`
- frame summary **依 transport 自動切換**:
  - TCP: `unit=01 FC=03`(exception 加 `*`)
  - RTU: `slv=01 FC=03 …`
- 方向(TX / RX)必須**一眼分得出來** — 顏色 + 字重雙重編碼,不只靠文字
- 空狀態:`No packets yet — connect and start polling.`

#### 5.6.5 Errors view — 錯誤紀錄

- 頂部一行:錯誤數 + `Clear` 按鈕
- 每筆:時間、來源 tag(`CONN` / `POLL`)、watch 標籤、錯誤訊息(多行可展開)
- 來源 tag 需要不同視覺重量(CONN = warning、POLL = error)
- 空狀態:`No errors logged for this device.`

#### 5.6.6 Pane footer
- 左:`OK <n>  ERR <n>  Avg <ms>` — 該 watch 的統計
- 右:最後一次失敗的錯誤訊息(truncated)

### 5.7 Add / Edit Device 對話框

頂部 **Transport segmented control**:`TCP | RTU`

共用欄位:
- Name(留空時自動用 host 或 port name 帶入)
- Poll interval (ms) — 整台 device 的 polling cycle
- Min request gap (ms) — cycle 內每個 request 之間的最小間隔
- Auto-reconnect checkbox
- `Serialize requests` checkbox(只 TCP;RTU 因半雙工強制 ON)
- `Test` 按鈕 → inline 顯示 `OK · 123 ms` 或 `FAIL · …`

TCP 欄位:
- Host / IP
- Port(預設 502)
- Timeout (ms)

RTU 欄位:
- **Serial port** 下拉 + Refresh 按鈕
  - 每個選項顯示 `path — description (manufacturer)`(可用時)
  - 已存的 port 若已不在當前 list,額外置頂顯示 `(not connected)` 並以離線樣式呈現
- Baud(1200 / 2400 / 4800 / 9600 / 19200 / 38400 / 57600 / 115200 / 230400)
- Data bits(7 / 8)
- Stop bits(1 / 2)
- Parity(None / Even / Odd)
- Timeout (ms)

### 5.8 Add / Edit Watch 對話框

- Device 下拉(從前面 context 帶入時自動選好)
- Function Code radio group(四選一):
  - `FC 03 — Holding Register`
  - `FC 04 — Input Register`
  - `FC 01 — Coil`
  - `FC 02 — Discrete Input`
- Unit ID、Start Addr(1-based,ModScan convention)、Quantity
- Initial Format 下拉(只 FC03 / FC04 顯示);若選 ASCII → 多一個 `chars per row` 欄位
- FC 01 / FC 02 → format 自動鎖定 Bool,顯示說明 chip

### 5.9 Edit Value popup(整數 / 浮點 / hex / ascii 等)

雙擊或長按非 bit cell 時跳出。

- 標題:`Write to register <addr>`
- 副標:`<format label> · <hint>`,例:
  - `UInt16 · 0..65535`
  - `Float32 · IEEE-754 float (e.g. 3.14, -1.5e3)`
  - `Hex · 0x0000..0xFFFF (hex digits)`
- 單一文字輸入欄(預填當前值並全選)
- 即時驗證錯誤直接在輸入下方顯示
- 按鈕:`Cancel`、`Write`(Enter 送出、Esc 取消)

### 5.10 Edit Bits popup(FC03 / FC04 + Binary format)

雙擊 bin-format 暫存器 cell 時跳出。

- 標題同上,副標:`Holding register · 16 bits (MSB ← bit 15 … bit 0 → LSB)`
- **兩排 × 8 個 checkbox**:bit 15..8 上排、7..0 下排,每個 box 上方標 bit 編號,nibble 中間留小間隔
- 即時預覽區:
  - Binary string:`0000 0000 0000 0000`(nibble 分組)
  - Hex + decimal:`0x0000 · dec 0`
- 工具按鈕:`Clear all`、`Set all`、`Invert`
- 動作按鈕:`Cancel`、`Write`

---

## 6. 領域詞彙(UI 上會出現)

**Register formats**(下拉裡的選項):

| Format | Reg/cell | 說明 |
|---|---|---|
| `UInt16` | 1 | 0..65535 |
| `Int16` | 1 | −32768..32767 |
| `Hex` | 1 | `0x0000..0xFFFF` |
| `Binary` | 1 | 16-bit,nibble 分組顯示 |
| `UInt32 BE / LE` | 2 | |
| `Int32 BE / LE` | 2 | |
| `Float32 BE / LE` | 2 | IEEE-754 |
| `ASCII` | N | 可調 chars per row |
| `Bool` | bit | FC01 / FC02 鎖定 |

**Function codes**(UI 上的 4 個讀取 FC):FC01 Coils、FC02 Discrete Inputs、FC03 Holding Registers、FC04 Input Registers。寫入用 FC05 / 06 / 15 / 16 但 UI 不曝光。

**Transport**:TCP、RTU。

**MDI window mode**:Normal / Minimised / Maximised / Hidden。

**Quick layout**:Cascade / Tile rows / Tile columns / Grid。

---

## 7. 連線狀態指示元件(共用 widget)

兩種顯示模式:
- **Dot only**(6–8 px)— 用在 sidebar device row、watch pane header
- **Dot + label**(label 例如 `ONLINE`)— 用在 device header

四種狀態,要清楚分得出來:
- `OFFLINE` — 中性,沒連
- `CONNECTING` — 過渡中(動態感)
- `ONLINE` — 連線中(強調)
- `ERROR` — 錯誤(警告)

**設計約束**:
- 不能只靠顏色區分(colour-blind safe)— 例如 solid vs outlined、動 vs 靜
- 6–8 px 小尺寸下仍要看得出差異
- 「線上」跟「錯誤」要在 sidebar 一掃就分得出來,不能兩個都是「亮色 dot」

---

## 8. 互動模式

桌面:
- **雙擊** value cell → Edit Value popup
- **單擊** bool cell → 直接翻轉(optimistic UI,不出 popup)
- **右鍵** sidebar 項目 → context menu(Connect / Edit / Remove)
- **雙擊** pane title bar → 最大化 / 還原
- **拖曳** pane title → 移動
- **拖曳** pane 右下角 → 縮放
- **點任何位置** pane → 置頂
- **Enter** 送出 popup;**Esc** 取消

觸控:
- **長按** cell → Edit Value popup
- **點** bool cell → 直接翻轉
- 所有 hit target ≥ 36 px

---

## 9. 響應式行為

- **寬螢幕(≥ 600 px)**:sidebar 常駐(260 px 固定寬)、完整 toolbar、緊湊 cell
- **窄螢幕**:sidebar 收 drawer、Import/Export 收 overflow、cell 變高
- MDI workspace 本身不需要 collapse;pane 變小就好(280 px 寬還是可用)

---

## 10. Icon 需求(全部要重新設計)

### 10.1 風格方向

- **工業 / 工程感** — 乾淨的線條、單一筆畫粗細(stroke-based)、銳利轉角。參考 Phosphor、Tabler、Lucide 的味道,**不是** Material 那種圓潤填色。
- **像測量儀器,不像消費 app 貼紙** — 因為旁邊都是密集 monospace 資料,icon 必須在那個語境下不顯得幼稚。
- **每個 icon 至少兩種尺寸**:14–16 px(toolbar / inline)、20–24 px(對話框、空狀態)
- **每個 icon 需要 stroke + filled 兩種版本**(filled 用於 active 狀態)

### 10.2 需要的 icon 清單

| 類別 | 需要的 icon |
|---|---|
| **連線狀態** | online / offline / connecting / error 四種 dot 變體 |
| **Transport** | TCP / network、RTU / serial、USB-serial(可選) |
| **Modbus FC**(這是最特殊的,沒現成 icon 集有) | Coil(FC01)、Discrete Input(FC02)、Holding Register(FC03)、Input Register(FC04)— 四個區分明顯的 glyph |
| **視窗 chrome** | minimise、maximise、restore、close、split、drag-handle、resize-handle |
| **Layout 切換** | cascade、tile-rows、tile-columns、grid、show-all、close-all |
| **操作** | add、edit、remove、refresh、import、export、reset / clear、test-connection |
| **樹狀** | expand-right、expand-down、more(vertical)、more(horizontal) |
| **方向** | TX(outgoing)、RX(incoming)— 用在 packet log |
| **狀態** | success-check、warning-triangle、error-x、info-i |
| **Polling** | live / paused(例如 play-dot 變體) |
| **Format hint**(下拉內的小裝飾,可選) | numeric、hex、binary、float、ascii、bool |
| **空狀態插圖** | "select a device"、"no data yet"、"no errors"— 單色線稿 |

### 10.3 App icon

Windows / macOS / Linux 三平台都要重設計。設計師自由發揮(目前是 register-row 風格)。需要:
- 方形 + 圓角方形 + macOS 圓角矩形三種變體
- 256 / 128 / 64 / 32 / 16 px size 都要看得清楚

---

## 11. 資訊密度基準(redesign 必須達標)

| 畫面 | 目標(1280 × 800 螢幕) |
|---|---|
| Watch table(u16 / hex)default pane(420 × 280) | ≥ 20 cells 可見 |
| Watch table maximised pane | ≥ 200 cells 可見 |
| Bool cells default pane | ≥ 30 個 |
| Sidebar 一個展開的 device | ≥ 12 watches 不需捲動 |
| Packet log default pane | ≥ 15 行 |
| Error log default pane | ≥ 10 行 |

若新風格需要更多留白,以上數字必須仍在 1080 p 螢幕上達標 — 透過更精確的 typography、單行 address、cell 間不放裝飾性分隔線等手段達成。

---

## 12. 元件狀態變體(redesign 都要交付)

每個元件至少要提供:

- **Empty** — 沒資料(sidebar 沒裝置、table 等第一筆、errors 沒事件、comm 沒封包)
- **Loading / 飛行中** — `connecting…`、optimistic write pending
- **Success / live** — 連線中、正常 cell 值、OK 統計
- **Warning** — RX 封包、CONNECTING 狀態、寫入成功但等待確認
- **Error** — 連線失敗、slave exception、CRC mismatch、port permission denied 等
- **Disabled / read-only** — 沒連線時的 Disconnect 鍵、bool-locked format selector 等

---

## 13. 範圍外(本次 redesign 不做)

- 動畫 / motion design — v1 保持靜態
- 品牌識別(logo + wordmark)— 另一個案子
- 淺色主題 — 只做深色(工業控制室主流)
- 手機螢幕(< 480 px)— 不是目標族群

---

## 14. 期待交付物

設計師回饋的格式建議:

1. **元件 library** — §5 的每個元件畫成 Figma / 圖檔,標上對應的功能名(我可以一對一接到 code)
2. **色彩 token 表** — 命名語意化的 token(brand / warn / danger / muted...)+ 對應 hex,而不是滿地散落的 raw 顏色
3. **字體尺度**(monospace + sans-serif)
4. **Icon set** — 單一 SVG sprite + 個別 SVG 檔,**按功能命名**(`fc03-holding-reg.svg`,不是 `chart-bar.svg`)
5. **每個元件的狀態變體** — empty / live / error / disabled 並排展示
6. **一張 1440 × 900 整體 mockup** — sidebar + device header + 三個 watch pane(一個 Table view、一個 Comm view、一個 Errors view),好讓我感受整體節奏
