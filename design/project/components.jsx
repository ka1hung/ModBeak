// Shared mbtool widgets

// ===== Connection indicator (dot + optional label) =====
function ConnIndicator({ status = 'offline', mode = 'dot', size = 8 }) {
  const labels = { offline: 'OFFLINE', connecting: 'CONNECTING', online: 'ONLINE', error: 'ERROR' };
  const colors = { offline: T.offline, connecting: T.connecting, online: T.online, error: T.error };
  if (mode === 'dot') return <StatusDot status={status} size={size} />;
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
      <StatusDot status={status} size={size} />
      <span style={{
        ...typeCSS(TY.labelSm),
        color: colors[status],
        fontVariantNumeric: 'tabular-nums',
      }}>{labels[status]}</span>
    </div>
  );
}

// ===== Transport chip =====
function TransportChip({ kind = 'TCP', address }) {
  const Icon = kind === 'TCP' ? IconTCP : IconRTU;
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '2px 6px',
      border: `1px solid ${T.border}`,
      background: T.bg2,
      borderRadius: R.sm,
      color: T.textMuted,
    }}>
      <Icon size={12} color={T.textMuted} />
      <span style={{ ...typeCSS(TY.labelSm), color: T.text }}>{kind}</span>
      {address && (
        <span style={{ ...typeCSS(TY.monoSm), color: T.textMuted, marginLeft: 2 }}>{address}</span>
      )}
    </div>
  );
}

// ===== FC chip =====
function FCChip({ fc = 'FC03', size = 'sm' }) {
  const map = {
    FC01: { label: 'FC01', icon: IconFC01, name: 'Coil', tint: T.fmtBool },
    FC02: { label: 'FC02', icon: IconFC02, name: 'Discrete', tint: T.fmtBool },
    FC03: { label: 'FC03', icon: IconFC03, name: 'Holding', tint: T.accent },
    FC04: { label: 'FC04', icon: IconFC04, name: 'Input', tint: T.fmtFloat },
  };
  const m = map[fc];
  const Ic = m.icon;
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: size === 'sm' ? '1px 5px' : '3px 7px',
      border: `1px solid ${T.border}`,
      background: 'transparent',
      borderRadius: R.sm,
    }}>
      <Ic size={11} color={m.tint} />
      <span style={{ ...typeCSS(TY.labelSm), color: T.text }}>{m.label}</span>
    </div>
  );
}

// ===== Format chip =====
function FormatChip({ fmt = 'UInt16' }) {
  return (
    <span style={{
      ...typeCSS(TY.labelSm),
      color: T.textMuted,
      padding: '1px 5px',
      border: `1px solid ${T.borderFaint}`,
      borderRadius: R.sm,
      letterSpacing: '0.04em',
    }}>{fmt}</span>
  );
}

// ===== Button =====
function Btn({ children, kind = 'ghost', size = 'md', icon: Icon, danger, disabled, active, onClick, style = {} }) {
  const sizes = {
    sm: { h: 22, px: 8, gap: 4, font: TY.labelSm, iconSize: 12 },
    md: { h: 28, px: 12, gap: 6, font: TY.label, iconSize: 14 },
    lg: { h: 34, px: 16, gap: 8, font: TY.h2, iconSize: 16 },
  };
  const sz = sizes[size];
  const kinds = {
    primary: { bg: T.accent, fg: T.onAccent, border: T.accent, hover: T.accentDim },
    secondary: { bg: T.bg3, fg: T.text, border: T.borderStrong, hover: T.bg4 },
    ghost: { bg: 'transparent', fg: T.textMuted, border: 'transparent', hover: T.bg3 },
    outline: { bg: 'transparent', fg: T.text, border: T.border, hover: T.bg3 },
    danger: { bg: 'transparent', fg: T.error, border: T.errorDim, hover: T.errorBg },
  };
  const k = danger ? kinds.danger : kinds[kind];
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      style={{
        height: sz.h,
        padding: `0 ${sz.px}px`,
        display: 'inline-flex',
        alignItems: 'center',
        gap: sz.gap,
        background: active ? T.accentBg : k.bg,
        color: active ? T.accent : k.fg,
        border: `1px solid ${active ? T.accent : k.border}`,
        borderRadius: R.sm,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.4 : 1,
        ...typeCSS(sz.font),
        whiteSpace: 'nowrap',
        ...style,
      }}
    >
      {Icon && <Icon size={sz.iconSize} />}
      {children}
    </button>
  );
}

// ===== Icon button (square, no label) =====
function IconBtn({ icon: Icon, size = 22, active, danger, onClick, title, style = {} }) {
  return (
    <button
      onClick={onClick}
      title={title}
      style={{
        width: size, height: size,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        background: active ? T.accentBg : 'transparent',
        border: '1px solid transparent',
        borderColor: active ? T.accent : 'transparent',
        color: danger ? T.error : (active ? T.accent : T.textMuted),
        cursor: 'pointer',
        borderRadius: R.sm,
        padding: 0,
        ...style,
      }}
    >
      <Icon size={Math.round(size * 0.6)} />
    </button>
  );
}

// ===== Segmented control =====
function Segmented({ options, value, onChange, size = 'md' }) {
  const heights = { sm: 22, md: 28, lg: 34 };
  return (
    <div style={{
      display: 'inline-flex',
      height: heights[size],
      background: T.bg2,
      border: `1px solid ${T.border}`,
      borderRadius: R.sm,
      padding: 2,
      gap: 1,
    }}>
      {options.map(o => {
        const k = typeof o === 'string' ? o : o.value;
        const label = typeof o === 'string' ? o : o.label;
        const active = k === value;
        return (
          <button
            key={k}
            onClick={() => onChange && onChange(k)}
            style={{
              flex: '0 1 auto',
              padding: '0 12px',
              background: active ? T.bg4 : 'transparent',
              border: 'none',
              borderRadius: R.sm,
              color: active ? T.text : T.textMuted,
              cursor: 'pointer',
              ...typeCSS(TY.label),
              fontSize: size === 'sm' ? 10 : 11,
            }}
          >{label}</button>
        );
      })}
    </div>
  );
}

// ===== Form input =====
function Field({ label, hint, error, children, width }) {
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 4, width }}>
      <span style={{ ...typeCSS(TY.labelSm), color: T.textMuted }}>{label}</span>
      {children}
      {error
        ? <span style={{ ...typeCSS(TY.caption), color: T.error }}>{error}</span>
        : hint && <span style={{ ...typeCSS(TY.caption), color: T.textDim }}>{hint}</span>}
    </label>
  );
}

function Input({ value = '', placeholder, mono, width, invalid, onChange, style = {} }) {
  return (
    <input
      value={value}
      placeholder={placeholder}
      onChange={onChange || (() => {})}
      readOnly={!onChange}
      style={{
        height: 30,
        padding: '0 8px',
        background: T.bg1,
        border: `1px solid ${invalid ? T.error : T.border}`,
        color: T.text,
        borderRadius: R.sm,
        ...typeCSS(mono ? TY.mono : TY.body),
        outline: 'none',
        width,
        ...style,
      }}
    />
  );
}

function Select({ value, options = [], width, onChange, mono, leftIcon: LI, style = {} }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center',
      height: 30,
      background: T.bg1,
      border: `1px solid ${T.border}`,
      borderRadius: R.sm,
      paddingRight: 8,
      paddingLeft: LI ? 8 : 0,
      gap: 6,
      width,
      ...style,
    }}>
      {LI && <LI size={14} color={T.textMuted} />}
      <select value={value} onChange={onChange || (() => {})} style={{
        flex: 1,
        height: '100%',
        padding: '0 8px',
        background: 'transparent',
        border: 'none',
        color: T.text,
        ...typeCSS(mono ? TY.mono : TY.body),
        outline: 'none',
        appearance: 'none',
        WebkitAppearance: 'none',
        cursor: 'pointer',
      }}>
        {options.map(o => (
          <option key={typeof o === 'string' ? o : o.value} value={typeof o === 'string' ? o : o.value}>
            {typeof o === 'string' ? o : o.label}
          </option>
        ))}
      </select>
      <IconExpandDown size={12} color={T.textMuted} />
    </div>
  );
}

function Checkbox({ checked, onChange, label }) {
  return (
    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
      <span style={{
        width: 14, height: 14,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        background: checked ? T.accent : T.bg1,
        border: `1.5px solid ${checked ? T.accent : T.border}`,
        borderRadius: R.sm,
      }}>
        {checked && <IconCheck size={10} color={T.onAccent} />}
      </span>
      {label && <span style={{ ...typeCSS(TY.body), color: T.text }}>{label}</span>}
    </label>
  );
}

// ===== Bool pill (FC01/02 cell) =====
function BoolPill({ value, pending, onClick, big }) {
  const w = big ? 64 : 56;
  const h = big ? 26 : 18;
  return (
    <div
      onClick={onClick}
      style={{
        width: w, height: h,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        background: value ? T.online : T.bg1,
        color: value ? T.onOnline : T.textMuted,
        border: `1px solid ${value ? T.onlineDim : T.border}`,
        borderRadius: 2,
        ...typeCSS(TY.monoSm),
        fontWeight: 600,
        letterSpacing: '0.08em',
        cursor: 'pointer',
        opacity: pending ? 0.45 : 1,
        transition: 'opacity 0.2s',
        userSelect: 'none',
      }}
    >{value ? 'TRUE' : 'FALSE'}</div>
  );
}

// ===== Section header (in sidebar / dialogs) =====
function SectionLabel({ children, count, action }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '10px 14px 6px',
    }}>
      <span style={{ ...typeCSS(TY.labelSm), color: T.textDim }}>
        {children}
        {count !== undefined && <span style={{ color: T.textFaint, marginLeft: 6 }}>({count})</span>}
      </span>
      {action}
    </div>
  );
}

// ===== Dialog shell =====
function Dialog({ title, subtitle, width = 480, children, footer, onClose }) {
  return (
    <div style={{
      width,
      background: T.bg2,
      border: `1px solid ${T.borderStrong}`,
      borderRadius: R.md,
      boxShadow: SH.modal,
      overflow: 'hidden',
    }}>
      <div style={{
        display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between',
        padding: '14px 16px 12px',
        borderBottom: `1px solid ${T.borderFaint}`,
      }}>
        <div>
          <div style={{ ...typeCSS(TY.h1), color: T.text }}>{title}</div>
          {subtitle && <div style={{ ...typeCSS(TY.caption), color: T.textMuted, marginTop: 2 }}>{subtitle}</div>}
        </div>
        <IconBtn icon={IconClose} size={22} onClick={onClose} title="Close" />
      </div>
      <div style={{ padding: 16 }}>
        {children}
      </div>
      {footer && (
        <div style={{
          padding: '12px 16px',
          borderTop: `1px solid ${T.borderFaint}`,
          background: T.bg1,
          display: 'flex', justifyContent: 'flex-end', gap: 8,
        }}>{footer}</div>
      )}
    </div>
  );
}

// ===== Pane chrome (MDI window) =====
function Pane({ width, height, elevated, active, children, style = {} }) {
  return (
    <div style={{
      width, height,
      background: T.bg2,
      border: `1px solid ${active ? T.accent : T.border}`,
      borderRadius: R.sm,
      boxShadow: elevated ? SH.pane : 'none',
      display: 'flex',
      flexDirection: 'column',
      overflow: 'hidden',
      position: 'relative',
      ...style,
    }}>
      {children}
    </div>
  );
}

function PaneHeader({ status, title, tabs, activeTab, onTab, actions }) {
  return (
    <div style={{
      height: 30,
      background: T.bg3,
      borderBottom: `1px solid ${T.border}`,
      display: 'flex', alignItems: 'center',
      paddingLeft: 8, paddingRight: 4,
      gap: 8,
      flexShrink: 0,
      cursor: 'move',
    }}>
      <StatusDot status={status} size={7} />
      <div style={{ ...typeCSS(TY.mono), color: T.text, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {title}
      </div>
      {tabs && (
        <div style={{ display: 'flex', gap: 2 }}>
          {tabs.map(tab => {
            const a = tab.id === activeTab;
            return (
              <button key={tab.id} onClick={() => onTab && onTab(tab.id)}
                style={{
                  height: 22,
                  padding: '0 8px',
                  background: a ? T.bg1 : 'transparent',
                  color: a ? T.text : T.textMuted,
                  border: `1px solid ${a ? T.border : 'transparent'}`,
                  borderRadius: R.sm,
                  ...typeCSS(TY.labelSm),
                  cursor: 'pointer',
                  display: 'inline-flex', alignItems: 'center', gap: 4,
                }}>
                {tab.label}
                {tab.badge && (
                  <span style={{
                    background: T.error,
                    color: T.onError,
                    padding: '0 4px',
                    borderRadius: 6,
                    ...typeCSS(TY.labelSm),
                    fontSize: 9,
                  }}>{tab.badge}</span>
                )}
              </button>
            );
          })}
        </div>
      )}
      {actions}
    </div>
  );
}

Object.assign(window, {
  ConnIndicator, TransportChip, FCChip, FormatChip,
  Btn, IconBtn, Segmented,
  Field, Input, Select, Checkbox,
  BoolPill, SectionLabel, Dialog,
  Pane, PaneHeader,
});
