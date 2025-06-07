#import <UIKit/UIKit.h>
#include <substrate.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <spawn.h>
#include "fishhook/fishhook.h"
#import "IgnoredAssertionHandler.h"
#include "xpc/xpc.h"
#import "PrivateAPI.h"

int (*_LSServerMain)(int argc, char *argv[], char *envp[]);
extern void PerformHook(void* _target, void* _replacement, void** orig);
extern bool os_variant_has_internal_content(const char* subsystem);

bool hook_os_variant_has_internal_content(const char* subsystem) {
	 return true;
}

void* hook_exit(int status) {
    NSLog(@"Ignored exit(%d)", status);
    // do not exit under any circumstances
    return NULL;
}

void SBLCRegisterInstalledApps(void) {
    static NSMutableArray *installedApps = nil;
    installedApps = [NSMutableArray array];
    NSURL *docPath = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s/Documents/Applications", getenv("LC_HOME_PATH")]];
    NSURL *appGroupPath = [[NSClassFromString(@"LCSharedUtils") appGroupPath] URLByAppendingPathComponent:@"LiveContainer/Applications"];
    
    LSApplicationWorkspace *workspace = [NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *apps = [fileManager contentsOfDirectoryAtURL:docPath includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles error:nil].mutableCopy;
    if(appGroupPath) {
        NSArray *sharedApps = [fileManager contentsOfDirectoryAtURL:appGroupPath includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                        options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
        [apps addObjectsFromArray:sharedApps];
    }
    for (NSURL *url in apps) {
        if (![url.pathExtension isEqualToString:@"app"]) continue;
        // TODO: handle hidden apps?
        NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfURL:[url URLByAppendingPathComponent:@"Info.plist"]];
        NSString *bundleID = infoPlist[@"CFBundleIdentifier"];
        [workspace registerApplicationDictionary:@{
            @"ApplicationType": @"System",
            @"CFBundleIdentifier": bundleID,
            @"CodeInfoIdentifier": bundleID,
            @"CompatibilityState": @0,
            @"IsContainerized": @(YES),
            @"EnvironmentVariables": @{},
            @"IsDeletable": @(NO),
            @"Path": url.path,
            @"SignerOrganization": @"Apple Inc.",
            @"SignatureVersion": @0x20500,
            @"SignerIdentity": @"Apple iPhone OS Application Signing",
            @"IsAdHocSigned": @YES,
            @"LSInstallType": @1,
            @"HasMIDBasedSINF": @0,
            @"MissingSINF": @0,
            @"FamilyID": @0,
            @"IsOnDemandInstallCapable": @0,
            @"HasAppGroupContainers": @YES
        }];
    }
}

int (*SBSystemAppMain)(int argc, char *argv[], char *envp[]);
int main(int argc, char *argv[], char *envp[]) {
    // initialize lsd
    dispatch_async(dispatch_get_main_queue(), ^{
        // once lsd hits the run loop, stop it to continue
        CFRunLoopStop(CFRunLoopGetMain());
    });
    void *csHandle = dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", 0);
    _LSServerMain = dlsym(csHandle,"_LSServerMain");
    _LSServerMain(argc, argv, envp);
    
    // Create symlinks (only works in LiveContainer)
    NSURL *fakeSBURL = NSBundle.mainBundle.bundleURL;
    NSURL *realSBURL = [NSURL fileURLWithPath:@"/System/Library/CoreServices/SpringBoard.app"];
    NSArray *realSBFiles = [NSFileManager.defaultManager contentsOfDirectoryAtURL:realSBURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for(NSURL *file in realSBFiles) {
        [NSFileManager.defaultManager createSymbolicLinkAtURL:[fakeSBURL URLByAppendingPathComponent:file.lastPathComponent] withDestinationURL:file error:nil];
    }
    
    // Ignore all assertions
    [NSThread.currentThread.threadDictionary setObject:[IgnoredAssertionHandler new] forKey:NSAssertionHandlerKey];
    
    // Avoid frameworks crashing due to not being SpringBoard :)
    PerformHook(os_variant_has_internal_content, hook_os_variant_has_internal_content, NULL);
    dlopen("/System/Library/PrivateFrameworks/SpringBoardHome.framework/SpringBoardHome", RTLD_GLOBAL);
    void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard", RTLD_GLOBAL);
    
    // Disable lock screen
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.springboard"];
    [defaults setBool:YES forKey:@"SBDontLockAfterCrash"];
    [defaults setBool:YES forKey:@"SBDontLockEver"];
    
    void *tweakHandle = dlopen("@executable_path/SpringBoardTweak.dylib", RTLD_GLOBAL|RTLD_NOW);
    if (!tweakHandle) {
        [@(dlerror()) writeToFile:[@(getenv("LC_HOME_PATH")) stringByAppendingPathComponent:@"Documents/SpringBoardLC.txt"] atomically:YES];
        abort();
    }
    
    // register installed apps, can only be done after loading SpringBoardTweak
    SBLCRegisterInstalledApps();
    
    dlopen("/var/jb/usr/lib/TweakInject/FLEXing.dylib", RTLD_GLOBAL|RTLD_NOW);
    SBSystemAppMain = dlsym(handle, "SBSystemAppMain");
	 return SBSystemAppMain(argc, argv, envp);
}
