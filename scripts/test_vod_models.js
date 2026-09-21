const fs = require('fs');

function formatDuration(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    if (hours > 0) {
        return `${hours} sa ${minutes} dk`;
    }
    return `${minutes} dk`;
}

function computeProgress(lastPos, duration) {
    if (duration <= 0) return 0;
    return Math.min(Math.max(lastPos / duration, 0), 1.0);
}

// Test Movie 1: 596 seconds duration, last position 300 seconds
const dur1 = 596;
const pos1 = 300;
const formatted1 = formatDuration(dur1);
const prog1 = computeProgress(pos1, dur1);

console.log(`Movie 1: ${dur1}s -> ${formatted1}, progress: ${(prog1 * 100).toFixed(1)}%`);

// Test Movie 2: 7340 seconds duration (over 2 hours)
const dur2 = 7340;
const formatted2 = formatDuration(dur2);
console.log(`Movie 2: ${dur2}s -> ${formatted2}`);

if (formatted1 === "9 dk" && prog1 > 0.5 && formatted2 === "2 sa 2 dk") {
    console.log("TEST PASSED: VOD model calculations and formatting match Swift implementation!");
} else {
    console.error("TEST FAILED!");
    process.exit(1);
}
