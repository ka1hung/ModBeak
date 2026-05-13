// Watch pane bodies — Table / Comm / Errors views

// Sample data generators
function genCells(start, count, formatter) {
  const out = [];
  for (let i = 0; i < count; i++) out.push({ addr: start + i, val: formatter(start + i, i) });
  return out;
}

// ===== Table view (u16/hex/bool/bin) =====
function TableView({ format = 'UInt16', cells, cellStyle = 'borderless', density = 'tight', startAddr = 100, count = 32, errorAddrs = [], writingAddrs = [] }) {
  const cellW = (() => {
    if (format === 'Binary') return 200;
    if (format === 'Float32 BE' || format === 'Float32 LE') return 150;
    if (format === 'UInt32 BE' || format === 'UInt32 LE' || format === 'Int32 BE') return 130;
    if (format === 'ASCII') return 220;
    return 120;
  })();
  const cellH = density === 'touch' ? 36 : (density === 'tight' ? 22 : 28);

  // Generate sample values if not provided
  const data = cells || genCells(startAddr, count, (addr, i) => {
    if (format === 'UInt16') return (1234 + i * 17 + (addr % 7) * 47).toString();
    if (format === 'Int16') return ((i * 37 - 200) % 32767).toString();
    if (format === 'Hex') return '0x' + ((0x1234 + i * 17) & 0xffff).toString(16).toUpperCase().padStart(4, '0');
    if (format === 'Binary') {
      const v = (0x4A2C + i * 13) & 0xffff;
      return v.toString(2).padStart(16, '0').replace(/(.{4})/g, '$1 ').trim();
    }
    if (format === 'Float32 BE') return (3.14 + i * 0.27).toFixed(3);
    if (format === 'UInt32 BE') return (10000 + i * 314).toString();
    if (format === 'Bool') return (i % 3 !== 0);
    if (format === 'ASCII') return ['HELLO', 'WORLD', 'PUMP-01', 'TANK-02', 'OK', 'RDY'][i % 6];
    return '0';
  });

  const isBool = format === 'Bool';
  const cellsPerCol = Math.max(4, Math.floor((density === 'touch' ? 320 : 240) / cellH));
  const cols = Math.ceil(data.length / cellsPerCol);

  return (
    <div style={{
      flex: 1,
      overflow: 'auto',
      background: T.bg2,
      padding: cellStyle === 'zebra' ? 0 : 0,
    }}>
      <div style={{
        display: 'inline-flex',
        flexDirection: 'column',
        flexWrap: 'wrap',
        height: cellsPerCol * cellH,
        alignContent: 'flex-start',
      }}>
        {data.map((c, i) => {
          const colIdx = Math.floor(i / cellsPerCol);
          const rowIdx = i % cellsPerCol;
          const hasError = errorAddrs.includes(c.addr);
          const writing = writingAddrs.includes(c.addr);
          const zebra = cellStyle === 'zebra' && rowIdx % 2 === 1;
          const grid = cellStyle === 'grid';
          return (
            <div key={i} style={{
              width: cellW,
              height: cellH,
              display: 'flex',
              alignItems: 'center',
              paddingLeft: 8, paddingRight: 8,
              gap: 8,
              background: hasError ? T.errorBg : (zebra ? T.bg1 : 'transparent'),
              borderRight: grid ? `1px solid ${T.borderFaint}` : 'none',
              borderBottom: grid ? `1px solid ${T.borderFaint}` : 'none',
              borderLeft: colIdx > 0 && !grid ? `1px solid ${T.borderFaint}` : 'none',
              opacity: writing ? 0.5 : 1,
              boxSizing: 'border-box',
            }}>
              <span style={{
                ...typeCSS(TY.monoAddr),
                color: hasError ? T.error : T.textDim,
                fontSize: density === 'touch' ? 11 : 10,
                minWidth: 32,
                textAlign: 'left',
              }}>{c.addr}</span>
              {isBool ? (
                <BoolPill value={c.val} pending={writing} big={density === 'touch'} />
              ) : (
                <span style={{
                  ...typeCSS(density === 'touch' ? TY.monoLg : TY.mono),
                  color: hasError ? T.error : T.text,
                  flex: 1,
                  textAlign: 'right',
                  fontVariantNumeric: 'tabular-nums',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}>{c.val}</span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ===== Format bar =====
function FormatBar({ format, onFormat, locked, polling = 'live', chars }) {
  return (
    <div style={{
      height: 28,
      padding: '0 8px',
      background: T.bg2,
      borderBottom: `1px solid ${T.border}`,
      display: 'flex', alignItems: 'center', gap: 8,
      flexShrink: 0,
    }}>
      <span style={{ ...typeCSS(TY.labelSm), color: T.textDim }}>FORMAT</span>
      <Select
        value={format}
        onChange={onFormat}
        width={130}
        mono
        style={{ height: 22 }}
        options={['UInt16','Int16','Hex','Binary','UInt32 BE','UInt32 LE','Int32 BE','Float32 BE','Float32 LE','ASCII','Bool']}
      />
      {chars !== undefined && (
        <>
          <span style={{ ...typeCSS(TY.labelSm), color: T.textDim, marginLeft: 4 }}>CHARS/ROW</span>
          <Input value={chars} mono width={42} style={{ height: 22, fontSize: 11 }} />
        </>
      )}
      {locked && (
        <span style={{ ...typeCSS(TY.caption), color: T.textDim, fontStyle: 'italic' }}>
          locked to Bool by FC
        </span>
      )}
      <div style={{ flex: 1 }} />
      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
        {polling === 'live' ? (
          <>
            <IconPollLive size={12} color={T.online} />
            <span style={{ ...typeCSS(TY.labelSm), color: T.online }}>LIVE</span>
          </>
        ) : (
          <>
            <IconPollPause size={11} color={T.textMuted} />
            <span style={{ ...typeCSS(TY.labelSm), color: T.textMuted }}>PAUSED</span>
          </>
        )}
      </div>
    </div>
  );
}

// ===== Pane footer (stats) =====
function PaneFooter({ ok, err, avg, lastError }) {
  return (
    <div style={{
      height: 22,
      background: T.bg3,
      borderTop: `1px solid ${T.border}`,
      padding: '0 8px',
      display: 'flex', alignItems: 'center', gap: 12,
      flexShrink: 0,
    }}>
      <Stat label="OK" value={ok} color={T.online} />
      <Stat label="ERR" value={err} color={err > 0 ? T.error : T.textMuted} />
      <Stat label="Avg" value={`${avg}ms`} color={T.textMuted} />
      <div style={{ flex: 1 }} />
      {lastError && (
        <span style={{
          ...typeCSS(TY.monoSm),
          color: T.error,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          maxWidth: 260,
        }}>{lastError}</span>
      )}
    </div>
  );
}

function Stat({ label, value, color }) {
  return (
    <div style={{ display: 'inline-flex', alignItems: 'baseline', gap: 5 }}>
      <span style={{ ...typeCSS(TY.labelSm), color: T.textDim, fontSize: 9 }}>{label}</span>
      <span style={{ ...typeCSS(TY.monoSm), color, fontVariantNumeric: 'tabular-nums' }}>{value}</span>
    </div>
  );
}

// ===== Comm view (packet log) =====
function CommView({ packets, txEncoding = 'color-arrow' }) {
  const sample = packets || [
    { t: '14:23:01.124', dir: 'TX', summary: 'unit=01 FC=03 addr=100 qty=10', hex: '00 01 00 00 00 06 01 03 00 64 00 0A' },
    { t: '14:23:01.137', dir: 'RX', summary: 'unit=01 FC=03 bytes=20', hex: '00 01 00 00 00 17 01 03 14 04 D2 00 7B 1A 2C 00 FF 12 34 AB CD 00 01 56 78 9A BC DE F0 EF FE' },
    { t: '14:23:01.624', dir: 'TX', summary: 'unit=01 FC=03 addr=100 qty=10', hex: '00 02 00 00 00 06 01 03 00 64 00 0A' },
    { t: '14:23:01.638', dir: 'RX', summary: 'unit=01 FC=03 bytes=20', hex: '00 02 00 00 00 17 01 03 14 04 E1 00 7C 1A 2D 00 FF 12 35 AB CD 00 01 56 78 9A BC DE F0 EF FE' },
    { t: '14:23:02.124', dir: 'TX', summary: 'unit=01 FC=03 addr=100 qty=10', hex: '00 03 00 00 00 06 01 03 00 64 00 0A' },
    { t: '14:23:02.139', dir: 'RX', summary: 'unit=01 FC=03 bytes=20', hex: '00 03 00 00 00 17 01 03 14 04 F0 00 7D 1A 2E 00 FF 12 36 AB CD 00 01 56 78 9A BC DE F0 EF FE' },
    { t: '14:23:02.624', dir: 'TX', summary: 'unit=01 FC=06 addr=200 val=0x1F40', hex: '00 04 00 00 00 06 01 06 00 C8 1F 40' },
    { t: '14:23:02.629', dir: 'RX', summary: 'unit=01 FC=86 EXC=02 *', hex: '00 04 00 00 00 03 01 86 02', err: true },
    { t: '14:23:03.124', dir: 'TX', summary: 'unit=01 FC=03 addr=100 qty=10', hex: '00 05 00 00 00 06 01 03 00 64 00 0A' },
    { t: '14:23:03.135', dir: 'RX', summary: 'unit=01 FC=03 bytes=20', hex: '00 05 00 00 00 17 01 03 14 05 00 00 7E 1A 2F 00 FF 12 37 AB CD 00 01 56 78 9A BC DE F0 EF FE' },
    { t: '14:23:03.624', dir: 'TX', summary: 'unit=01 FC=03 addr=100 qty=10', hex: '00 06 00 00 00 06 01 03 00 64 00 0A' },
    { t: '14:23:03.638', dir: 'RX', summary: 'unit=01 FC=03 bytes=20', hex: '00 06 00 00 00 17 01 03 14 05 12 00 7F 1A 30 00 FF 12 38 AB CD 00 01 56 78 9A BC DE F0 EF FE' },
    { t: '14:23:04.124', dir: 'TX', summary: 'unit=01 FC=03 addr=100 qty=10', hex: '00 07 00 00 00 06 01 03 00 64 00 0A' },
    { t: '14:23:04.137', dir: 'RX', summary: 'unit=01 FC=03 bytes=20', hex: '00 07 00 00 00 17 01 03 14 05 24 00 80 1A 31 00 FF 12 39 AB CD 00 01 56 78 9A BC DE F0 EF FE' },
    { t: '14:23:04.624', dir: 'TX', summary: 'unit=01 FC=03 addr=100 qty=10', hex: '00 08 00 00 00 06 01 03 00 64 00 0A' },
    { t: '14:23:04.640', dir: 'RX', summary: 'unit=01 FC=03 bytes=20', hex: '00 08 00 00 00 17 01 03 14 05 36 00 81 1A 32 00 FF 12 3A AB CD 00 01 56 78 9A BC DE F0 EF FE' },
  ];

  return (
    <div style={{ flex: 1, overflow: 'auto', background: T.bg1, padding: 0 }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', ...typeCSS(TY.monoSm) }}>
        <thead style={{ position: 'sticky', top: 0, background: T.bg2, zIndex: 1 }}>
          <tr>
            <Th>TIME</Th>
            <Th width={36} center>DIR</Th>
            <Th>SUMMARY</Th>
            <Th>HEX</Th>
          </tr>
        </thead>
        <tbody>
          {sample.map((p, i) => {
            const isTx = p.dir === 'TX';
            const c = isTx ? T.tx : T.rx;
            const Arrow = isTx ? IconTX : IconRX;
            return (
              <tr key={i} style={{ background: i % 2 ? T.bg2 : 'transparent' }}>
                <Td><span style={{ color: T.textDim }}>{p.t}</span></Td>
                <Td center>
                  <span style={{
                    display: 'inline-flex', alignItems: 'center', gap: 3,
                    color: c,
                    fontWeight: 600,
                    letterSpacing: '0.04em',
                  }}>
                    <Arrow size={10} color={c} />
                    {p.dir}
                  </span>
                </Td>
                <Td><span style={{ color: p.err ? T.error : T.text }}>{p.summary}</span></Td>
                <Td><span style={{ color: T.textMuted, fontSize: 10 }}>{p.hex}</span></Td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function Th({ children, width, center }) {
  return (
    <th style={{
      ...typeCSS(TY.labelSm),
      color: T.textDim,
      fontWeight: 600,
      textAlign: center ? 'center' : 'left',
      padding: '4px 8px',
      borderBottom: `1px solid ${T.border}`,
      width,
      whiteSpace: 'nowrap',
    }}>{children}</th>
  );
}

function Td({ children, center }) {
  return (
    <td style={{
      padding: '2px 8px',
      textAlign: center ? 'center' : 'left',
      whiteSpace: 'nowrap',
      verticalAlign: 'middle',
      borderBottom: `1px solid ${T.borderFaint}`,
    }}>{children}</td>
  );
}

// ===== Errors view =====
function ErrorsView({ errors }) {
  const sample = errors || [
    { t: '14:22:58.412', tag: 'CONN', watch: 'AC Drive · Holding', msg: 'Connection refused: 192.168.1.42:502' },
    { t: '14:23:02.629', tag: 'POLL', watch: 'PLC-Line-A · Holding 200', msg: 'Modbus exception 02 — illegal data address' },
    { t: '14:23:08.117', tag: 'POLL', watch: 'AC Drive · Holding', msg: 'Read timeout after 1000 ms (no response from slave 02)' },
    { t: '14:23:11.522', tag: 'POLL', watch: 'AC Drive · Holding', msg: 'CRC mismatch — got 0x1F42, expected 0x1F40' },
    { t: '14:23:14.901', tag: 'CONN', watch: 'Energy Meter · RTU', msg: 'Serial port /dev/ttyUSB0 — permission denied' },
    { t: '14:23:18.211', tag: 'POLL', watch: 'AC Drive · Holding', msg: 'Modbus exception 02 — illegal data address' },
  ];
  return (
    <div style={{ flex: 1, background: T.bg1, display: 'flex', flexDirection: 'column' }}>
      <div style={{
        padding: '6px 10px',
        borderBottom: `1px solid ${T.border}`,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <IconErrorX size={12} color={T.error} />
        <span style={{ ...typeCSS(TY.labelSm), color: T.text }}>{sample.length} ERRORS</span>
        <div style={{ flex: 1 }} />
        <Btn kind="ghost" size="sm" icon={IconClear}>Clear</Btn>
      </div>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {sample.map((e, i) => (
          <div key={i} style={{
            padding: '6px 10px',
            borderBottom: `1px solid ${T.borderFaint}`,
            display: 'flex', gap: 10,
            background: i % 2 ? T.bg2 : 'transparent',
          }}>
            <span style={{ ...typeCSS(TY.monoSm), color: T.textDim, minWidth: 88 }}>{e.t}</span>
            <span style={{
              ...typeCSS(TY.labelSm),
              color: e.tag === 'CONN' ? T.warn : T.error,
              border: `1px solid ${e.tag === 'CONN' ? T.warn : T.error}`,
              padding: '0 4px',
              borderRadius: 2,
              alignSelf: 'flex-start',
              minWidth: 36, textAlign: 'center',
            }}>{e.tag}</span>
            <span style={{ ...typeCSS(TY.caption), color: T.textMuted, minWidth: 130 }}>{e.watch}</span>
            <span style={{ ...typeCSS(TY.body), color: T.text, flex: 1 }}>{e.msg}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ===== Empty states =====
function EmptyState({ icon: Ic, title, hint, density = 'full' }) {
  if (density === 'tiny') {
    return (
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', background: T.bg2 }}>
        <span style={{ ...typeCSS(TY.caption), color: T.textDim }}>{title}</span>
      </div>
    );
  }
  if (density === 'compact') {
    return (
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, background: T.bg2 }}>
        {Ic && <Ic size={20} color={T.textDim} />}
        <span style={{ ...typeCSS(TY.body), color: T.textMuted }}>{title}</span>
      </div>
    );
  }
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10, background: T.bg2, padding: 20 }}>
      {Ic && <Ic size={32} color={T.textDim} />}
      <div style={{ ...typeCSS(TY.h2), color: T.text }}>{title}</div>
      {hint && <div style={{ ...typeCSS(TY.body), color: T.textMuted, textAlign: 'center', maxWidth: 280 }}>{hint}</div>}
    </div>
  );
}

Object.assign(window, {
  TableView, FormatBar, PaneFooter, CommView, ErrorsView, EmptyState,
});
