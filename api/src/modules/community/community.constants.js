/**
 * Assistant Community Manager : referentiels.
 *
 * Les regles de ton et les faits sur VizioBox ne sont PAS ici : ils vivent dans
 * la fiche de marque (system_settings, cle COMMUNITY_BRAND_PROFILE), modifiable
 * depuis l'admin. Ce fichier ne contient que les valeurs par defaut et les
 * contraintes propres a chaque reseau.
 */

const BRAND_PROFILE_SETTING_KEY = 'COMMUNITY_BRAND_PROFILE';

/** Contraintes de format par reseau, transmises telles quelles au modele. */
const NETWORKS = {
  facebook: {
    label: 'Facebook',
    guidance:
      'Publication de page : 40 a 120 mots, accroche des la premiere ligne, paragraphes courts, 1 a 3 emojis maximum, 2 a 4 hashtags en fin de texte.',
  },
  whatsapp: {
    label: 'WhatsApp',
    guidance:
      'Statut ou message de chaine : 20 a 60 mots, ton direct et chaleureux, une seule idee, pas de hashtags, un appel a l action clair.',
  },
  tiktok: {
    label: 'TikTok',
    guidance:
      'Script de video courte (15 a 45 secondes) : decris l accroche des 3 premieres secondes, les plans et le texte a dire, puis une legende courte avec 3 a 5 hashtags.',
  },
  instagram: {
    label: 'Instagram',
    guidance:
      'Legende de publication : 30 a 90 mots, premiere ligne forte, emojis moderes, 5 a 8 hashtags en fin de texte. Decris le visuel attendu.',
  },
  linkedin: {
    label: 'LinkedIn',
    guidance:
      'Publication professionnelle : 80 a 200 mots, angle inclusion financiere, entrepreneuriat ou innovation au Benin, ton expert et sobre, 0 a 1 emoji, 3 hashtags maximum.',
  },
};

const LANGUAGES = {
  fr: { label: 'Francais', guidance: 'Francais simple et clair, compris par le grand public beninois.' },
  fon: {
    label: 'Fongbe',
    guidance:
      'Fongbe (fon) du Benin. Garde en francais les noms propres et les termes techniques sans equivalent courant (VizioBox, Mobile Money, MTN, Moov, Celtiis). Si tu n es pas sur d une tournure, prefere une phrase plus simple.',
  },
};

const POST_KINDS = ['post', 'reply'];

const POST_STATUSES = ['draft', 'approved', 'published', 'archived'];

/** Transitions autorisees ; aucune suppression physique, on archive. */
const STATUS_TRANSITIONS = {
  draft: ['approved', 'archived'],
  approved: ['draft', 'published', 'archived'],
  published: ['archived'],
  archived: ['draft'],
};

const REPLY_CATEGORIES = [
  'question_produit',
  'question_compte',
  'probleme_paiement',
  'plainte',
  'compliment',
  'spam',
  'autre',
];

const REPLY_SENTIMENTS = ['positif', 'neutre', 'negatif'];

const MAX_POSTS_PER_GENERATION = 20;

const DEFAULT_BRAND_PROFILE = {
  brandName: 'VizioBox',
  description:
    'VizioBox est une application mobile de tontine et d epargne au Benin. Le client epargne a son rythme dans sa tontine, cree des coffres pour ses projets et peut cotiser en groupe. Il verse depuis son telephone par Mobile Money ou aupres d un agent collecteur VizioBox.',
  audience:
    'Grand public beninois : commercants, artisans, menages, jeunes actifs, utilisateurs habitues a la tontine traditionnelle.',
  tone:
    'Chaleureux, rassurant, simple, respectueux. On ne tutoie pas : on vouvoie. Jamais condescendant.',
  keyFacts: [
    'Versements par Mobile Money MTN, Moov et Celtiis, directement depuis l application.',
    'Agents collecteurs VizioBox sur le terrain pour les versements en especes.',
    'Application Android a telecharger depuis le site officiel viziobox.net.',
  ],
  forbiddenClaims: [
    'Promettre un rendement, un gain ou un interet.',
    'Garantir un delai de retrait ou de paiement precis.',
    'Inventer une fonctionnalite, un prix, un frais, une promotion ou un chiffre.',
    'Comparer nommement VizioBox a une autre entreprise.',
    'Demander ou citer un code PIN, un mot de passe, un code OTP ou un numero de compte.',
  ],
  supportContact:
    'Pour un probleme sur un compte ou un paiement : ecrire en message prive a la page VizioBox (a completer : numero WhatsApp support).',
  defaultHashtags: ['#VizioBox', '#Tontine', '#Benin'],
};

module.exports = {
  BRAND_PROFILE_SETTING_KEY,
  NETWORKS,
  LANGUAGES,
  POST_KINDS,
  POST_STATUSES,
  STATUS_TRANSITIONS,
  REPLY_CATEGORIES,
  REPLY_SENTIMENTS,
  MAX_POSTS_PER_GENERATION,
  DEFAULT_BRAND_PROFILE,
};
