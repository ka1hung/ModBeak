# 跨平台 Modbus 測試工具設計計畫(Flutter + 自製 TCP 核心)

## 1. 專案目標

打造一個類似 ModScan 的跨平台 Modbus Master 測試工具,使用 **Flutter** 開發,支援 Windows / macOS / Linux 桌面。**v1 聚焦於 Modbus TCP**,通訊核心**自行以 `dart:io` Socket 實作**,移植/改寫自個人 Go 函式庫 [`ka1hung/mbclient`](https://github.com/ka1hung/mbclient)。GUI 採**多視窗架構**,允許多個視窗同時對同一台設備查詢不同點位。

---

## 2. 技術選型

### 2.1 整體技術堆疊

| 層級 | 技術 | 理由 |
|------|------|------|
| 框架 | Flutter 3.x(stable) | 單一程式碼庫跨桌面;UI 一致;熱重載 |
| 語言 | Dart 3 | Null safety、Records、Pattern matching |
| 桌面平台 | Windows / macOS / Linux | v1 三平台 |
| **Modbus TCP 通訊** | **自製,純 `dart:io` Socket** | 完全掌控原始封包,移植自 `mbclient` |
| 多視窗 | `desktop_multi_window` | Flutter 桌面原生多視窗支援 |
| 狀態管理 | Riverpod 2 | 跨視窗同步、編譯期安全 |
| UI 元件 | Material 3 + 自製工業風主題 | 內建已足夠 |
| 表格 | `pluto_grid` | 大量列虛擬捲動、儲存格編輯 |
| 圖表(v1.5+) | `fl_chart` | 趨勢圖 |
| 本地儲存 | `drift`(SQLite)+ `shared_preferences` | 連線設定、輪詢任務 |
| 設定 import/export | JSON(內建 `dart:convert`) | 適合版控 |
| 路由 | `go_router` | 視窗內路由 |
| 序列化 | `freezed` + `json_serializable` | 資料模型 |

### 2.2 為什麼自製通訊核心

1. **掌控原始封包**:第三方套件常把 socket 細節包死,難以暴露 raw bytes 給 UI 顯示。
2. **設計可控**:能依 `mbclient` 的簡潔風格,把 API 設計得貼近自己的使用習慣。
3. **無外部風險**:Dart Modbus 套件生態小、維護不穩,自寫反而保險。
4. **TCP 協定簡單**:MBAP 7 bytes + PDU,自寫成本低。

---

## 3. 通訊核心:Dart 移植 `mbclient`

### 3.1 `mbclient` 原始 API(Go)

```go
type MBClient struct {
  IP      string
  Port    int
  Timeout time.Duration
  Conn    net.Conn
}

func NewClient(IP string, port int, timeout time.Duration) *MBClient
func (m *MBClient) Open() error
func (m *MBClient) Close()
func (m *MBClient) IsConnected() bool
func (m *MBClient) ReadCoil(id, addr, leng) ([]bool, error)        // FC 01
func (m *MBClient) ReadCoilIn(id, addr, leng) ([]bool, error)      // FC 02
func (m *MBClient) ReadReg(id, addr, leng) ([]uint16, error)       // FC 03
func (m *MBClient) ReadRegIn(id, addr, leng) ([]uint16, error)     // FC 04
func (m *MBClient) WriteCoil(id, addr, data bool) error            // FC 05
func (m *MBClient) WriteReg(id, addr, data uint16) error           // FC 06
func (m *MBClient) WriteCoils(id, addr, data []bool) error         // FC 15
func (m *MBClient) WriteRegs(id, addr, data []uint16) error        // FC 16
```

Sentinel errors: `ErrDisconnect` / `ErrNoResponse` / `ErrModbusError`。

### 3.2 Dart 改寫版 `MbClient`

保留 API 風格,但改成 async/Future,並加入兩項升級:

1. **Transaction ID 管理**:支援同連線並發請求(原 Go 版 transaction id 永遠是 0,無法並發)。
2. **Raw packet stream**:暴露 TX/RX 原始位元組給 UI 訂閱。

```dart
// lib/core/modbus/mb_client.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class MbException implements Exception {
  final String message;
  const MbException(this.message);
  @override String toString() => 'MbException: $message';
}

class MbDisconnect extends MbException { const MbDisconnect() : super('Disconnect'); }
class MbNoResponse extends MbException { const MbNoResponse() : super('NoResponse'); }
class MbModbusError extends MbException { const MbModbusError(super.msg); }

class RawPacket {
  final DateTime time;
  final bool isTx;            // true=TX, false=RX
  final Uint8List bytes;
  final int? transactionId;
  RawPacket(this.time, this.isTx, this.bytes, this.transactionId);
}

class MbClient {
  final String host;
  final int port;
  final Duration timeout;

  Socket? _socket;
  int _txId = 0;
  final Map<int, Completer<Uint8List>> _pending = {};
  Uint8List _rxBuffer = Uint8List(0);

  final _rawCtrl = StreamController<RawPacket>.broadcast();
  Stream<RawPacket> get rawPackets$ => _rawCtrl.stream;

  MbClient({required this.host, required this.port, this.timeout = const Duration(seconds: 2)});

  bool get isConnected => _socket != null;

  Future<void> open() async {
    try {
      _socket = await Socket.connect(host, port, timeout: timeout);
      _socket!.listen(_onData, onError: (_) => _shutdown(), onDone: _shutdown);
    } catch (_) {
      throw const MbDisconnect();
    }
  }

  Future<void> close() async {
    await _socket?.close();
    _shutdown();
  }

  void _shutdown() {
    _socket?.destroy();
    _socket = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(const MbDisconnect());
    }
    _pending.clear();
    _rxBuffer = Uint8List(0);
  }

  // ─── core query: build MBAP + PDU, dispatch by transaction id ───
  Future<Uint8List> _query(Uint8List pdu) async {
    final s = _socket;
    if (s == null) throw const MbDisconnect();

    final tid = (_txId = (_txId + 1) & 0xFFFF);
    final frame = _buildAdu(tid, pdu);

    final completer = Completer<Uint8List>();
    _pending[tid] = completer;
    s.add(frame);
    _rawCtrl.add(RawPacket(DateTime.now(), true, frame, tid));

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(tid);
      throw const MbNoResponse();
    }
  }

  static Uint8List _buildAdu(int tid, Uint8List pdu) {
    final b = BytesBuilder();
    b.add([tid >> 8, tid & 0xFF, 0, 0, pdu.length >> 8, pdu.length & 0xFF]);
    b.add(pdu);
    return b.toBytes();
  }

  void _onData(List<int> chunk) {
    _rxBuffer = Uint8List.fromList([..._rxBuffer, ...chunk]);
    while (_rxBuffer.length >= 8) {
      final len = (_rxBuffer[4] << 8) | _rxBuffer[5];
      final total = 6 + len;
      if (_rxBuffer.length < total) break;

      final frame = _rxBuffer.sublist(0, total);
      _rxBuffer = _rxBuffer.sublist(total);

      final tid = (frame[0] << 8) | frame[1];
      _rawCtrl.add(RawPacket(DateTime.now(), false, frame, tid));

      final completer = _pending.remove(tid);
      if (completer == null || completer.isCompleted) continue;

      // exception?
      final fc = frame[7];
      if ((fc & 0x80) != 0) {
        completer.completeError(MbModbusError(_exceptionText(frame[8])));
      } else {
        completer.complete(frame.sublist(6));   // unit id + PDU
      }
    }
  }

  // ─── public API:風格延續 mbclient ───

  Future<List<bool>> readCoil(int unitId, int addr, int qty) =>
      _readCoilInternal(unitId, addr, qty, 0x01);

  Future<List<bool>> readCoilIn(int unitId, int addr, int qty) =>
      _readCoilInternal(unitId, addr, qty, 0x02);

  Future<List<int>> readReg(int unitId, int addr, int qty) =>
      _readRegInternal(unitId, addr, qty, 0x03);

  Future<List<int>> readRegIn(int unitId, int addr, int qty) =>
      _readRegInternal(unitId, addr, qty, 0x04);

  Future<void> writeCoil(int unitId, int addr, bool value) async {
    final pdu = Uint8List.fromList([
      unitId, 0x05, addr >> 8, addr & 0xFF, value ? 0xFF : 0x00, 0x00,
    ]);
    await _query(pdu);
  }

  Future<void> writeReg(int unitId, int addr, int value) async {
    final pdu = Uint8List.fromList([
      unitId, 0x06, addr >> 8, addr & 0xFF, value >> 8, value & 0xFF,
    ]);
    await _query(pdu);
  }

  Future<void> writeCoils(int unitId, int addr, List<bool> values) async {
    final byteCount = (values.length + 7) ~/ 8;
    final coilBytes = Uint8List(byteCount);
    for (var i = 0; i < values.length; i++) {
      if (values[i]) coilBytes[i ~/ 8] |= (1 << (i % 8));
    }
    final pdu = Uint8List.fromList([
      unitId, 0x0F, addr >> 8, addr & 0xFF,
      values.length >> 8, values.length & 0xFF, byteCount, ...coilBytes,
    ]);
    await _query(pdu);
  }

  Future<void> writeRegs(int unitId, int addr, List<int> values) async {
    final byteCount = values.length * 2;
    final regBytes = Uint8List(byteCount);
    for (var i = 0; i < values.length; i++) {
      regBytes[i * 2]     = (values[i] >> 8) & 0xFF;
      regBytes[i * 2 + 1] = values[i] & 0xFF;
    }
    final pdu = Uint8List.fromList([
      unitId, 0x10, addr >> 8, addr & 0xFF,
      values.length >> 8, values.length & 0xFF, byteCount, ...regBytes,
    ]);
    await _query(pdu);
  }

  // ─── internals ───
  Future<List<bool>> _readCoilInternal(int unitId, int addr, int qty, int fc) async {
    final pdu = Uint8List.fromList([unitId, fc, addr >> 8, addr & 0xFF, qty >> 8, qty & 0xFF]);
    final res = await _query(pdu);
    final byteCount = res[2];
    final out = <bool>[];
    for (var i = 0; i < byteCount; i++) {
      for (var j = 0; j < 8; j++) {
        out.add((res[3 + i] & (1 << j)) != 0);
      }
    }
    return out.sublist(0, qty);
  }

  Future<List<int>> _readRegInternal(int unitId, int addr, int qty, int fc) async {
    final pdu = Uint8List.fromList([unitId, fc, addr >> 8, addr & 0xFF, qty >> 8, qty & 0xFF]);
    final res = await _query(pdu);
    final out = List<int>.filled(qty, 0);
    for (var i = 0; i < qty; i++) {
      out[i] = (res[3 + i * 2] << 8) | res[4 + i * 2];
    }
    return out;
  }

  static String _exceptionText(int code) => switch (code) {
        1  => '(01 illegal function)',
        2  => '(02 illegal data address)',
        3  => '(03 illegal data value)',
        4  => '(04 slave device failure)',
        5  => '(05 acknowledge)',
        6  => '(06 slave device busy)',
        7  => '(07 negative acknowledge)',
        8  => '(08 memory parity error)',
        10 => '(0A gateway path unavailable)',
        11 => '(0B gateway target device failed to respond)',
        _  => '(${code.toRadixString(16).padLeft(2, '0').toUpperCase()} error code not in list)',
      };
}
```

### 3.3 與原 Go 版的差異

| 項目 | Go 原版 | Dart 改寫版 |
|------|---------|-------------|
| Transaction ID | 永遠 0 | 自增 + 0xFFFF wrap,支援並發 |
| 並發 | ❌(每次 read 直到拿到 byteLen) | ✅(以 tid 對映 Completer) |
| Raw packet 暴露 | ❌ | ✅(`rawPackets$` Stream) |
| 錯誤型別 | `errors.Is` 比對 | sealed-like Exception 子類 |
| 連線重用 | 同步阻塞 read | 事件驅動 `socket.listen` |

---

## 4. 多視窗 GUI 架構

### 4.1 核心想法

- **Device(連線)是頂層概念**,擁有一個 `MbClient` 實例(一條 TCP 連線)。
- **Window(視窗)是觀察視角**,每個視窗訂閱一或多個 Device 的查詢結果。
- **每個 Watch Window 內部可分割為多個 Pane**,每個 pane 是一張獨立 Watch 表(獨立 FC、起始位址、format、輪詢)。
- **同一台 Device 可被 N 個視窗 / N 個 pane 同時觀察**,共用同一條 TCP 連線。
- 由於 Modbus TCP 用 transaction ID 配對請求/回應,**單條連線即可支援並發查詢**(slave 處理仍可能排隊,但 client 端不需要每個視窗開一條 socket)。

#### 為什麼要多面板分割?

工程除錯常需**多個位址交互比對**:
- PV 與 SV(40001 量測值 vs 40010 設定值)同畫面
- 同一參數在 PLC-A 與 PLC-B 上的差異
- 主機暫存器 vs 從機暫存器
- 不同 FC 的混合監看(HR + Coils + Input Registers)

每個情境另開一個視窗會雜亂,所以 Watch Window 內提供**水平 / 垂直 / 網格分割**。

### 4.2 視窗形態

```
┌─────────────── Main Window(主控台) ────────────────┐
│  Devices │ [+ 新增 Device]                           │
│  ─────── │ • PLC-A  192.168.1.10:502  ●已連線        │
│  PLC-A   │   ├── Watch Window 1 (HR 40001-40020)     │
│  PLC-B   │   ├── Watch Window 2 (Coils 1-32)         │
│          │   └── [+ 開新視窗監看此設備]              │
│  Status  │ • PLC-B  192.168.1.20:502  ○未連線        │
│  Logs    │                                           │
└──────────────────────────────────────────────────────┘

   ┌── Watch Window: PLC-A 比對視圖 ──────────────────────[_][□][X]┐
   │ Layout: [Horizontal Split]                       [+ Pane] [⤢] │
   │ ┌────────────── Pane 1 ─────────────┐ ┌──── Pane 2 ─────────┐ │
   │ │ PLC-A · FC03 · 40001-40010        │ │ PLC-A · FC03 · 40020│ │
   │ │ Format [UInt16 ▾]      Poll 500ms │ │ Format [Float32 BE ▾]│ │
   │ │ ┌────────┬─────────────────────┐ │ │ ┌────────┬────────┐ │ │
   │ │ │ Addr   │ Value               │ │ │ │ Addr   │ Value  │ │ │
   │ │ │ 40001  │ 1234                │ │ │ │ 40020  │ 56.78  │ │ │
   │ │ │ 40002  │ 5678                │ │ │ │ 40022  │ 102.40 │ │ │
   │ │ │ …                            │ │ │ │ …               │ │ │
   │ │ └────────┴─────────────────────┘ │ │ └─────────────────┘ │ │
   │ └───────────────────────────────────┘ └─────────────────────┘ │
   └────────────────────────────────────────────────────────────────┘

   ↑ 拖曳中間分隔線可調整比例;每個 Pane 右上角 [×] 移除、[⊟] 在
     旁邊再切一刀(可水平或垂直)。Layout 整個會存進設定檔。
```

### 4.3 多視窗 + 多面板實作

採用 [`desktop_multi_window`](https://pub.dev/packages/desktop_multi_window) 處理跨視窗,**視窗內**分割面板自行用 Flutter Widget 樹實作。

- 主程序(main isolate)持有所有 `Device` / `MbClient` 與**所有** `WatchSpec`(無論這個 watch 是哪個視窗的哪個 pane 訂閱)。
- 每個 Watch Window 是獨立 Flutter 視窗,**內部以樹狀 Layout 渲染多個 pane**;pane 不直接持有 socket,改用 IPC 訂閱主程序的資料流。
- 主程序與子視窗用 `desktop_multi_window` 的 `invokeMethod` / `setMethodHandler` 通訊(底層即 method channel)。
- **視窗內分割**用 `flutter_resizable_container` 或自訂 `MultiSplitView`(類似 IDE 的 split editor)實作,不需要平台支援。

```dart
// 主程序:管理 Device 與 Subscription
class DeviceHub {
  final Map<String, MbClient> _clients = {};
  final Map<String, _PollLoop> _polls = {};

  Future<void> addDevice(DeviceConfig cfg) async {
    final c = MbClient(host: cfg.host, port: cfg.port, timeout: cfg.timeout);
    await c.open();
    _clients[cfg.id] = c;
  }

  String startPoll(PollSpec spec, void Function(PollResult) onData) {
    final id = _uuid();
    _polls[id] = _PollLoop(_clients[spec.deviceId]!, spec, onData)..start();
    return id;
  }

  void stopPoll(String id) => _polls.remove(id)?.stop();
}

// 視窗端:呼叫 IPC 取得結果
final results = await DesktopMultiWindow.invokeMethod(0, 'startPoll', spec.toJson());
```

### 4.4 PollLoop:避免重疊呼叫

Modbus 請求-回應是循序的,即使支援 transaction id,仍應避免**同一輪詢任務疊送**。用 `await` 鏈而非 `Timer.periodic`:

```dart
class _PollLoop {
  final MbClient client;
  final PollSpec spec;
  final void Function(PollResult) onData;
  bool _running = false;

  _PollLoop(this.client, this.spec, this.onData);

  void start() async {
    _running = true;
    while (_running) {
      final t0 = DateTime.now();
      try {
        final values = switch (spec.functionCode) {
          1 => await client.readCoil(spec.unitId, spec.startAddr, spec.qty),
          2 => await client.readCoilIn(spec.unitId, spec.startAddr, spec.qty),
          3 => await client.readReg(spec.unitId, spec.startAddr, spec.qty),
          4 => await client.readRegIn(spec.unitId, spec.startAddr, spec.qty),
          _ => throw StateError('unsupported FC ${spec.functionCode}'),
        };
        onData(PollResult.ok(values, DateTime.now().difference(t0)));
      } catch (e) {
        onData(PollResult.err(e));
      }
      final elapsed = DateTime.now().difference(t0);
      final wait = spec.interval - elapsed;
      if (wait > Duration.zero) await Future.delayed(wait);
    }
  }

  void stop() => _running = false;
}
```

### 4.5 並發策略

- **不同視窗對同一 Device 的不同點位查詢**:**並發**(不同 transaction id 同時在線上)。
- **同一個 PollLoop 內**:**循序**(避免疊送)。
- 若 slave 要求嚴格序列化,提供 Device 設定:`serializeRequests: true`,則所有對該 Device 的請求進入單一 mutex queue。

---

## 5. v1 範圍

### 5.1 必備
- [x] Modbus TCP 連線(自製 `MbClient`,IP / Port / Unit ID / Timeout / Retry)
- [x] 多 Device 管理
- [x] **多視窗監看同一 Device**(`desktop_multi_window`)
- [x] **單視窗多面板分割**(水平 / 垂直 / 巢狀,樹狀 layout,可儲存)
- [x] **跨 Device / 跨位址比對**(同一視窗的不同 pane 可指向不同 Device)
- [x] FC 01 / 02 / 03 / 04 / 05 / 06 / 15 / 16
- [x] 輪詢(50ms ~ 60s)
- [x] **整個 Watch 表格使用統一資料格式**(隨時可在表頭下拉切換,讀/寫皆套用)
- [x] 支援格式:bin / hex / UInt16 / Int16 / UInt32(BE/LE)/ Int32(BE/LE)/ Float32(BE/LE)/ ASCII
- [x] **儲存格直接寫入**:雙擊 Value 編輯,Enter 送出,輸入會依當前格式解析(Float32 → 寫 2 個 register、Coil → bool 等)
- [x] 原始封包面板(訂閱 `rawPackets$`)
- [x] Exception code 友善訊息
- [x] 統計面板(成功率、平均延遲)
- [x] 設定檔 import/export(JSON)

### 5.2 v1 不做
- ❌ Modbus RTU / ASCII / RTU over TCP(v2)
- ❌ Slave 模擬 / Sniffer(v2.5)
- ❌ 趨勢圖 / 腳本重播(v1.5)
- ❌ 行動裝置(v3)

---

## 6. UI 設計草圖

### 6.1 主控台(Main Window)

```
┌──────────────────────────────────────────────────────────────────┐
│ ModbusBench                                            [_][□][X]│
├──────────────────────────────────────────────────────────────────┤
│ [+ Device] [⚙ Settings]                                          │
├──────────────────────────────────────────────────────────────────┤
│ Devices                                                          │
│ ─────────────────                                                │
│ ● PLC-A    192.168.1.10:502    Unit 1   ●Connected              │
│   ├── Watch #1 HR 40001-40020 [▶]   [Open in window]            │
│   ├── Watch #2 Coils 1-32     [▶]   [Open in window]            │
│   └── [+ 新增 Watch] [+ 開獨立視窗]                              │
│                                                                  │
│ ○ PLC-B    192.168.1.20:502    Unit 1   ○Disconnected           │
│   └── [+ 新增 Watch]                                             │
├──────────────────────────────────────────────────────────────────┤
│ [Logs] [Raw Packets] [Stats]                                     │
│ 12:03:45.210 PLC-A TX 0001 0000 0006 01 03 00 00 00 14           │
│ 12:03:45.231 PLC-A RX 0001 0000 002B 01 03 28 ...    (21ms)      │
└──────────────────────────────────────────────────────────────────┘
```

### 6.2 Watch Window(獨立視窗 + 多面板分割)

每個 Watch Window 是「容器」,內部可由多個 **Pane** 構成,Pane 之間用樹狀 split layout 排列。每個 Pane 是一張獨立的 Watch 表(自己的 FC、起始位址、format、輪詢週期)。

#### 單一 Pane(Watch 表)

```
┌── Watch Pane ───────────────────────────────[⊟ Split] [×]─┐
│ Source: PLC-A · FC 03 · 40001 · Qty 10 · Poll 500ms        │
│ Format [ Float32 BE ▾ ]                  ▶ Polling  ●      │
│ ┌────────────┬──────────────────────────────────────────┐  │
│ │ Address    │ Value                                    │  │
│ ├────────────┼──────────────────────────────────────────┤  │
│ │ 40001      │ 56.78                                    │  │  ← 佔 40001+40002
│ │ 40003      │ 102.40                                   │  │  ← 佔 40003+40004
│ │ 40005      │ 0.00                                     │  │
│ │ …                                                     │  │
│ └────────────┴──────────────────────────────────────────┘  │
│ Success 1283  Errors 2  Avg 18ms                           │
└────────────────────────────────────────────────────────────┘
```

- 整張表只有兩欄:Address、Value。**沒有 per-cell 的 Tag / Format**。
- 表頭的 Format 下拉**控制整張表**的解析方式,切換時 row 會重排:
  - UInt16 / Int16 / Hex / Bin → 1 register / row
  - UInt32 / Int32 / Float32(BE/LE)→ 2 registers / row
  - ASCII → 由使用者指定每筆字元數
  - Coils / Discrete Input(FC 01/02)→ 一律 bool / row
- 雙擊 Value 進入編輯模式,輸入字串**依當前 Format 解析**後寫入:
  - UInt16 / Int16 / Hex / Bin → `writeReg`(FC 06)
  - UInt32 / Int32 / Float32 → `writeRegs`(FC 16,2 個 register)
  - Coil → 解析為 0/1/true/false → `writeCoil`(FC 05)
- 解析失敗會在儲存格邊框轉紅 + tooltip 顯示錯誤,不送出。
- Pane 標題列右側:`⊟` 在自身旁邊再切一刀(問使用者要水平還垂直)、`×` 移除此 pane。

#### 多 Pane 分割(比對視圖)

```
┌── Watch Window: 比對視圖 ───────────────────────[_][□][X]┐
│ Layout: Horizontal Split           [+ Add Pane] [Save]    │
│ ┌────── Pane A ──────┐│┌────── Pane B ──────┐            │
│ │ PLC-A · FC03·40001 │││ PLC-B · FC03·40001 │            │
│ │ Format [Float32 ▾] │││ Format [Float32 ▾] │            │
│ │ Addr   │ Value     │││ Addr   │ Value     │            │
│ │ 40001  │ 56.78     │││ 40001  │ 56.91     │   ← 比對   │
│ │ 40003  │ 102.40    │││ 40003  │ 102.38    │            │
│ │ ...                │││ ...                │            │
│ └────────────────────┘│└────────────────────┘            │
│         ↑↑                                                │
│   拖曳分隔線改變比例                                      │
└───────────────────────────────────────────────────────────┘
```

- Layout 為**樹狀結構**,可巢狀:水平分割內再做垂直分割,做出 2×2、L 型等任意排列。
- 每個 Pane 可指向**任一 Device**(同一個視窗裡可同時看 PLC-A 與 PLC-B)。
- Layout 與所有 Pane 設定都會存進設定檔,可儲存命名(例如「鍋爐控制比對」),下次一鍵還原。
- 視窗內 `[+ Add Pane]` 工具列按鈕快速新增。

---

## 7. 系統架構

```
┌──────────────────────────────────────────────────────────────┐
│           Windows (Flutter UI, Riverpod scopes)              │
│  ┌── Main ──┐  ┌─── Watch Window 1 ───┐  ┌─ Watch Window 2 ─┐│
│  │ Devices  │  │ ┌Pane┐ ┌Pane┐ ┌Pane┐ │  │ ┌Pane┐  ┌Pane┐  ││
│  │ Logs     │  │ │ A  │ │ B  │ │ C  │ │  │ │  D │  │  E │  ││
│  │ Stats    │  │ └────┘ └────┘ └────┘ │  │ └────┘  └────┘  ││
│  └──────────┘  └──────────────────────┘  └──────────────────┘│
└──────┬─────────────────┬──────────────────┬─────────────────┘
       │  IPC (desktop_multi_window method channel)            │
       └─────────────────┬──────────────────┘                  │
                         │                                     │
┌────────────────────────▼─────────────────────────────────────┐
│                    Main Isolate (Hub)                        │
│  ┌──────────────────┐  ┌────────────────────────────────┐   │
│  │ DeviceHub        │  │ Format codecs / ADU parser     │   │
│  │ - MbClient × N   │  │ - bin/hex/u/i/f32/ascii        │   │
│  │ - PollLoop × N   │  │ - MBAP highlight               │   │
│  └──────┬───────────┘  └────────────────────────────────┘   │
│         │                                                    │
│  ┌──────▼─────────┐                                          │
│  │ MbClient       │  自製 TCP socket(本計畫第 3 章)        │
│  │ - dart:io Sock │                                          │
│  │ - txId mapping │                                          │
│  │ - rawPackets$  │                                          │
│  └────────────────┘                                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. 資料模型

```dart
@freezed
class DeviceConfig with _$DeviceConfig {
  const factory DeviceConfig({
    required String id,
    required String name,
    required String host,
    @Default(502) int port,
    @Default(1) int defaultUnitId,
    @Default(Duration(seconds: 2)) Duration timeout,
    @Default(false) bool serializeRequests,
  }) = _DeviceConfig;
}

@freezed
class WatchSpec with _$WatchSpec {
  const factory WatchSpec({
    required String id,
    required String deviceId,
    required int unitId,
    required int functionCode,            // 1/2/3/4
    required int startAddress,
    required int quantity,                // 以 register 為單位(coil 模式則為 bit 數)
    @Default(Duration(milliseconds: 500)) Duration interval,
    @Default(RegisterFormat.u16) RegisterFormat format,  // 整張表共用的 format,UI 可隨時切換
    @Default(0) int asciiCharsPerRow,     // 僅 ASCII 模式使用
  }) = _WatchSpec;
}

/// 切換 format **不必停止輪詢、不必重打 query**。
/// PollLoop 永遠拿到的是「原始 register 陣列」(`List<int>` 或 `List<bool>`),
/// 由 Watch Window 端在 render 時即時套用 codec 解析。
/// 改 format 只影響 UI 解析方式,連線、輪詢任務都不動。

/// Watch Window 是一個容器,內部以樹狀 Layout 排列多個 Pane。
/// 每個 Pane 對應一個 WatchSpec(獨立輪詢)。
@freezed
class WatchWindow with _$WatchWindow {
  const factory WatchWindow({
    required String id,
    required String name,                    // 視窗顯示名,例如「鍋爐控制比對」
    required PaneLayout layout,              // 根節點,可為 Leaf 或 Split
    Rect? bounds,                            // 視窗位置/大小,持久化
  }) = _WatchWindow;
}

/// 樹狀分割結構:葉節點是一個 WatchSpec,內部節點是水平/垂直分割。
@freezed
sealed class PaneLayout with _$PaneLayout {
  /// 葉節點:單一 Watch 表。
  const factory PaneLayout.leaf({
    required String paneId,                  // 該 pane 的唯一 id
    required WatchSpec watch,                // 此 pane 的輪詢設定
  }) = LeafPane;

  /// 分割節點:含兩個或以上子節點。
  const factory PaneLayout.split({
    required SplitDirection direction,       // horizontal | vertical
    required List<PaneLayout> children,      // 至少 2 個
    required List<double> ratios,            // 各 child 比例,總和 = 1.0
  }) = SplitPane;
}

enum SplitDirection { horizontal, vertical }

/// 範例:左右分割,左邊再上下分割成兩個 Pane,右邊單一 Pane(L 型佈局)
/// PaneLayout.split(
///   direction: horizontal,
///   ratios: [0.5, 0.5],
///   children: [
///     PaneLayout.split(
///       direction: vertical,
///       ratios: [0.5, 0.5],
///       children: [LeafPane(...), LeafPane(...)],
///     ),
///     LeafPane(...),
///   ],
/// )

enum RegisterFormat {
  u16, i16, hex, bin,           // 1 register / row
  u32be, u32le, i32be, i32le,   // 2 registers / row
  f32be, f32le,                 // 2 registers / row
  ascii,                        // N registers / row
  bool_,                        // FC 01/02/05/15 用
}

extension RegisterFormatX on RegisterFormat {
  /// 一個顯示列佔用幾個 register。
  int get registersPerRow => switch (this) {
        RegisterFormat.u16 || RegisterFormat.i16 ||
        RegisterFormat.hex || RegisterFormat.bin   => 1,
        RegisterFormat.u32be || RegisterFormat.u32le ||
        RegisterFormat.i32be || RegisterFormat.i32le ||
        RegisterFormat.f32be || RegisterFormat.f32le => 2,
        RegisterFormat.ascii => -1,    // 由 asciiCharsPerRow 決定
        RegisterFormat.bool_ => 0,     // coil 模式不適用
      };
}
```

### 8.1 Format Codec(讀/寫雙向)

```dart
abstract class FormatCodec {
  /// register 陣列 → 顯示字串
  String decode(List<int> regs, int offset);

  /// 顯示字串 → register 陣列(寫入時用)
  /// 失敗時拋 FormatException
  List<int> encode(String input);

  int get registersPerValue;
}

class U16Codec implements FormatCodec {
  @override int get registersPerValue => 1;
  @override String decode(List<int> r, int i) => r[i].toString();
  @override List<int> encode(String s) => [int.parse(s) & 0xFFFF];
}

class F32BeCodec implements FormatCodec {
  @override int get registersPerValue => 2;
  @override String decode(List<int> r, int i) {
    final bd = ByteData(4)
      ..setUint16(0, r[i],     Endian.big)
      ..setUint16(2, r[i + 1], Endian.big);
    return bd.getFloat32(0, Endian.big).toStringAsFixed(4);
  }
  @override List<int> encode(String s) {
    final bd = ByteData(4)..setFloat32(0, double.parse(s), Endian.big);
    return [bd.getUint16(0, Endian.big), bd.getUint16(2, Endian.big)];
  }
}

class HexCodec implements FormatCodec {
  @override int get registersPerValue => 1;
  @override String decode(List<int> r, int i) =>
      '0x${r[i].toRadixString(16).padLeft(4, '0').toUpperCase()}';
  @override List<int> encode(String s) {
    final clean = s.toLowerCase().replaceFirst('0x', '');
    return [int.parse(clean, radix: 16) & 0xFFFF];
  }
}
// …其他 codec 同模式
```

### 8.2 寫入流程

```
User 雙擊儲存格 → 進入編輯
    ↓
輸入新值 → 按 Enter
    ↓
codec.encode(input) → List<int>(1 或 2 個 register)或 bool
    ↓ 解析失敗 → 邊框轉紅 + tooltip,不送出
    ↓ 解析成功
依當前 FC 與 codec.registersPerValue 選 API:
  - 1 register  → mbClient.writeReg(unit, addr, regs[0])
  - 2 registers → mbClient.writeRegs(unit, addr, regs)
  - bool        → mbClient.writeCoil(unit, addr, value)
    ↓
寫入成功 → 儲存格綠閃 200ms;失敗 → 紅閃 + 顯示 exception
```

---

## 9. 開發里程碑

| 階段 | 內容 | 預估 | Demo 條件 |
|------|------|------|-----------|
| M1 | 專案骨架(三平台跑通)+ Riverpod + freezed | 3 天 | 三平台空視窗 |
| **M2** | **`MbClient` Dart 實作 + 單元測試**(對 `pymodbus` slave) | **5 天** | **CLI 可讀寫 FC 03/06** |
| M3 | 補完 FC 01/02/04/05/15/16 + Exception 處理 | 3 天 | 全 TCP FC 覆蓋 + 測試綠燈 |
| M4 | DeviceHub + PollLoop + 主控台 UI | 5 天 | 主視窗可監看單一 Device |
| M5 | `desktop_multi_window` 整合 + IPC + Watch Window 容器 + **樹狀 split layout(多面板分割)** | 6.5 天 | 多視窗、單視窗多面板皆可運作 |
| M6 | Format codec(讀/寫雙向)+ Watch 表格(`pluto_grid`,Address/Value 兩欄,表頭可切 format) | 4 天 | 接近 ModScan 體驗 |
| M7 | 原始封包面板 + 統計 + 日誌 | 3 天 | 工程除錯可用 |
| M8 | 設定檔 import/export(含 layout 持久化)+ 深色主題 | 3 天 | 工程化使用 |
| M9 | 三平台打包(MSIX / DMG / AppImage)+ 自動更新 | 3 天 | v1.0 發佈 |

**總計**:約 35.5 工作天(~7 週)單人全職。

---

## 10. 後續路線

| 版本 | 主題 | 內容 |
|------|------|------|
| v1.0 | TCP 核心 + 多視窗 | 上述 5.1 |
| v1.5 | 體驗強化 | 趨勢圖、CSV 匯出、腳本重播、深色主題精修 |
| v2.0 | 序列埠 | 加 RTU(`flutter_libserialport`)+ ASCII + RTU over TCP |
| v2.5 | 進階診斷 | Slave 模擬器、RTU Sniffer |
| v3.0 | CLI | CLI 模式整合 CI |

---

## 11. 跨平台注意事項

- **macOS sandbox**:entitlements 開 `com.apple.security.network.client`。
- **Windows 防火牆**:首次連線會跳出允許對話框,測試文件需提示。
- **多視窗在 Linux**:Wayland 與 X11 行為略異,需在 Mutter / KDE / GNOME 各測一次。
- **字體**:hex 顯示用 monospace(JetBrains Mono / Cascadia Code,內嵌字體資源)。
- **打包**:Windows MSIX、macOS DMG + Notarization、Linux AppImage + deb。

---

## 12. 風險與待研究

- **`desktop_multi_window` 維護狀態**:該套件更新較慢,需先 spike 確認三平台都能運行。若不穩,改用 Tab 介面 + `flutter_acrylic` 做視窗效果,或自寫 platform channel。
- **大量點位 UI 效能**:1000+ 點即時更新,`pluto_grid` + Riverpod `select` 是否撐得住,要做基準測試。
- **同連線並發 vs Slave 行為**:部分 Slave 不支援並發 transaction,先以 `serializeRequests` 開關處理。
- **TCP keepalive**:長時間閒置連線是否會被中介設備 drop,需在 `MbClient` 加 keepalive 與斷線自動重連。

---

## 13. 下一步行動

1. **Spike(0.5 天)**:建立最小 Dart Socket 範例,連到 `pymodbus` slave 跑 FC 03,驗證 MBAP 解析正確。
2. **建立 Git 倉庫** + GitHub Actions 三平台 build matrix。
3. **M1 啟動**:
   ```bash
   flutter create mbt --platforms=windows,macos,linux
   cd mbt
   flutter pub add flutter_riverpod freezed_annotation json_annotation
   flutter pub add desktop_multi_window pluto_grid
   flutter pub add --dev build_runner freezed json_serializable
   ```
4. **建立測試 Slave**:
   ```bash
   pip install pymodbus
   python -m pymodbus.server --type tcp --port 5020
   ```
5. **進入 M2**:把第 3.2 節的 `MbClient` 程式碼放進 `lib/core/modbus/mb_client.dart`,寫單元測試。
