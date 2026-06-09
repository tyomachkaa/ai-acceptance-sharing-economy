import { C, bg, footer, kicker, title, subtitle, figure, insight } from "./_shared.mjs";

export async function slide07(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Word network");
  title(slide, ctx, "The network exposes the human-exit problem.", 54, 76, 850, 108, false, 40);
  subtitle(slide, ctx, "Bigrams show which words travel together, revealing the structure behind isolated frequency counts.", 56, 192, 760, 42);
  await figure(slide, ctx, "figures/fig_06_network.png", 64, 238, 820, 402);
  insight(slide, ctx, "Reading the network", "Contact, support, customer, bot, human, real and person cluster around the same failure mode: users want a real route out when automation cannot solve the case.", 920, 258, 246, 196, C.blue);
  insight(slide, ctx, "Slide note", "For the final deck, export this chart with a white background and slightly larger labels if it will be projected in a bright room.", 920, 480, 246, 138, C.orange);
  footer(slide, ctx, 7);
  return slide;
}
