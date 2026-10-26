/**
 * Page d'accueil VizioBox (landing destinée aux clients).
 * HTML rendu côté serveur, sans JavaScript : rapide sur mobile et compatible
 * avec la CSP par défaut de helmet. Styles : /home.css.
 */

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const icon = {
  download:
    '<svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/></svg>',
  check:
    '<svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 5 5 9-10"/></svg>',
  list: '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M4 12h16M4 17h10"/></svg>',
  clock:
    '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 8v5l3 2"/><circle cx="12" cy="12" r="9"/></svg>',
  lock: '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>',
  card: '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18"/></svg>',
  bars: '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/></svg>',
  wallet:
    '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M16 13h2M3 10h18"/></svg>',
  up: '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18M5 10l7-7 7 7"/></svg>',
  star: '<svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.4 6.8 19.1l1-5.8L3.5 9.2l5.9-.9z"/></svg>',
  people:
    '<svg aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.5"/><path d="M3 19c0-3 3-5 6-5s6 2 6 5"/><path d="M15 14.5c2.5 0 6 1.3 6 4.5"/></svg>',
  bag: '<svg aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 7h12l-1 13H7z"/><path d="M9 7a3 3 0 0 1 6 0"/></svg>',
  qr: '<svg aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2"/></svg>',
  shield:
    '<svg aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 4 7v5c0 5 3.5 8 8 9 4.5-1 8-4 8-9V7z"/><path d="m9 12 2 2 4-4"/></svg>',
};

/** 31 barres d'épargne cumulée (une par jour), la dernière en or. */
function renderGrowthBars() {
  return Array.from({ length: 31 }, (_, i) => {
    const height = Math.round(((i + 1) / 31) * 100);
    const color =
      i === 30 ? '#c89818' : `rgba(255,255,255,${(0.18 + (i / 30) * 0.5).toFixed(2)})`;
    return `<i style="height:${height}%;background:${color}"></i>`;
  }).join('');
}

const faqItems = [
  {
    q: 'Quelle est la mise minimum ?',
    a: 'Vous choisissez votre mise, par multiples de 500 F CFA. Un cycle compte 31 mises.',
  },
  {
    q: 'Combien coûte VizioBox ?',
    a: 'Une seule mise par cycle, prélevée à la clôture comme frais. Aucuns frais cachés.',
  },
  {
    q: 'Puis-je arrêter ma tontine avant la fin ?',
    a: 'Oui. Le montant épargné est reversé sur votre solde disponible, moins une mise.',
  },
  {
    q: 'Comment retirer mon argent ?',
    a: "Demandez un retrait dans l'application, puis présentez votre QR code à un agent VizioBox.",
  },
  {
    q: 'Mes données sont-elles protégées ?',
    a: 'Votre compte est protégé par code PIN et empreinte, et chaque opération est tracée.',
  },
];

/**
 * @param {object} options
 * @param {string} [options.downloadUrl] lien direct de l'APK client (admin › Versions des apps)
 * @param {string} [options.qrDataUrl]   QR code du lien de téléchargement (data:image/png)
 * @param {object} [options.contact]     { whatsapp, email }
 */
function renderHomePage({ downloadUrl = '', qrDataUrl = '', contact = {} } = {}) {
  const downloadHref = downloadUrl ? escapeHtml(downloadUrl) : '#telecharger';
  const year = new Date().getFullYear();
  const whatsapp = contact.whatsapp ? escapeHtml(contact.whatsapp) : '';
  const email = contact.email ? escapeHtml(contact.email) : '';

  return `
<a class="skip-link" href="#contenu">Aller au contenu</a>

<div class="hero-band">
  <header class="container">
    <nav class="nav" aria-label="Navigation principale">
      <a class="brand" href="/" aria-label="VizioBox, accueil">
        <span class="brand-mark" aria-hidden="true">V</span>
        <span class="brand-name">VizioBox</span>
      </a>
      <div class="nav-links">
        <a href="#comment">Comment ça marche</a>
        <a href="#tontine">La tontine</a>
        <a href="#fonctionnalites">Fonctionnalités</a>
        <a href="#securite">Sécurité</a>
        <a href="#faq">Questions</a>
      </div>
      <a class="nav-cta" href="${downloadHref}">Télécharger l'app</a>
    </nav>
  </header>

  <section class="container hero" aria-labelledby="hero-title">
    <div class="hero-copy">
      <p class="pill"><span class="pill-dot" aria-hidden="true"></span>Tontine digitale · Bénin</p>
      <h1 id="hero-title">La tontine qui donne vie à <em>vos projets.</em></h1>
      <p class="hero-lead">Cotisez à votre rythme, suivez chaque franc en temps réel et transformez votre épargne en projets concrets : une machine, un loyer, une rentrée scolaire.</p>
      <div class="hero-actions">
        <a class="btn btn-gold" href="${downloadHref}">${icon.download}Télécharger pour Android</a>
        <a class="btn btn-ghost" href="#comment">Voir comment ça marche</a>
      </div>
      <div class="pay-row">
        <span class="pay-row-label">Cotisez avec</span>
        <span class="pay-chip">MTN Mobile Money</span>
        <span class="pay-chip">Moov Money</span>
        <span class="pay-chip">Celtiis Cash</span>
        <span class="pay-chip">Espèces via un agent</span>
      </div>
    </div>

    <div class="hero-visual" aria-hidden="true">
      <span class="ring ring-2"></span>
      <span class="ring ring-1"></span>
      <div class="phone">
        <div class="phone-screen">
          <div class="phone-head">
            <p class="phone-hello">Bonjour Awa</p>
            <p class="phone-label">Solde total</p>
            <p class="phone-total">184 500 <span>F CFA</span></p>
            <div class="phone-split">
              <div><small>Disponible</small><strong>48 500 F</strong></div>
              <div><small>En tontine</small><strong>21 000 F</strong></div>
            </div>
          </div>
          <div class="phone-body">
            <div class="phone-card phone-tontine">
              <span class="donut"></span>
              <div><strong>Ma tontine</strong><small>21 mises sur 31</small></div>
              <b>68 %</b>
            </div>
            <p class="phone-section">Mes coffres</p>
            <div class="phone-card">
              <div class="goal-row"><span>Machine à coudre</span><span>62 %</span></div>
              <div class="bar"><i style="width:62%"></i></div>
            </div>
            <div class="phone-card">
              <div class="goal-row"><span>Rentrée scolaire</span><span>35 %</span></div>
              <div class="bar"><i style="width:35%"></i></div>
            </div>
          </div>
        </div>
      </div>
      <div class="float-card float-deposit">
        <span class="tick">${icon.check}</span>
        <span><strong>Dépôt reçu · 1 000 F</strong><small>MTN Mobile Money · réf. VZB-0123</small></span>
      </div>
      <div class="float-card float-bonus">
        <small>Bonus de régularité</small>
        <strong>+ cycle respecté</strong>
      </div>
    </div>
  </section>
</div>

<main id="contenu">
  <section class="trust" aria-label="Nos engagements">
    <div class="container trust-grid">
      <p class="trust-item">${icon.list}Une référence unique pour chaque opération</p>
      <p class="trust-item">${icon.clock}Historique complet, rien n'est jamais effacé</p>
      <p class="trust-item">${icon.lock}Accès protégé par code PIN et empreinte</p>
      <p class="trust-item">${icon.card}Paiements Mobile Money sécurisés</p>
    </div>
  </section>

  <section id="comment" class="container steps" aria-labelledby="steps-title">
    <p class="eyebrow">Comment ça marche</p>
    <h2 id="steps-title" class="section-title">De la première mise à votre projet, en trois étapes.</h2>
    <div class="grid-3">
      <article class="card">
        <p class="step-num" aria-hidden="true">01</p>
        <h3>Créez votre compte</h3>
        <p>Votre numéro, un code reçu par SMS, votre code secret. C'est prêt en une minute.</p>
      </article>
      <article class="card">
        <p class="step-num" aria-hidden="true">02</p>
        <h3>Cotisez à votre rythme</h3>
        <p>Choisissez votre mise, puis payez par Mobile Money ou en espèces auprès d'un agent VizioBox près de chez vous.</p>
      </article>
      <article class="card card-dark">
        <p class="step-num" aria-hidden="true">03</p>
        <h3>Réalisez votre projet</h3>
        <p>À la fin du cycle, votre épargne alimente vos coffres, vos achats ou un retrait auprès d'un agent.</p>
      </article>
    </div>
  </section>

  <section id="tontine" class="container why" aria-labelledby="why-title">
    <div class="why-panel">
      <div class="why-copy">
        <p class="eyebrow">Pourquoi la tontine</p>
        <h2 id="why-title" class="section-title">Des petites mises aujourd'hui, un vrai projet demain.</h2>
        <p class="lead">La tontine a fait ses preuves dans nos familles et nos marchés depuis des générations. VizioBox garde ce qu'elle a de meilleur et la rend simple, transparente et sûre.</p>
        <div class="benefits">
          <div class="benefit"><span class="icon-tile">${icon.bars}</span><div><h3>La discipline, sans effort</h3><p>Une mise régulière devient une habitude. Votre épargne avance même les jours où vous n'y pensez pas.</p></div></div>
          <div class="benefit"><span class="icon-tile">${icon.wallet}</span><div><h3>Une somme utile, d'un seul coup</h3><p>Ce qui se serait dispersé en petites dépenses devient une somme qui permet d'acheter, d'investir dans son activité, de payer un loyer.</p></div></div>
          <div class="benefit"><span class="icon-tile">${icon.up}</span><div><h3>Sans crédit ni dette</h3><p>Vous avancez avec votre propre argent : pas de dossier, pas d'emprunt à rembourser.</p></div></div>
          <div class="benefit"><span class="icon-tile">${icon.star}</span><div><h3>La régularité récompensée</h3><p>Allez au bout de votre cycle : un bonus de régularité vient s'ajouter à votre solde.</p></div></div>
        </div>
      </div>
      <div class="growth">
        <p class="growth-label">Exemple : 1 000 F CFA par jour</p>
        <p class="growth-amount">31 000 <span>F CFA</span></p>
        <p class="growth-sub">épargnés en un mois, sans y penser</p>
        <div class="growth-bars" role="img" aria-label="L'épargne grandit chaque jour pendant 31 jours">${renderGrowthBars()}</div>
        <div class="growth-axis" aria-hidden="true"><span>Jour 1</span><span>Jour 31</span></div>
      </div>
    </div>
  </section>

  <section id="fonctionnalites" class="container features" aria-labelledby="features-title">
    <p class="eyebrow">Tout en une application</p>
    <h2 id="features-title" class="section-title">Épargnez seul, entre proches, ou pour un objectif précis.</h2>
    <div class="bento">
      <article class="feature-hero wide">
        <div>
          <h3>Coffres projets</h3>
          <p>Donnez un nom et un objectif à votre épargne. Suivez sa progression jour après jour, jusqu'au bout.</p>
        </div>
        <div class="feature-goals" aria-hidden="true">
          <div class="feature-goal"><div class="goal-row"><span>Machine à coudre</span><span>62 %</span></div><div class="bar"><i style="width:62%"></i></div></div>
          <div class="feature-goal"><div class="goal-row"><span>Loyer</span><span>80 %</span></div><div class="bar"><i style="width:80%"></i></div></div>
        </div>
      </article>
      <article class="card"><span class="icon-tile lg">${icon.people}</span><h3>Tontine entre proches</h3><p>Rejoignez le groupe de vos proches par QR code. L'ordre des tours est clair, visible par tous.</p></article>
      <article class="card"><span class="icon-tile lg">${icon.bag}</span><h3>Marketplace</h3><p>Achetez directement avec votre solde, ou créez un coffre lié à l'article qui vous fait envie.</p></article>
      <article class="card"><span class="icon-tile lg">${icon.qr}</span><h3>Retrait par QR code</h3><p>Générez un QR code à usage unique et présentez-le à un agent pour recevoir votre argent.</p></article>
      <article class="card card-gold"><span class="icon-tile lg">${icon.shield}</span><h3>Identité vérifiée</h3><p>Vérifiez votre identité depuis l'application pour relever vos plafonds en toute sécurité.</p></article>
    </div>
  </section>

  <section class="pay" aria-labelledby="pay-title">
    <div class="container pay-inner">
      <div>
        <p class="eyebrow">Cotiser</p>
        <h2 id="pay-title" class="section-title">Depuis votre téléphone ou au coin de la rue.</h2>
        <p class="lead">Payez votre cotisation par Mobile Money en quelques secondes, ou remettez vos espèces à l'agent VizioBox de votre quartier. Dans les deux cas, le dépôt s'affiche aussitôt dans votre application, avec sa référence.</p>
      </div>
      <div class="pay-grid">
        <div class="pay-tile"><small>Mobile Money</small><strong>MTN Mobile Money</strong></div>
        <div class="pay-tile"><small>Mobile Money</small><strong>Moov Money</strong></div>
        <div class="pay-tile"><small>Mobile Money</small><strong>Celtiis Cash</strong></div>
        <div class="pay-tile dark"><small>En espèces</small><strong>Agent VizioBox</strong></div>
      </div>
    </div>
  </section>

  <section id="securite" class="security" aria-labelledby="security-title">
    <div class="container security-inner">
      <p class="eyebrow">Sécurité et transparence</p>
      <h2 id="security-title" class="section-title">Chaque franc est tracé. Rien n'est jamais effacé.</h2>
      <div class="grid-4">
        <article class="sec-card"><h3>Code PIN et empreinte</h3><p>L'application se verrouille dès que vous la quittez.</p></article>
        <article class="sec-card"><h3>Références uniques</h3><p>Chaque dépôt et chaque retrait porte sa propre référence.</p></article>
        <article class="sec-card"><h3>Historique intact</h3><p>Une erreur se corrige par une opération visible, jamais par un effacement.</p></article>
        <article class="sec-card"><h3>Agents identifiés</h3><p>Chaque opération indique quel agent l'a enregistrée, et quand.</p></article>
      </div>
    </div>
  </section>

  <section id="faq" class="faq" aria-labelledby="faq-title">
    <p class="eyebrow">Questions fréquentes</p>
    <h2 id="faq-title" class="section-title">Tout ce qu'il faut savoir avant de commencer.</h2>
    <div class="faq-list">
      ${faqItems
        .map(
          (item, index) => `<details${index === 0 ? ' open' : ''}><summary>${item.q}</summary><p>${item.a}</p></details>`,
        )
        .join('\n      ')}
    </div>
  </section>

  <section id="telecharger" class="container final" aria-labelledby="final-title">
    <div class="final-panel">
      <div>
        <h2 id="final-title">Votre projet mérite de commencer <em>aujourd'hui.</em></h2>
        <p class="hero-lead">Téléchargez VizioBox et faites votre première mise en quelques minutes.</p>
        <div class="hero-actions">
          <a class="btn btn-gold" href="${downloadHref}">${icon.download}Télécharger pour Android</a>
          <a class="btn btn-ghost" href="#faq">Lire les questions</a>
        </div>
      </div>
      <div class="qr">
        <div class="qr-box">${
          qrDataUrl
            ? `<img src="${qrDataUrl}" width="140" height="140" alt="QR code pour télécharger l'application VizioBox" />`
            : 'Lien de téléchargement bientôt disponible'
        }</div>
        <small>${qrDataUrl ? 'Scannez pour télécharger' : 'Application Android'}</small>
      </div>
    </div>
  </section>
</main>

<footer class="footer">
  <div class="container footer-inner">
    <div class="footer-brand">
      <a class="brand" href="/" aria-label="VizioBox, accueil"><span class="brand-mark" aria-hidden="true">V</span><span class="brand-name">VizioBox</span></a>
      <p>Application de tontine et d'épargne projet. Cotonou, Bénin.</p>
    </div>
    <div class="footer-cols">
      <div><strong>Produit</strong><a href="#tontine">La tontine</a><a href="#fonctionnalites">Fonctionnalités</a><a href="#securite">Sécurité</a></div>
      <div><strong>Légal</strong><a href="/terms">Conditions d'utilisation</a><a href="/privacy">Confidentialité</a></div>
      ${
        whatsapp || email
          ? `<div><strong>Contact</strong>${whatsapp ? `<a href="https://wa.me/${whatsapp.replace(/\D/g, '')}">WhatsApp ${whatsapp}</a>` : ''}${email ? `<a href="mailto:${email}">${email}</a>` : ''}</div>`
          : ''
      }
    </div>
  </div>
  <p class="container copyright">© ${year} VizioBox. Tous droits réservés.</p>
</footer>`;
}

module.exports = { renderHomePage };
