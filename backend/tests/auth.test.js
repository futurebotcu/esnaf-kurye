/**
 * Auth API Integration Testleri
 *
 * NOT: Bu testler gerçek DB yerine mock kullanır.
 * Tam entegrasyon testi için test DB gerekir.
 */

// Env ayarla (config require edilmeden önce)
process.env.JWT_SECRET = 'test_secret_key_for_jest';
process.env.NODE_ENV = 'test';
process.env.PORT = '0'; // random port

// DB'yi mock'la
jest.mock('../src/config/database', () => ({
  query: jest.fn(),
}));

const request = require('supertest');
const express = require('express');
const authRoutes = require('../src/routes/auth');
const db = require('../src/config/database');

// Minimal express app (server.js'yi require etmeden)
const app = express();
app.use(express.json());
app.use('/api/auth', authRoutes);

describe('POST /api/auth/kayit', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('geçerli verilerle kayıt başarılı (201)', async () => {
    // Telefon mevcut değil
    db.query.mockResolvedValueOnce({ rows: [] });
    // INSERT başarılı
    db.query.mockResolvedValueOnce({
      rows: [{
        id: 'test-uuid',
        telefon: '5551234567',
        ad: 'Ali',
        soyad: 'Yılmaz',
        rol: 'musteri',
      }],
    });

    const res = await request(app)
      .post('/api/auth/kayit')
      .send({
        telefon: '5551234567',
        sifre: '123456',
        ad: 'Ali',
        soyad: 'Yılmaz',
        rol: 'musteri',
      });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('token');
    expect(res.body.kullanici.rol).toBe('musteri');
    expect(res.body.mesaj).toBe('Kayıt başarılı');
  });

  test('eksik alanlarla kayıt reddedilir (400)', async () => {
    const res = await request(app)
      .post('/api/auth/kayit')
      .send({
        telefon: '5551234567',
        // sifre eksik
      });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('hata');
  });

  test('geçersiz rol reddedilir (400)', async () => {
    const res = await request(app)
      .post('/api/auth/kayit')
      .send({
        telefon: '5551234567',
        sifre: '123456',
        ad: 'Ali',
        soyad: 'Yılmaz',
        rol: 'admin', // geçersiz
      });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('hata');
  });

  test('mevcut telefon reddedilir (409)', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ id: 'existing' }] });

    const res = await request(app)
      .post('/api/auth/kayit')
      .send({
        telefon: '5551234567',
        sifre: '123456',
        ad: 'Ali',
        soyad: 'Yılmaz',
        rol: 'esnaf',
      });

    expect(res.status).toBe(409);
    expect(res.body.hata).toContain('zaten kayıtlı');
  });
});

describe('POST /api/auth/giris', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('doğru bilgilerle giriş başarılı', async () => {
    const bcrypt = require('bcryptjs');
    const hash = await bcrypt.hash('123456', 12);

    db.query.mockResolvedValueOnce({
      rows: [{
        id: 'test-uuid',
        telefon: '5551234567',
        sifre_hash: hash,
        ad: 'Ali',
        soyad: 'Yılmaz',
        rol: 'kurye',
        aktif: true,
      }],
    });

    const res = await request(app)
      .post('/api/auth/giris')
      .send({
        telefon: '5551234567',
        sifre: '123456',
      });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body.kullanici.rol).toBe('kurye');
  });

  test('yanlış şifreyle giriş reddedilir (401)', async () => {
    const bcrypt = require('bcryptjs');
    const hash = await bcrypt.hash('dogru_sifre', 12);

    db.query.mockResolvedValueOnce({
      rows: [{
        id: 'test-uuid',
        telefon: '5551234567',
        sifre_hash: hash,
        ad: 'Ali',
        soyad: 'Yılmaz',
        rol: 'esnaf',
        aktif: true,
      }],
    });

    const res = await request(app)
      .post('/api/auth/giris')
      .send({
        telefon: '5551234567',
        sifre: 'yanlis_sifre',
      });

    expect(res.status).toBe(401);
    expect(res.body.hata).toContain('hatalı');
  });
});
