// Charte Lagoon (reconstituée d'après SKILL.md fgillet-lagoon-light-ppt : lagoon_theme.js absent du skill synchronisé)
const path = require('path');

const C = {
  BLUE: '06539D', ORANGE: 'EB692E', NAVY: '03386B', LIGHTBLUE: 'D6E4F3',
  TEXT: '2F2F2F', MUTED: '707070', BG: 'F5F7FA', WHITE: 'FFFFFF',
  GREEN: '2E8B57', AMBER: 'E8A33D', RED: 'C0392B', GREY: '9AA3AD', SOBLOO: '1038A8',
};
const FONT = 'Montserrat';
const MONO = 'Consolas';
let assetDir = '.';
let total = 1;
let project = 'Projet';

const setAssetDir = d => { assetDir = d; };
const setTotal = n => { total = n; };
const setProject = p => { project = p; };
const asset = f => path.join(assetDir, f);

function cover(pres, o) {
  const s = pres.addSlide();
  s.background = { color: C.WHITE };
  s.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.25, h: 7.5, fill: { color: C.ORANGE }, line: { color: C.ORANGE } });
  s.addImage({ path: asset('lagoon_logo.png'), x: 0.9, y: 0.7, w: 2.6, h: 0.956 });
  if (o.coBrandLogo) {
    s.addText('×', { x: 3.65, y: 0.85, w: 0.5, h: 0.6, fontFace: FONT, fontSize: 24, color: C.MUTED, align: 'center' });
    s.addImage({ path: o.coBrandLogo, x: 4.3, y: 0.92, w: 2.4, h: 0.529 });
  }
  s.addText(o.eyebrow.toUpperCase(), { x: 0.9, y: 2.55, w: 11, h: 0.4, fontFace: FONT, fontSize: 14, bold: true, color: C.ORANGE, charSpacing: 2 });
  s.addText(o.title, { x: 0.9, y: 3.0, w: 11.5, h: 1.3, fontFace: FONT, fontSize: 38, bold: true, color: C.BLUE, valign: 'top' });
  if (o.subtitle) s.addText(o.subtitle, { x: 0.9, y: 3.85, w: 11.5, h: 0.6, fontFace: FONT, fontSize: 18, color: C.MUTED, valign: 'top' });
  s.addShape(pres.shapes.LINE, { x: 0.9, y: 5.6, w: 0.8, h: 0, line: { color: C.ORANGE, width: 2.5 } });
  s.addText([
    { text: o.author, options: { bold: true, color: C.TEXT, breakLine: true } },
    { text: `${o.role} · ${o.date}`, options: { color: C.MUTED } },
  ], { x: 0.9, y: 5.75, w: 8, h: 0.8, fontFace: FONT, fontSize: 13, valign: 'top' });
  return s;
}

function header(pres, s, title, subtitle) {
  s.addText(title, { x: 0.6, y: 0.35, w: 12.1, h: 0.65, fontFace: FONT, fontSize: 26, bold: true, color: C.BLUE, valign: 'top', margin: 0 });
  if (subtitle) s.addText(subtitle, { x: 0.6, y: 1.0, w: 12.1, h: 0.4, fontFace: FONT, fontSize: 13, color: C.MUTED, valign: 'top', margin: 0 });
}

function footer(s, num) {
  s.addImage({ path: asset('lagoon_logo.png'), x: 0.6, y: 6.98, w: 0.9, h: 0.331 });
  s.addText(`${project} | Confidentiel`, { x: 1.65, y: 6.98, w: 8, h: 0.33, fontFace: FONT, fontSize: 9, color: C.MUTED, valign: 'middle', margin: 0 });
  s.addText(`${num} / ${total}`, { x: 11.2, y: 6.98, w: 1.53, h: 0.33, fontFace: FONT, fontSize: 9, color: C.MUTED, align: 'right', valign: 'middle', margin: 0 });
}

const th = (text, o = {}) => ({ text, options: { bold: true, color: C.WHITE, fill: { color: C.BLUE }, fontFace: FONT, fontSize: 11, align: o.align || 'left', valign: 'middle' } });
const td = (text, o = {}) => ({ text, options: { color: C.TEXT, fontFace: FONT, fontSize: o.size || 10.5, bold: !!o.bold, align: o.align || 'left', valign: 'middle', fill: o.fill ? { color: o.fill } : undefined } });
const statusCell = (text, color) => ({ text, options: { bold: true, color: C.WHITE, fill: { color }, fontFace: FONT, fontSize: 10, align: 'center', valign: 'middle' } });

function accentLine(s, pres, x, y, w = 0.6) {
  s.addShape(pres.shapes.LINE, { x, y, w, h: 0, line: { color: C.ORANGE, width: 2 } });
}

function accentCard(s, pres, x, y, w, h, title, desc, accent = C.BLUE) {
  s.addShape(pres.shapes.RECTANGLE, { x, y, w, h, fill: { color: C.BG }, line: { color: C.BG } });
  s.addShape(pres.shapes.RECTANGLE, { x, y, w: 0.08, h, fill: { color: accent }, line: { color: accent } });
  s.addText(title, { x: x + 0.25, y: y + 0.15, w: w - 0.4, h: 0.45, fontFace: FONT, fontSize: 14, bold: true, color: C.BLUE, valign: 'top', margin: 0 });
  s.addText(desc, { x: x + 0.25, y: y + 0.65, w: w - 0.4, h: h - 0.8, fontFace: FONT, fontSize: 12, color: C.TEXT, valign: 'top', margin: 0, paraSpaceAfter: 4 });
}

module.exports = { C, FONT, MONO, setAssetDir, setTotal, setProject, cover, header, footer, th, td, statusCell, accentLine, accentCard };
