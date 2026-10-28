/**
 * Page d'accueil VizioBox (landing destinée aux clients).
 * HTML rendu côté serveur. Le seul script (/home.js) pilote le guide
 * d'installation ; sans JavaScript, les liens de téléchargement fonctionnent
 * normalement. Compatible avec la CSP par défaut de helmet. Styles : /home.css.
 */

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const svg = (size, stroke, paths) =>
  `<svg aria-hidden="true" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">${paths}</svg>`;

const icon = {
  download: svg(18, 2.2, '<path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/>'),
  check: svg(18, 2.4, '<path d="m5 12 5 5 9-10"/>'),
  phone: svg(18, 2, '<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>'),
  bars: svg(22, 2, '<path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/>'),
  wallet: svg(22, 2, '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M16 13h2M3 10h18"/>'),
  up: svg(22, 2, '<path d="M12 3v18M5 10l7-7 7 7"/>'),
  star: svg(22, 2, '<path d="m12 3 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.4 6.8 19.1l1-5.8L3.5 9.2l5.9-.9z"/>'),
  people: svg(22, 2, '<circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.5"/><path d="M3 19c0-3 3-5 6-5s6 2 6 5"/><path d="M15 14.5c2.5 0 6 1.3 6 4.5"/>'),
  bag: svg(22, 2, '<path d="M6 7h12l-1 13H7z"/><path d="M9 7a3 3 0 0 1 6 0"/>'),
  qr: svg(22, 2, '<rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2"/>'),
  shield: svg(22, 2, '<path d="M12 3 4 7v5c0 5 3.5 8 8 9 4.5-1 8-4 8-9V7z"/><path d="m9 12 2 2 4-4"/>'),
  lock: svg(20, 2, '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
  receipt: svg(20, 2, '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>'),
  card: svg(20, 2, '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18"/>'),
  agent: svg(20, 2, '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.5 3-6 7-6s7 2.5 7 6"/>'),
  chat: svg(18, 2, '<path d="M4 18.5 5.3 15A8 8 0 1 1 9 18.8z"/>'),
  close: svg(20, 2.2, '<path d="M6 6l12 12M18 6 6 18"/>'),
};

/** 31 barres de cotisations cumulées (une par jour), la dernière en or. */
function renderGrowthBars() {
  return Array.from({ length: 31 }, (_, i) => {
    const height = Math.round(((i + 1) / 31) * 100);
    const color =
      i === 30 ? '#c89818' : `rgba(255,255,255,${(0.18 + (i / 30) * 0.5).toFixed(2)})`;
    return `<i style="height:${height}%;background:${color}"></i>`;
  }).join('');
}

function whatsappHref(number) {
  return `https://wa.me/${String(number).replace(/\D/g, '')}`;
}

/**
 * @param {object} options
 * @param {string} [options.downloadUrl] lien direct de l'APK client (admin › Versions des apps)
 * @param {string} [options.qrDataUrl]   QR code du lien de téléchargement (data:image/png)
 * @param {string} [options.version]     version publiée de l'APK (ex. 1.0.0)
 * @param {object} [options.contact]     { whatsapp, email }
 * @param {object} [options.legal]       { name, registration, address } (affichés seulement s'ils sont renseignés)
 */
function renderHomePage({
  downloadUrl = '',
  qrDataUrl = '',
  version = '',
  contact = {},
  legal = {},
} = {}) {
  const downloadHref = downloadUrl ? escapeHtml(downloadUrl) : '#telecharger';
  // Marque les liens qui déclenchent le guide d'installation (/home.js).
  const downloadAttr = downloadUrl ? ' data-download' : '';
  const year = new Date().getFullYear();
  const whatsapp = contact.whatsapp ? escapeHtml(contact.whatsapp) : '';
  const email = contact.email ? escapeHtml(contact.email) : '';
  const legalName = legal.name ? escapeHtml(legal.name) : '';
  const legalRegistration = legal.registration ? escapeHtml(legal.registration) : '';
  const legalAddress = legal.address ? escapeHtml(legal.address) : '';
  const appMeta = `Application Android${version ? ` · version ${escapeHtml(version)}` : ''}`;

  const faqItems = [
    {
      q: 'Quelle est la mise minimum ?',
      a: 'Vous choisissez votre mise, par multiples de 500&nbsp;F&nbsp;CFA. Un cycle compte 31 mises.',
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
    ...(legalName
      ? [
          {
            q: 'Qui est derrière VizioBox ?',
            a: `VizioBox est édité par ${legalName}${legalRegistration ? ` (${legalRegistration})` : ''}${legalAddress ? `, ${legalAddress}` : ''}.`,
          },
        ]
      : []),
    {
      q: "VizioBox est-il disponible sur iPhone ?",
      a: "Pas encore. VizioBox est pour l'instant disponible sur Android.",
    },
  ];

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
        <a href="#confiance">Votre argent</a>
        <a href="#faq">Questions</a>
      </div>
      <a class="nav-cta" href="${downloadHref}"${downloadAttr}>Télécharger</a>
    </nav>
  </header>

  <section class="container hero" aria-labelledby="hero-title">
    <div class="hero-copy">
      <h1 id="hero-title">La tontine qui donne vie à <em>vos projets.</em></h1>
      <p class="hero-lead">Tontine digitale au Bénin : cotisez à votre rythme, suivez chaque franc et transformez votre épargne en projets concrets. Une machine, un loyer, une rentrée scolaire.</p>
      <div class="hero-actions">
        <a class="btn btn-gold" href="${downloadHref}"${downloadAttr}>${icon.download}Télécharger pour Android</a>
        <a class="btn btn-ghost" href="#comment">Voir comment ça marche</a>
      </div>
      <p class="hero-meta">${icon.phone}<span>Cotisez par <strong>MTN Mobile Money</strong>, <strong>Moov Money</strong>, <strong>Celtiis Cash</strong> ou en espèces auprès d'un agent.</span></p>
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
              <div><small>Disponible</small><strong>48 500</strong></div>
              <div><small>Tontine</small><strong>21 000</strong></div>
              <div><small>Coffres</small><strong>115 000</strong></div>
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
              <div class="goal-row"><span>Machine à coudre</span><span>75 000 F</span></div>
              <div class="bar"><i style="width:62%"></i></div>
            </div>
            <div class="phone-card phone-card-extra">
              <div class="goal-row"><span>Rentrée scolaire</span><span>40 000 F</span></div>
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
        <small>Cycle respecté</small>
        <strong>Bonus de régularité ajouté</strong>
      </div>
    </div>
  </section>
</div>

<main id="contenu">
  <section id="comment" class="container steps" aria-labelledby="steps-title">
    <h2 id="steps-title" class="section-title">De la première mise à votre projet, en trois étapes.</h2>
    <ol class="steps-list">
      <li class="step">
        <span class="step-num" aria-hidden="true">1</span>
        <h3>Créez votre compte</h3>
        <p>Votre numéro, un code reçu par SMS, votre code secret. C'est prêt en une minute.</p>
      </li>
      <li class="step">
        <span class="step-num" aria-hidden="true">2</span>
        <h3>Cotisez à votre rythme</h3>
        <p>Choisissez votre mise, puis payez par Mobile Money ou en espèces auprès d'un agent VizioBox près de chez vous.</p>
      </li>
      <li class="step step-final">
        <span class="step-num" aria-hidden="true">3</span>
        <h3>Réalisez votre projet</h3>
        <p>À la fin du cycle, votre épargne alimente vos coffres, vos achats ou un retrait auprès d'un agent.</p>
      </li>
    </ol>
  </section>

  <section id="tontine" class="container why" aria-labelledby="why-title">
    <div class="why-panel">
      <div class="why-copy">
        <h2 id="why-title" class="section-title">Des petites mises aujourd'hui, un vrai projet demain.</h2>
        <p class="lead">La tontine a fait ses preuves dans nos familles et nos marchés depuis des générations. VizioBox garde ce qu'elle a de meilleur et la rend simple, transparente et sûre.</p>
        <div class="benefits">
          <div class="benefit"><span class="icon-tile">${icon.bars}</span><div><h3>La discipline, sans effort</h3><p>Une mise régulière devient une habitude. Votre épargne avance même les jours où vous n'y pensez pas.</p></div></div>
          <div class="benefit"><span class="icon-tile">${icon.wallet}</span><div><h3>Une somme utile, d'un seul coup</h3><p>Ce qui se serait dispersé en petites dépenses devient une somme pour acheter, développer votre activité ou payer un loyer.</p></div></div>
          <div class="benefit"><span class="icon-tile">${icon.up}</span><div><h3>Sans crédit ni dette</h3><p>Vous avancez avec votre propre argent : pas de dossier, pas d'emprunt à rembourser.</p></div></div>
          <div class="benefit"><span class="icon-tile">${icon.star}</span><div><h3>La régularité récompensée</h3><p>Allez au bout de votre cycle : un bonus de régularité vient s'ajouter à votre solde.</p></div></div>
        </div>
      </div>
      <div class="growth">
        <p class="growth-label">Exemple : 1 000 F CFA par jour</p>
        <p class="growth-amount">31 000 <span>F CFA</span></p>
        <p class="growth-sub">cotisés en un mois, sans y penser</p>
        <div class="growth-bars" role="img" aria-label="Les cotisations passent de 1 000 à 31 000 F CFA en 31 jours">${renderGrowthBars()}</div>
        <div class="growth-axis" aria-hidden="true"><span>Jour 1</span><span>Jour 31</span></div>
      </div>
    </div>
  </section>

  <section id="confiance" class="trust-band" aria-labelledby="trust-title">
    <div class="container trust-inner">
      <div class="trust-copy">
        <h2 id="trust-title" class="section-title">Qui garde votre argent ?</h2>
        <p class="lead">Vos cotisations Mobile Money sont traitées par <strong>FedaPay</strong>, prestataire de paiement. Chaque mouvement est enregistré dans votre application, avec sa référence et l'agent concerné, et reste consultable à tout moment.</p>
        ${
          legalName || whatsapp
            ? `<dl class="identity">
          ${legalName ? `<div><dt>Éditeur</dt><dd>${legalName}${legalRegistration ? `<br><span>${legalRegistration}</span>` : ''}</dd></div>` : ''}
          ${legalAddress ? `<div><dt>Adresse</dt><dd>${legalAddress}</dd></div>` : ''}
          ${whatsapp ? `<div><dt>Support</dt><dd><a href="${whatsappHref(whatsapp)}">WhatsApp ${whatsapp}</a></dd></div>` : ''}
        </dl>`
            : ''
        }
      </div>
      <ul class="proof-list">
        <li>${icon.receipt}<div><h3>Une référence par opération</h3><p>Chaque dépôt et chaque retrait porte sa propre référence, visible dans votre historique.</p></div></li>
        <li>${icon.shield}<div><h3>Un historique jamais effacé</h3><p>Une erreur se corrige par une opération visible, jamais par un effacement.</p></div></li>
        <li>${icon.agent}<div><h3>Des agents identifiés</h3><p>Chaque opération indique quel agent l'a enregistrée, et quand.</p></div></li>
        <li>${icon.lock}<div><h3>Un accès protégé</h3><p>Code PIN et empreinte : l'application se verrouille dès que vous la quittez.</p></div></li>
      </ul>
    </div>
  </section>

  <section id="fonctionnalites" class="container features" aria-labelledby="features-title">
    <h2 id="features-title" class="section-title">Épargnez seul, entre proches, ou pour un objectif précis.</h2>
    <div class="feature-hero">
      <div>
        <h3>Coffres projets</h3>
        <p>Donnez un nom et un objectif à votre épargne. Suivez sa progression jour après jour, jusqu'au bout.</p>
      </div>
      <div class="feature-goals" aria-hidden="true">
        <div class="feature-goal"><div class="goal-row"><span>Machine à coudre</span><span>62 %</span></div><div class="bar"><i style="width:62%"></i></div></div>
        <div class="feature-goal"><div class="goal-row"><span>Loyer</span><span>80 %</span></div><div class="bar"><i style="width:80%"></i></div></div>
      </div>
    </div>
    <ul class="feature-list">
      <li>${icon.people}<div><h3>Tontine entre proches</h3><p>Rejoignez le groupe de vos proches par QR code. Chacun reçoit la cagnotte à son tour, dans un ordre visible par tous.</p></div></li>
      <li>${icon.bag}<div><h3>Marketplace</h3><p>Achetez directement avec votre solde, ou créez un coffre lié à l'article qui vous fait envie.</p></div></li>
      <li>${icon.qr}<div><h3>Retrait par QR code</h3><p>Générez un QR code à usage unique et présentez-le à un agent pour recevoir votre argent.</p></div></li>
      <li>${icon.shield}<div><h3>Identité vérifiée</h3><p>Vérifiez votre identité depuis l'application pour relever vos plafonds de dépôt et de retrait.</p></div></li>
    </ul>
  </section>

  <section class="pay" aria-labelledby="pay-title">
    <div class="container pay-inner">
      <div>
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

  <section id="faq" class="faq" aria-labelledby="faq-title">
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
          <a class="btn btn-gold" href="${downloadHref}"${downloadAttr}>${icon.download}Télécharger pour Android</a>
          ${whatsapp ? `<a class="btn btn-ghost" href="${whatsappHref(whatsapp)}">${icon.chat}Une question ? WhatsApp</a>` : '<a class="btn btn-ghost" href="#faq">Lire les questions</a>'}
        </div>
        <p class="final-meta">${downloadUrl ? appMeta : 'Lien de téléchargement bientôt disponible.'}</p>
      </div>
      ${
        qrDataUrl
          ? `<div class="qr">
        <div class="qr-box"><img src="${qrDataUrl}" width="140" height="140" alt="QR code pour télécharger l'application VizioBox" /></div>
        <small>Sur ordinateur ? Scannez avec votre téléphone</small>
      </div>`
          : ''
      }
    </div>
  </section>
</main>

<footer class="footer">
  <div class="container footer-inner">
    <div class="footer-brand">
      <a class="brand" href="/" aria-label="VizioBox, accueil"><span class="brand-mark" aria-hidden="true">V</span><span class="brand-name">VizioBox</span></a>
      <p>Application de tontine et d'épargne projet.${legalName ? `<br>Éditée par ${legalName}.` : ''}<br>${legalAddress || 'Cotonou, Bénin.'}</p>
    </div>
    <div class="footer-cols">
      <div><strong>Produit</strong><a href="#tontine">La tontine</a><a href="#fonctionnalites">Fonctionnalités</a><a href="#confiance">Votre argent</a></div>
      <div><strong>Légal</strong><a href="/terms">Conditions d'utilisation</a><a href="/privacy">Confidentialité</a></div>
      ${
        whatsapp || email
          ? `<div><strong>Contact</strong>${whatsapp ? `<a href="${whatsappHref(whatsapp)}">WhatsApp ${whatsapp}</a>` : ''}${email ? `<a href="mailto:${email}">${email}</a>` : ''}</div>`
          : ''
      }
    </div>
  </div>
  <p class="container copyright">© ${year} VizioBox. Tous droits réservés.</p>
</footer>
${
  downloadUrl
    ? `<div class="mobile-cta"><a class="btn btn-gold" href="${downloadHref}" data-download>${icon.download}Télécharger pour Android</a></div>
${renderInstallGuide({ downloadHref, qrDataUrl, appMeta, whatsapp })}`
    : ''
}`;
}

/**
 * Fenêtre d'aide affichée au clic sur « Télécharger » (pilotée par /home.js) :
 * - « android » : le téléchargement a démarré, guide d'installation en 3 étapes ;
 * - « ios » : VizioBox n'existe pas encore sur iPhone ;
 * - « other » (ordinateur) : QR code à scanner avec un téléphone Android.
 */
function renderInstallGuide({ downloadHref, qrDataUrl, appMeta, whatsapp }) {
  const steps = [
    {
      title: 'Ouvrez le fichier',
      text: 'Touchez «&nbsp;VizioBox&nbsp;» dans la notification de téléchargement. Si Chrome affiche un avertissement, touchez «&nbsp;Télécharger quand même&nbsp;».',
    },
    {
      title: "Autorisez l'installation",
      text: 'Si Android le demande, touchez «&nbsp;Paramètres&nbsp;» puis activez «&nbsp;Autoriser cette source&nbsp;». C\'est normal pour une application installée hors Play Store.',
    },
    {
      title: 'Installez VizioBox',
      text: 'Touchez «&nbsp;Installer&nbsp;». Si Play Protect affiche un message, touchez «&nbsp;Installer quand même&nbsp;», puis «&nbsp;Ouvrir&nbsp;».',
    },
  ];
  const help = whatsapp
    ? `<a class="guide-help" href="${whatsappHref(whatsapp)}">${icon.chat}Besoin d'aide ? Écrivez-nous sur WhatsApp</a>`
    : '';

  return `
<dialog id="install-guide" class="guide" aria-labelledby="guide-title-android">
  <button type="button" class="guide-close" data-close aria-label="Fermer">${icon.close}</button>

  <div class="guide-variant guide-android">
    <h2 id="guide-title-android">Votre téléchargement démarre</h2>
    <p class="guide-lead">${appMeta}. Encore trois gestes pour l'installer :</p>
    <ol class="guide-steps">
      ${steps
        .map(
          (step, index) => `<li><span class="guide-num" aria-hidden="true">${index + 1}</span><div><h3>${step.title}</h3><p>${step.text}</p></div></li>`,
        )
        .join('\n      ')}
    </ol>
    <div class="guide-actions">
      <button type="button" class="btn btn-gold" data-close>J'ai compris</button>
      <a class="guide-link" href="${downloadHref}">Le téléchargement n'a pas démarré ? Réessayer</a>
      ${help}
    </div>
  </div>

  <div class="guide-variant guide-ios">
    <h2 id="guide-title-ios">Bientôt sur iPhone</h2>
    <p class="guide-lead">VizioBox est pour l'instant disponible sur Android. Un proche équipé d'un téléphone Android peut l'installer en scannant le QR code de cette page.</p>
    <div class="guide-actions">
      <button type="button" class="btn btn-gold" data-close>Fermer</button>
      ${help}
    </div>
  </div>

  <div class="guide-variant guide-other">
    <h2 id="guide-title-other">Installez VizioBox sur votre téléphone</h2>
    <p class="guide-lead">VizioBox est une application Android. Scannez ce QR code avec l'appareil photo de votre téléphone pour la télécharger.</p>
    ${
      qrDataUrl
        ? `<img class="guide-qr" src="${qrDataUrl}" width="200" height="200" alt="QR code pour télécharger l'application VizioBox" />`
        : ''
    }
    <div class="guide-actions">
      <button type="button" class="btn btn-gold" data-close>Fermer</button>
      <a class="guide-link" href="${downloadHref}">Télécharger le fichier sur cet ordinateur</a>
    </div>
  </div>
</dialog>
<script src="/home.js" defer></script>`;
}

module.exports = { renderHomePage };
