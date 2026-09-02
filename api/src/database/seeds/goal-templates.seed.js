/**
 * Coffres par defaut proposes aux nouveaux clients pendant l'onboarding
 * (1 a 3 choix max). Les administrateurs peuvent les modifier, en ajouter,
 * desactiver ou reordonner via le back-office : cette liste n'est qu'un
 * amorcage deterministe (upsert par identifiant fixe).
 */
const goalTemplatesSeed = [
  {
    id: '1a2b3c4d-0001-4a01-9c01-000000000001',
    label: 'Ecole & rentree',
    description: 'Frais de scolarite, fournitures et tenues scolaires.',
    iconCodePoint: 0xe80c, // Icons.school (MaterialIcons)
    colorValue: 0xff1565c0,
    defaultTargetAmount: 50000,
    sortOrder: 1,
  },
  {
    id: '1a2b3c4d-0002-4a02-9c02-000000000002',
    label: 'Commerce & stock',
    description: 'Reapprovisionner votre boutique ou votre activite.',
    iconCodePoint: 0xe8d1, // Icons.store (MaterialIcons)
    colorValue: 0xff6a1b9a,
    defaultTargetAmount: 100000,
    sortOrder: 2,
  },
  {
    id: '1a2b3c4d-0003-4a03-9c03-000000000003',
    label: 'Fetes & ceremonies',
    description: 'Mariages, baptêmes, fetes religieuses et evenements.',
    iconCodePoint: 0xe8f6, // Icons.card_giftcard (MaterialIcons)
    colorValue: 0xffb45309,
    defaultTargetAmount: 25000,
    sortOrder: 3,
  },
  {
    id: '1a2b3c4d-0004-4a04-9c04-000000000004',
    label: 'Terre & construction',
    description: 'Achat de terre, matériaux ou travaux de construction.',
    iconCodePoint: 0xe88a, // Icons.home (MaterialIcons)
    colorValue: 0xff2e7d32,
    defaultTargetAmount: 500000,
    sortOrder: 4,
  },
  {
    id: '1a2b3c4d-0005-4a05-9c05-000000000005',
    label: 'Urgences & sante',
    description: 'Imprevus medicaux et depenses urgentes du foyer.',
    iconCodePoint: 0xe8f3, // Icons.healing (MaterialIcons)
    colorValue: 0xffc62828,
    defaultTargetAmount: 20000,
    sortOrder: 5,
  },
];

module.exports = goalTemplatesSeed;
