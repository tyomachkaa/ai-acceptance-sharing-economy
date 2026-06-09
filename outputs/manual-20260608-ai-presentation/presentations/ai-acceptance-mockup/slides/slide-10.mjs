import { C, bg, footer, kicker, title, subtitle, figure, metric } from "./_shared.mjs";

export async function slide10(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Validation");
  title(slide, ctx, "Trustpilot gives the sentiment split a reality check.", 54, 76, 870, 86);
  subtitle(slide, ctx, "Reddit has no ground-truth label, so the same lexicon logic is tested against Trustpilot stars.", 56, 166, 820, 44);
  metric(slide, ctx, "93.4%", "agreement", "lexicon class vs star class", 68, 268, 250, false, C.blue);
  metric(slide, ctx, "0.76", "Cohen's kappa", "substantial agreement", 68, 392, 250, false, C.green);
  metric(slide, ctx, "3,534", "validation reviews", "neutral labels removed", 68, 516, 250, false, C.gold);
  await figure(slide, ctx, "figures/fig_08_validity.png", 386, 246, 640, 416);
  ctx.addText(slide, { x: 1054, y: 312, w: 164, h: 126, text: "Use this to defend the Reddit labels as directional, not perfect.", fontSize: 20, bold: true, color: C.ink, typeface: "Aptos Display" });
  footer(slide, ctx, 10);
  return slide;
}

