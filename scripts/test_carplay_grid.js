const fs = require('fs');

function computeGridChannels(favorites, allChannels, maxLimit = 8) {
    if (favorites && favorites.length > 0) {
        return favorites.slice(0, maxLimit);
    } else if (allChannels && allChannels.length > 0) {
        return allChannels.slice(0, maxLimit);
    }
    return [];
}

const sampleChannels = [
    { id: "1", name: "TRT 1", isFavorite: false },
    { id: "2", name: "NASA TV", isFavorite: false },
    { id: "3", name: "TRT World", isFavorite: false },
    { id: "4", name: "Euronews", isFavorite: false },
    { id: "5", name: "Red Bull TV", isFavorite: false },
    { id: "6", name: "DW English", isFavorite: false },
    { id: "7", name: "BBC News", isFavorite: false },
    { id: "8", name: "CNN Int", isFavorite: false },
    { id: "9", name: "Al Jazeera", isFavorite: false },
    { id: "10", name: "Bloomberg", isFavorite: false }
];

// Test 1: Empty favorites fallback
let favorites = [];
let grid = computeGridChannels(favorites, sampleChannels, 8);
console.log("Test 1 - Fallback count (expected 8):", grid.length);
if (grid.length !== 8 || grid[0].name !== "TRT 1") {
    console.error("Test 1 FAILED!");
    process.exit(1);
}

// Test 2: User stars 2 channels
favorites = [sampleChannels[4], sampleChannels[1]]; // Red Bull TV and NASA TV
grid = computeGridChannels(favorites, sampleChannels, 8);
console.log("Test 2 - Favorited channels count (expected 2):", grid.length);
if (grid.length !== 2 || grid[0].name !== "Red Bull TV" || grid[1].name !== "NASA TV") {
    console.error("Test 2 FAILED!");
    process.exit(1);
}

console.log("TEST PASSED: CarPlay Grid logic and capping verified successfully!");
