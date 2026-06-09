import { C, bg, footer, kicker, title, subtitle, figure, metric } from "./_shared.mjs";

export async function slide06(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Sentiment");
  title(slide, ctx, "The emotional gap is really a trust gap.", 54, 76, 760, 106, false, 40);
  subtitle(slide, ctx, "NRC emotions add nuance beyond the positive/negative split: positive comments show trust, anticipation and joy; negative comments show anger, fear and sadness.", 56, 192, 720, 60);
  metric(slide, ctx, "Trust", "widest visible gap", "the sharing-economy currency", 72, 296, 250, false, C.green);
  metric(slide, ctx, "Anger", "negative-class signal", "where escalation breaks", 72, 422, 250, false, C.orange);
  metric(slide, ctx, "Fear", "negative-class signal", "where safety feels uncertain", 72, 548, 250, false, C.gold);
  await figure(slide, ctx, "figures/fig_05_sentiment_nrc.png", 382, 258, 830, 408);
  footer(slide, ctx, 6);
  return slide;
}
