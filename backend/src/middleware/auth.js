const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../config/database');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ hata: 'Yetkilendirme token\'ı gerekli' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, config.jwt.secret);

    const result = await db.query(
      'SELECT id, telefon, rol, ad, soyad FROM kullanicilar WHERE id = $1 AND aktif = true',
      [decoded.id]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ hata: 'Geçersiz veya pasif kullanıcı' });
    }

    req.kullanici = result.rows[0];
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ hata: 'Token süresi dolmuş' });
    }
    return res.status(401).json({ hata: 'Geçersiz token' });
  }
};

const rolKontrol = (...roller) => {
  return (req, res, next) => {
    if (!roller.includes(req.kullanici.rol)) {
      return res.status(403).json({ hata: 'Bu işlem için yetkiniz yok' });
    }
    next();
  };
};

module.exports = { authMiddleware, rolKontrol };
