-- =============================================
-- ESNAF-KURYE LOJİSTİK KÖPRÜSÜ - VERİTABANI KURULUMU
-- =============================================
-- Kullanım (PowerShell):
--   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d esnaf_kurye -f "C:\dev\esnaf kurye\backend\database.sql"
--
-- NOT: PostGIS eklentisi gereklidir. Eğer yüklü değilse:
--   Stack Builder > PostgreSQL 18 > Spatial Extensions > PostGIS
-- =============================================

-- UUID desteği
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Konum hesaplamaları için
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =============================================
-- 1) ENUM TİPLERİ
-- =============================================

DO $$ BEGIN
    CREATE TYPE kurye_durum AS ENUM ('musait', 'mesgul', 'cevrimdisi');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE arac_tipi AS ENUM ('motorsiklet', 'bisiklet', 'otomobil', 'yaya');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE cagri_durum AS ENUM ('beklemede', 'atandi', 'teslim_alindi', 'teslimde', 'tamamlandi', 'iptal');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE odeme_yontemi AS ENUM ('nakit', 'sanal_pos');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE odeme_durum AS ENUM ('beklemede', 'dogrulandi', 'iptal');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE kullanici_rol AS ENUM ('esnaf', 'kurye');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================
-- 2) KULLANICILAR (Ortak Auth Tablosu)
-- =============================================

CREATE TABLE IF NOT EXISTS kullanicilar (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telefon VARCHAR(15) UNIQUE NOT NULL,
    sifre_hash VARCHAR(255) NOT NULL,
    rol kullanici_rol NOT NULL,
    ad VARCHAR(100) NOT NULL,
    soyad VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    profil_foto_url TEXT,
    aktif BOOLEAN DEFAULT true,
    olusturulma_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    guncellenme_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kullanicilar_telefon ON kullanicilar(telefon);
CREATE INDEX IF NOT EXISTS idx_kullanicilar_rol ON kullanicilar(rol);

-- =============================================
-- 3) ESNAFLAR
-- =============================================

CREATE TABLE IF NOT EXISTS esnaflar (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kullanici_id UUID NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
    dukkan_adi VARCHAR(200) NOT NULL,
    kategori VARCHAR(100) NOT NULL,
    adres TEXT NOT NULL,
    konum GEOGRAPHY(POINT, 4326) NOT NULL,
    telefon VARCHAR(15) NOT NULL,
    aciklama TEXT,
    calisma_saatleri JSONB,
    aktif BOOLEAN DEFAULT true,
    olusturulma_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    guncellenme_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_esnaflar_kullanici ON esnaflar(kullanici_id);
CREATE INDEX IF NOT EXISTS idx_esnaflar_konum ON esnaflar USING GIST(konum);
CREATE INDEX IF NOT EXISTS idx_esnaflar_kategori ON esnaflar(kategori);

-- =============================================
-- 4) KURYELER
-- =============================================

CREATE TABLE IF NOT EXISTS kuryeler (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kullanici_id UUID NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
    arac_tipi arac_tipi NOT NULL DEFAULT 'motorsiklet',
    konum GEOGRAPHY(POINT, 4326),
    durum kurye_durum DEFAULT 'cevrimdisi',
    ortalama_puan DECIMAL(3,2) DEFAULT 0.00,
    toplam_teslimat INTEGER DEFAULT 0,
    aktif BOOLEAN DEFAULT true,
    son_konum_zamani TIMESTAMP WITH TIME ZONE,
    olusturulma_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    guncellenme_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kuryeler_kullanici ON kuryeler(kullanici_id);
CREATE INDEX IF NOT EXISTS idx_kuryeler_konum ON kuryeler USING GIST(konum);
CREATE INDEX IF NOT EXISTS idx_kuryeler_durum ON kuryeler(durum);

-- =============================================
-- 5) ÇAĞRILAR (Teslimat Siparişleri)
-- =============================================

CREATE TABLE IF NOT EXISTS cagrilar (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    esnaf_id UUID NOT NULL REFERENCES esnaflar(id),
    kurye_id UUID REFERENCES kuryeler(id),

    -- Adres bilgileri
    hedef_adres TEXT NOT NULL,
    hedef_konum GEOGRAPHY(POINT, 4326) NOT NULL,
    baslangic_konum GEOGRAPHY(POINT, 4326) NOT NULL,

    -- Mesafe ve fiyat
    mesafe_km DECIMAL(6,2) NOT NULL,
    baz_ucret DECIMAL(10,2) NOT NULL,
    hava_carpani DECIMAL(4,2) DEFAULT 1.00,
    gece_ek_ucret DECIMAL(10,2) DEFAULT 0.00,
    toplam_ucret DECIMAL(10,2) NOT NULL,

    -- Durum takibi
    durum cagri_durum DEFAULT 'beklemede',
    bildirim_sirasi INTEGER DEFAULT 0,

    -- Zaman damgaları
    olusturulma_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    atanma_zamani TIMESTAMP WITH TIME ZONE,
    teslim_alma_zamani TIMESTAMP WITH TIME ZONE,
    teslim_etme_zamani TIMESTAMP WITH TIME ZONE,
    iptal_zamani TIMESTAMP WITH TIME ZONE,

    aciklama TEXT
);

CREATE INDEX IF NOT EXISTS idx_cagrilar_esnaf ON cagrilar(esnaf_id);
CREATE INDEX IF NOT EXISTS idx_cagrilar_kurye ON cagrilar(kurye_id);
CREATE INDEX IF NOT EXISTS idx_cagrilar_durum ON cagrilar(durum);
CREATE INDEX IF NOT EXISTS idx_cagrilar_tarih ON cagrilar(olusturulma_zamani DESC);

-- =============================================
-- 6) ÇAĞRI BİLDİRİM GEÇMİŞİ
-- =============================================

CREATE TABLE IF NOT EXISTS cagri_bildirimleri (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cagri_id UUID NOT NULL REFERENCES cagrilar(id) ON DELETE CASCADE,
    kurye_id UUID NOT NULL REFERENCES kuryeler(id),
    sira INTEGER NOT NULL,
    durum VARCHAR(20) DEFAULT 'gonderildi',
    gonderim_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    yanit_zamani TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_bildirimler_cagri ON cagri_bildirimleri(cagri_id);

-- =============================================
-- 7) ÖDEMELER
-- =============================================

CREATE TABLE IF NOT EXISTS odemeler (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cagri_id UUID NOT NULL REFERENCES cagrilar(id),
    tutar DECIMAL(10,2) NOT NULL,
    yontem odeme_yontemi NOT NULL,
    durum odeme_durum DEFAULT 'beklemede',
    dogrulama_zamani TIMESTAMP WITH TIME ZONE,
    olusturulma_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_odemeler_cagri ON odemeler(cagri_id);

-- =============================================
-- 8) PUAN DEĞERLENDİRME
-- =============================================

CREATE TABLE IF NOT EXISTS puanlamalar (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cagri_id UUID NOT NULL REFERENCES cagrilar(id),
    degerlendiren_id UUID NOT NULL REFERENCES kullanicilar(id),
    degerlendirilen_id UUID NOT NULL REFERENCES kullanicilar(id),
    puan INTEGER NOT NULL CHECK (puan >= 1 AND puan <= 5),
    yorum TEXT,
    olusturulma_zamani TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_puanlamalar_cagri ON puanlamalar(cagri_id);
CREATE INDEX IF NOT EXISTS idx_puanlamalar_kurye ON puanlamalar(degerlendirilen_id);

-- =============================================
-- 9) GÜNCELLENME TRİGGER'I
-- =============================================

CREATE OR REPLACE FUNCTION guncelle_zaman_damgasi()
RETURNS TRIGGER AS $$
BEGIN
    NEW.guncellenme_zamani = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_kullanicilar_guncelle ON kullanicilar;
CREATE TRIGGER trg_kullanicilar_guncelle
    BEFORE UPDATE ON kullanicilar
    FOR EACH ROW EXECUTE FUNCTION guncelle_zaman_damgasi();

DROP TRIGGER IF EXISTS trg_esnaflar_guncelle ON esnaflar;
CREATE TRIGGER trg_esnaflar_guncelle
    BEFORE UPDATE ON esnaflar
    FOR EACH ROW EXECUTE FUNCTION guncelle_zaman_damgasi();

DROP TRIGGER IF EXISTS trg_kuryeler_guncelle ON kuryeler;
CREATE TRIGGER trg_kuryeler_guncelle
    BEFORE UPDATE ON kuryeler
    FOR EACH ROW EXECUTE FUNCTION guncelle_zaman_damgasi();

-- =============================================
-- 10) KURYE PUAN GÜNCELLEME FONKSİYONU
-- =============================================

CREATE OR REPLACE FUNCTION kurye_puan_guncelle()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE kuryeler
    SET ortalama_puan = (
        SELECT COALESCE(AVG(p.puan), 0)
        FROM puanlamalar p
        JOIN kuryeler k ON k.kullanici_id = p.degerlendirilen_id
        WHERE k.id = (
            SELECT id FROM kuryeler WHERE kullanici_id = NEW.degerlendirilen_id
        )
    )
    WHERE kullanici_id = NEW.degerlendirilen_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_puan_guncelle ON puanlamalar;
CREATE TRIGGER trg_puan_guncelle
    AFTER INSERT ON puanlamalar
    FOR EACH ROW EXECUTE FUNCTION kurye_puan_guncelle();

-- =============================================
-- 11) MÜŞTERİ ROLÜ MİGRASYONU
-- =============================================

ALTER TYPE kullanici_rol ADD VALUE IF NOT EXISTS 'musteri';
ALTER TABLE cagrilar ADD COLUMN IF NOT EXISTS musteri_id UUID REFERENCES kullanicilar(id);
CREATE INDEX IF NOT EXISTS idx_cagrilar_musteri ON cagrilar(musteri_id);

-- =============================================
-- KURULUM TAMAMLANDI
-- =============================================
DO $$ BEGIN
    RAISE NOTICE '✓ Tüm tablolar başarıyla oluşturuldu!';
END $$;
