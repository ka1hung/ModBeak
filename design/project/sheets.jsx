// Auxiliary sheets — tokens display, icon sheet, app icon grid, component states

// ===== Color token sheet =====
function TokenSheet() {
  const groups = [
    {
      title: 'SURFACES', tokens: [
        { name: 'bg0', val: T.bg0, note: 'App shell' },
        { name: 'bg1', val: T.bg1, note: 'Workspace' },
        { name: 'bg2', val: T.bg2, note: 'Sidebar / pane' },
        { name: 'bg3', val: T.bg3, note: 'Header / raised' },
        { name: 'bg4', val: T.bg4, note: 'Hover' },
        { name: 'bgSelected', val: T.bgSelected, note: 'Selected row' },
      ],
    },
    {
      title: 'BORDERS', tokens: [
        { name: 'borderFaint', val: T.borderFaint },
        { name: 'border', val: T.border },
        { name: 'borderStrong', val: T.borderStrong },
      ],
    },
    {
      title: 'TEXT', tokens: [
        { name: 'text', val: T.text, note: 'Primary' },
        { name: 'textMuted', val: T.textMuted, note: 'Secondary' },
        { name: 'textDim', val: T.textDim, note: 'Tertiary / address' },
        { name: 'textFaint', val: T.textFaint, note: 'Disabled' },
      ],
    },
    {
      title: 'ACCENT', tokens: [
        { name: 'accent', val: T.accent, note: 'Selection / focus' },
        { name: 'accentDim', val: T.accentDim, note: 'Pressed' },
        { name: 'accentBg', val: T.accentBg, note: 'Selected bg' },
      ],
    },
    {
      title: 'STATUS', tokens: [
        { name: 'online', val: T.online, note: 'Solid circle' },
        { name: 'connecting', val: T.connecting, note: 'Dashed ring' },
        { name: 'error', val: T.error, note: 'Solid square' },
        { name: 'offline', val: T.offline, note: 'Outlined circle' },
        { name: 'tx', val: T.tx, note: 'TX + ▲' },
        { name: 'rx', val: T.rx, note: 'RX + ▼' },
      ],
    },
    {
      title: 'FORMAT', tokens: [
        { name: 'fmtNum', val: T.fmtNum },
        { name: 'fmtHex', val: T.fmtHex },
        { name: 'fmtBin', val: T.fmtBin },
        { name: 'fmtFloat', val: T.fmtFloat },
        { name: 'fmtAscii', val: T.fmtAscii },
        { name: 'fmtBool', val: T.fmtBool },
      ],
    },
  ];
  return (
    <div style={{ padding: 24, background: T.bg1, color: T.text, width: 920, fontFamily: FONT_SANS }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 24 }}>
        {groups.map(g => (
          <div key={g.title}>
            <div style={{ ...typeCSS(TY.label), color: T.textDim, marginBottom: 8 }}>{g.title}</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {g.tokens.map(t => (
                <div key={t.name} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: 28, height: 22, background: t.val, border: `1px solid ${T.borderFaint}`, borderRadius: R.sm }}/>
                  <div style={{ ...typeCSS(TY.mono), color: T.text, minWidth: 96 }}>{t.name}</div>
                  <div style={{ ...typeCSS(TY.monoSm), color: T.textDim, minWidth: 70 }}>{t.val}</div>
                  {t.note && <div style={{ ...typeCSS(TY.caption), color: T.textMuted }}>{t.note}</div>}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Type scale */}
      <div style={{ marginTop: 32 }}>
        <div style={{ ...typeCSS(TY.label), color: T.textDim, marginBottom: 12 }}>TYPE SCALE</div>
        <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: '8px 16px', alignItems: 'baseline' }}>
          {[
            ['display 22 / 600', TY.display, 'PLC-Line-A'],
            ['h1 17 / 600', TY.h1, 'Add Device'],
            ['h2 14 / 600', TY.h2, 'Section heading'],
            ['body 13 / 400', TY.body, 'Connection refused: 192.168.1.42:502'],
            ['bodySm 12 / 400', TY.bodySm, 'No watches on this device yet.'],
            ['label 11 / 600 +0.08em', TY.label, 'WATCHES'],
            ['labelSm 10 / 600 +0.1em', TY.labelSm, 'TCP'],
            ['caption 11 / 400', TY.caption, 'optional, defaults to host:port'],
            ['monoLg 14 / 500', TY.monoLg, '0x1234  ·  3.14159'],
            ['mono 12 / 500', TY.mono, '192.168.1.10:502  ·  FC03'],
            ['monoSm 11 / 500', TY.monoSm, '00 01 00 00 00 06 01 03 00 64'],
            ['monoAddr 11 / 400', TY.monoAddr, '40001  40002  40003'],
          ].map(([label, t, sample]) => (
            <React.Fragment key={label}>
              <span style={{ ...typeCSS(TY.caption), color: T.textDim }}>{label}</span>
              <span style={{ ...typeCSS(t), color: T.text }}>{sample}</span>
            </React.Fragment>
          ))}
        </div>
      </div>
    </div>
  );
}

// ===== Icon sheet =====
function IconSheet() {
  const sections = [
    { title: 'Connection status (special — used at 6–8 px)', custom: 'status' },
    { title: 'Transport', icons: [
      { c: IconTCP, n: 'tcp' }, { c: IconRTU, n: 'rtu' }, { c: IconUSB, n: 'usb-serial' },
    ]},
    { title: 'Modbus FC', icons: [
      { c: IconFC01, n: 'fc01-coil' }, { c: IconFC02, n: 'fc02-discrete-input' },
      { c: IconFC03, n: 'fc03-holding-reg' }, { c: IconFC04, n: 'fc04-input-reg' },
    ]},
    { title: 'Window chrome', icons: [
      { c: IconMinimise, n: 'minimise' }, { c: IconMaximise, n: 'maximise' },
      { c: IconRestore, n: 'restore' }, { c: IconClose, n: 'close' },
      { c: IconSplit, n: 'split' }, { c: IconDrag, n: 'drag-handle' }, { c: IconResize, n: 'resize-handle' },
    ]},
    { title: 'Layout', icons: [
      { c: IconCascade, n: 'cascade' }, { c: IconTileRows, n: 'tile-rows' },
      { c: IconTileCols, n: 'tile-cols' }, { c: IconGrid, n: 'grid' },
      { c: IconShowAll, n: 'show-all' }, { c: IconCloseAll, n: 'close-all' },
    ]},
    { title: 'Operations', icons: [
      { c: IconAdd, n: 'add' }, { c: IconEdit, n: 'edit' }, { c: IconRemove, n: 'remove' },
      { c: IconRefresh, n: 'refresh' }, { c: IconImport, n: 'import' }, { c: IconExport, n: 'export' },
      { c: IconReset, n: 'reset' }, { c: IconTest, n: 'test-connection' }, { c: IconClear, n: 'clear' },
    ]},
    { title: 'Tree', icons: [
      { c: IconExpandRight, n: 'expand-right' }, { c: IconExpandDown, n: 'expand-down' },
      { c: IconMoreV, n: 'more-v' }, { c: IconMoreH, n: 'more-h' },
    ]},
    { title: 'Direction', icons: [
      { c: IconTX, n: 'tx-outgoing' }, { c: IconRX, n: 'rx-incoming' },
    ]},
    { title: 'Status glyphs', icons: [
      { c: IconCheck, n: 'success' }, { c: IconWarning, n: 'warning' },
      { c: IconErrorX, n: 'error' }, { c: IconInfo, n: 'info' },
    ]},
    { title: 'Polling', icons: [
      { c: IconPollLive, n: 'live' }, { c: IconPollPause, n: 'paused' },
    ]},
    { title: 'Format hint', icons: [
      { c: IconFmtNum, n: 'numeric' }, { c: IconFmtHex, n: 'hex' },
      { c: IconFmtBin, n: 'binary' }, { c: IconFmtFloat, n: 'float' },
      { c: IconFmtAscii, n: 'ascii' }, { c: IconFmtBool, n: 'bool' },
    ]},
  ];
  return (
    <div style={{ padding: 24, background: T.bg1, width: 920, color: T.text, fontFamily: FONT_SANS }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>
        {sections.map(s => (
          <div key={s.title}>
            <div style={{ ...typeCSS(TY.label), color: T.textDim, marginBottom: 10 }}>{s.title}</div>
            {s.custom === 'status' ? (
              <div style={{ display: 'flex', gap: 18 }}>
                {['online', 'connecting', 'error', 'offline'].map(st => (
                  <div key={st} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, minWidth: 90 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, height: 24 }}>
                      <StatusDot status={st} size={6} />
                      <StatusDot status={st} size={8} />
                      <StatusDot status={st} size={12} />
                      <StatusDot status={st} size={16} />
                    </div>
                    <span style={{ ...typeCSS(TY.monoSm), color: T.textMuted }}>{st}</span>
                  </div>
                ))}
              </div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 12 }}>
                {s.icons.map(i => {
                  const Ic = i.c;
                  return (
                    <div key={i.n} style={{
                      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
                      padding: 10,
                      background: T.bg2,
                      border: `1px solid ${T.borderFaint}`,
                      borderRadius: R.sm,
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <Ic size={14} color={T.textMuted} />
                        <Ic size={20} color={T.text} />
                      </div>
                      <span style={{ ...typeCSS(TY.monoSm), color: T.textDim, fontSize: 10 }}>{i.n}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ===== App icon variants =====
function AppIconSheet() {
  return (
    <div style={{ padding: 24, background: T.bg1, width: 760, color: T.text, fontFamily: FONT_SANS }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 28 }}>
        <Variant label="Square (Windows / Linux)" cornerRadius={0} />
        <Variant label="Rounded square (Android / Web)" cornerRadius={0.12} />
        <Variant label="macOS rounded rect" cornerRadius={0.225} />

        <div>
          <div style={{ ...typeCSS(TY.label), color: T.textDim, marginBottom: 12 }}>SIZE GRID — readable at 16 px</div>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 22 }}>
            {[16, 32, 64, 128, 256].map(s => (
              <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <AppIcon size={s} cornerRadius={0.225} />
                <span style={{ ...typeCSS(TY.monoSm), color: T.textDim }}>{s}px</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Variant({ label, cornerRadius }) {
  return (
    <div>
      <div style={{ ...typeCSS(TY.label), color: T.textDim, marginBottom: 12 }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
        <AppIcon size={128} cornerRadius={cornerRadius} />
        <AppIcon size={64} cornerRadius={cornerRadius} />
        <AppIcon size={32} cornerRadius={cornerRadius} />
        <AppIcon size={16} cornerRadius={cornerRadius} />
      </div>
    </div>
  );
}

function AppIcon({ size = 128, cornerRadius = 0.225 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100">
      <defs>
        <linearGradient id={`bg-${size}-${cornerRadius}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#1f2932"/>
          <stop offset="1" stopColor="#0a0f14"/>
        </linearGradient>
      </defs>
      <rect width="100" height="100" rx={cornerRadius * 100} fill={`url(#bg-${size}-${cornerRadius})`} stroke="#2a3540" strokeWidth="0.5"/>

      {/* Cockatiel head, scaled + centered — readable down to 16px */}
      <g transform="translate(8 12) scale(0.84)">
        {/* Crest */}
        <path d="M 56 24 L 74 6 L 64 32 Z" fill="#fad65b"/>
        <path d="M 64 26 L 90 10 L 72 36 Z" fill="#f0c032"/>
        <path d="M 70 34 L 96 28 L 78 44 Z" fill="#d9a519"/>
        {/* Head */}
        <path d="M 30 50 C 30 30, 44 22, 56 22 C 72 22, 82 34, 82 52 C 82 72, 70 84, 54 84 C 38 84, 28 74, 28 62 L 28 56 Z" fill="#fce088"/>
        {/* Cheek */}
        <circle cx="44" cy="63" r="11" fill="#ff7c3d"/>
        {/* Eye */}
        <circle cx="42" cy="46" r="4" fill="#1a0f08"/>
        {size >= 32 && <circle cx="43.2" cy="44.8" r="1.2" fill="#ffffff"/>}
        {/* Beak */}
        <path d="M 28 50 Q 14 56, 14 66 Q 16 71, 24 70 Q 30 66, 32 60 Z" fill="#2a1810"/>
      </g>

      {/* Connection LED dot — only at large sizes */}
      {size >= 64 && <circle cx="86" cy="86" r="5" fill={T.online} stroke="#0a0f14" strokeWidth="1.5"/>}
    </svg>
  );
}

// ===== Component states matrix =====
function StatesSheet() {
  return (
    <div style={{ padding: 24, background: T.bg1, width: 1080, color: T.text, fontFamily: FONT_SANS }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 28 }}>

        {/* Connection indicator — 4 states × 2 modes */}
        <StateGroup title="Connection indicator — colour-blind safe via shape + colour">
          <StateCol label="Dot only (6–8 px)">
            <Row>
              <StatusDot status="online" size={8} /><Lab>online · solid circle</Lab>
            </Row>
            <Row>
              <StatusDot status="connecting" size={8} /><Lab>connecting · dashed ring</Lab>
            </Row>
            <Row>
              <StatusDot status="error" size={8} /><Lab>error · solid SQUARE</Lab>
            </Row>
            <Row>
              <StatusDot status="offline" size={8} /><Lab>offline · empty circle</Lab>
            </Row>
          </StateCol>
          <StateCol label="Dot + label (device header)">
            <Row><ConnIndicator status="online" mode="full" /></Row>
            <Row><ConnIndicator status="connecting" mode="full" /></Row>
            <Row><ConnIndicator status="error" mode="full" /></Row>
            <Row><ConnIndicator status="offline" mode="full" /></Row>
          </StateCol>
        </StateGroup>

        {/* Bool pill */}
        <StateGroup title="Bool pill (FC01 / FC02 cell)">
          <Row gap={10}>
            <Col><BoolPill value={true} /><Lab>live · true</Lab></Col>
            <Col><BoolPill value={false} /><Lab>live · false</Lab></Col>
            <Col><BoolPill value={true} pending /><Lab>writing (optimistic)</Lab></Col>
            <Col><BoolPill value={true} big /><Lab>touch density</Lab></Col>
          </Row>
        </StateGroup>

        {/* Buttons */}
        <StateGroup title="Buttons">
          <Row gap={8}>
            <Btn kind="primary" icon={IconAdd}>Device</Btn>
            <Btn kind="secondary" icon={IconAdd}>Watch</Btn>
            <Btn kind="outline">Test</Btn>
            <Btn kind="ghost" icon={IconImport}>Import</Btn>
            <Btn danger icon={IconRemove}>Remove</Btn>
            <Btn kind="primary" disabled>Connecting…</Btn>
          </Row>
        </StateGroup>

        {/* Sidebar row states */}
        <StateGroup title="Sidebar device row states">
          <div style={{ width: 260, background: T.bg2, padding: 4, borderRadius: R.sm }}>
            <DeviceRow device={{ id:'1', name:'PLC-Line-A', status:'online', transport:'TCP', address:'192.168.1.10:502', expanded: false }} selected />
            <DeviceRow device={{ id:'2', name:'AC Drive', status:'error', transport:'TCP', address:'192.168.1.42:502', expanded: false }} />
            <DeviceRow device={{ id:'3', name:'ESP32 Sensor', status:'connecting', transport:'TCP', address:'192.168.1.88:502', expanded: false }} />
            <DeviceRow device={{ id:'4', name:'IO Module 16DI', status:'offline', transport:'RTU', address:'COM3 @ 19200 8E1', expanded: false }} />
          </div>
        </StateGroup>

        {/* Empty states */}
        <StateGroup title="Empty state — three densities (tiny / compact / full)">
          <Row gap={12}>
            <div style={{ width: 200, height: 100, border: `1px solid ${T.border}`, borderRadius: R.sm, display: 'flex' }}>
              <EmptyState density="tiny" title="No data yet" />
            </div>
            <div style={{ width: 280, height: 160, border: `1px solid ${T.border}`, borderRadius: R.sm, display: 'flex' }}>
              <EmptyState density="compact" title="Waiting for first poll…" icon={IconPollLive} />
            </div>
            <div style={{ width: 360, height: 220, border: `1px solid ${T.border}`, borderRadius: R.sm, display: 'flex' }}>
              <EmptyState density="full" icon={IconAdd} title="No watches on this device yet" hint='Click "+ New watch" to start polling registers or coils.' />
            </div>
          </Row>
        </StateGroup>

        {/* Cell error / writing / waiting */}
        <StateGroup title="Cell states (Table view)">
          <div style={{ display: 'flex', gap: 14 }}>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <Lab>live</Lab>
              <MiniCell addr="100" val="4631" />
              <MiniCell addr="101" val="0x1A2C" mono />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <Lab>error (read failed)</Lab>
              <MiniCell addr="100" val="ERR" error />
              <MiniCell addr="101" val="ERR" error />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <Lab>writing (optimistic)</Lab>
              <MiniCell addr="100" val="9999" writing />
              <MiniCell addr="101" val="0x1A2C" mono />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <Lab>waiting for first poll</Lab>
              <MiniCell addr="100" val="—" muted />
              <MiniCell addr="101" val="—" muted />
            </div>
          </div>
        </StateGroup>
      </div>
    </div>
  );
}

function StateGroup({ title, children }) {
  return (
    <div>
      <div style={{ ...typeCSS(TY.label), color: T.textDim, marginBottom: 12 }}>{title}</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 24 }}>{children}</div>
    </div>
  );
}
function StateCol({ label, children }) {
  return (
    <div>
      <div style={{ ...typeCSS(TY.caption), color: T.textDim, marginBottom: 8 }}>{label}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>{children}</div>
    </div>
  );
}
function Row({ children, gap = 12 }) {
  return <div style={{ display: 'flex', alignItems: 'center', gap }}>{children}</div>;
}
function Col({ children }) {
  return <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 4 }}>{children}</div>;
}
function Lab({ children }) {
  return <span style={{ ...typeCSS(TY.caption), color: T.textDim }}>{children}</span>;
}
function MiniCell({ addr, val, error, writing, muted, mono }) {
  return (
    <div style={{
      width: 130, height: 22, display: 'flex', alignItems: 'center', gap: 8,
      padding: '0 8px',
      background: error ? T.errorBg : 'transparent',
      borderLeft: `1px solid ${T.borderFaint}`,
      opacity: writing ? 0.5 : 1,
    }}>
      <span style={{ ...typeCSS(TY.monoAddr), color: error ? T.error : T.textDim, fontSize: 10 }}>{addr}</span>
      <span style={{ ...typeCSS(TY.mono), color: error ? T.error : (muted ? T.textDim : T.text), flex: 1, textAlign: 'right' }}>{val}</span>
    </div>
  );
}

Object.assign(window, { TokenSheet, IconSheet, AppIconSheet, StatesSheet });
