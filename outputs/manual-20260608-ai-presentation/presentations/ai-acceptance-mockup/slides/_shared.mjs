export const ROOT = "/Users/tyomachka/Desktop/WU/Online Content Analysis/Final Project";

export const C = {
  ink: "#182126",
  paper: "#F7F3EA",
  paper2: "#EFE8DA",
  muted: "#5C625F",
  line: "#D7D1C4",
  orange: "#F26A38",
  green: "#3FA66B",
  blue: "#2F7EB6",
  gold: "#D5A039",
  white: "#FFFFFF",
};

export function bg(slide, ctx, fill = C.paper) {
  ctx.addShape(slide, { x: 0, y: 0, w: 1280, h: 720, fill });
}

export function footer(slide, ctx, n, dark = false) {
  const col = dark ? "#D8D2C7" : C.muted;
  ctx.addText(slide, {
    x: 54, y: 682, w: 520, h: 20, text: "AI Acceptance in the Sharing Economy",
    fontSize: 10, color: col, typeface: "Aptos", valign: "middle",
  });
  ctx.addText(slide, {
    x: 1198, y: 682, w: 48, h: 20, text: String(n).padStart(2, "0"),
    fontSize: 10, color: col, align: "right", valign: "middle",
  });
}

export function kicker(slide, ctx, label, x = 54, y = 42, dark = false, name = "kicker") {
  const col = dark ? C.paper : C.ink;
  ctx.addShape(slide, { x, y: y + 8, w: 28, h: 3, fill: C.orange, name: `${name}-marker` });
  ctx.addText(slide, {
    x: x + 40, y, w: 320, h: 20, text: label.toUpperCase(),
    fontSize: 12, color: col, bold: true, typeface: "Aptos", valign: "middle",
    name: `${name}-label`,
  });
}

export function title(slide, ctx, text, x = 54, y = 76, w = 800, h = 96, dark = false, size = 42) {
  ctx.addText(slide, {
    x, y, w, h, text, fontSize: size, bold: true, color: dark ? C.paper : C.ink,
    typeface: "Aptos Display", valign: "top",
  });
}

export function subtitle(slide, ctx, text, x, y, w, h, dark = false, size = 18) {
  ctx.addText(slide, {
    x, y, w, h, text, fontSize: size, color: dark ? "#D8D2C7" : C.muted,
    typeface: "Aptos", valign: "top", insets: { left: 0, right: 0, top: 0, bottom: 0 },
  });
}

export function label(slide, ctx, text, x, y, w, h, color = C.muted, size = 12, align = "left") {
  ctx.addText(slide, {
    x, y, w, h, text, fontSize: size, color, typeface: "Aptos",
    align, valign: "middle",
  });
}

export function metric(slide, ctx, value, labelText, note, x, y, w, dark = false, accent = C.orange) {
  ctx.addShape(slide, {
    x, y, w, h: 106, fill: dark ? "#243038" : C.white,
    line: { style: "solid", fill: dark ? "#3B4A51" : C.line, width: 1 },
  });
  ctx.addShape(slide, { x, y, w: 5, h: 106, fill: accent });
  ctx.addText(slide, {
    x: x + 18, y: y + 14, w: w - 34, h: 36, text: value,
    fontSize: 30, bold: true, color: dark ? C.paper : C.ink,
    typeface: "Aptos Display", valign: "middle",
  });
  ctx.addText(slide, {
    x: x + 18, y: y + 52, w: w - 34, h: 22, text: labelText,
    fontSize: 13, bold: true, color: dark ? "#E8E2D6" : C.ink,
    typeface: "Aptos", valign: "middle",
  });
  ctx.addText(slide, {
    x: x + 18, y: y + 76, w: w - 34, h: 18, text: note,
    fontSize: 10, color: dark ? "#AEB8B9" : C.muted,
    typeface: "Aptos", valign: "middle",
  });
}

export function insight(slide, ctx, heading, body, x, y, w, h, accent = C.orange) {
  ctx.addShape(slide, { x, y, w, h, fill: C.white, line: { style: "solid", fill: C.line, width: 1 } });
  ctx.addShape(slide, { x, y, w: 6, h, fill: accent });
  ctx.addText(slide, {
    x: x + 22, y: y + 18, w: w - 42, h: 28, text: heading,
    fontSize: 18, bold: true, color: C.ink, typeface: "Aptos Display", valign: "middle",
  });
  ctx.addText(slide, {
    x: x + 22, y: y + 54, w: w - 42, h: h - 70, text: body,
    fontSize: 15, color: C.muted, typeface: "Aptos", valign: "top",
    insets: { left: 0, right: 0, top: 0, bottom: 0 },
  });
}

export async function figure(slide, ctx, file, x, y, w, h, fit = "contain") {
  ctx.addShape(slide, { x, y, w, h, fill: C.white, line: { style: "solid", fill: C.line, width: 1 } });
  return ctx.addImage(slide, { path: `${ROOT}/${file}`, x: x + 8, y: y + 8, w: w - 16, h: h - 16, fit, alt: file });
}

export function bulletList(slide, ctx, items, x, y, w, lineH = 34, color = C.ink) {
  items.forEach((item, i) => {
    const yy = y + i * lineH;
    ctx.addShape(slide, { x, y: yy + 9, w: 7, h: 7, fill: item.accent || C.orange });
    ctx.addText(slide, {
      x: x + 20, y: yy, w: w - 20, h: lineH - 2, text: item.text || item,
      fontSize: item.size || 17, bold: Boolean(item.bold), color: item.color || color,
      typeface: "Aptos", valign: "top",
    });
  });
}

export function smallPill(slide, ctx, text, x, y, w, fill = C.paper2, color = C.ink) {
  ctx.addShape(slide, { x, y, w, h: 24, fill, line: { style: "solid", fill: "transparent", width: 0 } });
  ctx.addText(slide, { x, y: y + 1, w, h: 22, text, fontSize: 11, bold: true, color, align: "center", valign: "middle" });
}

