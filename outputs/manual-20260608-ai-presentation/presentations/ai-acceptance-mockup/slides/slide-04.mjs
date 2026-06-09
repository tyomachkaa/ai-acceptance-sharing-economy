import { C, bg, footer, kicker, title, subtitle } from "./_shared.mjs";

const steps = [
  ["1", "Clean", "lowercase, remove punctuation/numbers/stop words, lemmatise"],
  ["2", "Explore", "top words, commonality cloud, comparison clouds"],
  ["3", "Structure", "bigram network + NRC emotions"],
  ["4", "Model", "LDA topics + GloVe neighbours"],
  ["5", "Validate", "compare inferred class with Trustpilot stars"],
  ["6", "Synthesize", "role gradient + strategic recommendations"],
];

export async function slide04(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Method stack");
  title(slide, ctx, "The analysis pipeline covers the brief and ends in a decision rule.");
  subtitle(slide, ctx, "Each method has a role: describe the vocabulary, reveal structure, test sentiment, and translate findings into AI-agent design.", 56, 176, 830, 50);

  steps.forEach((s, i) => {
    const x = 68 + i * 192;
    ctx.addShape(slide, { x, y: 310, w: 140, h: 178, fill: i < 4 ? C.white : C.ink, line: { style: "solid", fill: i < 4 ? C.line : C.ink, width: 1 } });
    ctx.addText(slide, { x: x + 18, y: 326, w: 40, h: 34, text: s[0], fontSize: 28, bold: true, color: i < 4 ? C.orange : C.paper });
    ctx.addText(slide, { x: x + 18, y: 372, w: 104, h: 26, text: s[1], fontSize: 18, bold: true, color: i < 4 ? C.ink : C.paper });
    ctx.addText(slide, { x: x + 18, y: 410, w: 106, h: 58, text: s[2], fontSize: 11.5, color: i < 4 ? C.muted : "#D8D2C7" });
    if (i < steps.length - 1) {
      ctx.addShape(slide, { x: x + 148, y: 379, w: 44, h: 4, fill: C.orange });
      ctx.addShape(slide, { x: x + 188, y: 373, w: 12, h: 12, fill: C.orange });
    }
  });
  ctx.addShape(slide, { x: 270, y: 548, w: 734, h: 60, fill: C.paper2, line: { style: "solid", fill: C.line, width: 1 } });
  ctx.addText(slide, { x: 300, y: 562, w: 674, h: 34, text: "Presentation hook: methods become evidence for when users accept AI agents.", fontSize: 17, bold: true, color: C.ink, align: "center" });
  footer(slide, ctx, 4);
  return slide;
}
