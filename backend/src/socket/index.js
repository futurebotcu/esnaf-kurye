const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../config/database');

/**
 * Socket.io Gerçek Zamanlı Takip Modülü
 *
 * Olaylar:
 * - kurye:konum_guncelle → Kurye konumunu yayınlar
 * - esnaf:cagri_takip → Esnaf çağrı takibi başlatır
 * - yeni_cagri → Kuryeye yeni çağrı bildirimi
 * - cagri_kabul_edildi → Esnafa kabul bildirimi
 * - teslim_alindi, teslim_tamamlandi → Durum güncellemeleri
 */
function socketBaslat(io) {
  // JWT ile kimlik doğrulama
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      if (!token) {
        return next(new Error('Yetkilendirme gerekli'));
      }

      const decoded = jwt.verify(token, config.jwt.secret);
      const result = await db.query(
        'SELECT id, telefon, rol, ad, soyad FROM kullanicilar WHERE id = $1 AND aktif = true',
        [decoded.id]
      );

      if (result.rows.length === 0) {
        return next(new Error('Geçersiz kullanıcı'));
      }

      socket.kullanici = result.rows[0];
      next();
    } catch (error) {
      next(new Error('Geçersiz token'));
    }
  });

  io.on('connection', async (socket) => {
    const kullanici = socket.kullanici;
    console.log(`Bağlandı: ${kullanici.ad} ${kullanici.soyad} (${kullanici.rol})`);

    // Rol bazlı odaya katıl
    if (kullanici.rol === 'kurye') {
      const kuryeResult = await db.query(
        'SELECT id FROM kuryeler WHERE kullanici_id = $1',
        [kullanici.id]
      );
      if (kuryeResult.rows.length > 0) {
        const kuryeId = kuryeResult.rows[0].id;
        socket.join(`kurye_${kuryeId}`);
        socket.kuryeId = kuryeId;

        // Kurye durumunu müsait yap
        await db.query(
          "UPDATE kuryeler SET durum = 'musait' WHERE id = $1",
          [kuryeId]
        );
      }
    } else if (kullanici.rol === 'esnaf') {
      const esnafResult = await db.query(
        'SELECT id FROM esnaflar WHERE kullanici_id = $1',
        [kullanici.id]
      );
      if (esnafResult.rows.length > 0) {
        const esnafId = esnafResult.rows[0].id;
        socket.join(`esnaf_${esnafId}`);
        socket.esnafId = esnafId;
      }
    } else if (kullanici.rol === 'musteri') {
      socket.join(`musteri_${kullanici.id}`);
    }

    // ─────────────────────────────────────────────
    // KURYE: Konum güncelleme (gerçek zamanlı)
    // ─────────────────────────────────────────────
    socket.on('kurye:konum_guncelle', async (data) => {
      try {
        const { lat, lon } = data;

        // DB'de konumu güncelle
        await db.query(
          `UPDATE kuryeler SET
            konum = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
            son_konum_zamani = NOW()
           WHERE kullanici_id = $3`,
          [lon, lat, kullanici.id]
        );

        // Aktif çağrısı varsa esnafa konumu yayınla
        const aktifCagri = await db.query(
          `SELECT c.id, c.esnaf_id, c.musteri_id FROM cagrilar c
           JOIN kuryeler k ON k.id = c.kurye_id
           WHERE k.kullanici_id = $1
             AND c.durum IN ('atandi', 'teslim_alindi')`,
          [kullanici.id]
        );

        if (aktifCagri.rows.length > 0) {
          const cagri = aktifCagri.rows[0];
          const konumData = {
            cagri_id: cagri.id,
            lat,
            lon,
            zaman: new Date().toISOString(),
          };
          io.to(`esnaf_${cagri.esnaf_id}`).emit('kurye:konum', konumData);

          // Müşteriye de konum yayınla
          if (cagri.musteri_id) {
            io.to(`musteri_${cagri.musteri_id}`).emit('kurye:konum', konumData);
          }
        }
      } catch (error) {
        console.error('Konum güncelleme socket hatası:', error.message);
      }
    });

    // ─────────────────────────────────────────────
    // Bağlantı koptuğunda
    // ─────────────────────────────────────────────
    socket.on('disconnect', async () => {
      console.log(`Ayrıldı: ${kullanici.ad} ${kullanici.soyad}`);

      if (kullanici.rol === 'kurye' && socket.kuryeId) {
        await db.query(
          "UPDATE kuryeler SET durum = 'cevrimdisi' WHERE id = $1",
          [socket.kuryeId]
        );
      }
    });
  });
}

module.exports = socketBaslat;
