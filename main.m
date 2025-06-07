#import <UIKit/UIKit.h>
#include <substrate.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <spawn.h>
#include "fishhook/fishhook.h"
#import "IgnoredAssertionHandler.h"
#include "xpc/xpc.h"

int (*_LSServerMain)(int argc, char *argv[], char *envp[]);

extern void PerformHook(void* _target, void* _replacement, void** orig);

typedef char name_t[128];
extern kern_return_t bootstrap_check_in(mach_port_t bp, const name_t service_name, mach_port_t *sp);
extern bool os_variant_has_internal_content(const char* subsystem);

bool hook_os_variant_has_internal_content(const char* subsystem) {
	 return true;
}

void* hook_exit(int status) {
    NSLog(@"Ignored exit(%d)", status);
    // do not exit under any circumstances
    return NULL;
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
    
    dlopen("/var/jb/usr/lib/TweakInject/FLEXing.dylib", RTLD_GLOBAL|RTLD_NOW);
    SBSystemAppMain = dlsym(handle, "SBSystemAppMain");
	 return SBSystemAppMain(argc, argv, envp);
}
