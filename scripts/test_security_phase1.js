const fs = require('fs');
const path = require('path');

console.log("==========================================");
console.log("TEST: Security Phase 1 (Keychain, URL Sanitizer, ATS Hardening)");
console.log("==========================================");

// 1. URL Sanitizer Engine (Mirrors URLSanitizer.swift)
function sanitizeURL(urlString) {
    if (!urlString) return "nil";
    let sanitized = urlString;

    // Mask query parameters: password, pass, token, api_key, auth_token
    const queryRegex = /(password|pass|token|api_key|auth_token)=([^&]+)/gi;
    sanitized = sanitized.replace(queryRegex, "$1=***");

    // Mask Xtream stream paths: /(live|movie|series)/{username}/{password}/{id}.{ext}
    const xtreamStreamRegex = /\/(live|movie|series)\/([^/]+)\/([^/]+)\/([^/\s?#]+)/gi;
    sanitized = sanitized.replace(xtreamStreamRegex, "/$1/$2/***/$4");

    return sanitized;
}

// 2. Mock iOS Keychain (Mirrors KeychainHelper.swift)
class MockKeychainHelper {
    constructor() {
        this.store = new Map();
    }

    saveString(key, value, service = "com.carplaytv.credentials") {
        const fullKey = `${service}::${key}`;
        this.store.set(fullKey, {
            value: value,
            accessible: "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"
        });
        return true;
    }

    readString(key, service = "com.carplaytv.credentials") {
        const fullKey = `${service}::${key}`;
        const item = this.store.get(fullKey);
        return item ? item.value : null;
    }

    delete(key, service = "com.carplaytv.credentials") {
        const fullKey = `${service}::${key}`;
        return this.store.delete(fullKey);
    }
}

// EXECUTE TESTS
console.log("\n[Test 1] URL Sanitizer - Query Parameter Masking");
const testUrls = [
    {
        input: "http://iptv.provider.com/player_api.php?username=admin&password=mySuperSecretPassword123",
        forbidden: "mySuperSecretPassword123"
    },
    {
        input: "http://iptv.provider.com/get.php?username=alice&pass=secretPass456&type=m3u_plus",
        forbidden: "secretPass456"
    },
    {
        input: "https://auth.stream.tv/v1/auth?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9&user=99",
        forbidden: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    },
    {
        input: "https://cdn.tv.com/epg?api_key=SECRET_API_KEY_777888",
        forbidden: "SECRET_API_KEY_777888"
    }
];

for (const t of testUrls) {
    const sanitized = sanitizeURL(t.input);
    console.log(`- Original:  ${t.input}`);
    console.log(`  Sanitized: ${sanitized}`);
    if (sanitized.includes(t.forbidden)) {
        throw new Error(`Sanitizer failed! Forbidden string "${t.forbidden}" still present in output.`);
    }
    if (!sanitized.includes("***")) {
        throw new Error(`Sanitizer failed! Asterisks not found in sanitized output.`);
    }
}

console.log("\n[Test 2] URL Sanitizer - Xtream Path Segment Masking");
const pathTests = [
    {
        input: "http://stream.server.org:8080/live/john_doe/secretPass999/54321.m3u8",
        expected: "http://stream.server.org:8080/live/john_doe/***/54321.m3u8",
        forbidden: "secretPass999"
    },
    {
        input: "http://stream.server.org:8080/movie/john_doe/secretPass999/87654.mp4",
        expected: "http://stream.server.org:8080/movie/john_doe/***/87654.mp4",
        forbidden: "secretPass999"
    },
    {
        input: "http://stream.server.org:8080/series/john_doe/secretPass999/11223.mp4",
        expected: "http://stream.server.org:8080/series/john_doe/***/11223.mp4",
        forbidden: "secretPass999"
    }
];

for (const pt of pathTests) {
    const sanitized = sanitizeURL(pt.input);
    console.log(`- Stream Path: ${pt.input}`);
    console.log(`  Masked:      ${sanitized}`);
    if (sanitized !== pt.expected) {
        throw new Error(`Expected "${pt.expected}", got "${sanitized}"`);
    }
    if (sanitized.includes(pt.forbidden)) {
        throw new Error(`Forbidden credential leaked in stream path!`);
    }
}

console.log("\n[Test 3] Mock Keychain CRUD Operations");
const keychain = new MockKeychainHelper();
const testAccount = "user_account_9988";
const testSecret = "X_TRE_AM_SECURE_TOKEN_2026";

console.log("- Saving credential to Keychain...");
keychain.saveString(testAccount, testSecret);

console.log("- Reading credential back...");
const retrieved = keychain.readString(testAccount);
if (retrieved !== testSecret) {
    throw new Error(`Keychain mismatch! Expected "${testSecret}", got "${retrieved}"`);
}
console.log(`  Match verified: ${retrieved}`);

console.log("- Deleting credential...");
keychain.delete(testAccount);
const afterDelete = keychain.readString(testAccount);
if (afterDelete !== null) {
    throw new Error("Keychain item was not deleted properly!");
}
console.log("  Delete verified: item is nil.");

console.log("\n[Test 4] Verify Info.plist ATS Hardening");
const infoPlistPath = path.join(__dirname, '..', 'CarPlayTV', 'Info.plist');
const infoPlistContent = fs.readFileSync(infoPlistPath, 'utf8');

if (!infoPlistContent.includes("<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>") &&
    !infoPlistContent.includes("<key>NSAllowsArbitraryLoads</key>\r\n\t\t<true/>")) {
    throw new Error("Info.plist: NSAllowsArbitraryLoads must be true for IPTV providers!");
}
console.log("- NSAllowsArbitraryLoads is true (HTTP & HTTPS allowed for IPTV providers).");

// Note: NSAllowsArbitraryLoadsForMedia must NOT be present, because if set to true,
// Apple ATS forces HTTPS on all URLSession data tasks (Xtream player_api.php, M3U, EPG)!
if (infoPlistContent.includes("<key>NSAllowsArbitraryLoadsForMedia</key>")) {
    throw new Error("Info.plist: NSAllowsArbitraryLoadsForMedia must NOT be present as it disables HTTP for URLSession API data requests!");
}
console.log("- Clean NSAllowsArbitraryLoads verified (covers all URLSession data and AVPlayer media requests).");

if (!infoPlistContent.includes("<key>NSAllowsLocalNetworking</key>\n\t\t<true/>") &&
    !infoPlistContent.includes("<key>NSAllowsLocalNetworking</key>\r\n\t\t<true/>")) {
    throw new Error("Info.plist: NSAllowsLocalNetworking must be true for local LAN/Wi-Fi streams!");
}
console.log("- NSAllowsLocalNetworking is true.");

console.log("\n==========================================");
console.log("ALL SECURITY PHASE 1 TESTS PASSED SUCCESSFULLY!");
console.log("==========================================");
