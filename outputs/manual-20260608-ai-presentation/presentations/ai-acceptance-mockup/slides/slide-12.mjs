import { C, bg, footer, kicker } from "./_shared.mjs";

const recs = [
  ["1", "Keep a human one click away", "Escalation is the strongest recurring trust repair."],
  ["2", "Disclose the AI and its limits", "Accuracy complaints spike when AI overclaims."],
  ["3", "Optimise first-contact resolution", "Support and resolution language drives negativity."],
  ["4", "Match persona to role", "Warmth works for AI products; efficiency wins in transactions."],
  ["5", "Show price and refund rules upfront", "Rental frustration often starts before AI appears."],
];

export async function slide12(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx, C.ink);
  kicker(slide, ctx, "Close", 54, 46, true);
  ctx.addText(slide, {
    x: 54, y: 96, w: 760, h: 96, text: "The design answer: transparent, escapable, role-matched AI.",
    fontSize: 44, bold: true, color: C.paper, typeface: "Aptos Display",
  });
  recs.forEach((r, i) => {
    const y = 232 + i * 78;
    ctx.addShape(slide, { x: 70, y, w: 42, h: 42, fill: i < 3 ? C.orange : C.green });
    ctx.addText(slide, { x: 70, y: y + 7, w: 42, h: 28, text: r[0], fontSize: 18, bold: true, color: C.paper, align: "center" });
    ctx.addText(slide, { x: 132, y: y - 2, w: 440, h: 26, text: r[1], fontSize: 20, bold: true, color: C.paper, typeface: "Aptos Display" });
    ctx.addText(slide, { x: 132, y: y + 28, w: 500, h: 26, text: r[2], fontSize: 14, color: "#D8D2C7" });
  });
  ctx.addShape(slide, { x: 760, y: 240, w: 350, h: 222, fill: "#243038", line: { style: "solid", fill: "#3B4A51", width: 1 } });
  ctx.addText(slide, { x: 790, y: 270, w: 290, h: 28, text: "Say this in Q&A", fontSize: 22, bold: true, color: C.paper, typeface: "Aptos Display" });
  ctx.addText(slide, { x: 790, y: 320, w: 286, h: 116, text: "The broadened AI-native and support contexts are comparison lenses. The rental/sharing-economy finding is the core contribution and is validated with Trustpilot stars.", fontSize: 17, color: "#D8D2C7" });
  ctx.addShape(slide, { x: 760, y: 496, w: 350, h: 62, fill: C.orange });
  ctx.addText(slide, { x: 786, y: 511, w: 300, h: 30, text: "Final thesis: control creates acceptance.", fontSize: 20, bold: true, color: C.paper, align: "center" });
  footer(slide, ctx, 12, true);
  return slide;
}

