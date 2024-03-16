#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

int (*SBSystemAppMain)(int argc, char *argv[], char *envp[]);

int main(int argc, char *argv[], char *envp[]) {
   [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"SBDontLockAfterCrash"];
   void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard", RTLD_GLOBAL);
   dlopen("@executable_path/SpringBoardTweak.dylib", RTLD_GLOBAL|RTLD_NOW);
   dlopen("/var/jb/usr/lib/TweakInject/FLEXing.dylib", RTLD_GLOBAL|RTLD_NOW);
   SBSystemAppMain = dlsym(handle, "SBSystemAppMain");
	return SBSystemAppMain(argc, argv, envp);
}
