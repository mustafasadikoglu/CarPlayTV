// CarPlayTV — VOD Oynatma Tanılama Aracı
//
// Bu araç, Xtream sunucunuzdaki film/dizi akışlarının hangi formatlarda
// (.m3u8 / .mp4 / .mkv / .avi / .ts) gerçekten erişilebilir olduğunu test eder.
// Şifreniz hiçbir yerde kaydedilmez veya yazdırılmaz; rapor şifreyi *** ile maskeler.
//
// Kullanım:
//   node scripts/diagnose_vod.js --server http://host:port --user KULLANICI --pass SIFRE
//
// Çıktıyı olduğu gibi kopyalayıp paylaşabilirsiniz (şifre gizlidir).

const http = require('http');
const https = require('https');

function getArg(name) {
  const idx = process.argv.indexOf('--' + name);
  return idx !== -1 ? process.argv[idx + 1] : null;
}

const serverRaw = getArg('server');
const username = getArg('user');
const password = getArg('pass');

if (!serverRaw || !username || !password) {
  console.error('Kullanım: node scripts/diagnose_vod.js --server http://host:port --user KULLANICI --pass SIFRE');
  process.exit(1);
}

// --- Sunucu adresini temizle ---
function cleanServerURL(s) {
  let clean = s.trim();
  if (!/^https?:\/\//i.test(clean)) clean = 'http://' + clean;
  while (clean.endsWith('/')) clean = clean.slice(0, -1);
  ['/player_api.php', '/get.php', '/c'].forEach((suffix) => {
    if (clean.toLowerCase().endsWith(suffix)) clean = clean.slice(0, -suffix.length);
  });
  while (clean.endsWith('/')) clean = clean.slice(0, -1);
  return clean;
}

const BASE = cleanServerURL(serverRaw);

function encodePathComponent(s) {
  return encodeURIComponent(s);
}

function maskUrl(url) {
  // URL içindeki şifre kısmını (raw ve encode edilmiş) maskele
  let masked = url;
  [password, encodeURIComponent(password)].forEach((p) => {
    if (p && masked.includes(p)) masked = masked.split(p).join('***');
  });
  return masked;
}

function request(url, opts = {}) {
  return new Promise((resolve) => {
    let u;
    try {
      u = new URL(url);
    } catch (e) {
      resolve({ status: 0, error: 'bad-url' });
      return;
    }
    const lib = u.protocol === 'https:' ? https : http;
    const headers = {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      'Accept': '*/*'
    };
    if (opts.range) headers['Range'] = opts.range;

    const req = lib.get(u, { headers }, (res) => {
      let size = 0;
      const chunks = [];
      const MAX = opts.limitBytes || 8192;
      let finished = false;
      const finish = (extra) => {
        if (finished) return;
        finished = true;
        req.destroy();
        const body = Buffer.concat(chunks);
        resolve({
          status: res.statusCode,
          contentType: res.headers['content-type'] || '',
          contentLength: res.headers['content-length'] || null,
          location: res.headers['location'] || null,
          bytesRead: size,
          head: body.slice(0, 512)
        });
      };
      res.on('data', (c) => {
        size += c.length;
        chunks.push(c);
        if (size >= MAX) finish();
      });
      res.on('end', () => finish());
      res.on('error', () => finish());
      setTimeout(() => finish(), 10000);
    });
    req.on('error', (e) => resolve({ status: 0, error: e.message }));
    req.setTimeout(10000, () => { req.destroy(); resolve({ status: 0, error: 'timeout' }); });
  });
}

async function probe(url, opts = {}) {
  let current = url;
  const redirects = [];
  for (let i = 0; i < 6; i++) {
    const r = await request(current, opts);
    if (r.status >= 300 && r.status < 400 && r.location) {
      try {
        current = new URL(r.location, current).toString();
      } catch (e) {
        return { ...r, redirected: redirects };
      }
      redirects.push(r.status + ' -> ' + maskUrl(current));
      continue;
    }
    return { ...r, redirected: redirects };
  }
  return { status: 0, error: 'too-many-redirects', redirected: redirects };
}

function sniff(head, contentType) {
  const ct = (contentType || '').toLowerCase();
  const text = head.toString('latin1');
  if (ct.includes('mpegurl') || text.startsWith('#EXTM3U')) return 'HLS (.m3u8)';
  if (head.length >= 4 && head.toString('latin1', 0, 4) === '\u001aE\u00df\u00a3') return 'MKV/EBML';
  if (head.length >= 4 && head.toString('latin1', 0, 4) === 'RIFF' && head.length >= 12 && head.toString('latin1', 8, 12) === 'AVI ') return 'AVI';
  if (head.length >= 4 && head.toString('latin1', 0, 4) === 'ftyp') return 'MP4';
  if (ct.includes('mp4') || ct.includes('octet-stream')) return 'Muhtemelen MP4';
  if (ct.includes('matroska')) return 'MKV/EBML';
  if (ct.includes('text/html')) return 'HTML (hata sayfası olabilir)';
  if (ct.includes('json')) return 'JSON (hata mesajı olabilir)';
  return 'Bilinmiyor';
}

async function apiGet(path) {
  const url = `${BASE}/player_api.php?username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}${path ? '&action=' + path : ''}`;
  const raw = await fullRequest(url);
  if (!raw) return { status: 0, body: null };
  let body = null;
  try { body = JSON.parse(raw); } catch (e) { body = null; }
  return { status: 200, body };
}

function fullRequest(url) {
  return new Promise((resolve) => {
    const doGet = (u, depth) => {
      let parsed;
      try { parsed = new URL(u); } catch (e) { resolve(''); return; }
      const lib = parsed.protocol === 'https:' ? https : http;
      const headers = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148' };
      const req = lib.get(parsed, { headers }, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && depth < 6) {
          let next;
          try { next = new URL(res.headers.location, u).toString(); } catch (e) { resolve(''); return; }
          res.resume();
          doGet(next, depth + 1);
          return;
        }
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
      });
      req.on('error', () => resolve(''));
      req.setTimeout(15000, () => { req.destroy(); resolve(''); });
    };
    doGet(url, 0);
  });
}

function extFrom(c) {
  if (!c) return 'mp4';
  let e = String(c).toLowerCase().replace(/^\.+/, '').trim();
  return e || 'mp4';
}

async function main() {
  console.log('==================================================');
  console.log('CarPlayTV VOD Tanılama');
  console.log('Sunucu: ' + BASE.replace(/\/\/.*@/, '//***@').replace(new RegExp(password, 'g'), '***'));
  console.log('Kullanıcı: ' + username);
  console.log('==================================================\n');

  // 1. Kimlik doğrulama / hesap bilgisi
  const auth = await apiGet('');
  if (auth.status !== 200 || !auth.body) {
    console.log('❌ Kimlik doğrulama BAŞARISIZ (HTTP ' + auth.status + '). Sunucu/kullanıcı/şifre bilgilerini kontrol edin.');
    return;
  }
  const ui = auth.body.user_info || {};
  console.log('✅ Kimlik doğrulama başarılı. Durum: ' + (ui.status || '?') + ', Bitiş: ' + (ui.exp_date || '?'));

  const exts = ['m3u8', 'mp4', 'mkv', 'avi', 'ts'];

  // 2. Canlı yayın sağlık kontrolü (çalışan referans)
  console.log('\n--- CANLI YAYIN (referans) ---');
  const live = await apiGet('get_live_streams');
  if (live.body && Array.isArray(live.body) && live.body.length > 0) {
    const ch = live.body[0];
    const liveUrl = `${BASE}/live/${encodePathComponent(username)}/${encodePathComponent(password)}/${ch.stream_id}.m3u8`;
    const r = await probe(liveUrl);
    console.log(`  Canlı #${ch.stream_id} (.m3u8): HTTP ${r.status} [${sniff(r.head, r.contentType)}] ${r.bytesRead} byte`);
  } else {
    console.log('  Canlı liste alınamadı: HTTP ' + live.status);
  }

  // 3. Film (VOD) testleri
  console.log('\n--- FİLM (get_vod_streams) ---');
  const vod = await apiGet('get_vod_streams');
  if (!vod.body || !Array.isArray(vod.body) || vod.body.length === 0) {
    console.log('  ❌ Film listesi alınamadı: HTTP ' + vod.status);
  } else {
    const samples = vod.body.slice(0, 3);
    for (const m of samples) {
      const id = m.stream_id;
      const apiExt = extFrom(m.container_extension);
      console.log(`\n  🎬 Film #${id} "${(m.name || '').slice(0, 40)}" (API container_extension: ${apiExt})`);
      for (const ext of exts) {
        const u = `${BASE}/movie/${encodePathComponent(username)}/${encodePathComponent(password)}/${id}.${ext}`;
        const r = await probe(u);
        const tag = ext === apiExt ? ' (API bildirdi)' : '';
        console.log(`     .${ext}${tag}: HTTP ${r.status} [${sniff(r.head, r.contentType)}] ${r.bytesRead} byte${r.error ? ' | hata: ' + r.error : ''}`);
        if (ext === 'mp4' && r.status === 200) {
          const rr = await probe(u, { range: 'bytes=0-1023' });
          console.log(`        Range desteği (206 olmalı): HTTP ${rr.status}`);
        }
      }
    }
  }

  // 4. Dizi (bölüm) testleri
  console.log('\n--- DİZİ (get_series + get_series_info) ---');
  const series = await apiGet('get_series');
  if (!series.body || !Array.isArray(series.body) || series.body.length === 0) {
    console.log('  ❌ Dizi listesi alınamadı: HTTP ' + series.status);
  } else {
    const s = series.body[0];
    const sid = s.series_id;
    console.log(`  📺 Dizi #${sid} "${(s.name || '').slice(0, 40)}"`);
    const infoUrl = `${BASE}/player_api.php?username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}&action=get_series_info&series_id=${sid}`;
    const info = await fullRequest(infoUrl);
    let episodes = [];
    try {
      const parsed = JSON.parse(info);
      if (parsed.episodes) {
        const firstSeasonKey = Object.keys(parsed.episodes)[0];
        episodes = parsed.episodes[firstSeasonKey] || [];
      }
    } catch (e) { /* yoksay */ }
    if (episodes.length === 0) {
      console.log('  ⚠️ Bölüm listesi alınamadı (get_series_info boş/hata).');
    } else {
      const ep = episodes[0];
      const epId = String(ep.stream_id || ep.episode_id || ep.id || '');
      const apiExt = extFrom(ep.container_extension || (ep.info && ep.info.container_extension));
      console.log(`  ▶️ 1. Bölüm id=${epId} "${(ep.title || '').slice(0, 40)}" (container_extension: ${apiExt})`);
      for (const ext of exts) {
        const u = `${BASE}/series/${encodePathComponent(username)}/${encodePathComponent(password)}/${epId}.${ext}`;
        const r = await probe(u);
        const tag = ext === apiExt ? ' (API bildirdi)' : '';
        console.log(`     .${ext}${tag}: HTTP ${r.status} [${sniff(r.head, r.contentType)}] ${r.bytesRead} byte${r.error ? ' | hata: ' + r.error : ''}`);
      }
    }
  }

  console.log('\n==================================================');
  console.log('Rapor bitti. Bu çıktıyı paylaşabilirsiniz (şifre gizli).');
  console.log('==================================================');
}

main().catch((e) => {
  console.error('Beklenmeyen hata: ' + e.message);
  process.exit(1);
});
