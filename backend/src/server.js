const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const config = require('./config');

// Express uygulaması
const app = express();
const server = http.createServer(app);

// CORS origin:
// - production: config.corsOrigins zorunlu (config'de enforce ediliyor)
// - development/test: corsOrigins null ise '*' (tüm origin serbest)
const corsOrigin = config.corsOrigins || '*';

// Socket.io
const io = new Server(server, {
  cors: {
    origin: corsOrigin,
    methods: ['GET', 'POST'],
  },
});
app.set('io', io);

// ─────────────────────────────────────────────
// Middleware'ler
// ─────────────────────────────────────────────
app.use(cors({
  origin: corsOrigin,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));
app.use(express.json());

// Rate limiter
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 dakika
  max: 100,
  message: { hata: 'Çok fazla istek, lütfen bekleyin' },
});
app.use('/api/', limiter);

// ─────────────────────────────────────────────
// Rotalar
// ─────────────────────────────────────────────
const authRoutes = require('./routes/auth');
const esnafRoutes = require('./routes/esnaf');
const kuryeRoutes = require('./routes/kurye');
const musteriRoutes = require('./routes/musteri');

app.use('/api/auth', authRoutes);
app.use('/api/esnaf', esnafRoutes);
app.use('/api/kurye', kuryeRoutes);
app.use('/api/musteri', musteriRoutes);

// Sağlık kontrolü
app.get('/api/saglik', (req, res) => {
  res.json({
    durum: 'aktif',
    zaman: new Date().toISOString(),
    versiyon: '1.0.0',
  });
});

// ─────────────────────────────────────────────
// Socket.io başlat
// ─────────────────────────────────────────────
const socketBaslat = require('./socket');
socketBaslat(io);

// ─────────────────────────────────────────────
// 404 ve Hata yönetimi
// ─────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ hata: 'Endpoint bulunamadı' });
});

app.use((err, req, res, _next) => {
  console.error('Sunucu hatası:', err);
  res.status(500).json({ hata: 'Sunucu hatası' });
});

// ─────────────────────────────────────────────
// Sunucuyu başlat
// ─────────────────────────────────────────────
server.listen(config.port, () => {
  console.log(`
  ╔═══════════════════════════════════════════╗
  ║   ESNAF-KURYE LOJİSTİK KÖPRÜSÜ          ║
  ║   Sunucu aktif: http://localhost:${config.port}    ║
  ║   Ortam: ${config.nodeEnv.padEnd(20)}          ║
  ╚═══════════════════════════════════════════╝
  `);
});

module.exports = { app, server, io };
