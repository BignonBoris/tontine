const fs = require('fs');
let content = fs.readFileSync('migrations/20260908010000-create-missing-tables.js', 'utf8');
content = content.replace(/Sequelize\.ENUM\([^)]*\"values\"\:\[(.*?)\][^)]*\)/g, 'Sequelize.ENUM($1)');
// also handle boolean defaultValue true/false outputted as string if any, though our script did it right.
fs.writeFileSync('migrations/20260908010000-create-missing-tables.js', content);
console.log('Fixed');
