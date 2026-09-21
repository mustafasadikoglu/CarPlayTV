const fs = require('fs');

console.log("==========================================");
console.log("TEST: Multi-Account Xtream Management & Switching Engine");
console.log("==========================================");

// 1. Mock Keychain with ID Isolation
class MockKeychain {
    constructor() {
        this.store = new Map();
    }

    savePassword(accountId, pass) {
        this.store.set(`xtream_acc_pass_${accountId}`, pass);
    }

    readPassword(accountId) {
        return this.store.get(`xtream_acc_pass_${accountId}`) || null;
    }

    deletePassword(accountId) {
        return this.store.delete(`xtream_acc_pass_${accountId}`);
    }
}

// 2. Mock Multi-Account Store
class MockXtreamAccountStore {
    constructor(keychain) {
        this.keychain = keychain;
        this.accounts = [];
        this.activeAccount = null;
        this.channelCache = new Map();
        this.currentLiveChannels = [];
    }

    addAccount({ name, server, username, password, channelCount = 100, vodCount = 50 }) {
        const id = `acc_${this.accounts.length + 1}_${Date.now()}`;
        const isFirst = this.accounts.length === 0;

        const account = {
            id,
            name,
            server,
            username,
            isActive: isFirst,
            channelCount,
            vodCount,
            status: "Active",
            expirationDate: "2027-12-31",
            lastSynced: new Date()
        };

        // Save password securely in Keychain
        this.keychain.savePassword(id, password);

        // Generate synthetic channel list for this account
        const channels = Array.from({ length: channelCount }, (_, i) => ({
            id: `${id}_ch_${i + 1}`,
            name: `${name} - Kanal ${i + 1}`,
            streamURL: `http://${server}/live/${username}/STREAM_${i + 1}.m3u8`,
            groupTitle: i % 2 === 0 ? "Spor" : "Genel"
        }));

        this.channelCache.set(id, channels);
        this.accounts.push(account);

        if (isFirst) {
            this.activeAccount = account;
            this.currentLiveChannels = channels;
        }

        return account;
    }

    setActiveAccount(accountId) {
        const target = this.accounts.find(a => a.id === accountId);
        if (!target) throw new Error("Account not found");

        for (const a of this.accounts) {
            a.isActive = (a.id === accountId);
        }

        this.activeAccount = target;
        this.currentLiveChannels = this.channelCache.get(accountId) || [];
    }

    updateAccount(accountId, { name, server, username, password }) {
        const account = this.accounts.find(a => a.id === accountId);
        if (!account) throw new Error("Account not found");

        account.name = name;
        account.server = server;
        account.username = username;

        if (password) {
            this.keychain.savePassword(accountId, password);
        }

        if (this.activeAccount && this.activeAccount.id === accountId) {
            this.activeAccount = account;
        }
    }

    deleteAccount(accountId) {
        this.keychain.deletePassword(accountId);
        this.channelCache.delete(accountId);

        const wasActive = this.activeAccount && this.activeAccount.id === accountId;
        this.accounts = this.accounts.filter(a => a.id !== accountId);

        if (wasActive) {
            if (this.accounts.length > 0) {
                this.setActiveAccount(this.accounts[0].id);
            } else {
                this.activeAccount = null;
                this.currentLiveChannels = [];
            }
        }
    }
}

// EXECUTE TESTS
const keychain = new MockKeychain();
const store = new MockXtreamAccountStore(keychain);

console.log("\n[Test 1] Add Multiple Xtream Accounts");
const acc1 = store.addAccount({
    name: "Ev IPTV (Ana Paket)",
    server: "iptv.evserver.net:8080",
    username: "mustafa_ev",
    password: "super_secret_ev_pass_123",
    channelCount: 2500,
    vodCount: 1200
});
console.log(`- Account 1 created: "${acc1.name}" (Active: ${acc1.isActive})`);
if (!acc1.isActive) throw new Error("First account should be active by default");
if (store.currentLiveChannels.length !== 2500) throw new Error("Expected 2500 channels for Account 1");

const acc2 = store.addAccount({
    name: "Spor Paketi (Yedek)",
    server: "sports.provider.com:2086",
    username: "mustafa_spor",
    password: "super_secret_spor_pass_456",
    channelCount: 650,
    vodCount: 0
});
console.log(`- Account 2 created: "${acc2.name}" (Active: ${acc2.isActive})`);
if (acc2.isActive) throw new Error("Second account should NOT be active by default");

console.log("\n[Test 2] Password Isolation in Keychain");
const pass1 = keychain.readPassword(acc1.id);
const pass2 = keychain.readPassword(acc2.id);
console.log(`- Account 1 Keychain Pass: ${pass1 ? 'Verified (Securely Stored)' : 'Missing!'}`);
console.log(`- Account 2 Keychain Pass: ${pass2 ? 'Verified (Securely Stored)' : 'Missing!'}`);
if (pass1 !== "super_secret_ev_pass_123") throw new Error("Account 1 password mismatch");
if (pass2 !== "super_secret_spor_pass_456") throw new Error("Account 2 password mismatch");

console.log("\n[Test 3] Switch Active Account Profile (Account 1 -> Account 2)");
store.setActiveAccount(acc2.id);
console.log(`- Current Active Account: "${store.activeAccount.name}"`);
console.log(`- Active Channels Count: ${store.currentLiveChannels.length}`);
if (store.activeAccount.id !== acc2.id) throw new Error("Failed to set Account 2 active");
if (store.currentLiveChannels.length !== 650) throw new Error("Active channels did not switch to Account 2");
if (!store.currentLiveChannels[0].name.includes("Spor Paketi")) throw new Error("Channel names do not match Account 2");

console.log("\n[Test 4] Update Account Credentials");
store.updateAccount(acc1.id, {
    name: "Ev IPTV (VIP Ultra)",
    server: "vip.evserver.net:8080",
    username: "mustafa_ev_vip",
    password: "new_vip_password_789"
});
const updatedPass1 = keychain.readPassword(acc1.id);
console.log(`- Updated Account 1 Name: "${acc1.name}"`);
console.log(`- Updated Password in Keychain: ${updatedPass1 === 'new_vip_password_789' ? 'Success' : 'Failed'}`);
if (updatedPass1 !== "new_vip_password_789") throw new Error("Keychain password update failed");

console.log("\n[Test 5] Delete Active Account & Verify Fallback Migration");
// Currently acc2 is active. Deleting acc2 should fallback to acc1
store.deleteAccount(acc2.id);
console.log(`- Accounts remaining count: ${store.accounts.length}`);
console.log(`- New Active Account after fallback: "${store.activeAccount ? store.activeAccount.name : 'null'}"`);
console.log(`- Deleted Account 2 Password in Keychain: ${keychain.readPassword(acc2.id) === null ? 'Wiped (Success)' : 'Leaked!'}`);

if (store.accounts.length !== 1) throw new Error("Expected 1 account remaining");
if (store.activeAccount.id !== acc1.id) throw new Error("Expected Account 1 to become active after deleting Account 2");
if (keychain.readPassword(acc2.id) !== null) throw new Error("Keychain password was not wiped upon deletion");
if (store.currentLiveChannels.length !== 2500) throw new Error("Channels not restored to Account 1");

console.log("\n==========================================");
console.log("ALL MULTI-ACCOUNT XTREAM TESTS PASSED SUCCESSFULLY!");
console.log("==========================================");
