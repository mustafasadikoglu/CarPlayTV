const fs = require('fs');

console.log("==========================================");
console.log("TEST: Xtream Resilient Parsing & Category Name Mapping");
console.log("==========================================");

// 1. Mock Category Mapping
const liveCategories = [
    { category_id: "1", category_name: "TR: Ulusal Kanallar" },
    { category_id: "2", category_name: "TR: Spor" },
    { category_id: "42", category_name: "TR: Sinema" }
];

const categoryMap = new Map();
liveCategories.forEach(cat => categoryMap.set(cat.category_id, cat.category_name));

console.log("\n[Test 1] Live TV Category ID to Human-Readable Name Mapping");
const mockRawLiveStreams = [
    { stream_id: 101, name: "TRT 1 HD", category_id: "1" },
    { stream_id: 102, name: "beIN Sports 1 HD", category_id: 2 }, // Int category_id
    { stream_id: 103, name: "Sinema TV Aksiyon", category_id: "42" },
    { stream_id: 104, name: "Bilinmeyen Kanal", category_id: null }
];

const mappedChannels = mockRawLiveStreams.map(stream => {
    const catIdStr = stream.category_id != null ? String(stream.category_id) : null;
    const groupTitle = (catIdStr && categoryMap.has(catIdStr)) ? categoryMap.get(catIdStr) : "Genel";
    return {
        id: String(stream.stream_id),
        name: stream.name,
        groupTitle
    };
});

console.log("- Channel 101 group:", mappedChannels[0].groupTitle, "(Expected: TR: Ulusal Kanallar)");
console.log("- Channel 102 group:", mappedChannels[1].groupTitle, "(Expected: TR: Spor)");
console.log("- Channel 103 group:", mappedChannels[2].groupTitle, "(Expected: TR: Sinema)");
console.log("- Channel 104 group:", mappedChannels[3].groupTitle, "(Expected: Genel)");

if (mappedChannels[0].groupTitle !== "TR: Ulusal Kanallar") throw new Error("Category 1 mapping failed");
if (mappedChannels[1].groupTitle !== "TR: Spor") throw new Error("Numeric Category 2 mapping failed");
if (mappedChannels[2].groupTitle !== "TR: Sinema") throw new Error("Category 42 mapping failed");
if (mappedChannels[3].groupTitle !== "Genel") throw new Error("Null category fallback failed");

// 2. Resilient VOD & Series Decoding (Handling mixed rating: Float, Int, String, and skipping malformed)
console.log("\n[Test 2] Resilient VOD / Movie Array Decoding (Float, Int, String ratings)");
const rawVODPayload = [
    { stream_id: 501, name: "Inception", rating: 8.8, category_id: "10" },            // rating as Double
    { stream_id: "502", name: "Interstellar", rating: 9, category_id: 10 },           // rating as Int, stream_id as String
    { stream_id: 503, name: "The Matrix", rating: "8.7", category_id: "10" },         // rating as String
    { stream_id: null, name: "Corrupted Movie (Missing ID)", rating: "N/A" },         // Malformed item (should be safely skipped)
    { stream_id: 504, name: "Oppenheimer", rating: null, category_id: "10" }          // rating is null
];

function decodeResilientVOD(payload) {
    const valid = [];
    for (const item of payload) {
        try {
            if (!item.stream_id || !item.name) continue; // LossyDecodable skip
            const streamId = String(item.stream_id);
            let ratingNum = null;
            if (typeof item.rating === 'number') {
                ratingNum = item.rating;
            } else if (typeof item.rating === 'string') {
                const parsed = parseFloat(item.rating);
                if (!isNaN(parsed)) ratingNum = parsed;
            }
            valid.push({
                id: `vod_${streamId}`,
                title: item.name,
                rating: ratingNum
            });
        } catch (e) {
            // LossyDecodable ignores errors and continues
        }
    }
    return valid;
}

const decodedVOD = decodeResilientVOD(rawVODPayload);
console.log(`- Decoded VOD items count: ${decodedVOD.length} of 5 (1 malformed skipped)`);
console.log(`- Inception rating (from Double 8.8):`, decodedVOD[0].rating);
console.log(`- Interstellar rating (from Int 9):`, decodedVOD[1].rating);
console.log(`- The Matrix rating (from String "8.7"):`, decodedVOD[2].rating);
console.log(`- Oppenheimer rating (from null):`, decodedVOD[3].rating);

if (decodedVOD.length !== 4) throw new Error("Expected 4 valid VOD items, 1 malformed skipped");
if (decodedVOD[0].rating !== 8.8) throw new Error("Double rating parsing failed");
if (decodedVOD[1].rating !== 9) throw new Error("Int rating parsing failed");
if (decodedVOD[2].rating !== 8.7) throw new Error("String rating parsing failed");
if (decodedVOD[3].rating !== null) throw new Error("Null rating should remain null");

console.log("\n==========================================");
console.log("ALL RESILIENT PARSING & CATEGORY MAPPING TESTS PASSED!");
console.log("==========================================");
