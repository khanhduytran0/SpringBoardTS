#import <UIKit/UIKit.h>
#include <substrate.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <spawn.h>
#include "fishhook/fishhook.h"
#import "IgnoredAssertionHandler.h"
#include "xpc/xpc.h"

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

kern_return_t (*orig_bootstrap_check_in)(mach_port_t bp, const name_t service_name, mach_port_t *sp);
kern_return_t hook_bootstrap_check_in(mach_port_t bp, const name_t service_name, mach_port_t *sp) {
    orig_bootstrap_check_in(bp, service_name, sp);
    return 0; // regardless of errors
}

xpc_connection_t (*orig_xpc_connection_create_mach_service)(const char *name, dispatch_queue_t targetq, uint64_t flags);
xpc_connection_t hook_xpc_connection_create_mach_service(const char *name, dispatch_queue_t targetq, uint64_t flags) {
    NSLog(@"xpc_connection_create_mach_service(%s, %@, %llu)", name, targetq, flags);
    if (flags == XPC_CONNECTION_MACH_SERVICE_LISTENER) {
        NSLog(@"Changing flag for Mach Service: %s", name);
        // this is just to prevent it from crashing
        // com.apple.frontboard.systemappservices
        // com.apple.siri.activation.service
        return orig_xpc_connection_create_mach_service(name, targetq, 0);
    }
    return orig_xpc_connection_create_mach_service(name, targetq, flags);
}

int (*SBSystemAppMain)(int argc, char *argv[], char *envp[]);
int main(int argc, char *argv[], char *envp[]) {
    void *xpc_connection_create_mach_service_ = dlsym(RTLD_DEFAULT, "xpc_connection_create_mach_service");
    assert(xpc_connection_create_mach_service_ != NULL);
    PerformHook(os_variant_has_internal_content, hook_os_variant_has_internal_content, NULL);
    //PerformHook(bootstrap_check_in, hook_bootstrap_check_in, &orig_bootstrap_check_in);
    //PerformHook(xpc_connection_create_mach_service_, hook_xpc_connection_create_mach_service, &orig_xpc_connection_create_mach_service);
    
   //[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"SBDontLockAfterCrash"];
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Ignore assertion handler to prevent crashes from SpringBoardHome
        [NSThread.currentThread.threadDictionary setObject:[IgnoredAssertionHandler new] forKey:NSAssertionHandlerKey];
        dlopen("/System/Library/PrivateFrameworks/SpringBoardHome.framework/SpringBoardHome", RTLD_GLOBAL);
    });
    void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard", RTLD_GLOBAL);

    void *tweakHandle = dlopen("@executable_path/SpringBoardTweak.dylib", RTLD_GLOBAL|RTLD_NOW);
    if (!tweakHandle) {
        [@(dlerror()) writeToFile:[@(getenv("LC_HOME_PATH")) stringByAppendingPathComponent:@"Documents/SpringBoardLC.txt"] atomically:YES];
        abort();
    }

    dlopen("/var/jb/usr/lib/TweakInject/FLEXing.dylib", RTLD_GLOBAL|RTLD_NOW);
    
    SBSystemAppMain = dlsym(handle, "SBSystemAppMain");
	 return SBSystemAppMain(argc, argv, envp);
}
