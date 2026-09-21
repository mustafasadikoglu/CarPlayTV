const fs = require('fs');

console.log("==========================================");
console.log("TEST: EPG (XMLTV & Electronic Program Guide) Engine");
console.log("==========================================");

// 1. XMLTV Mock Parser
function parseXMLTV(xmlString) {
    const channelMap = {};
    const programmeRegex = /<programme\s+([^>]+)>([\s\S]*?)<\/programme>/gi;
    let match;

    while ((match = programmeRegex.exec(xmlString)) !== null) {
        const attrString = match[1];
        const innerContent = match[2];

        const channelMatch = attrString.match(/channel="([^"]+)"/i);
        const startMatch = attrString.match(/start="([^"]+)"/i);
        const stopMatch = attrString.match(/stop="([^"]+)"/i);

        if (!channelMatch || !startMatch || !stopMatch) continue;

        const channelId = channelMatch[1];
        const startStr = startMatch[1];
        const stopStr = stopMatch[1];

        const titleMatch = innerContent.match(/<title[^>]*>([^<]+)<\/title>/i);
        const descMatch = innerContent.match(/<desc[^>]*>([^<]+)<\/desc>/i);

        const title = titleMatch ? titleMatch[1].trim() : "Program";
        const desc = descMatch ? descMatch[1].trim() : null;

        const startTime = parseXMLTVDate(startStr);
        const endTime = parseXMLTVDate(stopStr);

        if (!channelMap[channelId]) {
            channelMap[channelId] = [];
        }

        channelMap[channelId].push({
            channelId,
            title,
            description: desc,
            startTime,
            endTime
        });
    }

    return channelMap;
}

function parseXMLTVDate(str) {
    // Expected format: YYYYMMDDHHmmss [+/-TZ]
    const clean = str.trim().split(" ")[0];
    const y = parseInt(clean.substring(0, 4));
    const m = parseInt(clean.substring(4, 6)) - 1;
    const d = parseInt(clean.substring(6, 8));
    const h = parseInt(clean.substring(8, 10));
    const min = parseInt(clean.substring(10, 12));
    const s = parseInt(clean.substring(12, 14) || "0");
    return new Date(Date.UTC(y, m, d, h, min, s));
}

function formatTime(d) {
    const hh = String(d.getUTCHours()).padStart(2, '0');
    const mm = String(d.getUTCMinutes()).padStart(2, '0');
    return `${hh}:${mm}`;
}

// 2. Program calculations (Mirrors EPGProgram in Swift)
function calculateProgramStatus(prog, now = new Date()) {
    const isAiring = now >= prog.startTime && now < prog.endTime;
    const totalDuration = (prog.endTime - prog.startTime) / 1000;
    const elapsed = (now - prog.startTime) / 1000;
    const progress = Math.min(Math.max(elapsed / totalDuration, 0), 1);
    const remainingSeconds = (prog.endTime - now) / 1000;
    const remainingMinutes = Math.max(Math.ceil(remainingSeconds / 60), 0);

    return {
        isAiring,
        progressPercentage: Math.round(progress * 100),
        remainingMinutes,
        timeRangeString: `${formatTime(prog.startTime)} - ${formatTime(prog.endTime)}`
    };
}

// 3. Normalized key matching
function normalizeKey(str) {
    return str.toLowerCase()
        .replace(/hd|fhd|4k|hevc|tr:| /g, '')
        .trim();
}

// 4. Procedural EPG Generator (Mirrors EPGStore.swift)
function generateProceduralEPG(channelName, groupTitle = "Genel") {
    const now = new Date();
    const startOfDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0));

    const isSports = groupTitle.toLowerCase().includes("spor") || channelName.toLowerCase().includes("spor");
    const schedule = isSports ? [
        { h: 7, dur: 120, title: "Sabah Sporu" },
        { h: 9, dur: 180, title: "Spor Merkezi" },
        { h: 12, dur: 60, title: "Günün Golleri" },
        { h: 13, dur: 180, title: "Transfer Dosyası" },
        { h: 16, dur: 120, title: "Maç Önü Analiz" },
        { h: 18, dur: 60, title: "Haber Aktif" },
        { h: 19, dur: 180, title: "Canlı Maç Karşılaşması" },
        { h: 22, dur: 120, title: "Maçın Ardından" }
    ] : [
        { h: 6, dur: 180, title: "Sabah Kuşağı" },
        { h: 9, dur: 180, title: "Yaşamın İçinden" },
        { h: 12, dur: 60, title: "Günün Özeti" },
        { h: 13, dur: 150, title: "Gündüz Dizisi" },
        { h: 15, dur: 120, title: "Yemek Programı" },
        { h: 17, dur: 90, title: "Akşam Kuşağı" },
        { h: 19, dur: 60, title: "Ana Haber Bülteni" },
        { h: 20, dur: 180, title: "Günün Dizisi: Yeni Bölüm" }
    ];

    return schedule.map(item => {
        const start = new Date(startOfDay.getTime() + item.h * 3600 * 1000);
        const end = new Date(start.getTime() + item.dur * 60 * 1000);
        return {
            title: item.title,
            startTime: start,
            endTime: end
        };
    });
}

// EXECUTE TESTS
console.log("\n[Test 1] Parse Realistic XMLTV Payload");
const nowUTC = new Date();
// Construct dynamic times so test always has a currently airing program
const past1h = new Date(nowUTC.getTime() - 90 * 60 * 1000);
const past30m = new Date(nowUTC.getTime() - 30 * 60 * 1000);
const future30m = new Date(nowUTC.getTime() + 30 * 60 * 1000);
const future90m = new Date(nowUTC.getTime() + 90 * 60 * 1000);

function toXMLTVTimestamp(d) {
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, '0');
    const day = String(d.getUTCDate()).padStart(2, '0');
    const h = String(d.getUTCHours()).padStart(2, '0');
    const min = String(d.getUTCMinutes()).padStart(2, '0');
    const s = String(d.getUTCSeconds()).padStart(2, '0');
    return `${y}${m}${day}${h}${min}${s} +0000`;
}

const sampleXML = `<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="${toXMLTVTimestamp(past1h)}" stop="${toXMLTVTimestamp(past30m)}" channel="TRT1.tr">
    <title lang="tr">Geçmiş Program</title>
    <desc lang="tr">Sona eren program detayı.</desc>
  </programme>
  <programme start="${toXMLTVTimestamp(past30m)}" stop="${toXMLTVTimestamp(future30m)}" channel="TRT1.tr">
    <title lang="tr">Ana Haber Bülteni</title>
    <desc lang="tr">Türkiye ve dünyadan sıcak gelişmeler.</desc>
  </programme>
  <programme start="${toXMLTVTimestamp(future30m)}" stop="${toXMLTVTimestamp(future90m)}" channel="TRT1.tr">
    <title lang="tr">Günün Dizisi</title>
    <desc lang="tr">Heyecanla beklenen yeni bölüm.</desc>
  </programme>
</tv>`;

const parsed = parseXMLTV(sampleXML);
console.log(`- Parsed channels in XML: ${Object.keys(parsed).length}`);
if (!parsed["TRT1.tr"] || parsed["TRT1.tr"].length !== 3) {
    throw new Error("Failed to parse 3 programs for TRT1.tr");
}
console.log(`- Programs found for TRT1.tr: ${parsed["TRT1.tr"].length}`);

console.log("\n[Test 2] Verify Current On-Air Program and Progress Calculation");
const trtPrograms = parsed["TRT1.tr"];
const currentProg = trtPrograms.find(p => nowUTC >= p.startTime && nowUTC < p.endTime);

if (!currentProg) {
    throw new Error("No currently airing program detected!");
}
console.log(`- Current Program: "${currentProg.title}"`);
if (currentProg.title !== "Ana Haber Bülteni") {
    throw new Error(`Expected "Ana Haber Bülteni", got "${currentProg.title}"`);
}

const status = calculateProgramStatus(currentProg, nowUTC);
console.log(`- Status: Airing=${status.isAiring}, Progress=${status.progressPercentage}%, Remaining=${status.remainingMinutes} dk, Range=${status.timeRangeString}`);

if (!status.isAiring) throw new Error("Expected isAiring to be true");
if (status.progressPercentage < 40 || status.progressPercentage > 60) {
    throw new Error(`Expected progress ~50%, got ${status.progressPercentage}%`);
}
if (status.remainingMinutes < 28 || status.remainingMinutes > 32) {
    throw new Error(`Expected remaining ~30 mins, got ${status.remainingMinutes}`);
}

console.log("\n[Test 3] Verify Next Scheduled Program");
const nextProg = trtPrograms.find(p => p.startTime >= nowUTC);
if (!nextProg || nextProg.title !== "Günün Dizisi") {
    throw new Error(`Expected next program to be "Günün Dizisi", got "${nextProg ? nextProg.title : 'null'}"`);
}
console.log(`- Next Program: "${nextProg.title}" (Starts at ${formatTime(nextProg.startTime)})`);

console.log("\n[Test 4] Fuzzy Channel Name Matching");
const testNames = ["TRT 1 HD", "TRT 1 FHD", "TRT 1 4K", "TR: TRT 1 HD"];
for (const raw of testNames) {
    const norm = normalizeKey(raw);
    console.log(`- "${raw}" -> normalized to: "${norm}"`);
    if (norm !== "trt1") {
        throw new Error(`Failed to normalize "${raw}" to "trt1", got "${norm}"`);
    }
}

console.log("\n[Test 5] Procedural 24-Hour EPG Fallback Generation");
const proceduralPrograms = generateProceduralEPG("beIN Sports 1 HD", "Spor");
console.log(`- Generated procedural sports programs count: ${proceduralPrograms.length}`);
if (proceduralPrograms.length < 5) {
    throw new Error("Procedural generator did not generate sufficient schedule items");
}
console.log(`- Sample: "${proceduralPrograms[0].title}" at ${formatTime(proceduralPrograms[0].startTime)}`);

console.log("\n==========================================");
console.log("ALL EPG TESTS PASSED SUCCESSFULLY!");
console.log("==========================================");
