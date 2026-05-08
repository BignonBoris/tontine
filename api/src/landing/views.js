function renderLandingLayout({ title, description, content }) {
  return `<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title}</title>
    <meta name="description" content="${description}" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&display=swap"
      rel="stylesheet"
    />
    <link rel="stylesheet" href="/landing.css" />
  </head>
  <body>
    ${content}
  </body>
</html>`;
}

function renderHomePage({ docsUrl }) {
  return `
  <main class="landing-shell">
    <header class="topbar">
      <a href="/" class="brand">maTontine</a>
      <nav class="topnav">
        <a href="#features">Fonctionnalites</a>
        <a href="#why">Pourquoi nous</a>
        <a href="#operations">Terrain</a>
        <a href="/docs">API</a>
      </nav>
    </header>

    <section class="hero">
      <div class="hero-copy">
        <span class="eyebrow">Fintech tontine et microfinance</span>
        <h1>
          Une plateforme moderne pour gerer la tontine, les coffres projets et
          la collecte terrain.
        </h1>
        <p>
          maTontine relie vos clients, vos agents et votre supervision
          operationnelle dans un meme systeme fiable, trace et mobile-first.
        </p>
        <div class="hero-actions">
          <a class="btn btn-primary" href="${docsUrl}">Voir la documentation API</a>
          <a class="btn btn-secondary" href="#features">Decouvrir la plateforme</a>
        </div>
        <div class="hero-metrics">
          <div class="metric-card">
            <strong>Clients</strong>
            <span>Gestion client, tontine, coffres et historique</span>
          </div>
          <div class="metric-card">
            <strong>Agents</strong>
            <span>Collecte terrain, depot, prospection et tracabilite</span>
          </div>
          <div class="metric-card">
            <strong>API</strong>
            <span>Backend modulaire pret pour mobile money et supervision</span>
          </div>
        </div>
      </div>
      <div class="hero-panel">
        <div class="hero-panel-card">
          <span class="panel-label">Pilotage</span>
          <h2>Vision claire des flux financiers</h2>
          <ul>
            <li>Tontine et progression de cycle</li>
            <li>Solde disponible et coffres projets</li>
            <li>Historique, notifications et audit</li>
          </ul>
        </div>
        <div class="hero-panel-accent"></div>
      </div>
    </section>

    <section id="features" class="section">
      <div class="section-heading">
        <span class="eyebrow">Fonctionnalites</span>
        <h2>Les briques essentielles pour lancer une tontine serieuse</h2>
      </div>
      <div class="feature-grid">
        ${featureCard(
          'Application client',
          "Tontine, solde disponible, coffres, marketplace et profil dans une experience mobile claire.",
        )}
        ${featureCard(
          'Application agent',
          "Collecte terrain, creation client, depot et suivi du portefeuille agent.",
        )}
        ${featureCard(
          'API metier',
          "API REST securisee, journalisation, regles metier et base de donnees relationnelle.",
        )}
        ${featureCard(
          'Trace et controle',
          "Audit log, references uniques, statuts, notifications et preparation des integrations futures.",
        )}
      </div>
    </section>

    <section id="why" class="section split">
      <div>
        <span class="eyebrow">Pourquoi maTontine</span>
        <h2>Un produit concu pour la realite du terrain.</h2>
      </div>
      <div class="bullet-stack">
        ${bulletRow(
          'Simple pour les clients',
          "Le client comprend ou se trouve son argent, comment il epargne et ce qu'il peut faire maintenant.",
        )}
        ${bulletRow(
          'Operationnel pour les agents',
          "L'agent collecte, inscrit et suit ses operations sans confusion entre portefeuille client et flux globaux.",
        )}
        ${bulletRow(
          'Solide pour la supervision',
          "La plateforme prepare la suite : administration, provisioning reel, mobile money et reporting.",
        )}
      </div>
    </section>

    <section id="operations" class="section operations-panel">
      <div class="operations-copy">
        <span class="eyebrow">Collecte terrain</span>
        <h2>Une chaine plus propre entre depot, tontine et supervision.</h2>
        <p>
          Les flux entrants ne sont plus confondus avec les mouvements internes.
          Les agents alimentent les clients via des operations tracees, pendant
          que les clients utilisent ensuite leur solde disponible pour financer
          leurs objectifs.
        </p>
      </div>
      <div class="operations-cards">
        <div class="operation-card">
          <strong>1. Provisioning</strong>
          <span>Operation initiee par agent ou canal autorise.</span>
        </div>
        <div class="operation-card">
          <strong>2. Solde disponible</strong>
          <span>Source de fonds claire pour la tontine et les coffres.</span>
        </div>
        <div class="operation-card">
          <strong>3. Audit</strong>
          <span>Toutes les actions critiques restent journalisees.</span>
        </div>
      </div>
    </section>

    <section class="section cta-section">
      <div class="cta-card">
        <div>
          <span class="eyebrow">Pret pour la suite</span>
          <h2>Une base MVP solide pour grandir proprement.</h2>
          <p>
            Explorez la documentation technique actuelle ou preparez la phase
            suivante : landing enrichie, admin web et integrations externes.
          </p>
        </div>
        <div class="cta-actions">
          <a class="btn btn-primary" href="${docsUrl}">Swagger API</a>
          <a class="btn btn-secondary" href="/privacy">Confidentialite</a>
          <a class="btn btn-secondary" href="/terms">Conditions</a>
        </div>
      </div>
    </section>

    <footer class="footer">
      <span>© maTontine</span>
      <div class="footer-links">
        <a href="/privacy">Confidentialite</a>
        <a href="/terms">Conditions</a>
        <a href="/docs">Documentation</a>
      </div>
    </footer>
  </main>`;
}

function renderPolicyPage({ heading, intro, sections }) {
  const sectionsHtml = sections
    .map(
      (section) => `
        <section class="policy-section">
          <h2>${section.title}</h2>
          <p>${section.body}</p>
        </section>`,
    )
    .join('');

  return `
  <main class="landing-shell policy-shell">
    <header class="topbar">
      <a href="/" class="brand">maTontine</a>
      <nav class="topnav">
        <a href="/">Accueil</a>
        <a href="/privacy">Confidentialite</a>
        <a href="/terms">Conditions</a>
      </nav>
    </header>
    <section class="policy-hero">
      <span class="eyebrow">Informations legales</span>
      <h1>${heading}</h1>
      <p>${intro}</p>
    </section>
    <div class="policy-content">
      ${sectionsHtml}
    </div>
  </main>`;
}

function featureCard(title, body) {
  return `
    <article class="feature-card">
      <h3>${title}</h3>
      <p>${body}</p>
    </article>`;
}

function bulletRow(title, body) {
  return `
    <article class="bullet-row">
      <div class="bullet-dot"></div>
      <div>
        <h3>${title}</h3>
        <p>${body}</p>
      </div>
    </article>`;
}

module.exports = {
  renderLandingLayout,
  renderHomePage,
  renderPolicyPage,
};
