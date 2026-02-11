const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const db = require('../config/database');
const config = require('../config');

const router = express.Router();

// Validasyon şemaları
const kayitSemasi = Joi.object({
  telefon: Joi.string().pattern(/^[0-9]{10,11}$/).required()
    .messages({ 'string.pattern.base': 'Geçerli bir telefon numarası girin' }),
  sifre: Joi.string().min(6).required(),
  ad: Joi.string().min(2).max(100).required(),
  soyad: Joi.string().min(2).max(100).required(),
  rol: Joi.string().valid('esnaf', 'kurye', 'musteri').required(),
  email: Joi.string().email().optional(),
});

const girisSemasi = Joi.object({
  telefon: Joi.string().required(),
  sifre: Joi.string().required(),
});

/**
 * POST /api/auth/kayit
 * Yeni kullanıcı kaydı
 */
router.post('/kayit', async (req, res) => {
  try {
    const { error, value } = kayitSemasi.validate(req.body);
    if (error) {
      return res.status(400).json({ hata: error.details[0].message });
    }

    const { telefon, sifre, ad, soyad, rol, email } = value;

    // Telefon kontrolü
    const mevcutKullanici = await db.query(
      'SELECT id FROM kullanicilar WHERE telefon = $1',
      [telefon]
    );
    if (mevcutKullanici.rows.length > 0) {
      return res.status(409).json({ hata: 'Bu telefon numarası zaten kayıtlı' });
    }

    // Şifre hash'le
    const sifreHash = await bcrypt.hash(sifre, 12);

    // Kullanıcı oluştur
    const result = await db.query(
      `INSERT INTO kullanicilar (telefon, sifre_hash, ad, soyad, rol, email)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, telefon, ad, soyad, rol`,
      [telefon, sifreHash, ad, soyad, rol, email]
    );

    const kullanici = result.rows[0];

    // Token oluştur
    const token = jwt.sign(
      { id: kullanici.id, rol: kullanici.rol },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    res.status(201).json({
      mesaj: 'Kayıt başarılı',
      kullanici,
      token,
    });
  } catch (error) {
    console.error('Kayıt hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

/**
 * POST /api/auth/giris
 * Kullanıcı girişi
 */
router.post('/giris', async (req, res) => {
  try {
    const { error, value } = girisSemasi.validate(req.body);
    if (error) {
      return res.status(400).json({ hata: error.details[0].message });
    }

    const { telefon, sifre } = value;

    const result = await db.query(
      'SELECT id, telefon, sifre_hash, ad, soyad, rol, aktif FROM kullanicilar WHERE telefon = $1',
      [telefon]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ hata: 'Telefon veya şifre hatalı' });
    }

    const kullanici = result.rows[0];

    if (!kullanici.aktif) {
      return res.status(403).json({ hata: 'Hesabınız devre dışı' });
    }

    const sifreGecerli = await bcrypt.compare(sifre, kullanici.sifre_hash);
    if (!sifreGecerli) {
      return res.status(401).json({ hata: 'Telefon veya şifre hatalı' });
    }

    const token = jwt.sign(
      { id: kullanici.id, rol: kullanici.rol },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    res.json({
      mesaj: 'Giriş başarılı',
      kullanici: {
        id: kullanici.id,
        telefon: kullanici.telefon,
        ad: kullanici.ad,
        soyad: kullanici.soyad,
        rol: kullanici.rol,
      },
      token,
    });
  } catch (error) {
    console.error('Giriş hatası:', error);
    res.status(500).json({ hata: 'Sunucu hatası' });
  }
});

module.exports = router;
