const fs = require('fs');

// Generate 10,000 synthetic channels in M3U format
function simulateLargeM3U(count = 10000) {
    const lines = ["#EXTM3U"];
    const categories = ["Ulusal", "Spor", "Haber", "Sinema", "Belgesel", "Muzik", "Cocuk"];

    for (let i = 1; i <= count; i++) {
        const cat = categories[i % categories.length];
        lines.push(`#EXTINF:-1 tvg-id="ch${i}" tvg-name="Kanal ${i}" tvg-logo="https://logo.com/${i}.png" group-title="${cat}",Kanal ${i} HD`);
        lines.push(`https://stream.server.com/live/ch_${i}.m3u8`);
    }
    return lines;
}

// Streaming chunk parser simulation
function parseStreamingLines(lines, chunkSize = 500, onChunk) {
    let totalParsed = 0;
    let currentChunk = [];
    let currentName = null;
    let currentGroup = "Genel";

    for (const raw of lines) {
        const line = raw.trim();
        if (!line) continue;

        if (line.startsWith("#EXTINF:")) {
            const comma = line.lastIndexOf(",");
            if (comma !== -1) {
                currentName = line.substring(comma + 1).trim();
            }
            const groupMatch = line.match(/group-title="([^"]*)"/i);
            if (groupMatch) {
                currentGroup = groupMatch[1];
            }
        } else if (!line.startsWith("#")) {
            currentChunk.push({
                name: currentName || `Kanal ${totalParsed + 1}`,
                url: line,
                group: currentGroup
            });
            totalParsed++;

            if (currentChunk.length >= chunkSize) {
                onChunk(currentChunk);
                currentChunk = [];
            }
            currentName = null;
            currentGroup = "Genel";
        }
    }

    if (currentChunk.length > 0) {
        onChunk(currentChunk);
    }
    return totalParsed;
}

console.log("Generating 10,000 channels...");
const m3uLines = simulateLargeM3U(10000);
console.log(`Generated ${m3uLines.length} lines.`);

let chunksReceived = 0;
let totalChannels = 0;
const categoryMap = {};

const startTime = Date.now();
totalChannels = parseStreamingLines(m3uLines, 500, (chunk) => {
    chunksReceived++;
    for (const ch of chunk) {
        if (!categoryMap[ch.group]) categoryMap[ch.group] = [];
        categoryMap[ch.group].push(ch);
    }
});
const durationMs = Date.now() - startTime;

console.log(`Parsed ${totalChannels} channels in ${chunksReceived} chunks in ${durationMs}ms.`);
console.log("Category counts:", Object.keys(categoryMap).map(k => `${k}: ${categoryMap[k].length}`).join(", "));

// Test search on 10,000 items with 100 limit
function searchChannels(query, limit = 100) {
    const q = query.toLowerCase();
    const results = [];
    for (const cat of Object.keys(categoryMap)) {
        for (const ch of categoryMap[cat]) {
            if (ch.name.toLowerCase().includes(q)) {
                results.push(ch);
                if (results.length >= limit) return results;
            }
        }
    }
    return results;
}

const searchStart = Date.now();
const searchResults = searchChannels("Kanal 1", 100);
const searchDuration = Date.now() - searchStart;

console.log(`Search for 'Kanal 1' found ${searchResults.length} results in ${searchDuration}ms.`);

if (totalChannels === 10000 && chunksReceived === 20 && searchResults.length === 100) {
    console.log("TEST PASSED: Streaming Chunk Parser and Index Search logic verified!");
} else {
    console.error("TEST FAILED!");
    process.exit(1);
}
