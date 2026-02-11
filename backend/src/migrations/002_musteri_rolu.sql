-- =============================================
-- Migration 002: Müşteri rolü + cagrilar.musteri_id
-- =============================================

-- Müşteri rolünü ENUM'a ekle
ALTER TYPE kullanici_rol ADD VALUE IF NOT EXISTS 'musteri';

-- Çağrılar tablosuna müşteri ilişkisi ekle
ALTER TABLE cagrilar ADD COLUMN IF NOT EXISTS musteri_id UUID REFERENCES kullanicilar(id);

-- Index'ler
CREATE INDEX IF NOT EXISTS idx_cagrilar_musteri ON cagrilar(musteri_id);
CREATE INDEX IF NOT EXISTS idx_cagrilar_musteri_durum ON cagrilar(musteri_id, durum);
CREATE INDEX IF NOT EXISTS idx_bildirimler_kurye_durum ON cagri_bildirimleri(kurye_id, durum);

-- Çift puanlama engeli
DO $$ BEGIN
    ALTER TABLE puanlamalar ADD CONSTRAINT uq_puanlama_cagri_kisi UNIQUE(cagri_id, degerlendiren_id);
EXCEPTION WHEN duplicate_table THEN NULL;
          WHEN duplicate_object THEN NULL;
END $$;
