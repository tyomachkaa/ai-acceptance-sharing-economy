import { C, bg, footer, kicker, title, subtitle, smallPill } from "./_shared.mjs";

export async function slide02(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Assignment fit");
  title(slide, ctx, "The project meets the brief, with comparison contexts used as guardrails.", 54, 76, 890, 128, false, 37);
  subtitle(slide, ctx, "Present the sharing-economy rental case as the center; AI-native and support contexts explain why acceptance changes by role.", 56, 210, 760, 48);

  const rows = [
    ["Primary data route", "Route 2: scraped/web-collected text", "Reddit archive + Trustpilot reviews"],
    ["Two classes", "Positive vs. negative acceptance", "Reddit inferred by lexicon; Trustpilot from stars"],
    ["Required methods", "Frequency, clouds, networks, sentiment, LDA, embeddings", "All implemented in analysis.R"],
    ["Business synthesis", "Actionable design and marketing implications", "Transparent, escapable, role-matched AI"],
  ];
  const x = 64, y = 286, w = 1110;
  ctx.addShape(slide, { x, y, w, h: 52, fill: C.ink });
  ["Brief requirement", "Our implementation", "What to say in class"].forEach((h, i) => {
    ctx.addText(slide, { x: x + [18, 365, 735][i], y: y + 13, w: [300, 330, 350][i], h: 26, text: h, fontSize: 14, bold: true, color: C.paper });
  });
  rows.forEach((r, i) => {
    const yy = y + 52 + i * 72;
    ctx.addShape(slide, { x, y: yy, w, h: 72, fill: i % 2 ? "#FFFFFF" : "#FBF8F1", line: { style: "solid", fill: C.line, width: 1 } });
    ctx.addText(slide, { x: x + 18, y: yy + 17, w: 300, h: 38, text: r[0], fontSize: 16, bold: true, color: C.ink });
    ctx.addText(slide, { x: x + 365, y: yy + 17, w: 330, h: 36, text: r[1], fontSize: 15, color: C.muted });
    ctx.addText(slide, { x: x + 735, y: yy + 17, w: 350, h: 36, text: r[2], fontSize: 15, color: C.muted });
  });
  smallPill(slide, ctx, "Caveat: Reddit is discussion context, not direct review evidence", 760, 630, 414, C.paper2, C.ink);
  footer(slide, ctx, 2);
  return slide;
}
