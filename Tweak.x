#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <assert.h>
#include <stdbool.h>
#include <unistd.h>
#include <xpc/xpc.h>
#include <dispatch/dispatch.h>
#import <objc/runtime.h>

/*
%hook BSXPCServiceConnection
-(void)_connection_handleInvalidateMessage:(id)arg1 withHandoff:(id)arg2 {
}
%end
*/

// prevent backboardd crashes
%hook BKSSystemShellService
- (void)setCollectiveWatchdogPingBlock:(id)block {}
%end

%hook SpringBoard
// skip initializing notification center
- (void)_startBulletinBoardServer {}

- (UISceneConfiguration *)application:(UIApplication *)application 
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    if (connectingSceneSession.role == UIWindowSceneSessionRoleApplication) {
        static BOOL roleAppInited = NO;
        if (!roleAppInited) {
            roleAppInited = YES;
            return %orig;
        } else {
            // SpringBoard as daemon doesn't call this twice, but SpringBoard as app does this and trips an assertion inside
            return nil;
        }
    }
    return %orig;
}
%end

// Optional if process name = SpringBoard
%hook TLAlert
+ (void)_stopAllAlerts {}
%end

// SB's implementation recursively calls this for some reason, so use UIKit's implementation instead
%hook UISApplicationInitializationContext
+ (id)sb_embeddedDisplayDefaultContext {
    return [self performSelector:@selector(defaultContext)];
}
%end

// Skip watchdog init
void wd_endpoint_activate();
%hookf(void, wd_endpoint_activate) {};

// Optional if process name = SpringBoard
BOOL _UIApplicationProcessIsSpringBoard();
%hookf(BOOL, _UIApplicationProcessIsSpringBoard) {
    return YES;
}

typedef char name_t[128];

kern_return_t bootstrap_check_in(mach_port_t bp, const name_t service_name, mach_port_t *sp);
%hookf(kern_return_t, bootstrap_check_in, mach_port_t bp, const name_t service_name, mach_port_t *sp) {
    %orig;
    return 0; // regardless of errors
}

%hookf(xpc_connection_t, xpc_connection_create_mach_service, const char *name, dispatch_queue_t targetq, uint64_t flags) {
    NSLog(@"xpc_connection_create_mach_service(%s, %@, %llu)", name, targetq, flags);
    if (flags == XPC_CONNECTION_MACH_SERVICE_LISTENER) {
#if 0
        char name_mod[0x1000];
        strcpy(name_mod, name);
        if (!strncmp(name_mod, "com.apple", 9)) {
            strncpy(name_mod, "com.troll", 9);
        }
        NSLog(@"Mach Service: %s -> %s", name, name_mod);
        return %orig(name_mod, targetq, flags);
#endif
        NSLog(@"Changing flag for Mach Service: %s", name);
        // this is just to prevent it from crashing
        // com.apple.frontboard.systemappservices
        // com.apple.siri.activation.service
        return %orig(name, targetq, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    }
    return %orig;
}

// Optional if process name = SpringBoard
NSString* CUTProcessNameForPid(int pid);
%hookf(NSString *, CUTProcessNameForPid, int pid) {
    if (pid == getpid()) {
        return @"SpringBoard";
    }
    return %orig;
}

%ctor {
    MSImageRef image;
image = MSGetImageByName("/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore");
    %init(_UIApplicationProcessIsSpringBoard = MSFindSymbol(image, "__UIApplicationProcessIsSpringBoard"));
}
