import { C, bg, footer, kicker, title, subtitle, figure } from "./_shared.mjs";

function topicBox(slide, ctx, x, y, heading, body, accent) {
  ctx.addShape(slide, { x, y, w: 250, h: 84, fill: C.white, line: { style: "solid", fill: C.line, width: 1 } });
  ctx.addShape(slide, { x, y, w: 5, h: 84, fill: accent });
  ctx.addText(slide, { x: x + 16, y: y + 12, w: 220, h: 22, text: heading, fontSize: 14, bold: true, color: C.ink });
  ctx.addText(slide, { x: x + 16, y: y + 38, w: 220, h: 38, text: body, fontSize: 12.5, color: C.muted });
}

export async function slide08(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Topic modelling");
  title(slide, ctx, "LDA turns thousands of comments into service-design themes.", 54, 76, 940, 112, false, 40);
  subtitle(slide, ctx, "The negative class repeatedly returns to support contact, bots, platform accounts, and host/guest automation.", 56, 198, 780, 44);
  await figure(slide, ctx, "figures/fig_07_lda_negative.png", 54, 244, 710, 400);
  topicBox(slide, ctx, 812, 250, "Negative T1", "Airbnb contact, bots, messages, issues", C.orange);
  topicBox(slide, ctx, 812, 350, "Negative T2", "customer, people, human, bot, call", C.orange);
  topicBox(slide, ctx, 812, 450, "Positive T3", "host, guest, automate, message, review", C.green);
  topicBox(slide, ctx, 812, 550, "Positive T4", "model, Claude, prompt, system, write", C.green);
  footer(slide, ctx, 8);
  return slide;
}
