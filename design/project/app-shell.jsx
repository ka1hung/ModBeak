// Main app shell — top toolbar, sidebar, device header, MDI workspace

// ===== Top toolbar =====
function TopToolbar({ theme = 'dark', onToggleTheme }) {
  const isLight = theme === 'light';
  return (
    <div style={{
      height: 38,
      background: T.bg3,
      borderBottom: `1px solid ${T.border}`,
      display: 'flex', alignItems: 'center',
      padding: '0 10px',
      gap: 10,
      flexShrink: 0,
    }}>
      <BrandMark />
      <div style={{ width: 1, height: 18, background: T.border, margin: '0 4px' }}/>
      <Btn kind="primary" size="sm" icon={IconAdd}>Device</Btn>
      <Btn kind="secondary" size="sm" icon={IconAdd}>Watch</Btn>
      <div style={{ flex: 1 }} />
      <Btn kind="ghost" size="sm" icon={IconImport}>Import</Btn>
      <Btn kind="ghost" size="sm" icon={IconExport}>Export</Btn>
      <div style={{ width: 1, height: 18, background: T.border, margin: '0 4px' }}/>
      <button
        onClick={onToggleTheme}
        title={isLight ? 'Switch to dark theme' : 'Switch to light theme'}
        style={{
          height: 26, width: 26,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          background: 'transparent',
          border: `1px solid ${T.border}`,
          borderRadius: R.sm,
          color: T.textMuted,
          cursor: 'pointer',
          padding: 0,
        }}
      >
        {isLight ? <IconMoon size={14} /> : <IconSun size={14} />}
      </button>
      <Btn kind="ghost" size="sm" icon={IconMoreH} />
    </div>
  );
}

// ===== Brand mark =====
function BrandMark({ size = 26 }) {
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
      <CockatielHead size={size} />
      <span style={{ ...typeCSS(TY.h2), color: T.text, letterSpacing: '-0.01em' }}>
        <span style={{ fontWeight: 400 }}>Mod</span><span style={{ fontWeight: 700 }}>Beak</span>
      </span>
    </div>
  );
}

// ===== Sidebar =====
function Sidebar({ devices, selectedDeviceId, selectedWatchId }) {
  return (
    <div style={{
      width: 260,
      flexShrink: 0,
      background: T.bg2,
      borderRight: `1px solid ${T.border}`,
      display: 'flex', flexDirection: 'column',
    }}>
      <SectionLabel>DEVICES</SectionLabel>
      <div style={{ flex: 1, overflow: 'auto', padding: '0 4px 8px' }}>
        {devices.map(d => (
          <DeviceRow key={d.id} device={d} selected={d.id === selectedDeviceId} selectedWatchId={selectedWatchId} />
        ))}
      </div>
    </div>
  );
}

function DeviceRow({ device, selected, selectedWatchId }) {
  const expanded = device.expanded;
  return (
    <div>
      <div style={{
        display: 'flex', alignItems: 'center',
        height: 34,
        padding: '0 8px',
        gap: 7,
        cursor: 'pointer',
        position: 'relative',
        background: selected ? T.bgSelected : 'transparent',
        borderRadius: R.sm,
        marginBottom: 1,
      }}>
        {selected && (
          <span style={{
            position: 'absolute', left: 0, top: 4, bottom: 4, width: 2,
            background: T.accent,
            borderRadius: 1,
          }}/>
        )}
        <IconBtn icon={expanded ? IconExpandDown : IconExpandRight} size={16} style={{ marginLeft: 2 }} />
        <StatusDot status={device.status} size={8} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            ...typeCSS(TY.body),
            color: T.text,
            fontWeight: selected ? 600 : 500,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>{device.name}</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 1 }}>
            <span style={{
              ...typeCSS(TY.labelSm),
              color: T.textMuted,
              padding: '0 4px',
              border: `1px solid ${T.borderFaint}`,
              borderRadius: 2,
              fontSize: 9,
            }}>{device.transport}</span>
            <span style={{ ...typeCSS(TY.monoSm), color: T.textDim, fontSize: 10, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {device.address}
            </span>
          </div>
        </div>
        <IconBtn icon={IconMoreV} size={20} />
      </div>
      {expanded && device.watches && (
        <div style={{ marginLeft: 12, borderLeft: `1px solid ${T.borderFaint}`, paddingLeft: 6 }}>
          {device.watches.map(w => (
            <WatchRow key={w.id} watch={w} selected={w.id === selectedWatchId} />
          ))}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            height: 24, padding: '0 8px',
            cursor: 'pointer',
            color: T.textMuted,
          }}>
            <IconAdd size={12} color={T.textMuted} />
            <span style={{ ...typeCSS(TY.caption) }}>New watch</span>
          </div>
        </div>
      )}
    </div>
  );
}

function WatchRow({ watch, selected }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 6,
      height: 26, padding: '0 6px',
      borderRadius: R.sm,
      marginBottom: 1,
      position: 'relative',
      background: selected ? T.bg4 : 'transparent',
    }}>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 5, minWidth: 0 }}>
        <FCChip fc={watch.fc} />
        <span style={{
          ...typeCSS(TY.monoSm),
          color: T.textMuted,
          fontSize: 10,
        }}>{watch.range}</span>
        <span style={{
          ...typeCSS(TY.labelSm),
          color: T.textDim,
          fontSize: 9,
          marginLeft: 'auto',
        }}>{watch.format}</span>
      </div>
      <IconBtn icon={IconMoreV} size={18} />
    </div>
  );
}

// ===== Device header (right of sidebar, above watches) =====
function DeviceHeader({ device }) {
  const s = device.status;
  return (
    <div style={{
      background: T.bg2,
      borderBottom: `1px solid ${T.border}`,
      padding: '12px 16px',
      display: 'flex', alignItems: 'flex-start', gap: 16,
      flexShrink: 0,
    }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
          <span style={{ ...typeCSS(TY.display), color: T.text }}>{device.name}</span>
          <ConnIndicator status={s} mode="full" size={9} />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <TransportChip kind={device.transport} address={device.address} />
          {device.lastError && (
            <span style={{
              ...typeCSS(TY.caption),
              color: T.error,
              display: 'inline-flex', alignItems: 'center', gap: 5,
            }}>
              <IconErrorX size={11} color={T.error} />
              {device.lastError}
            </span>
          )}
        </div>
      </div>
      <div>
        {s === 'online' ? (
          <Btn kind="outline" icon={IconClose}>Disconnect</Btn>
        ) : s === 'connecting' ? (
          <Btn kind="secondary" disabled>Connecting…</Btn>
        ) : (
          <Btn kind="primary" icon={IconPollLive}>Connect</Btn>
        )}
      </div>
    </div>
  );
}

// ===== Watches toolbar =====
function WatchesToolbar({ count }) {
  return (
    <div style={{
      height: 36,
      background: T.bg2,
      borderBottom: `1px solid ${T.border}`,
      padding: '0 12px',
      display: 'flex', alignItems: 'center', gap: 8,
      flexShrink: 0,
    }}>
      <span style={{ ...typeCSS(TY.label), color: T.textMuted }}>WATCHES</span>
      <span style={{ ...typeCSS(TY.mono), color: T.text }}>{count}</span>
      <div style={{ width: 1, height: 16, background: T.border, margin: '0 6px' }}/>
      <IconBtn icon={IconCascade} title="Cascade" active />
      <IconBtn icon={IconTileRows} title="Tile rows" />
      <IconBtn icon={IconTileCols} title="Tile cols" />
      <IconBtn icon={IconGrid} title="Grid" />
      <div style={{ width: 1, height: 16, background: T.border, margin: '0 6px' }}/>
      <IconBtn icon={IconShowAll} title="Show all" />
      <IconBtn icon={IconCloseAll} title="Close all" />
      <IconBtn icon={IconReset} title="Reset counters" />
      <div style={{ flex: 1 }} />
      <Btn kind="secondary" size="sm" icon={IconAdd}>New watch</Btn>
    </div>
  );
}

// ===== Sample data — commissioning scenario =====
const DEVICES = [
  {
    id: 'plc-a',
    name: 'PLC-Line-A',
    status: 'online',
    transport: 'TCP',
    address: '192.168.1.10:502',
    expanded: true,
    watches: [
      { id: 'w1', fc: 'FC03', range: '100–109', format: 'UInt16' },
      { id: 'w2', fc: 'FC03', range: '200–203', format: 'Float32' },
      { id: 'w3', fc: 'FC01', range: '1–32',    format: 'Bool' },
      { id: 'w4', fc: 'FC04', range: '300–315', format: 'Hex' },
    ],
  },
  {
    id: 'drive',
    name: 'AC Drive',
    status: 'error',
    transport: 'TCP',
    address: '192.168.1.42:502',
    expanded: true,
    lastError: 'Modbus exception 02 — illegal data address',
    watches: [
      { id: 'w5', fc: 'FC03', range: '40001–40016', format: 'Binary' },
      { id: 'w6', fc: 'FC04', range: '30100–30109', format: 'UInt16' },
    ],
  },
  {
    id: 'meter',
    name: 'Energy Meter',
    status: 'online',
    transport: 'RTU',
    address: 'usbserial-A1042 @ 9600 8N1',
    expanded: false,
    watches: [
      { id: 'w7', fc: 'FC04', range: '30000–30031', format: 'Float32' },
    ],
  },
  {
    id: 'esp',
    name: 'ESP32 Sensor',
    status: 'connecting',
    transport: 'TCP',
    address: '192.168.1.88:502',
    expanded: false,
    watches: [
      { id: 'w8', fc: 'FC04', range: '0–7', format: 'Int16' },
    ],
  },
  {
    id: 'io',
    name: 'IO Module 16DI',
    status: 'offline',
    transport: 'RTU',
    address: 'COM3 @ 19200 8E1',
    expanded: false,
    watches: [
      { id: 'w9', fc: 'FC02', range: '10001–10016', format: 'Bool' },
    ],
  },
];

Object.assign(window, {
  TopToolbar, BrandMark, Sidebar, DeviceRow, WatchRow,
  DeviceHeader, WatchesToolbar, DEVICES,
});
