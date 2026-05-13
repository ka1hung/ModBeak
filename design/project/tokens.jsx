// Design tokens for mbtool — dark industrial palette
// Colour-blind safe via shape + colour double-encoding

const T = {
  // Backgrounds — layered from deepest to surface
  bg0: '#0a0f14',        // app shell, behind everything
  bg1: '#0d1419',        // workspace
  bg2: '#151c23',        // sidebar, pane body
  bg3: '#1c242c',        // pane header, raised
  bg4: '#252f38',        // hover
  bgSelected: '#13303d', // selected row tint (cyan-tinted)

  // Borders / dividers
  border: '#2a3540',
  borderStrong: '#3a4754',
  borderFaint: '#1f2832',

  // Text
  text: '#e6edf3',
  textMuted: '#8b98a5',
  textDim: '#5a6675',
  textFaint: '#3f4a55',

  // Brand accent (selection / focus / active)
  accent: '#39bae6',
  accentDim: '#2a8fb3',
  accentBg: '#13303d',

  // Status — paired with SHAPE so colour-blind users still read it
  online:     '#aad94c',  // lime, solid circle
  onlineDim:  '#7ba534',
  onlineBg:   '#1f2a14',

  connecting: '#ffb454',  // amber, dashed ring (animated)
  connectingDim: '#c4862f',
  connectingBg: '#2a1f0e',

  error:      '#f07178',  // coral, solid SQUARE (different shape)
  errorDim:   '#b8454c',
  errorBg:    '#2a141a',

  offline:    '#5a6675',  // gray, outlined circle
  offlineBg:  '#1a2028',

  warn:       '#ffb454',  // same as connecting, but used for CONN-tag errors
  warnBg:     '#2a1f0e',

  // TX / RX direction — colour + arrow glyph double-encoded
  tx:         '#ffb454',  // amber outgoing
  rx:         '#39bae6',  // cyan incoming

  // Format hint accents (small chips)
  fmtNum:     '#aad94c',
  fmtHex:     '#39bae6',
  fmtBin:     '#c39bf0',
  fmtFloat:   '#ffb454',
  fmtAscii:   '#7cd1c0',
  fmtBool:    '#f07178',

  // Contrasting text for elements sitting on bright status / accent fills
  onAccent:   '#06121a',  // dark text on bright cyan
  onOnline:   '#0d1419',  // dark text on bright lime pill
  onError:    '#0d0809',  // dark text on coral badge
};

// Typography
const FONT_SANS = "'IBM Plex Sans', 'Inter', system-ui, -apple-system, sans-serif";
const FONT_MONO = "'IBM Plex Mono', 'JetBrains Mono', 'SF Mono', Consolas, monospace";

const TY = {
  // Sans
  display:   { font: FONT_SANS, size: 22, weight: 600, lh: 1.2, ls: '-0.01em' },
  h1:        { font: FONT_SANS, size: 17, weight: 600, lh: 1.25, ls: '-0.005em' },
  h2:        { font: FONT_SANS, size: 14, weight: 600, lh: 1.3 },
  body:      { font: FONT_SANS, size: 13, weight: 400, lh: 1.45 },
  bodySm:    { font: FONT_SANS, size: 12, weight: 400, lh: 1.4 },
  label:     { font: FONT_SANS, size: 11, weight: 600, lh: 1.2, ls: '0.08em', uppercase: true },
  labelSm:   { font: FONT_SANS, size: 10, weight: 600, lh: 1.2, ls: '0.1em', uppercase: true },
  caption:   { font: FONT_SANS, size: 11, weight: 400, lh: 1.3 },

  // Mono — all values, addresses, hex
  monoLg:    { font: FONT_MONO, size: 14, weight: 500, lh: 1.2 },
  mono:      { font: FONT_MONO, size: 12, weight: 500, lh: 1.2 },
  monoSm:    { font: FONT_MONO, size: 11, weight: 500, lh: 1.2 },
  monoAddr:  { font: FONT_MONO, size: 11, weight: 400, lh: 1.2 }, // addresses (muted)
};

// Spacing scale
const S = { 0: 0, 1: 2, 2: 4, 3: 6, 4: 8, 5: 12, 6: 16, 7: 20, 8: 24, 9: 32, 10: 40, 12: 56 };

// Radius — sharp industrial, max 4
const R = { none: 0, sm: 2, md: 3, lg: 4, pill: 999 };

// Shadows — used sparingly for elevated panes
const SH = {
  none: 'none',
  pane: '0 8px 24px -6px rgba(0,0,0,0.6), 0 2px 6px rgba(0,0,0,0.4)',
  modal: '0 24px 60px -12px rgba(0,0,0,0.8), 0 4px 12px rgba(0,0,0,0.5)',
  focusRing: '0 0 0 2px #39bae6, 0 0 0 4px rgba(57,186,230,0.2)',
};

// Helper: typography to CSS object
function typeCSS(t) {
  return {
    fontFamily: t.font,
    fontSize: t.size,
    fontWeight: t.weight,
    lineHeight: t.lh,
    letterSpacing: t.ls,
    textTransform: t.uppercase ? 'uppercase' : 'none',
  };
}

Object.assign(window, { T, TY, S, R, SH, FONT_SANS, FONT_MONO, typeCSS });
