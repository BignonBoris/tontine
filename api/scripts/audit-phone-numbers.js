const path = require('path');

const apiDir = path.resolve(__dirname, '..');
process.chdir(apiDir);

require(path.resolve(apiDir, 'src/config/env'));
const sequelize = require(path.resolve(apiDir, 'src/config/database'));

async function fetchRows(sql) {
  const [rows] = await sequelize.query(sql);
  return rows;
}

async function main() {
  try {
    await sequelize.authenticate();

    const columns = await fetchRows(`
      SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND (
          COLUMN_NAME LIKE '%phone%'
          OR COLUMN_NAME LIKE '%telephone%'
        )
      ORDER BY TABLE_NAME, COLUMN_NAME
    `);

    const usersSummary = await fetchRows(`
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN phone_number REGEXP '^[0-9]{8}$' THEN 1 ELSE 0 END) AS len8,
        SUM(CASE WHEN phone_number REGEXP '^[0-9]{10}$' THEN 1 ELSE 0 END) AS len10,
        SUM(CASE WHEN phone_number IS NULL OR phone_number = '' THEN 1 ELSE 0 END) AS empty_or_null,
        SUM(
          CASE
            WHEN phone_number IS NOT NULL
              AND phone_number <> ''
              AND phone_number NOT REGEXP '^[0-9]{8}$'
              AND phone_number NOT REGEXP '^[0-9]{10}$'
            THEN 1
            ELSE 0
          END
        ) AS other_shape
      FROM users
    `);

    const authOtpsSummary = await fetchRows(`
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN phone_number REGEXP '^[0-9]{8}$' THEN 1 ELSE 0 END) AS len8,
        SUM(CASE WHEN phone_number REGEXP '^[0-9]{10}$' THEN 1 ELSE 0 END) AS len10,
        SUM(CASE WHEN phone_number IS NULL OR phone_number = '' THEN 1 ELSE 0 END) AS empty_or_null,
        SUM(
          CASE
            WHEN phone_number IS NOT NULL
              AND phone_number <> ''
              AND phone_number NOT REGEXP '^[0-9]{8}$'
              AND phone_number NOT REGEXP '^[0-9]{10}$'
            THEN 1
            ELSE 0
          END
        ) AS other_shape
      FROM auth_otps
    `);

    const usersLen8 = await fetchRows(`
      SELECT
        u.id,
        u.phone_number,
        u.display_name,
        u.account_type,
        u.is_active,
        ap.id AS agent_profile_id,
        ap.agent_code,
        ap.is_active AS agent_is_active,
        u.created_at,
        u.updated_at
      FROM users u
      LEFT JOIN agent_profiles ap ON ap.user_id = u.id
      WHERE u.phone_number REGEXP '^[0-9]{8}$'
      ORDER BY u.updated_at DESC
    `);

    const authOtpsLen8ByPhonePurpose = await fetchRows(`
      SELECT
        phone_number,
        purpose,
        COUNT(*) AS total,
        MAX(updated_at) AS last_updated_at
      FROM auth_otps
      WHERE phone_number REGEXP '^[0-9]{8}$'
      GROUP BY phone_number, purpose
      ORDER BY last_updated_at DESC
    `);

    const otpPhonesWithoutUser = await fetchRows(`
      SELECT DISTINCT ao.phone_number
      FROM auth_otps ao
      LEFT JOIN users u ON u.phone_number = ao.phone_number
      WHERE ao.phone_number REGEXP '^[0-9]{8}$'
        AND u.id IS NULL
      ORDER BY ao.phone_number ASC
    `);

    const report = {
      generatedAt: new Date().toISOString(),
      tablesWithPhoneColumns: columns,
      summaries: {
        users: usersSummary[0] || null,
        authOtps: authOtpsSummary[0] || null,
      },
      impactedUsersLen8: usersLen8,
      impactedAuthOtpsLen8ByPhonePurpose: authOtpsLen8ByPhonePurpose,
      otpPhonesWithoutMatchingUser: otpPhonesWithoutUser,
    };

    console.log(JSON.stringify(report, null, 2));
  } catch (error) {
    console.error('PHONE_AUDIT_FAILED');
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  } finally {
    try {
      await sequelize.close();
    } catch (_) {
      // ignore close errors in a read-only audit script
    }
  }
}

main();
