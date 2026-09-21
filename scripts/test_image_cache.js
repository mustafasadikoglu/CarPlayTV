const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

console.log("==========================================");
console.log("TEST: Two-Tier Image & Poster Cache Verification");
console.log("==========================================");

// 1. SHA256 Key Generation (Mirrors ImageCacheManager.swift)
function cacheKey(urlString) {
    return crypto.createHash('sha256').update(urlString).digest('hex');
}

// 2. Mock Image Cache Manager
class MockImageCacheManager {
    constructor(diskDir, maxRamCount = 5, maxDiskBytes = 10 * 1024 * 1024) {
        this.diskDir = diskDir;
        this.maxRamCount = maxRamCount;
        this.maxDiskBytes = maxDiskBytes;
        this.ramCache = new Map(); // Emulates NSCache with LRU eviction
        this.stats = {
            networkDownloads: 0,
            ramHits: 0,
            diskHits: 0
        };

        if (!fs.existsSync(diskDir)) {
            fs.mkdirSync(diskDir, { recursive: true });
        }
    }

    // Synchronous RAM lookup (Zero delay UI thread check)
    getRAM(urlString) {
        const key = cacheKey(urlString);
        if (this.ramCache.has(key)) {
            this.stats.ramHits++;
            return this.ramCache.get(key);
        }
        return null;
    }

    // Disk lookup
    getDisk(urlString) {
        const key = cacheKey(urlString);
        const filePath = path.join(this.diskDir, key);
        if (fs.existsSync(filePath)) {
            this.stats.diskHits++;
            const data = fs.readFileSync(filePath);
            // Promote to RAM
            this.setRAM(key, data);
            return data;
        }
        return null;
    }

    setRAM(key, data) {
        if (this.ramCache.size >= this.maxRamCount) {
            const firstKey = this.ramCache.keys().next().value;
            this.ramCache.delete(firstKey);
        }
        this.ramCache.set(key, data);
    }

    // Full fetch pipeline
    fetchImage(urlString, simulatedDataGenerator) {
        // Step 1: RAM check
        const inMemory = this.getRAM(urlString);
        if (inMemory) {
            return { data: inMemory, source: 'RAM' };
        }

        // Step 2: Disk check
        const onDisk = this.getDisk(urlString);
        if (onDisk) {
            return { data: onDisk, source: 'DISK' };
        }

        // Step 3: Network download simulation
        this.stats.networkDownloads++;
        const key = cacheKey(urlString);
        const downloaded = simulatedDataGenerator();
        
        // Save to disk
        const filePath = path.join(this.diskDir, key);
        fs.writeFileSync(filePath, downloaded);

        // Save to RAM
        this.setRAM(key, downloaded);

        return { data: downloaded, source: 'NETWORK' };
    }

    clearRAM() {
        this.ramCache.clear();
    }

    clearDisk() {
        if (fs.existsSync(this.diskDir)) {
            const files = fs.readdirSync(this.diskDir);
            for (const f of files) {
                fs.unlinkSync(path.join(this.diskDir, f));
            }
        }
    }
}

// 3. Downsampling Simulation Test
function calculateDownsampledSize(sourceWidth, sourceHeight, targetMaxDimension) {
    const maxSource = Math.max(sourceWidth, sourceHeight);
    if (maxSource <= targetMaxDimension) {
        return { width: sourceWidth, height: sourceHeight, reductionPercent: 0 };
    }
    const ratio = targetMaxDimension / maxSource;
    const newWidth = Math.round(sourceWidth * ratio);
    const newHeight = Math.round(sourceHeight * ratio);
    const originalPixels = sourceWidth * sourceHeight;
    const newPixels = newWidth * newHeight;
    const reductionPercent = Math.round((1 - (newPixels / originalPixels)) * 100);
    return { width: newWidth, height: newHeight, reductionPercent };
}

// EXECUTE TESTS
const testCacheDir = path.join(__dirname, 'test_cache_temp');

try {
    const manager = new MockImageCacheManager(testCacheDir, 3);
    const sampleLogoURL = "https://cdn.iptvserver.com/logos/trt1_hd.png";
    const samplePosterURL = "https://cdn.iptvserver.com/posters/oppenheimer_2023.jpg";

    console.log("\n[Test 1] Initial Fetch (Expect NETWORK download & caching)");
    const res1 = manager.fetchImage(sampleLogoURL, () => Buffer.from("DUMMY_IMAGE_BYTES_FOR_TRT1"));
    console.log(`- Result source: ${res1.source} (Expected: NETWORK)`);
    if (res1.source !== 'NETWORK') throw new Error("Expected initial fetch to be NETWORK");

    console.log("\n[Test 2] Immediate Second Fetch (Expect instant RAM cache hit)");
    const res2 = manager.fetchImage(sampleLogoURL, () => Buffer.from("FAIL"));
    console.log(`- Result source: ${res2.source} (Expected: RAM)`);
    if (res2.source !== 'RAM') throw new Error("Expected second fetch to be RAM hit");

    console.log("\n[Test 3] RAM Purge Simulation (Expect DISK hit and auto-promotion to RAM)");
    manager.clearRAM();
    const res3 = manager.fetchImage(sampleLogoURL, () => Buffer.from("FAIL"));
    console.log(`- Result source: ${res3.source} (Expected: DISK)`);
    if (res3.source !== 'DISK') throw new Error("Expected fetch after RAM purge to be DISK hit");

    console.log("\n[Test 4] Verify Promotion from Disk back into RAM");
    const res4 = manager.fetchImage(sampleLogoURL, () => Buffer.from("FAIL"));
    console.log(`- Result source: ${res4.source} (Expected: RAM)`);
    if (res4.source !== 'RAM') throw new Error("Expected promoted image to be in RAM");

    console.log("\n[Test 5] RAM Eviction Limit (Max 3 items in RAM cache)");
    manager.fetchImage("https://cdn.test/1.png", () => Buffer.from("img1"));
    manager.fetchImage("https://cdn.test/2.png", () => Buffer.from("img2"));
    manager.fetchImage("https://cdn.test/3.png", () => Buffer.from("img3"));
    // At this point, sampleLogoURL should have been evicted from RAM
    const resEvictedRAM = manager.getRAM(sampleLogoURL);
    console.log(`- sampleLogoURL in RAM after 3 new items: ${resEvictedRAM === null ? 'Evicted (Correct)' : 'Still in RAM'}`);
    if (resEvictedRAM !== null) throw new Error("Expected sampleLogoURL to be evicted from small RAM cache");

    console.log("\n[Test 6] Downsampling Calculation for Posters and Logos");
    const posterDownsample = calculateDownsampledSize(1000, 1500, 300);
    console.log(`- 1000x1500 Full Poster -> Max Dim 300 -> ${posterDownsample.width}x${posterDownsample.height} (${posterDownsample.reductionPercent}% RAM reduction)`);
    if (posterDownsample.reductionPercent < 90) throw new Error("Expected >90% pixel reduction for thumbnail");

    const logoDownsample = calculateDownsampledSize(512, 512, 100);
    console.log(`- 512x512 Channel Logo -> Max Dim 100 -> ${logoDownsample.width}x${logoDownsample.height} (${logoDownsample.reductionPercent}% RAM reduction)`);

    console.log("\n[Test 7] Cleanup");
    manager.clearDisk();
    const diskRemaining = fs.readdirSync(testCacheDir).length;
    console.log(`- Files remaining on disk after clear: ${diskRemaining} (Expected: 0)`);
    if (diskRemaining !== 0) throw new Error("Disk cache clear failed");

    console.log("\n==========================================");
    console.log("ALL IMAGE CACHE TESTS PASSED SUCCESSFULLY!");
    console.log(`Total Stats: RAM Hits: ${manager.stats.ramHits}, Disk Hits: ${manager.stats.diskHits}, Network: ${manager.stats.networkDownloads}`);
    console.log("==========================================");
} finally {
    if (fs.existsSync(testCacheDir)) {
        fs.rmSync(testCacheDir, { recursive: true, force: true });
    }
}
