// ModBeak — cockatiel head logo glyph
// Side profile facing left, with iconic crest + orange cheek

function CockatielHead({ size = 100, detail = 'full' }) {
  // detail: 'full' (≥32px), 'simple' (16-32px)
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ display: 'block', flexShrink: 0 }}>
      {/* Crest — 3 swept-back feathers */}
      <path d="M 56 24 L 74 6 L 64 32 Z" fill="#fad65b"/>
      <path d="M 64 26 L 90 10 L 72 36 Z" fill="#f0c032"/>
      <path d="M 70 34 L 96 28 L 78 44 Z" fill="#d9a519"/>

      {/* Head fill */}
      <path d="M 30 50
               C 30 30, 44 22, 56 22
               C 72 22, 82 34, 82 52
               C 82 72, 70 84, 54 84
               C 38 84, 28 74, 28 62
               L 28 56 Z" fill="#fce088"/>

      {/* Cheek shadow under orange */}
      {detail === 'full' && (
        <ellipse cx="44" cy="64" rx="14" ry="11" fill="#f5c860" opacity="0.6"/>
      )}

      {/* Orange cheek patch — the signature */}
      <circle cx="44" cy="63" r="11" fill="#ff7c3d"/>

      {/* Eye */}
      <circle cx="42" cy="46" r="4" fill="#1a0f08"/>
      {detail === 'full' && <circle cx="43.2" cy="44.8" r="1.2" fill="#ffffff"/>}

      {/* Beak — hooked downward, dark */}
      <path d="M 28 50
               Q 14 56, 14 66
               Q 16 71, 24 70
               Q 30 66, 32 60 Z" fill="#2a1810"/>
      {/* Beak inner shadow */}
      {detail === 'full' && (
        <path d="M 22 64 Q 18 65, 18 67 Q 20 69, 24 68 Z" fill="#0d0703"/>
      )}
    </svg>
  );
}

Object.assign(window, { CockatielHead });
