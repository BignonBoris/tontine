const env = require('../config/env');
const {
  renderLandingLayout,
  renderHomePage,
  renderPolicyPage,
} = require('./views');

function renderHome(req, res) {
  return res.status(200).send(
    renderLandingLayout({
      title: 'VizioBox — L’épargne qui donne vie à tes projets',
      description:
        "Choisis ton projet. Construis ton objectif. Fais-le avancer avec VizioBox. Tontine digitale, coffres projets et discipline d'épargne.",
      isHome: true,
      content: renderHomePage(),
    }),
  );
}

function renderPrivacy(req, res) {
  return res.status(200).send(
    renderLandingLayout({
      title: 'Politique de confidentialité | VizioBox',
      description:
        "Informations sur la collecte, l'utilisation et la protection des données dans VizioBox.",
      isHome: false,
      content: renderPolicyPage({
        heading: 'Politique de confidentialité',
        intro:
          "VizioBox collecte uniquement les données nécessaires au bon fonctionnement de la plateforme, à la sécurité des opérations financières et à la traçabilité des opérations de tontine et d'épargne.",
        sections: [
          {
            title: 'Données collectées',
            body:
              "Nous pouvons traiter votre nom, prénom, numéro de téléphone, pièces d'identité (KYC), historique des transactions de tontine, approvisionnements et journaux techniques de connexion.",
          },
          {
            title: 'Finalités des traitements',
            body:
              "Ces données servent à gérer vos comptes tontine, vos coffres projets, votre solde disponible, vos opérations avec les agents terrain et la sécurité générale de la plateforme.",
          },
          {
            title: 'Protection et sécurité financière',
            body:
              "Les accès sont strictement contrôlés par chiffrement. Conformément aux standards fintech, toutes les opérations sensibles sont journalisées de manière immuable pour audit et conformité.",
          },
        ],
      }),
    }),
  );
}

function renderTerms(req, res) {
  return res.status(200).send(
    renderLandingLayout({
      title: "Conditions d'utilisation | VizioBox",
      description:
        "Conditions générales d'utilisation de VizioBox pour les clients, agents terrain et administrateurs.",
      isHome: false,
      content: renderPolicyPage({
        heading: "Conditions d'utilisation",
        intro:
          "L'utilisation de la plateforme VizioBox implique l'acceptation pleine et entière des règles de fonctionnement, de la discipline d'épargne et des contrôles de sécurité associés.",
        sections: [
          {
            title: 'Utilisation autorisée',
            body:
              "La plateforme est réservée aux utilisateurs, agents terrain et superviseurs autorisés. Toute tentative de fraude, de contournement ou d'usage abusif entraîne la suspension immédiate du compte.",
          },
          {
            title: 'Opérations financières et immuabilité',
            body:
              "Toutes les opérations sont enregistrées avec une référence unique et ne peuvent pas faire l'objet d'une suppression physique. Toute régularisation s'effectue par annulation ou contrepassation tracée.",
          },
          {
            title: 'Tontines et coffres projets',
            body:
              "L'adhésion à un cycle de tontine ou l'ouverture d'un coffre projet engage l'utilisateur au respect de l'échéancier et des règles de déblocage convenues lors de la souscription.",
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
