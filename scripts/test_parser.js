const fs = require('fs');
const path = require('path');

const sampleM3U = `#EXTM3U
#EXTINF:-1 tvg-id="TRT1.tr" tvg-name="TRT 1 HD" tvg-logo="https://example.com/trt1.png" group-title="Ulusal",TRT 1 HD
https://example.com/live/trt1.m3u8
#EXTINF:-1 tvg-id="NASA.us" tvg-name="NASA TV" tvg-logo="https://example.com/nasa.png" group-title="Bilim",NASA TV HD
#EXTVLCOPT:http-user-agent=CustomAgent/1.0
https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8
`;

function extractAttribute(name, line) {
    const regex = new RegExp(`${name}="([^"]*)"`, 'i');
    const match = line.match(regex);
    return match ? match[1] : null;
}

function parseM3U(content) {
    const channels = [];
    const lines = content.split(/\r?\n/);

    let currentTvgId = null;
    let currentTvgName = null;
    let currentTvgLogo = null;
    let currentGroupTitle = "Genel";
    let currentChannelName = null;
    let currentUserAgent = null;

    for (const rawLine of lines) {
        const line = rawLine.trim();
        if (!line) continue;

        if (line.startsWith("#EXTINF:")) {
            currentTvgId = extractAttribute("tvg-id", line);
            currentTvgName = extractAttribute("tvg-name", line);
            currentTvgLogo = extractAttribute("tvg-logo", line);
            currentGroupTitle = extractAttribute("group-title", line) || "Genel";

            const lastCommaIdx = line.lastIndexOf(",");
            if (lastCommaIdx !== -1) {
                currentChannelName = line.substring(lastCommaIdx + 1).trim();
            }
        } else if (line.startsWith("#EXTVLCOPT:http-user-agent=")) {
            currentUserAgent = line.substring("#EXTVLCOPT:http-user-agent=".length).trim();
        } else if (!line.startsWith("#")) {
            const channelName = currentChannelName || currentTvgName || `Kanal ${channels.length + 1}`;
            channels.push({
                name: channelName,
                streamURL: line,
                logoURL: currentTvgLogo,
                groupTitle: currentGroupTitle,
                tvgId: currentTvgId,
                tvgName: currentTvgName,
                httpUserAgent: currentUserAgent
            });

            currentTvgId = null;
            currentTvgName = null;
            currentTvgLogo = null;
            currentGroupTitle = "Genel";
            currentChannelName = null;
            currentUserAgent = null;
        }
    }

    return channels;
}

const parsed = parseM3U(sampleM3U);
console.log("Parsed channels count:", parsed.length);
console.log(JSON.stringify(parsed, null, 2));

if (parsed.length === 2 &&
    parsed[0].name === "TRT 1 HD" &&
    parsed[0].groupTitle === "Ulusal" &&
    parsed[1].httpUserAgent === "CustomAgent/1.0") {
    console.log("TEST PASSED: M3U Parser logic matches Swift M3UParser implementation!");
} else {
    console.error("TEST FAILED!");
    process.exit(1);
}
