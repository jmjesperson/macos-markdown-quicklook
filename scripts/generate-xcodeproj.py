#!/usr/bin/env python3
"""Write an Xcode project.pbxproj for a macOS app embedding a Quick Look preview extension.

Mirrors what Xcode 26's "macOS SwiftUI App" + "Quick Look Preview Extension" templates
produce (folder-synchronised groups, objectVersion 77, sandbox via ENABLE_* build settings).
Usage: scripts/generate-xcodeproj.py MarkdownQuicklook.xcodeproj "$(cat scripts/xcodeproj-config.json)"
Run from the repository root; object IDs derive from the output path, so they stay stable.
"""
import hashlib, json, os, sys

out, cfg = sys.argv[1], json.loads(sys.argv[2])
APP, EXT = cfg["app"], cfg["ext"]
APP_DIR, EXT_DIR = cfg["app_dir"], cfg["ext_dir"]
BID = cfg["bundle_id"]
PKG = cfg.get("package")  # {"path": "Packages/X", "product": "X"}
EXT_ENT = cfg.get("ext_entitlements")  # optional path
DEPLOY = cfg.get("deployment", "15.0")

def oid(name):
    return hashlib.sha1(("%s:%s" % (out, name)).encode()).hexdigest()[:24].upper()

def q(v):
    if isinstance(v, list):
        return "(\n" + "".join("\t\t\t\t\t%s,\n" % q(x) for x in v) + "\t\t\t\t)"
    s = str(v)
    import re
    if re.fullmatch(r"[A-Za-z0-9_./]+", s) and s:
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def settings(d):
    return "{\n" + "".join("\t\t\t\t%s = %s;\n" % (k, q(v)) for k, v in sorted(d.items())) + "\t\t\t}"

common_proj = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "MACOSX_DEPLOYMENT_TARGET": DEPLOY,
    "SDKROOT": "macosx",
}
proj_debug = dict(common_proj, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
})
proj_release = dict(common_proj, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
})
signing = {
    "CODE_SIGN_STYLE": "Manual",
    "CODE_SIGN_IDENTITY": "-",
    "DEVELOPMENT_TEAM": "",
    "ENABLE_APP_SANDBOX": "YES",
    "ENABLE_HARDENED_RUNTIME": "YES",
    "ENABLE_USER_SELECTED_FILES": "readonly",
    "CURRENT_PROJECT_VERSION": "1",
    "MARKETING_VERSION": cfg.get("version", "0.1.0"),
    "SWIFT_VERSION": "5.0",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "PRODUCT_NAME": "$(TARGET_NAME)",
}
app_settings = dict(signing, **{
    "COMBINE_HIDPI_IMAGES": "YES",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_NSHumanReadableCopyright": "",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks"],
    "PRODUCT_BUNDLE_IDENTIFIER": BID,
})
app_settings.update(cfg.get("app_settings", {}))
app_settings = {k: v for k, v in app_settings.items() if v is not None}
ext_settings = dict(signing, **{
    "ENABLE_OUTGOING_NETWORK_CONNECTIONS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_FILE": "%s/Info.plist" % EXT_DIR,
    "INFOPLIST_KEY_CFBundleDisplayName": EXT,
    "INFOPLIST_KEY_NSHumanReadableCopyright": "",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks", "@executable_path/../../../../Frameworks"],
    "PRODUCT_BUNDLE_IDENTIFIER": BID + "." + EXT,
    "SKIP_INSTALL": "YES",
})
if EXT_ENT:
    ext_settings["CODE_SIGN_ENTITLEMENTS"] = EXT_ENT
ext_settings.update(cfg.get("ext_settings", {}))

ext_exceptions = ["Info.plist"] + ([os.path.basename(EXT_ENT)] if EXT_ENT else [])

o = []
def add(name, body, comment=""):
    o.append("\t\t%s /* %s */ = %s;" % (oid(name), comment or name, body))

R = oid
add("bf_embed", "{isa = PBXBuildFile; fileRef = %s; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; }" % R("prod_ext"), EXT + ".appex in Embed Foundation Extensions")
add("bf_quartz", "{isa = PBXBuildFile; fileRef = %s; }" % R("fr_quartz"), "Quartz.framework in Frameworks")
if PKG:
    add("bf_pkg", "{isa = PBXBuildFile; productRef = %s; }" % R("pkg_prod"), PKG["product"] + " in Frameworks")
add("proxy", "{isa = PBXContainerItemProxy; containerPortal = %s; proxyType = 1; remoteGlobalIDString = %s; remoteInfo = %s; }" % (R("project"), R("t_ext"), q(EXT)), "PBXContainerItemProxy")
add("embed", "{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = \"\"; dstSubfolderSpec = 13; files = (%s, ); name = \"Embed Foundation Extensions\"; runOnlyForDeploymentPostprocessing = 0; }" % R("bf_embed"), "Embed Foundation Extensions")
add("prod_app", "{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = %s; sourceTree = BUILT_PRODUCTS_DIR; }" % q(APP + ".app"), APP + ".app")
add("prod_ext", "{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = %s; sourceTree = BUILT_PRODUCTS_DIR; }" % q(EXT + ".appex"), EXT + ".appex")
add("fr_quartz", "{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Quartz.framework; path = System/Library/Frameworks/Quartz.framework; sourceTree = SDKROOT; }", "Quartz.framework")
if PKG:
    add("fr_pkg", "{isa = PBXFileReference; lastKnownFileType = wrapper; path = %s; sourceTree = \"<group>\"; }" % q(PKG["path"]), os.path.basename(PKG["path"]))
add("exc_ext", "{isa = PBXFileSystemSynchronizedBuildFileExceptionSet; membershipExceptions = (%s); target = %s; }" % ("".join(q(x) + ", " for x in ext_exceptions), R("t_ext")), "Exceptions for \"%s\" folder in \"%s\" target" % (EXT_DIR, EXT))
add("g_app", "{isa = PBXFileSystemSynchronizedRootGroup; path = %s; sourceTree = \"<group>\"; }" % q(APP_DIR), APP_DIR)
add("g_ext", "{isa = PBXFileSystemSynchronizedRootGroup; exceptions = (%s, ); path = %s; sourceTree = \"<group>\"; }" % (R("exc_ext"), q(EXT_DIR)), EXT_DIR)
add("fw_app", "{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }", "Frameworks")
add("fw_ext", "{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (%s, %s); runOnlyForDeploymentPostprocessing = 0; }" % (R("bf_quartz"), (R("bf_pkg") + ", ") if PKG else ""), "Frameworks")
main_children = ([R("fr_pkg")] if PKG else []) + [R("g_app"), R("g_ext"), R("g_fw"), R("g_prod")]
add("g_main", "{isa = PBXGroup; children = (%s); sourceTree = \"<group>\"; }" % "".join(c + ", " for c in main_children), "main")
add("g_fw", "{isa = PBXGroup; children = (%s, ); name = Frameworks; sourceTree = \"<group>\"; }" % R("fr_quartz"), "Frameworks")
add("g_prod", "{isa = PBXGroup; children = (%s, %s, ); name = Products; sourceTree = \"<group>\"; }" % (R("prod_app"), R("prod_ext")), "Products")
add("t_app", "{isa = PBXNativeTarget; buildConfigurationList = %s; buildPhases = (%s, %s, %s, %s, ); buildRules = ( ); dependencies = (%s, ); fileSystemSynchronizedGroups = (%s, ); name = %s; packageProductDependencies = ( ); productName = %s; productReference = %s; productType = \"com.apple.product-type.application\"; }" % (R("cl_app"), R("src_app"), R("fw_app"), R("res_app"), R("embed"), R("dep"), R("g_app"), q(APP), q(APP), R("prod_app")), APP)
add("t_ext", "{isa = PBXNativeTarget; buildConfigurationList = %s; buildPhases = (%s, %s, %s, ); buildRules = ( ); dependencies = ( ); fileSystemSynchronizedGroups = (%s, ); name = %s; packageProductDependencies = (%s); productName = %s; productReference = %s; productType = \"com.apple.product-type.app-extension\"; }" % (R("cl_ext"), R("src_ext"), R("fw_ext"), R("res_ext"), R("g_ext"), q(EXT), (R("pkg_prod") + ", ") if PKG else "", q(EXT), R("prod_ext")), EXT)
pkg_refs = ("packageReferences = (%s, ); " % R("pkg_ref")) if PKG else ""
add("project", "{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 2600; LastUpgradeCheck = 2600; TargetAttributes = {%s = {CreatedOnToolsVersion = 26.0; }; %s = {CreatedOnToolsVersion = 26.0; }; }; }; buildConfigurationList = %s; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base, ); mainGroup = %s; minimizedProjectReferenceProxies = 1; %spreferredProjectObjectVersion = 77; productRefGroup = %s; projectDirPath = \"\"; projectRoot = \"\"; targets = (%s, %s, ); }" % (R("t_app"), R("t_ext"), R("cl_proj"), R("g_main"), pkg_refs, R("g_prod"), R("t_app"), R("t_ext")), "Project object")
for n in ("res_app", "res_ext"):
    add(n, "{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }", "Resources")
for n in ("src_app", "src_ext"):
    add(n, "{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }", "Sources")
add("dep", "{isa = PBXTargetDependency; target = %s; targetProxy = %s; }" % (R("t_ext"), R("proxy")), "PBXTargetDependency")
for scope, deb, rel in (("proj", proj_debug, proj_release), ("app", app_settings, app_settings), ("ext", ext_settings, ext_settings)):
    add("c_%s_d" % scope, "{isa = XCBuildConfiguration; buildSettings = %s; name = Debug; }" % settings(deb), "Debug")
    add("c_%s_r" % scope, "{isa = XCBuildConfiguration; buildSettings = %s; name = Release; }" % settings(rel), "Release")
    add("cl_%s" % scope, "{isa = XCConfigurationList; buildConfigurations = (%s, %s, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }" % (R("c_%s_d" % scope), R("c_%s_r" % scope)), "Build configuration list")
if PKG:
    add("pkg_ref", "{isa = XCLocalSwiftPackageReference; relativePath = %s; }" % q(PKG["path"]), "XCLocalSwiftPackageReference")
    add("pkg_prod", "{isa = XCSwiftPackageProductDependency; productName = %s; }" % q(PKG["product"]), PKG["product"])

os.makedirs(out, exist_ok=True)
with open(os.path.join(out, "project.pbxproj"), "w") as f:
    f.write("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 77;\n\tobjects = {\n\n")
    f.write("\n".join(o))
    f.write("\n\t};\n\trootObject = %s /* Project object */;\n}\n" % R("project"))

# Shared scheme so `xcodebuild -scheme <APP>` works from a clean checkout.
sd = os.path.join(out, "xcshareddata", "xcschemes")
os.makedirs(sd, exist_ok=True)
proj_name = os.path.basename(out)
def bref(t, name, prod):
    return '<BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "%s" BuildableName = "%s" BlueprintName = "%s" ReferencedContainer = "container:%s"></BuildableReference>' % (R(t), prod, name, proj_name)
with open(os.path.join(sd, cfg.get("scheme", APP) + ".xcscheme"), "w") as f:
    f.write('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            %s
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES"></TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         %s
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES"></ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
''' % (bref("t_app", APP, APP + ".app"), bref("t_app", APP, APP + ".app")))
print("wrote", out)
