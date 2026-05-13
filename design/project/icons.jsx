// mbtool icon set — stroke-based industrial style, single weight, sharp corners
// All 20px viewBox, stroke=1.5, currentColor. Filled variants where noted.

const ICON_STROKE = 1.5;

// Wrapper component
function I({ children, size = 16, color = 'currentColor', style, title }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 20 20"
      fill="none"
      stroke={color}
      strokeWidth={ICON_STROKE}
      strokeLinecap="square"
      strokeLinejoin="miter"
      style={{ flexShrink: 0, display: 'block', ...style }}
      aria-label={title}
    >
      {children}
    </svg>
  );
}

// ===== CONNECTION STATUS DOTS (special — used at 6-8px) =====
// These are the "indicator widgets" — not generic icons
function StatusDot({ status = 'offline', size = 8, animated = true }) {
  const s = size;
  const half = s / 2;
  if (status === 'online') {
    // solid filled circle, lime
    return (
      <svg width={s} height={s} viewBox={`0 0 ${s} ${s}`} style={{ flexShrink: 0 }}>
        <circle cx={half} cy={half} r={half - 0.5} fill={T.online} />
      </svg>
    );
  }
  if (status === 'connecting') {
    // dashed ring, amber, animated rotation
    return (
      <svg width={s} height={s} viewBox={`0 0 ${s} ${s}`} style={{ flexShrink: 0 }}>
        <circle
          cx={half} cy={half} r={half - 1}
          fill="none" stroke={T.connecting} strokeWidth="1.5"
          strokeDasharray="2 1.5"
          style={animated ? { transformOrigin: 'center', animation: 'mbtoolSpin 1.2s linear infinite' } : {}}
        />
      </svg>
    );
  }
  if (status === 'error') {
    // SOLID SQUARE — different shape from online
    return (
      <svg width={s} height={s} viewBox={`0 0 ${s} ${s}`} style={{ flexShrink: 0 }}>
        <rect x="0.5" y="0.5" width={s - 1} height={s - 1} fill={T.error} />
      </svg>
    );
  }
  // offline — outlined empty circle, gray
  return (
    <svg width={s} height={s} viewBox={`0 0 ${s} ${s}`} style={{ flexShrink: 0 }}>
      <circle cx={half} cy={half} r={half - 1} fill="none" stroke={T.offline} strokeWidth="1.25" />
    </svg>
  );
}

// ===== TRANSPORT =====
const IconTCP = (p) => (
  <I {...p} title="TCP / Ethernet">
    <rect x="2" y="6" width="16" height="9" />
    <path d="M5 9h2M9 9h2M13 9h2M5 12h2M9 12h2M13 12h2" />
    <path d="M10 15v2" />
    <path d="M6 17h8" />
  </I>
);
const IconRTU = (p) => (
  <I {...p} title="RTU / Serial">
    <rect x="3" y="7" width="14" height="7" rx="0.5" />
    <circle cx="6" cy="10.5" r="0.6" fill="currentColor" />
    <circle cx="8" cy="10.5" r="0.6" fill="currentColor" />
    <circle cx="10" cy="10.5" r="0.6" fill="currentColor" />
    <circle cx="12" cy="10.5" r="0.6" fill="currentColor" />
    <circle cx="14" cy="10.5" r="0.6" fill="currentColor" />
    <path d="M10 4v3M7 5l3 2 3-2" />
  </I>
);
const IconUSB = (p) => (
  <I {...p} title="USB Serial">
    <circle cx="10" cy="3" r="1.5" />
    <path d="M10 4.5v11" />
    <path d="M10 8l-3 2v3" />
    <path d="M10 11l3-1.5v2.5" />
    <rect x="8" y="15" width="4" height="3" />
  </I>
);

// ===== MODBUS FC — custom glyphs =====
// FC01 Coil — wound spring/loop motif
const IconFC01 = (p) => (
  <I {...p} title="FC01 Coil">
    <path d="M3 6c0 0 1.5-2 3.5-2s3.5 2 3.5 2-1.5 2-3.5 2-3.5-2-3.5-2zm0 4c0 0 1.5-2 3.5-2s3.5 2 3.5 2-1.5 2-3.5 2-3.5-2-3.5-2zm0 4c0 0 1.5-2 3.5-2s3.5 2 3.5 2-1.5 2-3.5 2-3.5-2-3.5-2z" />
    <path d="M13 10h4M15 7v6" />
  </I>
);
// FC02 Discrete Input — arrow into bool slot
const IconFC02 = (p) => (
  <I {...p} title="FC02 Discrete Input">
    <path d="M2 10h6M5 7l3 3-3 3" />
    <rect x="10" y="7" width="7" height="6" />
    <path d="M12 10h3" />
  </I>
);
// FC03 Holding Register — stacked register rows (read/write)
const IconFC03 = (p) => (
  <I {...p} title="FC03 Holding Register">
    <rect x="2.5" y="3.5" width="15" height="13" />
    <path d="M2.5 7.5h15M2.5 11.5h15" />
    <path d="M6 5.5h2M12 5.5h3M6 9.5h3M12 9.5h2M6 13.5h2M12 13.5h3" />
  </I>
);
// FC04 Input Register — arrow into stacked rows
const IconFC04 = (p) => (
  <I {...p} title="FC04 Input Register">
    <path d="M2 10h3M3.5 8.5l1.5 1.5-1.5 1.5" />
    <rect x="6.5" y="3.5" width="11" height="13" />
    <path d="M6.5 7.5h11M6.5 11.5h11" />
    <path d="M9 5.5h2M14 5.5h2M9 9.5h2M14 9.5h2M9 13.5h2M14 13.5h2" />
  </I>
);

// ===== WINDOW CHROME =====
const IconMinimise = (p) => <I {...p} title="Minimise"><path d="M4 14h12" /></I>;
const IconMaximise = (p) => <I {...p} title="Maximise"><rect x="4" y="4" width="12" height="12" /></I>;
const IconRestore  = (p) => (
  <I {...p} title="Restore">
    <rect x="3" y="6" width="11" height="11" />
    <path d="M6 6V3h11v11h-3" />
  </I>
);
const IconClose    = (p) => <I {...p} title="Close"><path d="M5 5l10 10M15 5L5 15" /></I>;
const IconSplit    = (p) => (
  <I {...p} title="Split">
    <rect x="3" y="3" width="14" height="14" />
    <path d="M10 3v14" />
  </I>
);
const IconDrag     = (p) => (
  <I {...p} title="Drag">
    <circle cx="7" cy="5" r="0.8" fill="currentColor" />
    <circle cx="13" cy="5" r="0.8" fill="currentColor" />
    <circle cx="7" cy="10" r="0.8" fill="currentColor" />
    <circle cx="13" cy="10" r="0.8" fill="currentColor" />
    <circle cx="7" cy="15" r="0.8" fill="currentColor" />
    <circle cx="13" cy="15" r="0.8" fill="currentColor" />
  </I>
);
const IconResize   = (p) => (
  <I {...p} title="Resize">
    <path d="M16 8v8h-8M16 12l-4 4M16 16l-8-8" strokeWidth="1.25" />
  </I>
);

// ===== LAYOUT =====
const IconCascade = (p) => (
  <I {...p} title="Cascade">
    <rect x="3" y="3" width="10" height="8" />
    <rect x="7" y="7" width="10" height="8" />
  </I>
);
const IconTileRows = (p) => (
  <I {...p} title="Tile rows">
    <rect x="3" y="3" width="14" height="6" />
    <rect x="3" y="11" width="14" height="6" />
  </I>
);
const IconTileCols = (p) => (
  <I {...p} title="Tile cols">
    <rect x="3" y="3" width="6" height="14" />
    <rect x="11" y="3" width="6" height="14" />
  </I>
);
const IconGrid = (p) => (
  <I {...p} title="Grid">
    <rect x="3" y="3" width="6" height="6" />
    <rect x="11" y="3" width="6" height="6" />
    <rect x="3" y="11" width="6" height="6" />
    <rect x="11" y="11" width="6" height="6" />
  </I>
);
const IconShowAll = (p) => (
  <I {...p} title="Show all">
    <rect x="3" y="3" width="14" height="14" />
    <path d="M7 7h6v6H7z" fill="currentColor" stroke="none" opacity="0.3" />
    <path d="M7 7h6v6H7z" />
  </I>
);
const IconCloseAll = (p) => (
  <I {...p} title="Close all">
    <rect x="3" y="3" width="10" height="10" />
    <rect x="7" y="7" width="10" height="10" />
    <path d="M14 14l-6-6M14 8l-6 6" strokeWidth="1.25" />
  </I>
);

// ===== OPERATIONS =====
const IconAdd       = (p) => <I {...p} title="Add"><path d="M10 4v12M4 10h12" /></I>;
const IconEdit      = (p) => <I {...p} title="Edit"><path d="M3 17l4-1 10-10-3-3L4 13l-1 4z" /><path d="M12 5l3 3" /></I>;
const IconRemove    = (p) => <I {...p} title="Remove"><path d="M3 6h14M8 3h4M5 6l1 11h8l1-11" /><path d="M9 9v6M11 9v6" /></I>;
const IconRefresh   = (p) => <I {...p} title="Refresh"><path d="M3 10a7 7 0 0 1 12-5l2 2M17 4v3h-3M17 10a7 7 0 0 1-12 5l-2-2M3 16v-3h3" /></I>;
const IconImport    = (p) => <I {...p} title="Import"><path d="M10 3v10M6 9l4 4 4-4M3 16h14" /></I>;
const IconExport    = (p) => <I {...p} title="Export"><path d="M10 14V4M6 8l4-4 4 4M3 16h14" /></I>;
const IconReset     = (p) => <I {...p} title="Reset"><path d="M4 4h12v12H4z" /><path d="M7 10h6M10 7v6" /></I>;
const IconTest      = (p) => <I {...p} title="Test"><path d="M3 10l3 3 8-8M14 13l2 2 2-2" /></I>;
const IconClear     = (p) => <I {...p} title="Clear"><path d="M4 4l12 12M16 4L4 16" /></I>;

// ===== TREE =====
const IconExpandRight = (p) => <I {...p} title="Expand right"><path d="M7 5l5 5-5 5" /></I>;
const IconExpandDown  = (p) => <I {...p} title="Expand down"><path d="M5 7l5 5 5-5" /></I>;
const IconMoreV       = (p) => (
  <I {...p} title="More">
    <circle cx="10" cy="5" r="1" fill="currentColor" stroke="none" />
    <circle cx="10" cy="10" r="1" fill="currentColor" stroke="none" />
    <circle cx="10" cy="15" r="1" fill="currentColor" stroke="none" />
  </I>
);
const IconMoreH = (p) => (
  <I {...p} title="More">
    <circle cx="5" cy="10" r="1" fill="currentColor" stroke="none" />
    <circle cx="10" cy="10" r="1" fill="currentColor" stroke="none" />
    <circle cx="15" cy="10" r="1" fill="currentColor" stroke="none" />
  </I>
);

// ===== DIRECTION (TX / RX) =====
const IconTX = (p) => (
  <I {...p} title="TX">
    <path d="M10 16V4M5 9l5-5 5 5" />
  </I>
);
const IconRX = (p) => (
  <I {...p} title="RX">
    <path d="M10 4v12M5 11l5 5 5-5" />
  </I>
);

// ===== STATUS GLYPHS =====
const IconCheck   = (p) => <I {...p} title="Success"><path d="M4 10l4 4 8-8" /></I>;
const IconWarning = (p) => <I {...p} title="Warning"><path d="M10 3l8 14H2z" /><path d="M10 8v4M10 14.5v0.5" /></I>;
const IconErrorX  = (p) => <I {...p} title="Error"><path d="M5 5l10 10M15 5L5 15" /></I>;
const IconInfo    = (p) => <I {...p} title="Info"><circle cx="10" cy="10" r="7" /><path d="M10 9v5M10 6v1" /></I>;

// ===== POLLING =====
const IconPollLive = (p) => (
  <I {...p} title="Live">
    <circle cx="10" cy="10" r="2.5" fill="currentColor" stroke="none" />
    <circle cx="10" cy="10" r="5.5" opacity="0.6" />
    <circle cx="10" cy="10" r="8" opacity="0.3" />
  </I>
);
const IconPollPause = (p) => (
  <I {...p} title="Paused">
    <rect x="6" y="5" width="2.5" height="10" fill="currentColor" stroke="none" />
    <rect x="11.5" y="5" width="2.5" height="10" fill="currentColor" stroke="none" />
  </I>
);

// ===== FORMAT HINT (small inline) =====
const IconFmtNum   = (p) => <I {...p} title="Numeric"><path d="M5 6h10M5 14h10M8 3l-2 14M14 3l-2 14" /></I>;
const IconFmtHex   = (p) => <I {...p} title="Hex"><path d="M5 14V6M5 6l4 4-4 4M11 6v8h4M11 10h3" /></I>;
const IconFmtBin   = (p) => <I {...p} title="Binary"><path d="M5 14V6h2v4H5M5 10h2M11 6h3v8h-3z" /></I>;
const IconFmtFloat = (p) => <I {...p} title="Float"><path d="M3 14l4-8 3 6 3-4 4 6" /></I>;
const IconFmtAscii = (p) => <I {...p} title="ASCII"><path d="M4 14V8a2 2 0 0 1 4 0v6M4 11h4M12 8h3v6M12 11h3" /></I>;
const IconFmtBool  = (p) => <I {...p} title="Bool"><rect x="3" y="6" width="14" height="8" rx="4" /><circle cx="7" cy="10" r="2" fill="currentColor" stroke="none" /></I>;

// Sun / Moon — theme toggle
const IconSun = (p) => <I {...p} title="Light theme"><circle cx="10" cy="10" r="3.5" /><path d="M10 2v2M10 16v2M2 10h2M16 10h2M4.2 4.2l1.4 1.4M14.4 14.4l1.4 1.4M4.2 15.8l1.4-1.4M14.4 5.6l1.4-1.4" /></I>;
const IconMoon = (p) => <I {...p} title="Dark theme"><path d="M16 11.5A6 6 0 0 1 8.5 4a6 6 0 1 0 7.5 7.5z" /></I>;

Object.assign(window, {
  I, StatusDot,
  IconTCP, IconRTU, IconUSB,
  IconFC01, IconFC02, IconFC03, IconFC04,
  IconMinimise, IconMaximise, IconRestore, IconClose, IconSplit, IconDrag, IconResize,
  IconCascade, IconTileRows, IconTileCols, IconGrid, IconShowAll, IconCloseAll,
  IconAdd, IconEdit, IconRemove, IconRefresh, IconImport, IconExport, IconReset, IconTest, IconClear,
  IconExpandRight, IconExpandDown, IconMoreV, IconMoreH,
  IconTX, IconRX,
  IconCheck, IconWarning, IconErrorX, IconInfo,
  IconPollLive, IconPollPause,
  IconFmtNum, IconFmtHex, IconFmtBin, IconFmtFloat, IconFmtAscii, IconFmtBool,
  IconSun, IconMoon,
});
