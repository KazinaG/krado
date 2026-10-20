// Optional headless PNG renderer for an already available sharp installation.
// SVG is the shared source; no package installation or GUI is performed here.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

(async () => {
  for (const dir of process.argv.slice(2)) {
    const svg = fs.readFileSync(path.join(dir, 'background.svg'));
    for (const scale of [1, 2]) {
      await sharp(svg, { density: 72 * scale }).png().toFile(
        path.join(dir, `background${scale === 2 ? '@2x' : ''}.png`));
    }
  }
})().catch(error => { console.error(error); process.exit(1); });
