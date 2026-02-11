const fs = require('fs');
const path = require('path');
const db = require('../config/database');

async function migrate() {
  try {
    console.log('Migration başlatılıyor...\n');

    // Migration takip tablosu oluştur
    await db.query(`
      CREATE TABLE IF NOT EXISTS _migrations (
        id SERIAL PRIMARY KEY,
        dosya VARCHAR(255) NOT NULL UNIQUE,
        uygulama_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    // Migration dosyalarını sıralı oku
    const migrationDir = __dirname;
    const dosyalar = fs.readdirSync(migrationDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    for (const dosya of dosyalar) {
      // Daha önce çalıştırılmış mı?
      const mevcut = await db.query(
        'SELECT id FROM _migrations WHERE dosya = $1',
        [dosya]
      );

      if (mevcut.rows.length > 0) {
        console.log(`  ATLA: ${dosya} (zaten uygulanmış)`);
        continue;
      }

      // SQL dosyasını çalıştır
      const sqlPath = path.join(migrationDir, dosya);
      const sql = fs.readFileSync(sqlPath, 'utf8');

      console.log(`  UYGULA: ${dosya}...`);
      await db.query(sql);

      // Takip tablosuna kaydet
      await db.query(
        'INSERT INTO _migrations (dosya) VALUES ($1)',
        [dosya]
      );
      console.log(`  OK: ${dosya}`);
    }

    console.log('\nMigration tamamlandı!');
    process.exit(0);
  } catch (error) {
    console.error('\nMigration hatası:', error.message);
    process.exit(1);
  }
}

migrate();
