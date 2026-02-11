const express = require('express');
const Joi = require('joi');
const db = require('../config/database');
const { authMiddleware, rolKontrol } = require('../middleware/auth');
const { ucretHesapla } = require('../services/fiyatlandirma');
const { enYakinKuryeleri, siraliKuryeBildirimGonder } = require('../services/kuryeBul');

const router = express.Router();

// Tüm rotalar auth gerektirir
router.use(authMiddleware);
router.use(rolKontrol('esnaf'));

/**
 * POST /api/esnaf/profil
 * Esnaf dükkan profili oluştur/güncelle
 */
router.post('/profil', async (req, res) => {
  try {
    const sema = Joi.object({
      dukkan_adi: Joi.string().min(2).max(200).required(),
      kategori: Joi.string().required(),
      adres: Joi.string().required(),
      lat: Joi.number().min(-90).max(90).required(),
      lon: Joi.number().min(-180).max(180).required(),
      telefon: Joi.string().required(),
      aciklama: Joi.string().optional(),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    const { dukkan_adi, kategori, adres, lat, lon, telefon, aciklama } = value;

    // Mevcut profil var mı kontrol et
    const mevcut = await db.query(
      'SELECT id FROM esnaflar WHERE kullanici_id = $1',
      [req.kullanici.id]
    );

    let result;
    if (mevcut.rows.length > 0) {
      result = await db.query(
        `UPDATE esnaflar SET
          dukkan_adi = $1, kategori = $2, adres = $3,
          konum = ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
          telefon = $6, aciklama = $7
        WHERE kullanici_id = $8
        RETURNING *`,
        [dukkan_adi, kategori, adres, lon, lat, telefon, aciklama, req.kullanici.id]
      );
    } else {
      result = await db.query(
        `INSERT INTO esnaflar (kullanici_id, dukkan_adi, kategori, adres, konum, telefon, aciklama)
        VALUES ($1, $2, $3, $4, ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography, $7, $8)
        RETURNING *`,
        [req.kullanici.id, dukkan_adi, kategori, adres, lon, lat, telefon, aciklama]
      );
    }

    res.json({ mesaj: 'Profil kaydedildi', esnaf: result.rows[0] });
  } catch (error) {
    console.error('Esnaf profil hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * GET /api/esnaf/profil
 * Esnaf profilini getir
 */
router.get('/profil', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT e.*, u.ad, u.soyad, u.telefon as kullanici_telefon
       FROM esnaflar e
       JOIN kullanicilar u ON u.id = e.kullanici_id
       WHERE e.kullanici_id = $1`,
      [req.kullanici.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ hata: 'Esnaf profili bulunamadı' });
    }

    res.json({ esnaf: result.rows[0] });
  } catch (error) {
    console.error('Profil getirme hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * POST /api/esnaf/fiyat-hesapla
 * Teslimat fiyatını ön hesapla (onay öncesi)
 */
router.post('/fiyat-hesapla', async (req, res) => {
  try {
    const sema = Joi.object({
      hedef_lat: Joi.number().min(-90).max(90).required(),
      hedef_lon: Joi.number().min(-180).max(180).required(),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    // Esnaf konumunu al
    const esnafResult = await db.query(
      `SELECT ST_Y(konum::geometry) as lat, ST_X(konum::geometry) as lon
       FROM esnaflar WHERE kullanici_id = $1`,
      [req.kullanici.id]
    );

    if (esnafResult.rows.length === 0) {
      return res.status(404).json({ hata: 'Önce dükkan profilinizi oluşturun' });
    }

    const esnaf = esnafResult.rows[0];
    const fiyat = await ucretHesapla(
      esnaf.lat, esnaf.lon,
      value.hedef_lat, value.hedef_lon
    );

    res.json({ fiyat });
  } catch (error) {
    console.error('Fiyat hesaplama hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * POST /api/esnaf/cagri-olustur
 * Kurye çağrısı oluştur ve en yakın kuryeye bildirim gönder
 */
router.post('/cagri-olustur', async (req, res) => {
  try {
    const sema = Joi.object({
      hedef_adres: Joi.string().required(),
      hedef_lat: Joi.number().min(-90).max(90).required(),
      hedef_lon: Joi.number().min(-180).max(180).required(),
      aciklama: Joi.string().optional().allow(''),
    });

    const { error, value } = sema.validate(req.body);
    if (error) return res.status(400).json({ hata: error.details[0].message });

    // Esnaf bilgisini al
    const esnafResult = await db.query(
      `SELECT id, ST_Y(konum::geometry) as lat, ST_X(konum::geometry) as lon
       FROM esnaflar WHERE kullanici_id = $1`,
      [req.kullanici.id]
    );

    if (esnafResult.rows.length === 0) {
      return res.status(404).json({ hata: 'Önce dükkan profilinizi oluşturun' });
    }

    const esnaf = esnafResult.rows[0];

    // Fiyat hesapla
    const fiyat = await ucretHesapla(
      esnaf.lat, esnaf.lon,
      value.hedef_lat, value.hedef_lon
    );

    // Çağrı oluştur
    const cagriResult = await db.query(
      `INSERT INTO cagrilar
        (esnaf_id, hedef_adres, hedef_konum, baslangic_konum,
         mesafe_km, baz_ucret, hava_carpani, gece_ek_ucret, toplam_ucret, aciklama)
       VALUES
        ($1, $2,
         ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
         ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography,
         $7, $8, $9, $10, $11, $12)
       RETURNING *`,
      [
        esnaf.id,
        value.hedef_adres,
        value.hedef_lon, value.hedef_lat,
        esnaf.lon, esnaf.lat,
        fiyat.mesafe_km, fiyat.baz_ucret, fiyat.hava_carpani,
        fiyat.gece_ek_ucret, fiyat.toplam_ucret,
        value.aciklama || null,
      ]
    );

    const cagri = cagriResult.rows[0];

    // En yakın kuryeleri bul
    const kuryeler = await enYakinKuryeleri(esnaf.lat, esnaf.lon);

    if (kuryeler.length === 0) {
      await db.query(
        "UPDATE cagrilar SET durum = 'iptal', iptal_zamani = NOW() WHERE id = $1",
        [cagri.id]
      );
      return res.status(404).json({
        hata: 'Şu anda müsait kurye bulunmuyor',
        fiyat,
      });
    }

    // İlk kuryeye bildirim gönder
    const io = req.app.get('io');
    await siraliKuryeBildirimGonder(cagri.id, kuryeler, 0, io);

    // Esnafı bilgilendir
    if (io) {
      io.to(`esnaf_${esnaf.id}`).emit('cagri_olusturuldu', {
        cagri_id: cagri.id,
        durum: 'beklemede',
        fiyat,
      });
    }

    res.status(201).json({
      mesaj: 'Çağrı oluşturuldu, kurye aranıyor...',
      cagri: cagri,
      fiyat,
    });
  } catch (error) {
    console.error('Çağrı oluşturma hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * GET /api/esnaf/cagrilarim
 * Esnafın çağrı geçmişi
 */
router.get('/cagrilarim', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT c.*, u.ad as kurye_ad, u.soyad as kurye_soyad
       FROM cagrilar c
       LEFT JOIN kuryeler k ON k.id = c.kurye_id
       LEFT JOIN kullanicilar u ON u.id = k.kullanici_id
       JOIN esnaflar e ON e.id = c.esnaf_id
       WHERE e.kullanici_id = $1
       ORDER BY c.olusturulma_zamani DESC
       LIMIT 50`,
      [req.kullanici.id]
    );

    res.json({ cagrilar: result.rows });
  } catch (error) {
    console.error('Çağrı listeleme hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

module.exports = router;
