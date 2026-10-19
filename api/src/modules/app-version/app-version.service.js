/**
 * App Version Service
 * Informations de version des applications mobiles (agent et client),
 * utilisées pour proposer ou imposer une mise à jour de l'APK hors Play Store.
 *
 * Source de vérité, par ordre de priorité :
 *   1. table `system_settings` (clés APP_VERSION_AGENT / APP_VERSION_CLIENT),
 *      modifiable depuis l'admin (PUT /api/v1/admin/settings/:key) sans redéploiement ;
 *   2. variables d'environnement (AGENT_APP_* / CLIENT_APP_*) ;
 *   3. valeurs par défaut neutres (build 0 = aucune mise à jour proposée).
 *
 * Champs :
 *   version        chaîne lisible affichée dans la fenêtre (ex. "1.0.1")
 *   build          entier, doit être égal au numéro après "+" dans pubspec.yaml
 *   min_build      tout build installé < min_build doit obligatoirement se mettre à jour
 *   mandatory      true = la mise à jour vers `build` est obligatoire
 *   download_url   lien direct vers l'APK (vide = aucune mise à jour proposée)
 *   release_notes  texte « Nouveautés »
 *   released_at    date de publication (AAAA-MM-JJ)
 */
const { models } = require('../../database/models');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');

const APPS = {
  agent: { settingKey: 'APP_VERSION_AGENT', envPrefix: 'AGENT_APP' },
  client: { settingKey: 'APP_VERSION_CLIENT', envPrefix: 'CLIENT_APP' },
};

function toInt(value, fallback = 0) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

function toBool(value) {
  return value === true || value === 'true' || value === 1 || value === '1';
}

function fromEnv(prefix) {
  const read = (name) => process.env[`${prefix}_${name}`];
  return {
    version: read('VERSION'),
    build: read('BUILD'),
    min_build: read('MIN_BUILD'),
    mandatory: read('MANDATORY'),
    download_url: read('DOWNLOAD_URL'),
    release_notes: read('RELEASE_NOTES'),
    released_at: read('RELEASED_AT'),
  };
}

async function fromSettings(settingKey) {
  try {
    const setting = await models.SystemSetting.findByPk(settingKey);
    if (!setting) return {};
    const value =
      typeof setting.value === 'string' ? JSON.parse(setting.value) : setting.value;
    return value && typeof value === 'object' ? value : {};
  } catch (error) {
    // Une base indisponible ne doit pas casser la vérification : on retombe sur l'env.
    console.error('[app-version] Lecture system_settings impossible:', error.message);
    return {};
  }
}

/**
 * Retourne les informations de version normalisées d'une application.
 * @param {'agent'|'client'} app
 */
async function getAppVersion(app) {
  const config = APPS[app];
  if (!config) {
    throw new AppError("Application inconnue. Valeurs acceptées : 'agent', 'client'.", 404);
  }

  const env = fromEnv(config.envPrefix);
  const db = await fromSettings(config.settingKey);
  const pick = (field) => (db[field] !== undefined && db[field] !== null ? db[field] : env[field]);

  const build = toInt(pick('build'));
  return {
    app,
    version: String(pick('version') || ''),
    build,
    min_build: Math.min(toInt(pick('min_build')), build),
    mandatory: toBool(pick('mandatory')),
    download_url: String(pick('download_url') || ''),
    release_notes: String(pick('release_notes') || ''),
    released_at: String(pick('released_at') || ''),
  };
}

// ─── Administration ───────────────────────────────────────────────────────────

const VERSION_PATTERN = /^\d+\.\d+\.\d+$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const MAX_BUILD = 2_000_000_000; // limite du versionCode Android (2 100 000 000)
const MAX_RELEASE_NOTES = 1000;

/** Versions publiées des deux applications (vue admin). */
async function listAppVersions() {
  const entries = await Promise.all(
    Object.keys(APPS).map(async (app) => [app, await getAppVersion(app)]),
  );
  return Object.fromEntries(entries);
}

function validationError(message, field) {
  return new AppError(message, 422, { field });
}

/**
 * Valide puis enregistre la version publiée d'une application.
 * Le build ne peut jamais redescendre : pour retirer une version défectueuse,
 * on publie un build supérieur (et/ou on relève min_build).
 */
async function updateAppVersion(app, payload, requestContext = {}) {
  const config = APPS[app];
  if (!config) {
    throw new AppError("Application inconnue. Valeurs acceptées : 'agent', 'client'.", 404);
  }
  const current = await getAppVersion(app);
  const input = payload || {};

  const version = String(input.version ?? '').trim();
  if (!VERSION_PATTERN.test(version)) {
    throw validationError('La version doit avoir le format X.Y.Z (ex. 1.0.1).', 'version');
  }

  const build = Number(input.build);
  if (!Number.isInteger(build) || build < 1 || build > MAX_BUILD) {
    throw validationError('Le build doit être un entier positif (le nombre après « + » dans pubspec.yaml).', 'build');
  }
  if (build < current.build) {
    throw validationError(
      `Le build ne peut pas redescendre (actuel : ${current.build}). Publiez un build supérieur pour remplacer une version.`,
      'build',
    );
  }

  const minBuild = input.min_build === undefined || input.min_build === '' ? 0 : Number(input.min_build);
  if (!Number.isInteger(minBuild) || minBuild < 0 || minBuild > build) {
    throw validationError('Le build minimum doit être un entier entre 0 et le build publié.', 'min_build');
  }

  const downloadUrl = String(input.download_url ?? '').trim();
  let parsedUrl = null;
  try {
    parsedUrl = new URL(downloadUrl);
  } catch (error) {
    parsedUrl = null;
  }
  if (!parsedUrl || parsedUrl.protocol !== 'https:') {
    throw validationError("Le lien de téléchargement doit être une adresse https:// valide.", 'download_url');
  }

  const releaseNotes = String(input.release_notes ?? '').trim();
  if (releaseNotes.length > MAX_RELEASE_NOTES) {
    throw validationError(`Les nouveautés ne doivent pas dépasser ${MAX_RELEASE_NOTES} caractères.`, 'release_notes');
  }

  const releasedAt = String(input.released_at ?? '').trim() || new Date().toISOString().slice(0, 10);
  if (!DATE_PATTERN.test(releasedAt) || Number.isNaN(Date.parse(releasedAt))) {
    throw validationError('La date de publication doit avoir le format AAAA-MM-JJ.', 'released_at');
  }

  const value = {
    version,
    build,
    min_build: minBuild,
    mandatory: input.mandatory === true,
    download_url: parsedUrl.toString(),
    release_notes: releaseNotes,
    released_at: releasedAt,
  };

  const existing = await models.SystemSetting.findByPk(config.settingKey);
  if (existing) {
    await existing.update({ value });
  } else {
    // La migration crée normalement la ligne ; on la crée ici si elle manque.
    // created_at / updated_at sont NOT NULL en base mais hors du modèle.
    const now = new Date();
    await models.SystemSetting.sequelize.getQueryInterface().bulkInsert('system_settings', [
      {
        key: config.settingKey,
        value: JSON.stringify(value),
        description: `Version publiée de l'app ${app === 'agent' ? 'Agent' : 'Client'} (mise à jour APK hors Play Store)`,
        created_at: now,
        updated_at: now,
      },
    ]);
  }

  await writeAuditLog({
    userId: requestContext.userId || null,
    action: 'app_version.updated',
    entityType: 'system_setting',
    entityId: config.settingKey,
    ipAddress: requestContext.ipAddress || null,
    userAgent: requestContext.userAgent || null,
    metadata: {
      app,
      admin: requestContext.adminUsername || null,
      previous: current,
      next: value,
    },
  });

  return getAppVersion(app);
}

module.exports = { getAppVersion, listAppVersions, updateAppVersion, APPS };
