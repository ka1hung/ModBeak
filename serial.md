# Modbus RTU 支援計畫

> **目標平台**:Windows + macOS + Linux(mobile 不在此計畫範圍)
> **參考**:Go RTU 函式庫 [ka1hung/mbmaster](https://github.com/ka1hung/mbmaster)、現有 TCP 端 [ka1hung/mbclient](https://github.com/ka1hung/mbclient)

---

## 1. 介面決策 — `MbClient` 改成抽象基底

現在 `MbClient` 已經是「TCP + 多個升級」的具體實作。最小擾動的做法是把它抽象化:

```dart
// 抽象 — 公開 API 表面跟現在完全一樣
abstract class MbClient {
  Stream<RawPacket> get rawPackets$;
  bool get isConnected;
  Future<void> open();
  Future<void> close();
  Future<void> dispose();

  Future<List<bool>> readCoil(int unitId, int addr, int qty);
  Future<List<bool>> readCoilIn(int unitId, int addr, int qty);
  Future<List<int>>  readReg(int unitId, int addr, int qty);
  Future<List<int>>  readRegIn(int unitId, int addr, int qty);
  Future<void> writeCoil(int unitId, int addr, bool v);
  Future<void> writeReg(int unitId, int addr, int v);
  Future<void> writeCoils(int unitId, int addr, List<bool> v);
  Future<void> writeRegs(int unitId, int addr, List<int> v);

  // 共用的限流邏輯抽到基底 (serializeRequests / minRequestGapMs)
  factory MbClient.tcp({...}) = TcpMbClient;
  factory MbClient.rtu({...}) = RtuMbClient;
}
```

**好處**:`DeviceHub`、`PollLoop`、所有 UI 完全不必動 — 它們都只用 public API。

**檔案拆法**:
- `lib/core/modbus/mb_client.dart` — abstract 基底 + factory
- `lib/core/modbus/tcp_mb_client.dart` — 現有 TCP 實作搬過去
- `lib/core/modbus/rtu_mb_client.dart` — 新增 RTU 實作
- `lib/core/modbus/crc16.dart` — 共用 CRC-16-IBM

---

## 2. RTU client 設計差異

| 維度 | TCP (現有) | RTU (新增) |
|---|---|---|
| Transport | `Socket` | `SerialPort` (`flutter_libserialport`) |
| Framing | MBAP 7 bytes + PDU | `[slaveId, fc, payload, crc16_lo, crc16_hi]` |
| 並發 | TX ID demux,可並行 | **物理半雙工,強制 mutex** |
| End-of-frame | MBAP `length` 欄位 | **依 FC 計算預期長度** + CRC 驗證 |
| Sentinel error | `MbDisconnect / MbNoResponse / MbModbusError` | **直接重用同一組** |

### 2.1 CRC16 (Modbus IBM, poly 0xA001)

約 10 行,可預先建 lookup table 提速:

```dart
class Crc16 {
  static final _table = _build();
  static Uint8List append(Uint8List data) { ... }   // 回 data + [lo, hi]
  static bool   check (Uint8List frame)   { ... }   // 驗證最後 2 bytes
  static int    compute(Uint8List data)   { ... }
}
```

### 2.2 預期回應長度(從 FC 計算,不必等 timeout 才知道結束)

| FC | 回應長度 (bytes) |
|---|---|
| 01 / 02 (read bits) | `5 + ceil(qty/8)` |
| 03 / 04 (read regs) | `5 + qty*2` |
| 05 / 06 / 0F / 10 | `8` (echo) |
| Exception (FC \| 0x80) | `5`(提前判定) |

### 2.3 讀取策略

Dart 比 Go ref 好處理 — 不必每 10ms 輪詢:

```dart
final completer = Completer<Uint8List>();
final buf = BytesBuilder();
late StreamSubscription sub;
sub = reader.stream.listen((chunk) {
  buf.add(chunk);
  // 提前判斷例外回應(5 bytes 且 FC 高位 1)
  if (buf.length >= 5 && (buf.toBytes()[1] & 0x80) != 0) {
    sub.cancel(); completer.complete(buf.toBytes()); return;
  }
  if (buf.length >= expectedLen) {
    sub.cancel(); completer.complete(buf.toBytes());
  }
});
return completer.future.timeout(timeout);
```

完成後驗 CRC、剝掉 CRC + slaveId,把 payload 餵給跟 TCP 共用的 FC parser。

### 2.4 並發

RTU 整條 bus 只准一筆 in-flight,所以 `RtuMbClient` 內部**強制**走 mutex queue。UI 對 RTU device 把 `Serialize requests` 選項隱藏(或顯示為唯讀 ON)。

---

## 3. `DeviceConfig` 擴充

```dart
enum ModbusTransport { tcp, rtu }
enum SerialParity { none, even, odd }

@freezed
abstract class DeviceConfig with _$DeviceConfig {
  const factory DeviceConfig({
    required String id,
    required String name,
    @Default(ModbusTransport.tcp) ModbusTransport transport,

    // ── TCP ──
    @Default('') String host,
    @Default(502) int port,

    // ── RTU ──
    @Default('') String serialPort,   // e.g. /dev/cu.usbserial-110, COM3
    @Default(9600) int baudRate,
    @Default(8) int dataBits,
    @Default(1) int stopBits,
    @Default(SerialParity.none) SerialParity parity,

    // 共用
    @Default(2000) int timeoutMs,
    @Default(2) int retries,
    @Default(true) bool serializeRequests,  // RTU 強制 true
    @Default(true) bool autoReconnect,
    @Default(100) int minRequestGapMs,
  }) = _DeviceConfig;
  ...
}
```

舊 config(`transport` 欄位不存在)→ freezed 預設為 `tcp`,**完全向後相容**。

`DeviceHub.connect()` 改成依 `cfg.transport` 走 `MbClient.tcp(...)` 或 `MbClient.rtu(...)` 分支。

---

## 4. RawPacket / 通訊面板

RTU 沒有 MBAP。現有 `RawPacket.mbap` getter 只給 TCP 用。改成:

```dart
class RawPacket {
  ...
  final ModbusTransport transport;   // 新增

  // TCP: parse MBAP; RTU: parse [slaveId, fc, ...]
  MbapHeader? get mbap => transport == ModbusTransport.tcp
      ? MbapHeader.tryParse(bytes) : null;
  RtuFrameInfo? get rtu => transport == ModbusTransport.rtu
      ? RtuFrameInfo.tryParse(bytes) : null;
}
```

UI 的 Comm view 用 `switch (p.transport)` 分支顯示:
- **TCP**: `tid=0001 unit=01 FC=03 ...`
- **RTU**: `slave=01 FC=03 ... CRC=BC54`

---

## 5. 平台依賴 — Windows + macOS + Linux

新增 `flutter_libserialport: ^0.4.x`(FFI 包裝 libserialport,三平台都驗證)。

### 5.1 macOS

- 序列埠名稱:`/dev/cu.usbserial-*` / `/dev/cu.usbmodem*`
- **Sandbox 問題**:目前 [Release.entitlements](macos/Runner/Release.entitlements) 與 [DebugProfile.entitlements](macos/Runner/DebugProfile.entitlements) 都有 `com.apple.security.app-sandbox = true`,sandboxed app **無法存取 `/dev/cu.*`**
- 解法選一:
  1. **關 sandbox**(`com.apple.security.app-sandbox = false`)— 失去 App Store 上架資格,但 dev tool 派發 OK
  2. 加 `com.apple.security.device.usb` + 用 IOKit 列舉(複雜,且仍可能無法直接 read/write 字元裝置)
- **建議**:Modbus RTU 工具屬於 dev tool,直接關 sandbox 最乾淨;發佈走 notarized DMG。
- Code signing 仍要 (`Developer ID Application`),才能在新版 macOS 不被 Gatekeeper 擋。

### 5.2 Windows

- 序列埠名稱:`COM1`–`COM9` 直接寫;`COM10` 以上要用 `\\.\COM10` 格式(`libserialport` 應自動處理,需驗證)
- 無 sandbox 問題
- 列舉:`SerialPort.availablePorts` 即可

### 5.3 Linux

- 序列埠名稱:
  - `/dev/ttyUSB*` — USB-Serial 晶片(CH340 / FTDI / CP210x 等)
  - `/dev/ttyACM*` — USB CDC(Arduino 類)
  - `/dev/ttyS*` — 主機板原生 UART(罕見)
- 無 sandbox 問題,不需 entitlement
- **權限**:預設裝置節點屬於群組 `dialout`(Debian / Ubuntu)或 `uucp`(Arch / Fedora),一般使用者無權限。首次使用要設定:

  ```bash
  sudo usermod -aG dialout $USER   # Debian / Ubuntu
  sudo usermod -aG uucp    $USER   # Arch / Fedora
  # 然後登出再登入
  ```

- 實作上,`RtuMbClient.open()` 失敗時若是 `EACCES / Permission denied` 且 `Platform.isLinux`,要把 error message 包一層提示告訴使用者去加群組,而不是丟裸的 IO error
- 列舉:`SerialPort.availablePorts` 即可

### 5.4 不在此計畫範圍

- iOS / Android — 行動裝置一般沒有原生序列埠,跨架構問題大,先不做

---

## 6. UI 改動

### 6.1 Add Device dialog

最上方加 protocol toggle `[ TCP | RTU ]`。

- **TCP 模式**(現有):Host / Port / Timeout / Gap / Serialize / Auto-reconnect
- **RTU 模式**(新增):
  - **Port**(下拉,旁邊放 refresh 按鈕)
    - 列舉用 `SerialPort.availablePorts`
    - 顯示時帶上 `description` / `manufacturer` / `productName`,例如 `COM3 — USB-SERIAL CH340`、`/dev/ttyUSB0 — Silicon Labs CP2102`,使用者插多個轉接器時才分得出來
    - JSON 仍存平台原生路徑(`COM3`、`/dev/ttyUSB0`、`/dev/cu.usbserial-110`)
    - 若 `cfg.serialPort` 不在當前 `availablePorts` 中(換電腦或拔了轉接器),下拉裡額外加一條灰色 `COM3 (not connected)` 並選中,讓使用者一眼看出問題
    - **不做**自動掃描 slave(掃 port × baud × slave id 太慢、會干擾 bus 上其他正常 slave;讓使用者明確指定即可)
    - **不做** USB 熱插拔自動偵測(refresh 按鈕已足夠)
  - **Baud**(下拉 1200 / 2400 / 4800 / 9600 / 19200 / 38400 / 57600 / 115200 / 230400)
  - **Data bits**(7 / 8)
  - **Stop bits**(1 / 2)
  - **Parity**(None / Even / Odd)
  - Timeout / Gap / Auto-reconnect(Serialize 隱藏因為強制 ON)

### 6.2 Device header / sidebar

用 `cfg.transport` 切換顯示文字:
- **TCP**: `192.168.1.10:502`
- **RTU**: `/dev/cu.usbserial-110 @ 9600 8N1`

[conn_indicator.dart](lib/ui/widgets/conn_indicator.dart) 旁邊加一個小 chip 顯示 `TCP` / `RTU` 標籤,讓使用者一眼看出協定。

---

## 7. 開發里程碑

| 階段 | 內容 | 預估 |
|---|---|---|
| **R1** | 重構 `MbClient` 為抽象 + `TcpMbClient` 子類(純搬家,行為不變,既有 28 個測試應全綠) | 0.5 天 |
| **R2** | `CRC16` + `RtuMbClient` 基本(open/close + FC03),`flutter_libserialport` 整合 + Win/mac/Linux spike | 1.5 天 |
| **R3** | 補完 FC 01/02/04/05/06/0F/10 + exception 路徑 + 預期長度算法 | 1 天 |
| **R4** | `DeviceConfig` 加 transport 欄位 + freezed 重新生成 + JSON 向後相容驗證 | 0.5 天 |
| **R5** | Add Device dialog protocol toggle + 序列埠列舉 + 顯示適配 | 1 天 |
| **R6** | `RawPacket` 加 transport tag + Comm view 分支顯示 RTU frame | 0.5 天 |
| **R7** | 測試 — CRC roundtrip / RTU frame builder / 預期長度計算;macOS sandbox 關閉 + Win + Linux build 驗證(含 dialout 群組權限提示) | 1 天 |
| **R8** | 真實 RTU slave 整合測(USB-RS485 + ESP32 跑 slave firmware,或 `libmodbus` slave) | 0.5 天 |

**總計**:約 6.5 工作天。

---

## 8. 風險 / 待研究

1. **`flutter_libserialport` 維護狀態**:套件最後更新 2023 末;**先在 R2 spike**,Win + mac + Linux 都能 open + 收發 + 列舉。若不穩,fallback 是 `libserialport` 直接走 `dart:ffi` 自己包。
2. **macOS sandbox 關閉的影響**:會失去 App Store 上架資格;目標是 dev tool 派發無妨,確認後再執行。
3. **RTU 與 TCP 對 `serializeRequests` 行為一致性**:RTU 強制 true,UI 隱藏;但 JSON config 仍存 true,讓未來切回 TCP 時不會被驚訝重設。
4. **`autoReconnect`**:RTU 斷線通常是 USB 拔除 → `libserialport` 應丟錯。實作要把這個錯 map 到 `MbDisconnect` 才能觸發既有的重連邏輯。
5. **跨平台序列埠名稱差異**:macOS `/dev/cu.usbserial-*`、Windows `COM\d+`、Linux `/dev/ttyUSB*` / `/dev/ttyACM*`;dropdown 列舉時帶 description / manufacturer 顯示,JSON 儲存平台原生路徑。
6. **timeout 行為**:RTU 沒回應就乾等 → 必須在 stream 層加 `Future.timeout`,**不要只依賴序列埠驅動的 read timeout**(Win/mac 行為不一)。
7. **Code signing(macOS)**:關 sandbox 之後仍需 `Developer ID Application` 簽章 + notarize,否則新版 macOS 一律擋。
8. **Linux 權限**:`/dev/ttyUSB*` 預設屬於 `dialout`(Debian/Ubuntu)或 `uucp`(Arch/Fedora)群組,使用者首次跑會 EACCES;open 失敗時要把錯誤 map 成友善提示告訴使用者去加群組,不要丟裸 IO error。

---

## 9. 下一步

**先做 R1 重構**(0.5 天):純搬家,把現有 `MbClient` 拆成 abstract + `TcpMbClient`。完成後跑既有 28 個測試,綠燈才繼續。這一步抓出來的任何介面問題會比後面寫 RTU 時遇到便宜得多。

R1 完成後再決定 R2 用哪個 serial port 套件 — `flutter_libserialport` 是第一順位,但 Win/mac 真實跑過再下單。
