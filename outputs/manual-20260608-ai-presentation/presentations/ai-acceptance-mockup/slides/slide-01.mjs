import { C, bg, footer, kicker, metric } from "./_shared.mjs";

export async function slide01(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx, C.ink);
  kicker(slide, ctx, "Final project presentation mockup", 54, 46, true);
  ctx.addText(slide, {
    x: 54, y: 102, w: 820, h: 196,
    text: "AI acceptance depends on whether AI is chosen or imposed.",
    fontSize: 54, bold: true, color: C.paper, typeface: "Aptos Display",
  });
  ctx.addText(slide, {
    x: 56, y: 312, w: 650, h: 76,
    text: "Text mining Reddit and Trustpilot to understand trust, frustration, and adoption of AI agents in sharing-economy service moments.",
    fontSize: 20, color: "#D8D2C7", typeface: "Aptos",
  });
  metric(slide, ctx, "4,269", "Reddit comments", "discussion baseline", 56, 444, 255, true, C.blue);
  metric(slide, ctx, "3,912", "Trustpilot reviews", "star-labelled verification", 334, 444, 255, true, C.green);
  metric(slide, ctx, "1.89★", "AI penalty", "2.32★ AI vs 4.21★ non-AI", 612, 444, 255, true, C.orange);
  ctx.addShape(slide, { x: 948, y: 88, w: 164, h: 164, fill: "#243038", line: { style: "solid", fill: "#435158", width: 1 } });
  ctx.addText(slide, { x: 970, y: 122, w: 120, h: 40, text: "Core case", fontSize: 15, bold: true, color: C.paper, align: "center" });
  ctx.addText(slide, { x: 966, y: 166, w: 128, h: 72, text: "AI agents in rental and sharing-economy platforms", fontSize: 15, color: "#D8D2C7", align: "center" });
  ctx.addShape(slide, { x: 1074, y: 318, w: 74, h: 74, fill: C.orange });
  ctx.addShape(slide, { x: 1016, y: 382, w: 74, h: 74, fill: C.green });
  ctx.addShape(slide, { x: 1110, y: 448, w: 74, h: 74, fill: C.blue });
  footer(slide, ctx, 1, true);
  return slide;
}
