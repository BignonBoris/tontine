// Installe Chrome pour whatsapp-web.js (Render / Docker / local).
// Ignoré sur Vercel : le binaire (~170 Mo) ferait dépasser la limite de taille des fonctions.
if (process.env.VERCEL) {
  console.log('[install-chrome] Vercel détecté : installation de Chrome ignorée.');
  process.exit(0);
}
require('node:child_process').execSync('npx puppeteer browsers install chrome', {
  stdio: 'inherit',
});
