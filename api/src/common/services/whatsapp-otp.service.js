const qrcode = require('qrcode-terminal');
const { Client, LocalAuth } = require('whatsapp-web.js');
const fsp = require('node:fs/promises');
const path = require('node:path');

// Version WhatsApp Web épinglée sur le cache local (.wwebjs_cache).
// SANS version épinglée, LocalWebCache.resolve(undefined) cherche "undefined.html",
// échoue et whatsapp-web.js bascule sur un listener 'response' interne (Client.js:1267)
// qui lève "ProtocolError: Could not load response body" quand Chrome sert
// web.whatsapp.com depuis son Service Worker -> rejet non géré -> crash complet
// du processus Node (et donc de toute l'API). Surchargable via WHATSAPP_WEB_VERSION.
const WHATSAPP_WEB_VERSION = process.env.WHATSAPP_WEB_VERSION || '2.3000.1046226669';
const MAX_INIT_ATTEMPTS = 3;
const INIT_RETRY_DELAY_MS = 15000;

class WhatsAppOtpService {
  constructor() {
    this.client = null;
    this.isReady = false;
    this.initAttempts = 0;
    this.signalHandlersRegistered = false;
    this.status = 'disconnected';
    this.qrCode = null;
    this.lastError = null;
    this.hasLoggedQr = false;
  }

  initialize() {
    if (process.env.ENABLE_WHATSAPP_OTP === 'false') {
      console.log('ℹ️ WhatsApp OTP Service désactivé dans la configuration.');
      return;
    }

    try {
      console.log('🔄 Initialisation du service WhatsApp OTP (Open-Source)...');
      this.status = 'initializing';
      this.qrCode = null;
      this.lastError = null;
      this.hasLoggedQr = false;
      this.client = new Client({
        authStrategy: new LocalAuth({ clientId: 'tontine-session' }),
        webVersionCache: {
          type: 'remote',
          remotePath:
            'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
        },
        puppeteer: {
          headless: true,
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

      this.client.on('qr', (qr) => {
        this.status = 'qr_ready';
        this.qrCode = qr;
        if (this.hasLoggedQr) {
          return;
        }
        this.hasLoggedQr = true;
        console.log('\n======================================================');
        console.log('📱 SCANNEZ CE QR CODE AVEC VOTRE WHATSAPP POUR LA DEMO :');
        console.log('======================================================\n');
        qrcode.generate(qr, { small: true });
        console.log('\n======================================================\n');
      });

      this.client.on('ready', () => {
        this.isReady = true;
        this.status = 'ready';
        this.qrCode = null;
        console.log('✅ Service WhatsApp OTP prêt ! Les codes OTP seront envoyés en temps réel par WhatsApp.');
      });

      this.client.on('authenticated', () => {
        this.status = 'ready';
        this.qrCode = null;
        console.log('🔐 Session WhatsApp authentifiée avec succès.');
      });

      this.client.on('auth_failure', (msg) => {
        console.error('❌ Échec d\'authentification WhatsApp :', msg);
        this.isReady = false;
        this.status = 'auth_failure';
        this.qrCode = null;
        this.lastError = typeof msg === 'object' ? JSON.stringify(msg) : String(msg);
      });

      this.client.on('disconnected', (reason) => {
        console.warn('⚠️ WhatsApp déconnecté :', reason);
        this.isReady = false;
        this.status = 'disconnected';
        this.qrCode = null;
        this.lastError = typeof reason === 'object' ? JSON.stringify(reason) : String(reason);
      });

      // Nettoyage propre du processus Puppeteer lors des redémarrages Nodemon ou arrêts
      const cleanup = async () => {
        if (this.client) {
          try {
            await this.client.destroy();
          } catch (_) {}
        }
      };
      process.once('SIGINT', cleanup);
      process.once('SIGTERM', cleanup);
      process.once('SIGUSR2', cleanup);

      this.client.initialize().catch((err) => {
        console.warn('⚠️ Remarque WhatsApp Initialisation :', err.message);
      });
    } catch (error) {
      console.warn('⚠️ Service WhatsApp OTP non démarré :', error.message);
    }
  }

  async sendOtp(rawPhoneNumber, otpCode) {
    if (!this.client || !this.isReady) {
      console.log(`ℹ️ [WhatsApp OTP Fallback Mode Dev] Code OTP pour ${rawPhoneNumber} : ${otpCode}`);
      return { success: false, mode: 'fallback', message: 'WhatsApp non connecté' };
    }

    try {
      let cleanDigits = String(rawPhoneNumber || '').replace(/\D/g, '');

      // Auto-prepend country code 229 (Bénin) if national 8-digit or 10-digit number is passed
      if (cleanDigits.length === 8 || cleanDigits.length === 10) {
        cleanDigits = `229${cleanDigits}`;
      } else if (cleanDigits.startsWith('00')) {
        cleanDigits = cleanDigits.substring(2);
      }

      // 1. Résolution de l'identifiant WhatsApp officiel (LID)
      let numberDetails = await this.client.getNumberId(cleanDigits);

      // 2. Gestion de la transition 8 chiffres vers 10 chiffres au Bénin (+22901... vers +229...)
      if (!numberDetails && cleanDigits.startsWith('22901') && cleanDigits.length === 13) {
        const legacyDigits = `229${cleanDigits.substring(5)}`;
        numberDetails = await this.client.getNumberId(legacyDigits);
      }

      // 3. Fallback générique si le numéro n'est pas encore identifié par l'API
      const targetJid = numberDetails ? numberDetails._serialized : `${cleanDigits}@c.us`;

      const messageText = `📱 *VizioBox Tontine*\n\nVotre code de vérification est : *${otpCode}*\n\nValable pendant 5 minutes. Ne le partagez avec personne.`;

      await this.client.sendMessage(targetJid, messageText);
      console.log(`✅ [WhatsApp OTP] Code ${otpCode} envoyé avec succès par WhatsApp à ${targetJid}`);
      return { success: true, mode: 'whatsapp' };
    } catch (error) {
      console.error(`❌ [WhatsApp OTP Error] Impossible d'envoyer le message au ${rawPhoneNumber} :`, error.message);
      return { success: false, mode: 'error', error: error.message };
    }
  }

  async reinitialize(forceNewSession = false) {
    console.log(`🔄 Demande de réinitialisation du service WhatsApp (forceNewSession=${forceNewSession})...`);
    this.isReady = false;
    this.status = 'initializing';
    this.qrCode = null;
    this.lastError = null;

    if (this.client) {
      try {
        await this.client.destroy();
      } catch (err) {
        console.warn('⚠️ Erreur lors de la destruction du client WhatsApp précédent :', err.message);
      }
      this.client = null;
    }

    if (forceNewSession) {
      const sessionPath = path.join(process.cwd(), '.wwebjs_auth/session-tontine-session');
      try {
        await fsp.rm(sessionPath, { recursive: true, force: true });
        console.log('🧹 Session WhatsApp locale supprimée avec succès.');
      } catch (err) {
        console.warn('⚠️ Erreur lors de la suppression de la session WhatsApp locale :', err.message);
      }
    }

    this.initialize();
  }
}

const whatsAppOtpService = new WhatsAppOtpService();
module.exports = whatsAppOtpService;
