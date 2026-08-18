import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class LegalTermsBottomSheet extends StatelessWidget {
  final int initialTabIndex;

  const LegalTermsBottomSheet({
    super.key,
    this.initialTabIndex = 0,
  });

  static void show(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LegalTermsBottomSheet(initialTabIndex: initialTab),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.gavel_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Informations Légales & CGU',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.accentColor,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
              tabs: const [
                Tab(text: "CGU Tontine"),
                Tab(text: "Confidentialité (APDP)"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCguContent(),
                  _buildPrivacyContent(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "J'ai compris et j'accepte",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCguContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("1. Objet des Services VizioBox Tontine"),
          _buildParagraph(
            "VizioBox Tontine est une plateforme de microfinance et d'épargne rotative tontinière numérique. "
            "En vous inscrivant, vous souscrivez à un service de collecte et de gestion automatisée de cotisations d'épargne.",
          ),
          _buildSectionTitle("2. Obligations & Cotisations"),
          _buildParagraph(
            "Le membre souscripteur s'engage à effectuer ses versements de cotisations conformément à la fréquence "
            "(journalière, hebdomadaire ou mensuelle) du produit de tontine choisi. Tout retard ou défaut peut entraîner "
            "des pénalités de retard calculées selon le barème du produit.",
          ),
          _buildSectionTitle("3. Sécurité des Fonds & Liquidations"),
          _buildParagraph(
            "Les fonds collectés sont centralisés et sécurisés au niveau de la caisse centrale et des partenaires financiers agréés. "
            "Les retraits et liquidations de tontine sont soumis à la validation des conditions de cycle et au contrôle KYC.",
          ),
          _buildSectionTitle("4. Sécurité des Accès & Code PIN"),
          _buildParagraph(
            "Votre code PIN à 4 chiffres est strictement personnel et confidentiel. VizioBox ne vous demandera jamais votre code PIN. "
            "Vous êtes entièrement responsable de la confidentialité de vos identifiants.",
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("1. Conformité APDP Bénin & Législation"),
          _buildParagraph(
            "VizioBox respecte la réglementation relative à la protection des données personnelles (Loi APDP au Bénin et normes internationales). "
            "Vos données sont collectées uniquement pour la gestion de votre compte tontine et l'exécution des opérations financières.",
          ),
          _buildSectionTitle("2. Données Collectées (KYC)"),
          _buildParagraph(
            "Nous collectons : vos nom et prénom, numéro de téléphone, date de naissance, pièces d'identité (KYC), ainsi que l'historique des cotisations "
            "et transactions réalisées sur la plateforme.",
          ),
          _buildSectionTitle("3. Partage & Confidentialité"),
          _buildParagraph(
            "Vos données personnelles ne sont jamais vendues ni cédées à des tiers commerciaux. Elles sont partagées uniquement avec nos partenaires de paiement "
            "agréés et les autorités réglementaires en cas d'obligation légale.",
          ),
          _buildSectionTitle("4. Droits d'Accès & Rectification"),
          _buildParagraph(
            "Vous disposez d'un droit permanent d'accès, de rectification et de suppression de vos données personnelles en contactant l'assistance VizioBox.",
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: AppTheme.textPrimaryColor,
        height: 1.5,
      ),
    );
  }
}
