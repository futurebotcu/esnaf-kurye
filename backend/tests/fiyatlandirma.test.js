/**
 * Fiyatlandırma Servisi Unit Testleri
 */

// Config'i mock'la (config require edilmeden önce)
jest.mock('../src/config', () => ({
  fiyatlandirma: {
    kmBasi: 5.0,
    yagmurCarpani: 1.3,
    geceEkUcret: 15.0,
    geceBaslangic: 22,
    minUcret: 20.0,
  },
  weatherApiKey: '',
}));

jest.mock('axios');

const { mesafeHesapla, geceEkUcretiHesapla, ucretHesapla } = require('../src/services/fiyatlandirma');

describe('mesafeHesapla', () => {
  test('aynı nokta arası 0 km döner', () => {
    const sonuc = mesafeHesapla(41.0, 29.0, 41.0, 29.0);
    expect(sonuc).toBe(0);
  });

  test('İstanbul Kadıköy → Beşiktaş yaklaşık 6-8 km', () => {
    // Kadıköy: 40.9903, 29.0295 → Beşiktaş: 41.0422, 29.0070
    const sonuc = mesafeHesapla(40.9903, 29.0295, 41.0422, 29.0070);
    expect(sonuc).toBeGreaterThan(5);
    expect(sonuc).toBeLessThan(10);
  });

  test('büyük mesafe doğru hesaplanır (İstanbul → Ankara ~350km)', () => {
    const sonuc = mesafeHesapla(41.0082, 28.9784, 39.9334, 32.8597);
    expect(sonuc).toBeGreaterThan(300);
    expect(sonuc).toBeLessThan(400);
  });
});

describe('geceEkUcretiHesapla', () => {
  test('gece saatinde (23:00) ek ücret döner', () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15T23:00:00'));
    const sonuc = geceEkUcretiHesapla();
    expect(sonuc).toBe(15.0);
    jest.useRealTimers();
  });

  test('gündüz saatinde (14:00) ek ücret 0 döner', () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15T14:00:00'));
    const sonuc = geceEkUcretiHesapla();
    expect(sonuc).toBe(0);
    jest.useRealTimers();
  });

  test('gece yarısı (02:00) ek ücret döner', () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15T02:00:00'));
    const sonuc = geceEkUcretiHesapla();
    expect(sonuc).toBe(15.0);
    jest.useRealTimers();
  });
});

describe('ucretHesapla', () => {
  test('kısa mesafe minimum ücret altına düşmez', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15T14:00:00'));
    // Çok kısa mesafe (aynı mahalle ~0.5km)
    const sonuc = await ucretHesapla(41.0082, 28.9784, 41.0082, 28.9824);
    expect(sonuc.toplam_ucret).toBeGreaterThanOrEqual(20.0);
    expect(sonuc.mesafe_km).toBeLessThan(1);
    jest.useRealTimers();
  });

  test('gece mesafe + ek ücret doğru hesaplanır', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15T23:00:00'));
    // ~6km mesafe → baz: 6*5=30, gece ek: 15 → toplam: 45
    const sonuc = await ucretHesapla(40.9903, 29.0295, 41.0422, 29.0070);
    expect(sonuc.gece_ek_ucret).toBe(15.0);
    expect(sonuc.toplam_ucret).toBeGreaterThan(30);
    expect(sonuc.hava_carpani).toBe(1.0);
    jest.useRealTimers();
  });

  test('dönen objede tüm alanlar mevcut', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15T12:00:00'));
    const sonuc = await ucretHesapla(41.0, 29.0, 41.05, 29.05);
    expect(sonuc).toHaveProperty('mesafe_km');
    expect(sonuc).toHaveProperty('baz_ucret');
    expect(sonuc).toHaveProperty('hava_durumu');
    expect(sonuc).toHaveProperty('hava_carpani');
    expect(sonuc).toHaveProperty('gece_ek_ucret');
    expect(sonuc).toHaveProperty('toplam_ucret');
    expect(sonuc).toHaveProperty('hesaplama_zamani');
    jest.useRealTimers();
  });
});
