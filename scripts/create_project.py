from pathlib import Path
import json, shutil, hashlib
root = Path(__file__).resolve().parent.parent
app = root / 'Mellow'
assets = app / 'Resources/Assets.xcassets'
assets.mkdir(parents=True, exist_ok=True)
info = {'info': {'author': 'xcode', 'version': 1}}
(assets/'Contents.json').write_text(json.dumps(info, indent=2))
# Only the handoff art the app still uses. The companions are the sprite sets made by
# scripts/slice_sprites.swift, so the original plant / cat / candle files must not overwrite them.
used = {'flower-icon', 'mellow-logo', 'mellow-logo-1024', 'menubar-blossom'}
for source in (root/'Mellow-handoff/Assets').iterdir():
    if source.stem not in used: continue
    folder = assets / (source.stem + '.imageset')
    folder.mkdir(exist_ok=True)
    shutil.copy2(source, folder/source.name)
    data = dict(info, images=[{'filename': source.name, 'idiom': 'universal'}])
    if source.suffix == '.svg':
        data['properties'] = {'preserves-vector-representation': True, 'template-rendering-intent': 'template'}
    (folder/'Contents.json').write_text(json.dumps(data, indent=2))
colors = {'labelPrimary': ('1C1C1E','F5F5F7'), 'labelSecondary': ('6E6E73','A1A1A6'),
'labelTertiary': ('8E8E93','8E8E93'), 'onTint': ('FFFFFF','0B0B0C'), 'tintFocus': ('1F8A3F','30D158'),
'tintFocusPressed': ('176B31','28B84C'), 'tintBreak': ('0E7C93','40C8E0'), 'tintFlower': ('E8588A','FF7AA2'),
'separator': ('D1D1D6','3A3A3C'), 'progressTrack': ('000000','FFFFFF'), 'AccentColor': ('1F8A3F','30D158')}
for name, values in colors.items():
    folder = assets/(name+'.colorset'); folder.mkdir(exist_ok=True)
    entries = []
    for i, value in enumerate(values):
        color = {'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {
            **{key: str(int(value[j:j+2],16)/255) for key,j in [('red',0),('green',2),('blue',4)]},
            'alpha': format((.08 if i == 0 else .12) if name == 'progressTrack' else 1, '.6f')}}}
        if i: color['appearances'] = [{'appearance':'luminosity','value':'dark'}]
        entries.append(color)
    (folder/'Contents.json').write_text(json.dumps(dict(info, colors=entries), indent=2))
icon = assets/'AppIcon.appiconset'; icon.mkdir(exist_ok=True)
shutil.copy2(root/'Mellow-handoff/Assets/mellow-logo-1024.png', icon/'AppIcon.png')
(icon/'Contents.json').write_text(json.dumps(dict(info, images=[{'filename':'AppIcon.png','idiom':'mac','size':'512x512','scale':'2x'}]),indent=2))
project = root/'Mellow.xcodeproj'; project.mkdir(exist_ok=True)
# Synchronized groups let Xcode and the build automatically pick up new Swift source files.
(project/'project.pbxproj').write_text('''// !$*UTF8*$!
{
 archiveVersion = 1; classes = {}; objectVersion = 77;
 objects = {
  A10000000000000000000001 = {isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700;}; buildConfigurationList = A10000000000000000000002; compatibilityVersion = "Xcode 16.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = A10000000000000000000003; productRefGroup = A10000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (A10000000000000000000005);};
  A10000000000000000000002 = {isa = XCConfigurationList; buildConfigurations = (A10000000000000000000010, A10000000000000000000011); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
  A10000000000000000000003 = {isa = PBXGroup; children = (A10000000000000000000006, A10000000000000000000007, A10000000000000000000004); sourceTree = "<group>";};
  A10000000000000000000004 = {isa = PBXGroup; children = (A10000000000000000000008); name = Products; sourceTree = "<group>";};
  A10000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = A10000000000000000000009; buildPhases = (A10000000000000000000012, A10000000000000000000013, A10000000000000000000014); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = (A10000000000000000000006, A10000000000000000000007); name = Mellow; productName = Mellow; productReference = A10000000000000000000008; productType = "com.apple.product-type.application";};
  A10000000000000000000006 = {isa = PBXFileSystemSynchronizedRootGroup; path = Mellow; sourceTree = "<group>";};
  A10000000000000000000007 = {isa = PBXFileSystemSynchronizedRootGroup; path = Sources/MellowCore; sourceTree = "<group>";};
  A10000000000000000000008 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Mellow.app; sourceTree = BUILT_PRODUCTS_DIR;};
  A10000000000000000000009 = {isa = XCConfigurationList; buildConfigurations = (A10000000000000000000015, A10000000000000000000016); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
  A10000000000000000000010 = {isa = XCBuildConfiguration; buildSettings = {CLANG_ENABLE_MODULES = YES; MACOSX_DEPLOYMENT_TARGET = 26.0; SDKROOT = macosx;}; name = Debug;};
  A10000000000000000000011 = {isa = XCBuildConfiguration; buildSettings = {CLANG_ENABLE_MODULES = YES; MACOSX_DEPLOYMENT_TARGET = 26.0; SDKROOT = macosx;}; name = Release;};
  A10000000000000000000012 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;};
  A10000000000000000000013 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;};
  A10000000000000000000014 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;};
  A10000000000000000000015 = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; CODE_SIGN_STYLE = Automatic; CODE_SIGN_IDENTITY = "-"; ENABLE_APP_SANDBOX = YES; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_LSUIElement = YES; INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity"; INFOPLIST_KEY_CFBundleDisplayName = Mellow; INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Oybek Ruziev"; PRODUCT_BUNDLE_IDENTIFIER = uz.oybek.Mellow; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 6.0; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0;}; name = Debug;};
  A10000000000000000000016 = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; CODE_SIGN_STYLE = Automatic; CODE_SIGN_IDENTITY = "-"; ENABLE_APP_SANDBOX = YES; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_LSUIElement = YES; INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity"; INFOPLIST_KEY_CFBundleDisplayName = Mellow; INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Oybek Ruziev"; PRODUCT_BUNDLE_IDENTIFIER = uz.oybek.Mellow; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 6.0; SWIFT_COMPILATION_MODE = wholemodule; ENABLE_HARDENED_RUNTIME = YES; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0;}; name = Release;};
 }; rootObject = A10000000000000000000001;
}
''')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
(schemes/'Mellow.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A10000000000000000000005" BuildableName="Mellow.app" BlueprintName="Mellow" ReferencedContainer="container:Mellow.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A10000000000000000000005" BuildableName="Mellow.app" BlueprintName="Mellow" ReferencedContainer="container:Mellow.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A10000000000000000000005" BuildableName="Mellow.app" BlueprintName="Mellow" ReferencedContainer="container:Mellow.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Created native Xcode project and asset catalog.')
