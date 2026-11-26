/**
 * Tests de l'assistant Community Manager.
 * Le vrai SDK Anthropic est utilise avec un fetch simule : on verifie la
 * requete envoyee a l'API Claude sans appel reseau ni base de donnees.
 */
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');

const src = path.join(__dirname, '..', 'src');
const state = { posts: [], settings: {}, audits: [], requests: [], reply: null, status: 200 };

function stubModule(relativePath, exportsValue) {
  const resolved = require.resolve(path.join(src, relativePath));
  require.cache[resolved] = { id: resolved, filename: resolved, loaded: true, exports: exportsValue };
}

function makeRow(fields) {
  const row = {
    ...fields,
    async update(patch) {
      Object.assign(row, patch);
      return row;
    },
    get() {
      const { update, get, ...plain } = row;
      return plain;
    },
  };
  return row;
}

stubModule('database/models/index.js', {
  models: {
    CommunityPost: {
      create: async (fields) => {
        const row = makeRow({ id: `post-${state.posts.length + 1}`, createdAt: new Date(), ...fields });
        state.posts.push(row);
        return row;
      },
      findByPk: async (id) => state.posts.find((row) => row.id === id) || null,
      findAndCountAll: async () => ({ rows: state.posts, count: state.posts.length }),
    },
    SystemSetting: {
      findByPk: async (key) => (state.settings[key] ? { value: state.settings[key] } : null),
      upsert: async ({ key, value }) => {
        state.settings[key] = value;
      },
    },
  },
});
stubModule('common/services/audit-log.service.js', {
  writeAuditLog: async (entry) => state.audits.push(entry),
});

const service = require('../src/modules/community/community.service');

function claudeMessage(payload, stopReason = 'end_turn') {
  return {
    id: 'msg_test',
    type: 'message',
    role: 'assistant',
    model: 'claude-opus-5-5',
    content: payload === null ? [] : [{ type: 'text', text: JSON.stringify(payload) }],
    stop_reason: stopReason,
    stop_sequence: null,
    usage: { input_tokens: 10, output_tokens: 10 },
  };
}

const fakeFetch = async (url, init) => {
  state.requests.push({ url: String(url), headers: init.headers, body: JSON.parse(init.body) });
  return new Response(JSON.stringify(state.reply), {
    status: state.status,
    headers: { 'content-type': 'application/json', 'request-id': 'req_test' },
  });
};

service.setClaudeClient(new Anthropic({ apiKey: 'sk-ant-test', fetch: fakeFetch, maxRetries: 0 }));

beforeEach(() => {
  state.posts.length = 0;
  state.audits.length = 0;
  state.requests.length = 0;
  state.settings = {};
  state.status = 200;
});

function headerValue(headers, name) {
  if (typeof headers?.get === 'function') return headers.get(name);
  const entry = Object.entries(headers || {}).find(([key]) => key.toLowerCase() === name);
  return entry ? entry[1] : null;
}

test('generation : requete Claude conforme et brouillons enregistres', async () => {
  state.reply = claudeMessage({
    posts: [
      {
        network: 'facebook',
        language: 'fr',
        title: 'Lancement Mobile Money',
        content: 'Versez dans votre tontine sans quitter l application.',
        hashtags: ['VizioBox', '#MobileMoney'],
        visual_idea: 'Telephone avec l ecran de paiement',
        call_to_action: 'Telechargez l application',
      },
      {
        network: 'whatsapp',
        language: 'fon',
        title: 'Statut fongbe',
        content: 'Texte en fongbe',
        hashtags: [],
        visual_idea: '',
        call_to_action: '',
      },
      // Combinaison non demandee : doit etre ignoree
      { network: 'tiktok', language: 'fr', title: 'x', content: 'hors demande', hashtags: [], visual_idea: '', call_to_action: '' },
    ],
  });

  const posts = await service.generatePosts(
    { networks: ['facebook', 'whatsapp'], languages: ['fr', 'fon'], topic: 'Paiement Mobile Money', count: 1 },
    { adminUsername: 'admin' },
  );

  const [request] = state.requests;
  assert.match(request.url, /\/v1\/messages/);
  assert.equal(request.body.model, 'claude-opus-5-5');
  assert.equal(request.body.fallbacks, 'default');
  assert.match(headerValue(request.headers, 'anthropic-beta') || '', /server-side-fallback-2026-07-01/);
  assert.equal(request.body.output_config.format.type, 'json_schema');
  assert.equal(request.body.output_config.effort, 'medium');
  assert.equal(request.body.system[0].cache_control.type, 'ephemeral');
  assert.match(request.body.system[0].text, /Interdits absolus/);
  assert.ok(!('thinking' in request.body), 'pas de thinking desactive sur Opus 5.5');

  assert.equal(posts.length, 2);
  assert.deepEqual(posts[0].hashtags, ['#VizioBox', '#MobileMoney']);
  assert.equal(posts[0].status, 'draft');
  assert.match(posts[0].reference, /^CM-\d{8}-[0-9A-F]{6}$/);
  assert.equal(posts[1].language, 'fon');
  assert.equal(state.audits[0].action, 'community.posts_generated');
});

test('generation : validation avant tout appel Claude', async () => {
  await assert.rejects(service.generatePosts({ networks: [], topic: 'Sujet' }), (e) => e.statusCode === 422);
  await assert.rejects(service.generatePosts({ networks: ['myspace'], topic: 'Sujet' }), (e) => e.statusCode === 422);
  await assert.rejects(service.generatePosts({ networks: ['facebook'], topic: '' }), (e) => e.statusCode === 422);
  await assert.rejects(
    service.generatePosts({
      networks: ['facebook', 'whatsapp', 'tiktok', 'instagram', 'linkedin'],
      languages: ['fr', 'fon'],
      topic: 'Sujet',
      count: 3,
    }),
    /Maximum 20/,
  );
  assert.equal(state.requests.length, 0);
});

test('reponse : probleme de paiement toujours oriente vers le support', async () => {
  state.reply = claudeMessage({
    language: 'fr',
    category: 'probleme_paiement',
    sentiment: 'negatif',
    needs_support: false,
    support_reason: '',
    reply: 'Merci pour votre message, ecrivez-nous en prive.',
  });

  const reply = await service.suggestReply({
    network: 'facebook',
    comment: 'Mon versement de 5000 F n apparait pas !!',
  });

  assert.equal(reply.kind, 'reply');
  assert.equal(reply.needsSupport, true, 'force a true malgre needs_support=false');
  assert.equal(reply.sourceText, 'Mon versement de 5000 F n apparait pas !!');
  assert.match(state.requests[0].body.messages[0].content, /<commentaire>/);
});

test('refus du modele -> erreur claire, rien enregistre', async () => {
  state.reply = claudeMessage(null, 'refusal');
  await assert.rejects(
    service.suggestReply({ network: 'facebook', comment: 'texte' }),
    (e) => e.statusCode === 422 && /refuse/.test(e.message),
  );
  assert.equal(state.posts.length, 0);
});

test('erreur API Claude (500) -> 502 sans fuite technique', async () => {
  state.status = 500;
  state.reply = { type: 'error', error: { type: 'api_error', message: 'boom' } };
  await assert.rejects(
    service.suggestReply({ network: 'facebook', comment: 'Bonjour' }),
    (e) => e.statusCode === 502,
  );
});

test('statuts : brouillon -> valide -> publie, pas d edition apres publication', async () => {
  state.reply = claudeMessage({
    language: 'fr', category: 'compliment', sentiment: 'positif',
    needs_support: false, support_reason: '', reply: 'Merci !',
  });
  const reply = await service.suggestReply({ network: 'instagram', comment: 'Super appli' });

  await assert.rejects(service.updatePost(reply.id, { status: 'published' }), (e) => e.statusCode === 409);

  const approved = await service.updatePost(reply.id, { status: 'approved', content: 'Merci beaucoup !' }, { adminUsername: 'admin' });
  assert.equal(approved.status, 'approved');
  assert.equal(approved.approvedBy, 'admin');
  assert.equal(approved.content, 'Merci beaucoup !');

  const published = await service.updatePost(reply.id, { status: 'published' });
  assert.ok(published.publishedAt);
  await assert.rejects(service.updatePost(reply.id, { content: 'modif' }), (e) => e.statusCode === 409);

  const archived = await service.updatePost(reply.id, { status: 'archived' });
  assert.equal(archived.status, 'archived');
});

test('fiche de marque : valeurs par defaut puis enregistrement normalise', async () => {
  const initial = await service.getBrandProfile();
  assert.equal(initial.isDefault, true);
  assert.equal(initial.brandName, 'VizioBox');

  await assert.rejects(service.updateBrandProfile({ description: '' }), (e) => e.statusCode === 422);

  const saved = await service.updateBrandProfile({
    description: 'Tontine digitale',
    keyFacts: 'Fait 1\n\nFait 2',
    defaultHashtags: ['VizioBox', '#Benin'],
  });
  assert.deepEqual(saved.keyFacts, ['Fait 1', 'Fait 2']);
  assert.deepEqual(saved.defaultHashtags, ['#VizioBox', '#Benin']);
  assert.equal((await service.getBrandProfile()).isDefault, false);
});

// ---------------------------------------------------------------------------
// Fournisseur Gemini
// ---------------------------------------------------------------------------

const gemini = { requests: [], reply: null, status: 200 };
service.setGeminiFetch(async (url, init) => {
  gemini.requests.push({ url: String(url), headers: init.headers, body: JSON.parse(init.body) });
  return new Response(JSON.stringify(gemini.reply), {
    status: gemini.status,
    headers: { 'content-type': 'application/json' },
  });
});

function geminiReply(payload, finishReason = 'STOP') {
  return {
    candidates: [
      {
        content: { role: 'model', parts: [{ text: 'reflexion', thought: true }, { text: JSON.stringify(payload) }] },
        finishReason,
      },
    ],
    modelVersion: 'gemini-3.8-flash',
  };
}

async function withGemini(fn) {
  process.env.COMMUNITY_AI_PROVIDER = 'gemini';
  gemini.requests.length = 0;
  gemini.status = 200;
  try {
    await fn();
  } finally {
    delete process.env.COMMUNITY_AI_PROVIDER;
  }
}

test('gemini : requete generateContent conforme et brouillons enregistres', () =>
  withGemini(async () => {
    gemini.reply = geminiReply({
      posts: [
        {
          network: 'linkedin', language: 'fr', title: 'Digitalisation',
          content: 'La tontine passe au numerique au Benin.', hashtags: ['Tontine'],
          visual_idea: '', call_to_action: 'Decouvrez VizioBox',
        },
      ],
    });

    const posts = await service.generatePosts({ networks: ['linkedin'], languages: ['fr'], topic: 'Tontine digitale' });

    const [request] = gemini.requests;
    assert.match(request.url, /\/v1beta\/models\/gemini-3\.8-flash:generateContent$/);
    assert.ok(request.headers['x-goog-api-key']);
    assert.equal(request.body.generationConfig.responseMimeType, 'application/json');
    assert.deepEqual(request.body.generationConfig.responseJsonSchema.required, ['posts']);
    assert.match(request.body.systemInstruction.parts[0].text, /Interdits absolus/);
    assert.equal(state.requests.length, 0, 'aucun appel Claude');

    assert.equal(posts.length, 1);
    assert.equal(posts[0].aiModel, 'gemini-3.8-flash');
    assert.deepEqual(posts[0].hashtags, ['#Tontine']);
    assert.equal(service.getOptions().provider, 'gemini');
  }));

test('gemini : contenu bloque -> 422, quota -> 429, cle invalide -> 503', () =>
  withGemini(async () => {
    gemini.reply = { promptFeedback: { blockReason: 'SAFETY' } };
    await assert.rejects(service.suggestReply({ network: 'facebook', comment: 'texte' }), (e) => e.statusCode === 422);

    gemini.reply = geminiReply({}, 'SAFETY');
    await assert.rejects(service.suggestReply({ network: 'facebook', comment: 'texte' }), (e) => e.statusCode === 422);

    gemini.status = 429;
    gemini.reply = { error: { code: 429, status: 'RESOURCE_EXHAUSTED', message: 'quota' } };
    await assert.rejects(service.suggestReply({ network: 'facebook', comment: 'texte' }), (e) => e.statusCode === 429);

    gemini.status = 400;
    gemini.reply = { error: { code: 400, status: 'INVALID_ARGUMENT', message: 'API key not valid. Please pass a valid API key.' } };
    await assert.rejects(service.suggestReply({ network: 'facebook', comment: 'texte' }), (e) => e.statusCode === 503);

    gemini.status = 500;
    gemini.reply = { error: { code: 500, status: 'INTERNAL', message: 'boom' } };
    await assert.rejects(service.suggestReply({ network: 'facebook', comment: 'texte' }), (e) => e.statusCode === 502);
    assert.equal(state.posts.length, 0);
  }));

test('fournisseur : Gemini par defaut des que GEMINI_API_KEY existe', () => {
  const saved = process.env.GEMINI_API_KEY;
  process.env.GEMINI_API_KEY = 'cle-de-test';
  try {
    assert.equal(service.getOptions().provider, 'gemini');
    process.env.COMMUNITY_AI_PROVIDER = 'anthropic';
    assert.equal(service.getOptions().provider, 'anthropic');
    assert.equal(service.getOptions().model, 'claude-opus-5-5');
  } finally {
    delete process.env.COMMUNITY_AI_PROVIDER;
    if (saved === undefined) delete process.env.GEMINI_API_KEY; else process.env.GEMINI_API_KEY = saved;
  }
});
