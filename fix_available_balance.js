const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'mobile', 'lib', 'features', 'dashboard', 'presentation', 'screens', 'available_balance_detail_screen.dart');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Add import
content = content.replace(
  "import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';",
  "import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';\nimport 'package:mobile/features/dashboard/presentation/widgets/finance_hero_header.dart';"
);

// 2. Replace Scaffold
const oldScaffold = `        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          appBar: AppBar(
            title: Text(
              "Solde disponible",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(`;

const newScaffold = `        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          body: Column(
            children: [
              const FinanceHeroHeader(
                title: "Solde disponible",
                subtitle: "Votre compte de transit",
                showBackButton: true,
              ),
              Expanded(
                child: SingleChildScrollView(`;

content = content.replace(oldScaffold, newScaffold);

// 3. Close the expanded/column at the end
// Let's find the closing of the Scaffold
const oldClosing = `                        ],
                      ),
                    ),
                  ],
                ),
          ),
        );
      },`;

const newClosing = `                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },`;

content = content.replace(oldClosing, newClosing);

fs.writeFileSync(filePath, content, 'utf8');
console.log("Done");
