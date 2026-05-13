// Full 1440×900 commissioning scenario — main mockup

function FullAppMockup({ cellStyle = 'borderless', paneChrome = 'flat', txEncoding = 'color-arrow', density = 'tight', theme = 'dark', onToggleTheme }) {
  const elevated = paneChrome === 'elevated';
  return (
    <div style={{
      width: 1440, height: 900,
      background: T.bg1,
      display: 'flex', flexDirection: 'column',
      color: T.text,
      fontFamily: FONT_SANS,
      overflow: 'hidden',
    }}>
      <TopToolbar theme={theme} onToggleTheme={onToggleTheme} />
      <div style={{ flex: 1, display: 'flex', minHeight: 0 }}>
        <Sidebar devices={DEVICES} selectedDeviceId="plc-a" selectedWatchId="w1" />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <DeviceHeader device={DEVICES[0]} />
          <WatchesToolbar count={4} />
          <MDIWorkspace cellStyle={cellStyle} elevated={elevated} density={density} />
        </div>
      </div>
    </div>
  );
}

function MDIWorkspace({ cellStyle, elevated, density }) {
  // Cascade-ish layout with 3 active panes + 1 minimised
  return (
    <div style={{
      flex: 1, position: 'relative',
      background: T.bg1,
      backgroundImage: `radial-gradient(${T.borderFaint} 1px, transparent 1px)`,
      backgroundSize: '20px 20px',
      backgroundPosition: '-1px -1px',
      overflow: 'hidden',
    }}>
      {/* Pane 1 — Table view (active, focused) */}
      <div style={{ position: 'absolute', left: 16, top: 16, zIndex: 3 }}>
        <Pane width={460} height={320} elevated={elevated} active>
          <PaneHeader
            status="online"
            title="PLC-Line-A · FC03 · 100–131 · 500ms"
            tabs={[
              { id: 'table', label: 'TABLE' },
              { id: 'comm', label: 'COMM' },
              { id: 'errors', label: 'ERRORS' },
            ]}
            activeTab="table"
            actions={<>
              <IconBtn icon={IconEdit} size={20} title="Edit" />
              <IconBtn icon={IconSplit} size={20} title="Split" />
              <IconBtn icon={IconMinimise} size={20} title="Minimise" />
              <IconBtn icon={IconMaximise} size={20} title="Maximise" />
              <IconBtn icon={IconClose} size={20} title="Close" />
            </>}
          />
          <FormatBar format="UInt16" polling="live" />
          <TableView format="UInt16" cellStyle={cellStyle} density={density} startAddr={100} count={32} />
          <PaneFooter ok={1284} err={0} avg={13} />
        </Pane>
      </div>

      {/* Pane 2 — Comm view */}
      <div style={{ position: 'absolute', left: 500, top: 60, zIndex: 2 }}>
        <Pane width={520} height={340} elevated={elevated}>
          <PaneHeader
            status="online"
            title="PLC-Line-A · FC03 · 200–203 · 500ms"
            tabs={[
              { id: 'table', label: 'TABLE' },
              { id: 'comm', label: 'COMM' },
              { id: 'errors', label: 'ERRORS', badge: 1 },
            ]}
            activeTab="comm"
            actions={<>
              <IconBtn icon={IconEdit} size={20} />
              <IconBtn icon={IconSplit} size={20} />
              <IconBtn icon={IconMinimise} size={20} />
              <IconBtn icon={IconMaximise} size={20} />
              <IconBtn icon={IconClose} size={20} />
            </>}
          />
          <CommView />
          <PaneFooter ok={642} err={1} avg={14} lastError="exception 02 — illegal data address" />
        </Pane>
      </div>

      {/* Pane 3 — Bool table (coils) */}
      <div style={{ position: 'absolute', left: 60, top: 360, zIndex: 1 }}>
        <Pane width={420} height={220} elevated={elevated}>
          <PaneHeader
            status="online"
            title="PLC-Line-A · FC01 · 1–32 · 500ms"
            tabs={[
              { id: 'table', label: 'TABLE' },
              { id: 'comm', label: 'COMM' },
              { id: 'errors', label: 'ERRORS' },
            ]}
            activeTab="table"
            actions={<>
              <IconBtn icon={IconEdit} size={20} />
              <IconBtn icon={IconMinimise} size={20} />
              <IconBtn icon={IconMaximise} size={20} />
              <IconBtn icon={IconClose} size={20} />
            </>}
          />
          <FormatBar format="Bool" polling="live" locked />
          <TableView format="Bool" cellStyle={cellStyle} density={density} startAddr={1} count={32} writingAddrs={[5]} />
          <PaneFooter ok={1284} err={0} avg={11} />
        </Pane>
      </div>

      {/* Pane 4 — Errors view for AC Drive */}
      <div style={{ position: 'absolute', left: 540, top: 420, zIndex: 1 }}>
        <Pane width={460} height={160} elevated={elevated}>
          <PaneHeader
            status="error"
            title="AC Drive · FC03 · 40001–40016 · 1000ms"
            tabs={[
              { id: 'table', label: 'TABLE' },
              { id: 'comm', label: 'COMM' },
              { id: 'errors', label: 'ERRORS', badge: 6 },
            ]}
            activeTab="errors"
            actions={<>
              <IconBtn icon={IconEdit} size={20} />
              <IconBtn icon={IconMinimise} size={20} />
              <IconBtn icon={IconMaximise} size={20} />
              <IconBtn icon={IconClose} size={20} />
            </>}
          />
          <ErrorsView />
          <PaneFooter ok={42} err={6} avg={998} lastError="Connection refused: 192.168.1.42:502" />
        </Pane>
      </div>

      {/* Minimised strip */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        height: 28,
        background: T.bg3,
        borderTop: `1px solid ${T.border}`,
        display: 'flex', alignItems: 'center',
        padding: '0 8px', gap: 4,
      }}>
        <MinimisedTab title="FC04 · 300–315" status="online" />
        <MinimisedTab title="Energy Meter · FC04 · 30000–30031" status="online" />
        <span style={{ ...typeCSS(TY.caption), color: T.textDim, marginLeft: 8 }}>
          2 minimised
        </span>
      </div>
    </div>
  );
}

function MinimisedTab({ title, status }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      height: 20,
      padding: '0 8px',
      background: T.bg2,
      border: `1px solid ${T.border}`,
      borderRadius: R.sm,
    }}>
      <StatusDot status={status} size={6} />
      <span style={{ ...typeCSS(TY.monoSm), color: T.textMuted, fontSize: 10 }}>{title}</span>
      <IconBtn icon={IconClose} size={14} />
    </div>
  );
}

Object.assign(window, { FullAppMockup, MDIWorkspace, MinimisedTab });
