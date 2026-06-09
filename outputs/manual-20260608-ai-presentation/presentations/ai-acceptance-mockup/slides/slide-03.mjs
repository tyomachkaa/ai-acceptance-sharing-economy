import { C, bg, footer, kicker, title, subtitle, metric, insight } from "./_shared.mjs";

export async function slide03(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Data design");
  title(slide, ctx, "Two corpora give us both open discussion and behavioural validation.");
  subtitle(slide, ctx, "Reddit captures how people talk about AI. Trustpilot adds star ratings from actual service encounters.", 56, 176, 780, 44);

  metric(slide, ctx, "2,027", "AI-native comments", "context where AI is the product", 68, 274, 250, false, C.blue);
  metric(slide, ctx, "1,715", "Rental comments", "sharing-economy core case", 68, 398, 250, false, C.orange);
  metric(slide, ctx, "527", "Support comments", "AI at the service desk", 68, 522, 250, false, C.gold);

  ctx.addShape(slide, { x: 382, y: 296, w: 240, h: 220, fill: C.ink });
  ctx.addText(slide, { x: 410, y: 326, w: 184, h: 34, text: "Reddit", fontSize: 28, bold: true, color: C.paper, align: "center" });
  ctx.addText(slide, { x: 414, y: 374, w: 176, h: 82, text: "discussion baseline\ntext-mining depth\ncontext comparison", fontSize: 18, color: "#D8D2C7", align: "center" });
  ctx.addShape(slide, { x: 622, y: 402, w: 82, h: 4, fill: C.orange });
  ctx.addShape(slide, { x: 704, y: 396, w: 14, h: 14, fill: C.orange });
  ctx.addShape(slide, { x: 724, y: 296, w: 240, h: 220, fill: C.white, line: { style: "solid", fill: C.line, width: 1 } });
  ctx.addText(slide, { x: 752, y: 326, w: 184, h: 34, text: "Trustpilot", fontSize: 28, bold: true, color: C.ink, align: "center" });
  ctx.addText(slide, { x: 756, y: 374, w: 176, h: 82, text: "transaction reviews\n1-5 star labels\nrental-platform proof", fontSize: 18, color: C.muted, align: "center" });

  insight(slide, ctx, "Why this is stronger than one source", "The Reddit labels are inferred, so Trustpilot tests whether the same sentiment logic agrees with real ratings before we use it as evidence.", 1016, 292, 222, 218, C.blue);
  footer(slide, ctx, 3);
  return slide;
}

