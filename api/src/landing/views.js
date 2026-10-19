function renderLandingLayout({ title, description, content, isHome = true }) {
  return `<!DOCTYPE html>
<html lang="fr" class="scroll-smooth">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title}</title>
    <meta name="description" content="${description}" />
    <meta property="og:title" content="${title}" />
    <meta property="og:description" content="${description}" />
    <meta property="og:type" content="website" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&display=swap"
      rel="stylesheet"
    />
    <link rel="stylesheet" href="/viziobox.css" />
    ${!isHome ? '<link rel="stylesheet" href="/policy.css" />' : ''}
  </head>
  <body class="antialiased selection:bg-[#c89818]/20 selection:text-[#082040]">
    ${content}
  </body>
</html>`;
}

function renderHomePage() {
  return `
    <div id="root"></div>
    <script type="module" src="/viziobox.js"></script>
    <noscript>
      <div style="padding: 40px; text-align: center; color: #fff; background: #082040; min-height: 100vh;">
        <h1 style="font-family: 'Plus Jakarta Sans', sans-serif; font-size: 2rem; margin-bottom: 16px;">VizioBox</h1>
        <p style="font-family: 'Inter', sans-serif; max-width: 600px; margin: 0 auto; color: rgba(255,255,255,0.7);">
          Votre partenaire d'épargne digitale, tontine et réalisation de projets.
        </p>
      </div>
    </noscript>
  `;
}

function renderPolicyPage({ heading, intro, sections }) {
  const sectionsHtml = sections
    .map(
      (section) => `
        <article class="policy-card">
          <h2>${section.title}</h2>
          <p>${section.body}</p>
        </article>`,
    )
    .join('');

  return `
  <main class="policy-shell">
    <header class="policy-header">
      <div class="policy-nav-container">
        <a href="/" class="policy-brand">
          <div class="policy-brand-badge">V</div>
          <span>VizioBox</span>
        </a>
        <nav class="policy-nav-links">
          <a href="/">Accueil</a>
          <a href="/privacy">Confidentialité</a>
          <a href="/terms">Conditions</a>
        </nav>
      </div>
    </header>

    <div class="policy-container">
      <section class="policy-hero">
        <span class="policy-eyebrow">Informations légales & conformité</span>
        <h1>${heading}</h1>
        <p>${intro}</p>
      </section>

      <div class="policy-content">
        ${sectionsHtml}
      </div>
    </div>

    <footer class="policy-footer">
      <div>
        <span>© ${new Date().getFullYear()} VizioBox. Tous droits réservés.</span>
      </div>
      <div style="margin-top: 10px;">
        <a href="/">Accueil</a> •
        <a href="/privacy">Confidentialité</a> •
        <a href="/terms">Conditions</a>
      </div>
    </footer>
  </main>`;
}

module.exports = {
  renderLandingLayout,
  renderHomePage,
  renderPolicyPage,
};
