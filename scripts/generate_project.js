const fs = require('fs');
const path = require('path');

function generateUUID(seed) {
    let hash = 0;
    for (let i = 0; i < seed.length; i++) {
        hash = ((hash << 5) - hash) + seed.charCodeAt(i);
        hash |= 0;
    }
    const hex = Math.abs(hash).toString(16).padStart(8, '0').toUpperCase();
    const prefix = "1A2B3C4D";
    const mid = "5E6F";
    return `${prefix}${mid}${hex.substring(0, 8)}`.padEnd(24, '0').toUpperCase();
}

const files = [
    { name: "CarPlayTVApp.swift", path: "CarPlayTV/App/CarPlayTVApp.swift", isSource: true },
    { name: "SceneDelegate.swift", path: "CarPlayTV/App/SceneDelegate.swift", isSource: true },
    { name: "AppDelegate.swift", path: "CarPlayTV/App/AppDelegate.swift", isSource: true },
    { name: "Channel.swift", path: "CarPlayTV/Models/Channel.swift", isSource: true },
    { name: "XtreamModels.swift", path: "CarPlayTV/Models/XtreamModels.swift", isSource: true },
    { name: "VODModels.swift", path: "CarPlayTV/Models/VODModels.swift", isSource: true },
    { name: "EPGModels.swift", path: "CarPlayTV/Models/EPGModels.swift", isSource: true },
    { name: "XtreamAccount.swift", path: "CarPlayTV/Models/XtreamAccount.swift", isSource: true },
    { name: "M3UParser.swift", path: "CarPlayTV/Services/M3UParser.swift", isSource: true },
    { name: "XtreamCodesClient.swift", path: "CarPlayTV/Services/XtreamCodesClient.swift", isSource: true },
    { name: "PlaybackManager.swift", path: "CarPlayTV/Services/PlaybackManager.swift", isSource: true },
    { name: "PlaylistStore.swift", path: "CarPlayTV/Services/PlaylistStore.swift", isSource: true },
    { name: "VODStore.swift", path: "CarPlayTV/Services/VODStore.swift", isSource: true },
    { name: "XtreamAccountStore.swift", path: "CarPlayTV/Services/XtreamAccountStore.swift", isSource: true },
    { name: "NetworkMonitor.swift", path: "CarPlayTV/Services/NetworkMonitor.swift", isSource: true },
    { name: "ImageCacheManager.swift", path: "CarPlayTV/Services/ImageCacheManager.swift", isSource: true },
    { name: "KeychainHelper.swift", path: "CarPlayTV/Services/KeychainHelper.swift", isSource: true },
    { name: "URLSanitizer.swift", path: "CarPlayTV/Services/URLSanitizer.swift", isSource: true },
    { name: "EPGParser.swift", path: "CarPlayTV/Services/EPGParser.swift", isSource: true },
    { name: "EPGStore.swift", path: "CarPlayTV/Services/EPGStore.swift", isSource: true },
    { name: "CarPlaySceneDelegate.swift", path: "CarPlayTV/CarPlay/CarPlaySceneDelegate.swift", isSource: true },
    { name: "CarPlayInterfaceManager.swift", path: "CarPlayTV/CarPlay/CarPlayInterfaceManager.swift", isSource: true },
    { name: "CarPlayVideoWindowController.swift", path: "CarPlayTV/CarPlay/CarPlayVideoWindowController.swift", isSource: true },
    { name: "CachedAsyncImage.swift", path: "CarPlayTV/Views/Common/CachedAsyncImage.swift", isSource: true },
    { name: "CustomVideoPlayerView.swift", path: "CarPlayTV/Views/Player/CustomVideoPlayerView.swift", isSource: true },
    { name: "VideoControlsOverlayView.swift", path: "CarPlayTV/Views/Player/VideoControlsOverlayView.swift", isSource: true },
    { name: "FullscreenPlayerView.swift", path: "CarPlayTV/Views/Player/FullscreenPlayerView.swift", isSource: true },
    { name: "ChannelRowView.swift", path: "CarPlayTV/Views/Channels/ChannelRowView.swift", isSource: true },
    { name: "ChannelListView.swift", path: "CarPlayTV/Views/Channels/ChannelListView.swift", isSource: true },
    { name: "ChannelEPGSheetView.swift", path: "CarPlayTV/Views/Channels/ChannelEPGSheetView.swift", isSource: true },
    { name: "VODCardView.swift", path: "CarPlayTV/Views/VOD/VODCardView.swift", isSource: true },
    { name: "VODDetailView.swift", path: "CarPlayTV/Views/VOD/VODDetailView.swift", isSource: true },
    { name: "VODHomeView.swift", path: "CarPlayTV/Views/VOD/VODHomeView.swift", isSource: true },
    { name: "AddPlaylistSheet.swift", path: "CarPlayTV/Views/Playlist/AddPlaylistSheet.swift", isSource: true },
    { name: "EditXtreamAccountSheet.swift", path: "CarPlayTV/Views/Playlist/EditXtreamAccountSheet.swift", isSource: true },
    { name: "XtreamAccountRowView.swift", path: "CarPlayTV/Views/Playlist/XtreamAccountRowView.swift", isSource: true },
    { name: "PlaylistManagerView.swift", path: "CarPlayTV/Views/Playlist/PlaylistManagerView.swift", isSource: true },
    { name: "CarPlaySettingsView.swift", path: "CarPlayTV/Views/Settings/CarPlaySettingsView.swift", isSource: true },
    { name: "MainTabView.swift", path: "CarPlayTV/Views/MainTabView.swift", isSource: true },
    { name: "Assets.xcassets", path: "CarPlayTV/Assets.xcassets", isResource: true },
    { name: "Info.plist", path: "CarPlayTV/Info.plist", isSource: false },
    { name: "CarPlayTV.entitlements", path: "CarPlayTV/CarPlayTV.entitlements", isSource: false }
];

const frameworks = [
    "CarPlay.framework",
    "AVFoundation.framework",
    "AVKit.framework",
    "MediaPlayer.framework",
    "Network.framework",
    "Security.framework"
];

for (const f of files) {
    f.fileRef = generateUUID("fileref_" + f.path);
    if (f.isSource) {
        f.buildRef = generateUUID("buildref_" + f.path);
    } else if (f.isResource) {
        f.resourceRef = generateUUID("resref_" + f.path);
    }
}

const fwObjs = frameworks.map(fw => ({
    name: fw,
    fileRef: generateUUID("fw_ref_" + fw),
    buildRef: generateUUID("fw_build_" + fw)
}));

const TARGET_UUID = generateUUID("target_CarPlayTV");
const CONFIG_LIST_TARGET = generateUUID("cfglist_target");
const CONFIG_LIST_PROJECT = generateUUID("cfglist_project");
const PROJECT_UUID = generateUUID("project_uuid");
const MAIN_GROUP = generateUUID("main_group");
const APP_GROUP = generateUUID("app_group");
const FRAMEWORKS_GROUP = generateUUID("fw_group");
const PRODUCTS_GROUP = generateUUID("products_group");
const APP_PRODUCT = generateUUID("product_app");
const SOURCES_BUILD_PHASE = generateUUID("sources_phase");
const FRAMEWORKS_BUILD_PHASE = generateUUID("fw_phase");
const RESOURCES_BUILD_PHASE = generateUUID("res_phase");

const DEBUG_TARGET_CONF = generateUUID("dbg_target_conf");
const RELEASE_TARGET_CONF = generateUUID("rel_target_conf");
const DEBUG_PROJ_CONF = generateUUID("dbg_proj_conf");
const RELEASE_PROJ_CONF = generateUUID("rel_proj_conf");

let content = `// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
`;

for (const f of files) {
    if (f.isSource) {
        content += `\t\t${f.buildRef} /* ${f.name} in Sources */ = {isa = PBXBuildFile; fileRef = ${f.fileRef} /* ${f.name} */; };\n`;
    } else if (f.isResource) {
        content += `\t\t${f.resourceRef} /* ${f.name} in Resources */ = {isa = PBXBuildFile; fileRef = ${f.fileRef} /* ${f.name} */; };\n`;
    }
}

for (const fw of fwObjs) {
    content += `\t\t${fw.buildRef} /* ${fw.name} in Frameworks */ = {isa = PBXBuildFile; fileRef = ${fw.fileRef} /* ${fw.name} */; };\n`;
}

content += `/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t${APP_PRODUCT} /* CarPlayTV.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CarPlayTV.app; sourceTree = BUILT_PRODUCTS_DIR; };
`;

for (const f of files) {
    const fileType = f.name.endsWith('.swift') ? 'sourcecode.swift' :
                     f.name.endsWith('.xcassets') ? 'folder.assetcatalog' :
                     f.name.endsWith('.plist') ? 'text.plist.xml' :
                     f.name.endsWith('.entitlements') ? 'text.plist.entitlements' : 'text';
    content += `\t\t${f.fileRef} /* ${f.name} */ = {isa = PBXFileReference; lastKnownFileType = ${fileType}; name = "${f.name}"; path = "${f.path}"; sourceTree = SOURCE_ROOT; };\n`;
}

for (const fw of fwObjs) {
    content += `\t\t${fw.fileRef} /* ${fw.name} */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = "${fw.name}"; path = "System/Library/Frameworks/${fw.name}"; sourceTree = SDKROOT; };\n`;
}

content += `/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t${FRAMEWORKS_BUILD_PHASE} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
${fwObjs.map(fw => `\t\t\t\t${fw.buildRef} /* ${fw.name} in Frameworks */,`).join('\n')}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t${MAIN_GROUP} = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t${APP_GROUP} /* CarPlayTV */,
\t\t\t\t${FRAMEWORKS_GROUP} /* Frameworks */,
\t\t\t\t${PRODUCTS_GROUP} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t${PRODUCTS_GROUP} /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t${APP_PRODUCT} /* CarPlayTV.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t${FRAMEWORKS_GROUP} /* Frameworks */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
${fwObjs.map(fw => `\t\t\t\t${fw.fileRef} /* ${fw.name} */,`).join('\n')}
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t${APP_GROUP} /* CarPlayTV */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
${files.map(f => `\t\t\t\t${f.fileRef} /* ${f.name} */,`).join('\n')}
\t\t\t);
\t\t\tpath = CarPlayTV;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t${TARGET_UUID} /* CarPlayTV */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = ${CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "CarPlayTV" */;
\t\t\tbuildPhases = (
\t\t\t\t${SOURCES_BUILD_PHASE} /* Sources */,
\t\t\t\t${FRAMEWORKS_BUILD_PHASE} /* Frameworks */,
\t\t\t\t${RESOURCES_BUILD_PHASE} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = CarPlayTV;
\t\t\tproductName = CarPlayTV;
\t\t\tproductReference = ${APP_PRODUCT} /* CarPlayTV.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t${PROJECT_UUID} /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tattributes = {
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {
\t\t\t\t\t${TARGET_UUID} = {
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t\tbuildConfigurationList = ${CONFIG_LIST_PROJECT} /* Build configuration list for PBXProject "CarPlayTV" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = ${MAIN_GROUP};
\t\t\tproductRefGroup = ${PRODUCTS_GROUP} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t${TARGET_UUID} /* CarPlayTV */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t${RESOURCES_BUILD_PHASE} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
${files.filter(f => f.isResource).map(f => `\t\t\t\t${f.resourceRef} /* ${f.name} in Resources */,`).join('\n')}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t${SOURCES_BUILD_PHASE} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
${files.filter(f => f.isSource).map(f => `\t\t\t\t${f.buildRef} /* ${f.name} in Sources */,`).join('\n')}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t${DEBUG_PROJ_CONF} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${RELEASE_PROJ_CONF} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\t${DEBUG_TARGET_CONF} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = CarPlayTV/CarPlayTV.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = CarPlayTV/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.1.1;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.carplaytv.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${RELEASE_TARGET_CONF} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = CarPlayTV/CarPlayTV.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = CarPlayTV/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.1.1;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.carplaytv.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Release;
\t\t};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t${CONFIG_LIST_PROJECT} /* Build configuration list for PBXProject "CarPlayTV" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${DEBUG_PROJ_CONF} /* Debug */,
\t\t\t\t${RELEASE_PROJ_CONF} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t${CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "CarPlayTV" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${DEBUG_TARGET_CONF} /* Debug */,
\t\t\t\t${RELEASE_TARGET_CONF} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */

\t};
\trootObject = ${PROJECT_UUID} /* Project object */;
}
`;

const projectDir = path.join(__dirname, '..', 'CarPlayTV.xcodeproj');
if (!fs.existsSync(projectDir)) {
    fs.mkdirSync(projectDir, { recursive: true });
}

fs.writeFileSync(path.join(projectDir, 'project.pbxproj'), content, 'utf8');
console.log("Successfully generated CarPlayTV.xcodeproj/project.pbxproj");
