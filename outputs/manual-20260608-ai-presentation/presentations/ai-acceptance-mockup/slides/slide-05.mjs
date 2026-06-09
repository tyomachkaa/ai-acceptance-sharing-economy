import { C, bg, footer, kicker, title, subtitle, figure, insight } from "./_shared.mjs";

export async function slide05(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Vocabulary split");
  title(slide, ctx, "Positive text praises useful automation; negative text gets stuck at contact friction.", 54, 76, 1030, 92);
  subtitle(slide, ctx, "Top words make the acceptance contrast visible before the more advanced models.", 56, 176, 750, 36);
  await figure(slide, ctx, "figures/fig_01_top_words.png", 58, 230, 792, 420);
  insight(slide, ctx, "What to say", "Automation is not automatically bad. The positive class also mentions automation, message, support and checks. The difference is whether automation saves time or blocks resolution.", 892, 256, 278, 214, C.green);
  insight(slide, ctx, "Classroom caveat", "Airbnb and Turo dominate the rental language, so frame professional gear platforms as part of the broader sharing-economy marketplace sample.", 892, 492, 278, 138, C.orange);
  footer(slide, ctx, 5);
  return slide;
}

