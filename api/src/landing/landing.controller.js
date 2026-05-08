const env = require('../config/env');
const {
  renderLandingLayout,
  renderHomePage,
  renderPolicyPage,
} = require('./views');

function renderHome(req, res) {
  return res.status(200).send(
    renderLandingLayout({
      title: 'maTontine | Epargne, tontine et collecte terrain',
      description:
        "maTontine simplifie la gestion de la tontine, des coffres projets et de la collecte terrain pour les clients et les agents.",
      content: renderHomePage({
        docsUrl: `${env.appBaseUrl}/docs`,
      }),
    }),
  );
}

function renderPrivacy(req, res) {
  return res.status(200).send(
    renderLandingLayout({
      title: 'Politique de confidentialite | maTontine',
      description:
        "Informations sur la collecte, l'utilisation et la protection des donnees dans maTontine.",
      content: renderPolicyPage({
        heading: 'Politique de confidentialite',
        intro:
          "Cette version MVP de maTontine collecte uniquement les donnees necessaires au fonctionnement de la plateforme, a la securite des operations et a la tracabilite des actions.",
        sections: [
          {
            title: 'Donnees collectees',
            body:
              "Nous pouvons traiter votre nom, numero de telephone, informations de profil, historique des operations et journaux techniques de connexion.",
          },
          {
            title: 'Finalites',
            body:
              "Ces donnees servent a gerer vos comptes tontine, vos soldes, vos interactions avec les agents et la securite generale du service.",
          },
          {
            title: 'Protection',
            body:
              "Les acces sont controles, les actions sensibles sont tracees et les traitements financiers restent journalises pour audit.",
          },
        ],
      }),
    }),
  );
}

function renderTerms(req, res) {
  return res.status(200).send(
    renderLandingLayout({
      title: "Conditions d'utilisation | maTontine",
      description:
        "Conditions generales d'utilisation de maTontine pour les clients, agents et administrateurs.",
      content: renderPolicyPage({
        heading: "Conditions d'utilisation",
        intro:
          "L'utilisation de maTontine implique l'acceptation des regles de fonctionnement de la plateforme, de la tracabilite des operations et des controles de securite associes.",
        sections: [
          {
            title: 'Utilisation autorisee',
            body:
              "La plateforme est reservee aux utilisateurs, agents et administrateurs autorises. Toute tentative de fraude, de contournement ou d'usage abusif peut entrainer une suspension.",
          },
          {
            title: 'Operations financieres',
            body:
              "Les operations sont enregistrees avec references uniques et ne peuvent pas etre supprimees. Toute correction passe par annulation ou contrepassation.",
          },
          {
            title: 'Evolution du service',
            body:
              "Le produit est en evolution. Certaines fonctionnalites peuvent etre ameliorees, restreintes ou etendues sans remise en cause des obligations de securite et de conformite.",
          },
        ],
      }),
    }),
  );
}

module.exports = {
  renderHome,
  renderPrivacy,
  renderTerms,
};
