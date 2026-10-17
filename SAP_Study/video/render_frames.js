// Screenshot every frame HTML listed in jobs.json at 1920x1080.
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  for (const png of jobs.files) {
    const html = path.join(jobs.dir, png.replace(".png", ".html"));
    await page.goto("file://" + html);
    await page.screenshot({ path: path.join(jobs.dir, png) });
  }
  await browser.close();
})();
