import { C, bg, footer, kicker, title, subtitle, insight } from "./_shared.mjs";

const rows = [
  ["trust", "safety, people, stop, relationship, customer, design"],
  ["bot", "contact, question, phone, support, issue, customer"],
  ["human", "real, agent, customer, replace, automation, support"],
  ["host", "guest, Airbnb, platform, communication, Turo, automate"],
  ["automate", "message, guest, set, check, system, send, book"],
];

export async function slide09(presentation, ctx) {
  const slide = presentation.slides.add();
  bg(slide, ctx);
  kicker(slide, ctx, "Embeddings");
  title(slide, ctx, "GloVe independently rediscovers the human-versus-automation tension.", 54, 76, 990, 88);
  subtitle(slide, ctx, "Nearest neighbours show semantic context learned from the corpus, not a hand-built theme dictionary.", 56, 166, 820, 42);
  const x = 74, y = 260, w = 720;
  ctx.addShape(slide, { x, y, w, h: 46, fill: C.ink });
  ctx.addText(slide, { x: x + 22, y: y + 12, w: 160, h: 22, text: "Seed term", fontSize: 14, bold: true, color: C.paper });
  ctx.addText(slide, { x: x + 200, y: y + 12, w: 480, h: 22, text: "Nearest neighbours in corpus", fontSize: 14, bold: true, color: C.paper });
  rows.forEach((r, i) => {
    const yy = y + 46 + i * 62;
    ctx.addShape(slide, { x, y: yy, w, h: 62, fill: i % 2 ? C.white : "#FBF8F1", line: { style: "solid", fill: C.line, width: 1 } });
    ctx.addText(slide, { x: x + 22, y: yy + 17, w: 150, h: 26, text: r[0], fontSize: 18, bold: true, color: i === 2 ? C.orange : C.ink });
    ctx.addText(slide, { x: x + 200, y: yy + 17, w: 480, h: 26, text: r[1], fontSize: 16, color: C.muted });
  });
  insight(slide, ctx, "Why it matters", "The embeddings support the same story from a different method: bot language sits near support/contact, while human sits near real, agent, automation and support.", 866, 276, 282, 184, C.blue);
  insight(slide, ctx, "Class line", "This is the difference between AI as a helpful tool and AI as a barrier in a high-trust transaction.", 866, 486, 282, 116, C.orange);
  footer(slide, ctx, 9);
  return slide;
}

