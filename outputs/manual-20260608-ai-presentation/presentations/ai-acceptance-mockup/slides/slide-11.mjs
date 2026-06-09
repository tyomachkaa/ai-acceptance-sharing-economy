import { C, bg, footer, kicker, title, subtitle, figure, insight } from "./_shared.mjs";

const grad = [
  ["AI-native", 58, C.green, "AI is the product"],
  ["Support desk", 56, C.blue, "AI handles service"],
  ["Rental add-on", 49, C.orange, "AI mediates a transaction"],
];

export async function slide11(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Role gradient");
  title(slide, ctx, "Same technology, different reception: users punish AI when it feels imposed.", 54, 76, 1030, 92);
  subtitle(slide, ctx, "Reddit shows the role gradient; Trustpilot shows the rental-platform AI penalty in stars.", 56, 176, 820, 38);
  ctx.addText(slide, { x: 76, y: 246, w: 420, h: 28, text: "Reddit positive share by AI role", fontSize: 20, bold: true, color: C.ink, typeface: "Aptos Display" });
  grad.forEach((g, i) => {
    const yy = 306 + i * 82;
    ctx.addText(slide, { x: 78, y: yy, w: 126, h: 24, text: g[0], fontSize: 15, bold: true, color: C.ink });
    ctx.addShape(slide, { x: 214, y: yy + 4, w: 300, h: 16, fill: C.paper2 });
    ctx.addShape(slide, { x: 214, y: yy + 4, w: 300 * g[1] / 70, h: 16, fill: g[2] });
    ctx.addText(slide, { x: 530, y: yy - 1, w: 62, h: 26, text: `${g[1]}%`, fontSize: 18, bold: true, color: g[2] });
    ctx.addText(slide, { x: 78, y: yy + 30, w: 470, h: 24, text: g[3], fontSize: 13, color: C.muted });
  });
  await figure(slide, ctx, "figures/fig_11_ai_penalty.png", 662, 246, 470, 318);
  insight(slide, ctx, "Headline line", "Acceptance is highest when AI is chosen; it drops when AI is unavoidable in a trust-heavy exchange.", 662, 574, 470, 102, C.orange);
  footer(slide, ctx, 11);
  return slide;
}
