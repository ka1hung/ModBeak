// Dialogs: Add Device (TCP/RTU), Add/Edit Watch, Edit Value, Edit Bits

// ===== Add Device — TCP =====
function DialogAddDeviceTCP() {
  return (
    <Dialog
      title="Add Device"
      subtitle="Configure a new Modbus connection"
      width={520}
      footer={<>
        <Btn kind="ghost">Cancel</Btn>
        <Btn kind="primary">Add Device</Btn>
      </>}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Segmented value="TCP" options={['TCP', 'RTU']} />

        <Field label="Name" hint="Optional — defaults to host:port">
          <Input value="PLC-Line-A" />
        </Field>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 100px 100px', gap: 10 }}>
          <Field label="Host / IP">
            <Input value="192.168.1.10" mono />
          </Field>
          <Field label="Port">
            <Input value="502" mono />
          </Field>
          <Field label="Timeout (ms)">
            <Input value="1000" mono />
          </Field>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <Field label="Poll interval (ms)" hint="Whole device cycle">
            <Input value="500" mono />
          </Field>
          <Field label="Min request gap (ms)" hint="Between requests in a cycle">
            <Input value="20" mono />
          </Field>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, paddingTop: 4 }}>
          <Checkbox checked={true} label="Auto-reconnect on failure" />
          <Checkbox checked={false} label="Serialize requests (one in flight at a time)" />
        </div>

        <div style={{
          marginTop: 4,
          padding: '8px 10px',
          background: T.onlineBg,
          border: `1px solid ${T.onlineDim}`,
          borderRadius: R.sm,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <IconCheck size={14} color={T.online} />
          <span style={{ ...typeCSS(TY.body), color: T.online }}>Connection test</span>
          <span style={{ ...typeCSS(TY.mono), color: T.online }}>OK · 123 ms</span>
          <div style={{ flex: 1 }} />
          <Btn kind="outline" size="sm" icon={IconTest}>Test again</Btn>
        </div>
      </div>
    </Dialog>
  );
}

// ===== Add Device — RTU =====
function DialogAddDeviceRTU() {
  return (
    <Dialog
      title="Add Device"
      subtitle="Configure a new Modbus connection"
      width={520}
      footer={<>
        <Btn kind="ghost">Cancel</Btn>
        <Btn kind="primary">Add Device</Btn>
      </>}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Segmented value="RTU" options={['TCP', 'RTU']} />

        <Field label="Name" hint="Optional — defaults to port name">
          <Input value="Energy Meter · RTU" />
        </Field>

        <Field label="Serial port">
          <div style={{ display: 'flex', gap: 6 }}>
            <Select
              value="/dev/tty.usbserial-A1042"
              width="100%"
              mono
              options={[
                { value: '/dev/tty.usbserial-A1042', label: '/dev/tty.usbserial-A1042 — FT232R USB UART (FTDI)' },
                { value: '/dev/tty.usbmodem1101', label: '/dev/tty.usbmodem1101 — Arduino MKR (Arduino)' },
                { value: 'COM3 (not connected)', label: 'COM3 — (not connected)' },
              ]}
            />
            <IconBtn icon={IconRefresh} size={30} title="Refresh ports" />
          </div>
        </Field>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 10 }}>
          <Field label="Baud">
            <Select value="9600" mono options={['1200','2400','4800','9600','19200','38400','57600','115200','230400']} />
          </Field>
          <Field label="Data bits">
            <Select value="8" mono options={['7', '8']} />
          </Field>
          <Field label="Stop bits">
            <Select value="1" mono options={['1', '2']} />
          </Field>
          <Field label="Parity">
            <Select value="None" mono options={['None', 'Even', 'Odd']} />
          </Field>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
          <Field label="Timeout (ms)">
            <Input value="1000" mono />
          </Field>
          <Field label="Poll interval (ms)">
            <Input value="500" mono />
          </Field>
          <Field label="Min request gap (ms)">
            <Input value="50" mono />
          </Field>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, paddingTop: 4 }}>
          <Checkbox checked={true} label="Auto-reconnect on failure" />
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Checkbox checked={true} label="Serialize requests" />
            <span style={{ ...typeCSS(TY.caption), color: T.textDim }}>(forced ON for RTU half-duplex)</span>
          </div>
        </div>

        <div style={{
          marginTop: 4,
          padding: '8px 10px',
          background: T.errorBg,
          border: `1px solid ${T.errorDim}`,
          borderRadius: R.sm,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <IconErrorX size={14} color={T.error} />
          <span style={{ ...typeCSS(TY.body), color: T.error }}>FAIL · Permission denied (try sudo or add user to dialout)</span>
          <div style={{ flex: 1 }} />
          <Btn kind="outline" size="sm" icon={IconTest}>Test</Btn>
        </div>
      </div>
    </Dialog>
  );
}

// ===== Add / Edit Watch =====
function DialogAddWatch() {
  const fcs = [
    { v: 'FC03', label: 'FC 03 — Holding Register', desc: 'Read/write registers · 16-bit', icon: IconFC03 },
    { v: 'FC04', label: 'FC 04 — Input Register', desc: 'Read-only registers · 16-bit', icon: IconFC04 },
    { v: 'FC01', label: 'FC 01 — Coil', desc: 'Read/write booleans', icon: IconFC01 },
    { v: 'FC02', label: 'FC 02 — Discrete Input', desc: 'Read-only booleans', icon: IconFC02 },
  ];
  const selected = 'FC03';
  return (
    <Dialog
      title="Add Watch"
      subtitle="Define which registers or bits to poll"
      width={540}
      footer={<>
        <Btn kind="ghost">Cancel</Btn>
        <Btn kind="primary">Add Watch</Btn>
      </>}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Field label="Device">
          <Select value="PLC-Line-A" options={['PLC-Line-A', 'AC Drive', 'Energy Meter · RTU']} leftIcon={IconTCP} />
        </Field>

        <div>
          <span style={{ ...typeCSS(TY.labelSm), color: T.textMuted }}>FUNCTION CODE</span>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginTop: 6 }}>
            {fcs.map(fc => {
              const a = fc.v === selected;
              const Ic = fc.icon;
              return (
                <div key={fc.v} style={{
                  padding: '8px 10px',
                  background: a ? T.accentBg : T.bg1,
                  border: `1px solid ${a ? T.accent : T.border}`,
                  borderRadius: R.sm,
                  cursor: 'pointer',
                  display: 'flex', alignItems: 'center', gap: 8,
                }}>
                  <span style={{
                    width: 12, height: 12,
                    border: `1.5px solid ${a ? T.accent : T.border}`,
                    borderRadius: '50%',
                    display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                  }}>
                    {a && <span style={{ width: 6, height: 6, background: T.accent, borderRadius: '50%' }}/>}
                  </span>
                  <Ic size={16} color={a ? T.accent : T.textMuted} />
                  <div>
                    <div style={{ ...typeCSS(TY.body), color: T.text, fontWeight: 600 }}>{fc.label}</div>
                    <div style={{ ...typeCSS(TY.caption), color: T.textDim }}>{fc.desc}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '80px 1fr 1fr', gap: 10 }}>
          <Field label="Unit ID">
            <Input value="1" mono />
          </Field>
          <Field label="Start address" hint="1-based, ModScan convention">
            <Input value="100" mono />
          </Field>
          <Field label="Quantity">
            <Input value="10" mono />
          </Field>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <Field label="Initial format">
            <Select value="UInt16" mono options={['UInt16','Int16','Hex','Binary','UInt32 BE','Float32 BE','ASCII']} />
          </Field>
          <Field label="Chars per row" hint="ASCII only">
            <Input value="—" mono style={{ opacity: 0.4 }} />
          </Field>
        </div>
      </div>
    </Dialog>
  );
}

// ===== Edit Value popup =====
function DialogEditValue({ format = 'UInt16' }) {
  const hints = {
    UInt16: { label: 'UInt16', hint: '0..65535', current: '4631' },
    Int16: { label: 'Int16', hint: '−32768..32767', current: '-1024' },
    Hex: { label: 'Hex', hint: '0x0000..0xFFFF (hex digits)', current: '0x1234' },
    Float32: { label: 'Float32', hint: 'IEEE-754 float (e.g. 3.14, -1.5e3)', current: '3.14159' },
    ASCII: { label: 'ASCII', hint: 'up to 2 chars per register', current: 'HE' },
  };
  const h = hints[format] || hints.UInt16;
  return (
    <Dialog
      title="Write to register 100"
      subtitle={`${h.label} · ${h.hint}`}
      width={380}
      footer={<>
        <Btn kind="ghost">Cancel</Btn>
        <Btn kind="primary" icon={IconCheck}>Write</Btn>
      </>}
    >
      <Field label="Value">
        <Input value={h.current} mono style={{ fontSize: 15, height: 36 }} />
      </Field>
      <div style={{ marginTop: 8, ...typeCSS(TY.caption), color: T.textDim }}>
        Enter to send · Esc to cancel
      </div>
    </Dialog>
  );
}

// ===== Edit Bits popup =====
function DialogEditBits() {
  const initialValue = 0x4A2C; // sample
  const bits = [];
  for (let i = 15; i >= 0; i--) bits.push({ idx: i, on: !!((initialValue >> i) & 1) });

  const binary = initialValue.toString(2).padStart(16, '0').replace(/(.{4})/g, '$1 ').trim();
  const hex = '0x' + initialValue.toString(16).toUpperCase().padStart(4, '0');
  const dec = initialValue.toString();

  return (
    <Dialog
      title="Write to register 100"
      subtitle="Holding register · 16 bits (MSB ← bit 15 … bit 0 → LSB)"
      width={520}
      footer={<>
        <Btn kind="ghost">Cancel</Btn>
        <Btn kind="primary" icon={IconCheck}>Write</Btn>
      </>}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* Bit grid */}
        <div>
          {[0, 1].map(row => {
            const slice = bits.slice(row * 8, row * 8 + 8);
            return (
              <div key={row} style={{ display: 'flex', gap: 0, marginBottom: row === 0 ? 6 : 0 }}>
                {slice.map((b, i) => {
                  const nibbleGap = i === 4 ? 10 : 0;
                  return (
                    <div key={b.idx} style={{
                      width: 50,
                      display: 'flex', flexDirection: 'column', alignItems: 'center',
                      marginLeft: nibbleGap,
                    }}>
                      <span style={{ ...typeCSS(TY.monoSm), color: T.textDim, fontSize: 10, marginBottom: 3 }}>{b.idx}</span>
                      <button style={{
                        width: 40, height: 40,
                        background: b.on ? T.accent : T.bg1,
                        border: `1.5px solid ${b.on ? T.accent : T.border}`,
                        borderRadius: R.sm,
                        color: b.on ? T.onAccent : T.textMuted,
                        ...typeCSS(TY.monoLg),
                        cursor: 'pointer',
                      }}>{b.on ? '1' : '0'}</button>
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>

        {/* Preview */}
        <div style={{
          padding: 10,
          background: T.bg1,
          border: `1px solid ${T.borderFaint}`,
          borderRadius: R.sm,
          display: 'flex', flexDirection: 'column', gap: 6,
        }}>
          <PreviewLine label="BIN" value={binary} accent={T.fmtBin} />
          <PreviewLine label="HEX" value={hex} accent={T.fmtHex} />
          <PreviewLine label="DEC" value={dec} accent={T.fmtNum} />
        </div>

        {/* Tools */}
        <div style={{ display: 'flex', gap: 6 }}>
          <Btn kind="outline" size="sm">Clear all</Btn>
          <Btn kind="outline" size="sm">Set all</Btn>
          <Btn kind="outline" size="sm">Invert</Btn>
        </div>
      </div>
    </Dialog>
  );
}

function PreviewLine({ label, value, accent }) {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
      <span style={{ ...typeCSS(TY.labelSm), color: accent, width: 28 }}>{label}</span>
      <span style={{ ...typeCSS(TY.mono), color: T.text, fontVariantNumeric: 'tabular-nums' }}>{value}</span>
    </div>
  );
}

Object.assign(window, {
  DialogAddDeviceTCP, DialogAddDeviceRTU, DialogAddWatch,
  DialogEditValue, DialogEditBits,
});
