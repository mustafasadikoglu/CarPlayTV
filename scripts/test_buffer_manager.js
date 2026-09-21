const fs = require('fs');

class MockPlaybackManager {
    constructor() {
        this.bufferDuration = 0;
        this.isPlaying = false;
        this.playbackError = null;
        this.currentChannel = null;
        this.expansionTimeout = null;
    }

    play(channel) {
        // Instant teardown
        if (this.expansionTimeout) {
            clearTimeout(this.expansionTimeout);
            this.expansionTimeout = null;
        }

        this.currentChannel = channel;
        this.playbackError = null;
        this.isPlaying = true;

        // Stage 1: Ultra fast startup buffer (< 1s)
        this.bufferDuration = 1.0;

        // Stage 2: Scheduled expansion to 6.0s
        this.expansionTimeout = setTimeout(() => {
            this.bufferDuration = 6.0;
        }, 100); // 100ms for test simulation
    }

    simulateNetworkLoss() {
        this.isPlaying = false;
        this.playbackError = "Ağ bağlantısı koptu";
    }

    onNetworkRestored() {
        if (this.currentChannel && (!this.isPlaying || this.playbackError)) {
            this.play(this.currentChannel);
        }
    }
}

const manager = new MockPlaybackManager();
const testChannel = { id: "1", name: "TRT 1 HD" };

// Test 1: Fast zapping stage 1
manager.play(testChannel);
console.log("Stage 1 Buffer (expected 1.0):", manager.bufferDuration);
if (manager.bufferDuration !== 1.0) {
    console.error("Test 1 FAILED!");
    process.exit(1);
}

// Test 2: Buffer expansion stage 2
setTimeout(() => {
    console.log("Stage 2 Buffer (expected 6.0):", manager.bufferDuration);
    if (manager.bufferDuration !== 6.0) {
        console.error("Test 2 FAILED!");
        process.exit(1);
    }

    // Test 3: Network loss and auto-recovery
    manager.simulateNetworkLoss();
    console.log("After network loss - isPlaying:", manager.isPlaying, "error:", manager.playbackError);

    manager.onNetworkRestored();
    console.log("After network restored - isPlaying:", manager.isPlaying, "error:", manager.playbackError);
    if (!manager.isPlaying || manager.playbackError !== null || manager.bufferDuration !== 1.0) {
        console.error("Test 3 FAILED!");
        process.exit(1);
    }

    console.log("TEST PASSED: Fast zapping, two-stage buffer and network restoration logic verified!");
}, 150);
