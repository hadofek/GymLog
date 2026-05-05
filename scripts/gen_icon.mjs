// Generates a 1024x1024 app icon: black bg, white "GL" wordmark
// Uses sharp + SVG input (no external font needed — geometric sans shapes)
import sharp from 'sharp';
import { writeFileSync } from 'fs';

const SIZE = 1024;

// SVG: black square, white italic bold "GL" centred
// Using a constructed geometric letterform so no font dependency
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 1024 1024">
  <!-- Background -->
  <rect width="1024" height="1024" fill="#000000"/>

  <!-- "G" — constructed from arcs and rects, italic skew via transform -->
  <!-- "L" — simple L shape -->

  <!-- We'll use text with a system serif-free stack and skew it -->
  <text
    x="512" y="600"
    text-anchor="middle"
    font-family="Arial, Helvetica, sans-serif"
    font-size="520"
    font-weight="900"
    font-style="italic"
    letter-spacing="-20"
    fill="#E8E8E8"
    transform="skewX(-6)"
  >GL</text>

  <!-- thin bottom line accent -->
  <rect x="160" y="820" width="704" height="6" rx="3" fill="#E8E8E8" opacity="0.3"/>
</svg>`;

const buf = Buffer.from(svg);

sharp(buf)
  .resize(1024, 1024)
  .png()
  .toFile('assets/images/app_icon.png')
  .then(() => console.log('✓ app_icon.png written (1024×1024)'))
  .catch(e => { console.error(e); process.exit(1); });
