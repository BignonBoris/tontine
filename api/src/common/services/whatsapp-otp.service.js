const qrcodeTerminal = require('qrcode-terminal');
const QRCode = require('qrcode');
const { Client, LocalAuth } = require('whatsapp-web.js');
const fsp = require('node:fs/promises');
const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');
const env = require('../../config/env');

// Version WhatsApp Web stable compatible avec le remote cache wppconnect-team
const DEFAULT_WHATSAPP_WEB_VERSION = '2.3000.1046618780-alpha';

class WhatsAppOtpService {
  constructor() {
    this.client = null;
    this.isReady = false;
    this.initAttempts = 0;
    this.signalHandlersRegistered = false;
    this.status = 'disconnected';
    this.qrCode = null;
    this.qrCodeDataUrl = null;
    this.lastError = null;
    this.hasLoggedQr = false;
  }

  get provider() {
    return (process.env.WHATSAPP_PROVIDER || env.whatsapp?.provider || 'meta').toLowerCase();
  }

  get isEnabled() {
    return process.env.ENABLE_WHATSAPP_OTP !== 'false' && env.whatsapp?.enabled !== false;
  }

  _resolveOrInstallChrome() {
    if (
      process.env.PUPPETEER_EXECUTABLE_PATH &&
      fs.existsSync(process.env.PUPPETEER_EXECUTABLE_PATH)
    ) {
      return process.env.PUPPETEER_EXECUTABLE_PATH;
    }

    try {
      const puppeteer = require('puppeteer');
      const execPath = puppeteer.executablePath();
      if (fs.existsSync(execPath)) {
        return execPath;
      }
    } catch (err) {
      console.warn('⚠️ Chrome non détecté dans le cache local :', err.message);
    }

    console.log(
      '🔄 Téléchargement automatique de Chromium en cours (npx puppeteer browsers install chrome)...',
    );
    try {
      execSync('npx puppeteer browsers install chrome', {
        stdio: 'inherit',
        cwd: process.cwd(),
        env: process.env,
      });
      const puppeteer = require('puppeteer');
      const execPath = puppeteer.executablePath();
      console.log("✅ Chromium prêt à l'utilisation :", execPath);
      return execPath;
    } catch (installErr) {
      console.error(
        '❌ Impossible de télécharger Chromium automatiquement :',
        installErr.message,
      );
      return undefined;
    }
  }

  initialize() {
    if (!this.isEnabled) {
      console.log('ℹ️ WhatsApp OTP Service désactivé dans la configuration.');
      this.status = 'disabled';
      this.isReady = false;
      this.qrCode = null;
      this.qrCodeDataUrl = null;
      return;
    }

    const currentProvider = this.provider;
    console.log(`🔄 Initialisation du service WhatsApp OTP (Provider: ${currentProvider.toUpperCase()})...`);

    if (currentProvider === 'meta') {
      this._initializeMetaCloudApi();
    } else if (currentProvider === 'wwebjs') {
      this._initializeWWebJS();
    } else {
      console.log('ℹ️ Provider WhatsApp configuré en mode fallback / dev console.');
      this.status = 'ready';
      this.isReady = true;
      this.qrCode = null;
      this.qrCodeDataUrl = null;
    }
  }

  _initializeMetaCloudApi() {
    const token = process.env.META_WHATSAPP_TOKEN || env.whatsapp?.metaToken;
    const phoneNumberId = process.env.META_WHATSAPP_PHONE_NUMBER_ID || env.whatsapp?.metaPhoneNumberId;

    if (!token || !phoneNumberId) {
      console.warn('⚠️ [Meta WhatsApp Cloud API] Configuration incomplète. META_WHATSAPP_TOKEN et META_WHATSAPP_PHONE_NUMBER_ID sont requis.');
      this.status = 'error';
      this.isReady = false;
      this.lastError = "Identifiants Meta WhatsApp Cloud API manquants dans l'environnement";
      return;
    }

    this.status = 'ready';
    this.isReady = true;
    this.lastError = null;
    this.qrCode = null;
    this.qrCodeDataUrl = null;
    console.log(`✅ [Meta WhatsApp Cloud API] Service prêt à l'emploi ! (Phone Number ID: ${phoneNumberId})`);
  }

  _initializeWWebJS() {
    try {
      console.log('🔄 Démarrage du client WhatsApp Web JS (Puppeteer)...');
      this.status = 'initializing';
      this.qrCode = null;
      this.qrCodeDataUrl = null;
      this.lastError = null;
      this.hasLoggedQr = false;

      const webVersion = process.env.WHATSAPP_WEB_VERSION || DEFAULT_WHATSAPP_WEB_VERSION;

      const sessionDir = path.join(process.cwd(), '.wwebjs_auth', 'session-tontine-session');
      const lockFiles = ['SingletonLock', 'SingletonCookie', 'SingletonSocket'];
      for (const file of lockFiles) {
        try {
          fsp.rm(path.join(sessionDir, file), { force: true }).catch(() => {});
        } catch (_) {}
      }

      if (!process.env.PUPPETEER_CACHE_DIR) {
        process.env.PUPPETEER_CACHE_DIR = path.join(process.cwd(), '.cache', 'puppeteer');
      }

      const chromeExecutablePath =
        this._resolveOrInstallChrome() || process.env.PUPPETEER_EXECUTABLE_PATH || undefined;

      this.client = new Client({
        authStrategy: new LocalAuth({ clientId: 'tontine-session' }),
        webVersion,
        webVersionCache: {
          type: 'remote',
          remotePath:
            'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/{version}.html',
        },
        puppeteer: {
          headless: true,
          executablePath: chromeExecutablePath,
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu',
          ],
        },
      });

      this.client.on('qr', async (qr) => {
        this.status = 'qr_ready';
        this.qrCode = qr;
        try {
          this.qrCodeDataUrl = await QRCode.toDataURL(qr, { margin: 2, width: 280 });
        } catch (err) {
          console.warn('⚠️ Erreur lors de la conversion du QR Code en image base64 :', err.message);
        }

        if (this.hasLoggedQr) {
          return;
        }
        this.hasLoggedQr = true;
        console.log('\n======================================================');
        console.log('📱 SCANNEZ CE QR CODE AVEC VOTRE WHATSAPP POUR LA DEMO :');
        console.log('======================================================\n');
        qrcodeTerminal.generate(qr, { small: true });
        console.log('\n======================================================\n');
      });

      this.client.on('ready', () => {
        this.isReady = true;
        this.status = 'ready';
        this.qrCode = null;
        this.qrCodeDataUrl = null;
        console.log('✅ Service WhatsApp Web JS prêt !');
      });

      this.client.on('authenticated', () => {
        this.status = 'ready';
        this.qrCode = null;
        this.qrCodeDataUrl = null;
        console.log('🔐 Session WhatsApp Web JS authentifiée avec succès.');
      });

      this.client.on('auth_failure', (msg) => {
        console.error("❌ Échec d'authentification WhatsApp Web JS :", msg);
        this.isReady = false;
        this.status = 'auth_failure';
        this.qrCode = null;
        this.qrCodeDataUrl = null;
        this.lastError = typeof msg === 'object' ? JSON.stringify(msg) : String(msg);
      });

      this.client.on('disconnected', (reason) => {
        console.warn('⚠️ WhatsApp Web JS déconnecté :', reason);
        this.isReady = false;
        this.status = 'disconnected';
        this.qrCode = null;
        this.qrCodeDataUrl = null;
        this.lastError = typeof reason === 'object' ? JSON.stringify(reason) : String(reason);
      });

      if (!this.signalHandlersRegistered) {
        this.signalHandlersRegistered = true;
        const cleanup = async () => {
          if (this.client) {
            try {
              await this.client.destroy();
            } catch (_) {}
            this.client = null;
          }
        };

        process.once('SIGUSR2', async () => {
          await cleanup();
          process.kill(process.pid, 'SIGUSR2');
        });

        process.once('SIGINT', async () => {
          await cleanup();
          process.exit(0);
        });

        process.once('SIGTERM', async () => {
          await cleanup();
          process.exit(0);
        });
      }

      this.client.initialize().catch((err) => {
        const errorDetails = err?.stack || err?.message || (typeof err === 'object' ? JSON.stringify(err) : String(err));
        console.warn('⚠️ Remarque WhatsApp Web JS Initialisation :', errorDetails);
        this.status = 'error';
        this.isReady = false;
        this.lastError = errorDetails;
      });
    } catch (error) {
      this.status = 'error';
      this.isReady = false;
      this.lastError = error.message;
      console.warn('⚠️ Service WhatsApp Web JS non démarré :', error.message);
    }
  }

  async sendOtp(rawPhoneNumber, otpCode) {
    if (!this.isEnabled) {
      console.log(`ℹ️ [WhatsApp OTP Disabled] Code OTP pour ${rawPhoneNumber} : ${otpCode}`);
      return { success: false, mode: 'disabled', message: 'WhatsApp OTP désactivé' };
    }

    const currentProvider = this.provider;

    if (currentProvider === 'meta') {
      return await this._sendViaMetaCloudApi(rawPhoneNumber, otpCode);
    } else if (currentProvider === 'wwebjs') {
      return await this._sendViaWWebJS(rawPhoneNumber, otpCode);
    } else {
      console.log(`ℹ️ [WhatsApp OTP Fallback Mode Dev] Code OTP pour ${rawPhoneNumber} : ${otpCode}`);
      return { success: true, mode: 'fallback', message: 'OTP affiché dans la console' };
    }
  }

  async _sendViaMetaCloudApi(rawPhoneNumber, otpCode) {
    const token = process.env.META_WHATSAPP_TOKEN || env.whatsapp?.metaToken;
    const phoneNumberId = process.env.META_WHATSAPP_PHONE_NUMBER_ID || env.whatsapp?.metaPhoneNumberId;
    const version = process.env.META_WHATSAPP_GRAPH_VERSION || env.whatsapp?.metaGraphVersion || 'v21.0';
    const templateName = process.env.META_WHATSAPP_TEMPLATE_NAME || env.whatsapp?.metaTemplateName || '';
    const templateLang = process.env.META_WHATSAPP_TEMPLATE_LANG || env.whatsapp?.metaTemplateLang || 'fr';

    if (!token || !phoneNumberId) {
      console.error('❌ [Meta WhatsApp Cloud API Error] Token ou Phone Number ID manquant.');
      return { success: false, mode: 'error', error: 'Identifiants Meta Cloud API non configurés' };
    }

    let cleanDigits = String(rawPhoneNumber || '').replace(/\D/g, '');

    // Formatage auto numéro international (Bénin 229 si 8 ou 10 chiffres transmis)
    if (cleanDigits.length === 8 || cleanDigits.length === 10) {
      cleanDigits = `229${cleanDigits}`;
    } else if (cleanDigits.startsWith('00')) {
      cleanDigits = cleanDigits.substring(2);
    }

    const url = `https://graph.facebook.com/${version}/${phoneNumberId}/messages`;

    let payload;
    if (templateName) {
      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: cleanDigits,
        type: 'template',
        template: {
          name: templateName,
          language: { code: templateLang },
          components: [
            {
              type: 'body',
              parameters: [
                { type: 'text', text: String(otpCode) },
              ],
            },
            {
              type: 'button',
              sub_type: 'url',
              index: '0',
              parameters: [
                { type: 'text', text: String(otpCode) },
              ],
            },
          ],
        },
      };
    } else {
      const messageText = `📱 *VizioBox Tontine*\n\nVotre code de vérification est : *${otpCode}*\n\nValable pendant 5 minutes. Ne le partagez avec personne.`;
      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: cleanDigits,
        type: 'text',
        text: {
          preview_url: false,
          body: messageText,
        },
      };
    }

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const responseData = await response.json();

      if (!response.ok) {
        const errorMsg =
          responseData?.error?.message ||
          responseData?.error?.details ||
          response.statusText;
        console.error(
          `❌ [Meta WhatsApp API Error] HTTP ${response.status}: ${errorMsg}`,
          responseData,
        );
        return {
          success: false,
          mode: 'meta_error',
          error: errorMsg,
          details: responseData,
        };
      }

      const messageId = responseData?.messages?.[0]?.id || 'unknown';
      console.log(
        `✅ [Meta WhatsApp OTP] Code ${otpCode} envoyé avec succès au +${cleanDigits} (Message ID: ${messageId})`,
      );
      return { success: true, mode: 'meta_cloud_api', messageId };
    } catch (error) {
      console.error(
        `❌ [Meta WhatsApp Network Error] Impossible d'envoyer au +${cleanDigits}:`,
        error.message,
      );
      return { success: false, mode: 'error', error: error.message };
    }
  }

  async _sendViaWWebJS(rawPhoneNumber, otpCode) {
    if (!this.client || !this.isReady) {
      console.log(`ℹ️ [WhatsApp Web JS non connecté] Code OTP pour ${rawPhoneNumber} : ${otpCode}`);
      return { success: false, mode: 'fallback', message: 'WhatsApp Web JS non connecté' };
    }

    try {
      let cleanDigits = String(rawPhoneNumber || '').replace(/\D/g, '');

      if (cleanDigits.length === 8 || cleanDigits.length === 10) {
        cleanDigits = `229${cleanDigits}`;
      } else if (cleanDigits.startsWith('00')) {
        cleanDigits = cleanDigits.substring(2);
      }

      let numberDetails = await this.client.getNumberId(cleanDigits);

      if (!numberDetails && cleanDigits.startsWith('22901') && cleanDigits.length === 13) {
        const legacyDigits = `229${cleanDigits.substring(5)}`;
        numberDetails = await this.client.getNumberId(legacyDigits);
      }

      const targetJid = numberDetails ? numberDetails._serialized : `${cleanDigits}@c.us`;
      const messageText = `📱 *VizioBox Tontine*\n\nVotre code de vérification est : *${otpCode}*\n\nValable pendant 5 minutes. Ne le partagez avec personne.`;

      await this.client.sendMessage(targetJid, messageText);
      console.log(`✅ [WhatsApp Web JS] Code ${otpCode} envoyé avec succès à ${targetJid}`);
      return { success: true, mode: 'wwebjs' };
    } catch (error) {
      console.error(`❌ [WhatsApp Web JS Error] Impossible d'envoyer le message au ${rawPhoneNumber} :`, error.message);
      return { success: false, mode: 'error', error: error.message };
    }
  }

  getStatus() {
    const currentProvider = this.provider;
    const isConfigDisabled = !this.isEnabled;
    const effectiveStatus = isConfigDisabled ? 'disabled' : this.status;

    const phoneNumberId = process.env.META_WHATSAPP_PHONE_NUMBER_ID || env.whatsapp?.metaPhoneNumberId || '';
    const maskedPhoneNumberId = phoneNumberId
      ? `${phoneNumberId.substring(0, 4)}...${phoneNumberId.substring(Math.max(0, phoneNumberId.length - 4))}`
      : '';

    return {
      status: effectiveStatus,
      provider: currentProvider,
      isReady: this.isReady,
      enabled: !isConfigDisabled,
      metaConfig: {
        phoneNumberIdConfigured: Boolean(phoneNumberId),
        phoneNumberIdMasked: maskedPhoneNumberId,
        templateName: process.env.META_WHATSAPP_TEMPLATE_NAME || env.whatsapp?.metaTemplateName || null,
        graphVersion: process.env.META_WHATSAPP_GRAPH_VERSION || env.whatsapp?.metaGraphVersion || 'v21.0',
      },
      qrCode: currentProvider === 'wwebjs' ? this.qrCode : null,
      qrCodeDataUrl: currentProvider === 'wwebjs' ? this.qrCodeDataUrl : null,
      lastError: this.lastError,
    };
  }

  async reinitialize(options = {}) {
    const providerParam = typeof options === 'object' && options.provider ? options.provider : null;
    if (providerParam) {
      process.env.WHATSAPP_PROVIDER = providerParam;
    }

    const enable =
      typeof options === 'object' && options.enable !== undefined ? options.enable : true;

    if (enable) {
      process.env.ENABLE_WHATSAPP_OTP = 'true';
    }

    console.log(
      `🔄 Demande de réinitialisation du service WhatsApp (provider=${this.provider}, enable=${enable})...`,
    );
    this.isReady = false;
    this.status = 'initializing';
    this.qrCode = null;
    this.qrCodeDataUrl = null;
    this.lastError = null;

    if (this.client) {
      try {
        await this.client.destroy();
      } catch (err) {
        console.warn('⚠️ Erreur lors de la destruction du client WhatsApp Web JS précédent :', err.message);
      }
      this.client = null;
    }

    this.initialize();
  }
}

const whatsAppOtpService = new WhatsAppOtpService();
module.exports = whatsAppOtpService;
