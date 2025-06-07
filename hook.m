//
//  hook.m
//
//
//  Created by Duy Tran on 1/6/25.
//
@import Darwin;
@import Foundation;
@import MachO;
@import ObjectiveC;

#include <assert.h>

extern void EKJITLessHook(void* _target, void* _replacement, void** orig);
void (*MSHookFunction_)(void* _target, void* _replacement, void** orig);

#define ASM(...) __asm__(#__VA_ARGS__)
// ldr x8, value; br x8; value: .ascii "\x41\x42\x43\x44\x45\x46\x47\x48"
static char patch[] = {0x88,0x00,0x00,0x58,0x00,0x01,0x1f,0xd6,0x1f,0x20,0x03,0xd5,0x1f,0x20,0x03,0xd5,0x41,0x41,0x41,0x41,0x41,0x41,0x41,0x41};

// Since we're patching libsystem_kernel, we must avoid calling to its functions
static void builtin_memcpy(char *target, char *source, size_t size) {
    for (int i = 0; i < size; i++) {
        target[i] = source[i];
    }
}

// Originated from _kernelrpc_mach_vm_protect_trap
kern_return_t builtin_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_prot);
ASM(
.global _builtin_vm_protect \n
_builtin_vm_protect:     \n
    mov x16, #-0xe       \n
    svc #0x80            \n
    ret
);

void redirectFunction(void *patchAddr, void *target) {
    kern_return_t kret = builtin_vm_protect(mach_task_self(), (vm_address_t)patchAddr, sizeof(patch), false, PROT_READ | PROT_WRITE | VM_PROT_COPY);
    assert(kret == KERN_SUCCESS);
    
    builtin_memcpy((char *)patchAddr, patch, sizeof(patch));
    *(void **)((char*)patchAddr + 16) = target;
    
    kret = builtin_vm_protect(mach_task_self(), (vm_address_t)patchAddr, sizeof(patch), false, PROT_READ | PROT_EXEC);
    assert(kret == KERN_SUCCESS);
}

void PerformHook(void* _target, void* _replacement, void** orig) {
    if(orig) {
#if 0 // ellekit
        EKJITLessHook(_target, _replacement, orig);
#else
        void *handle = dlopen("@executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate", RTLD_GLOBAL);
        MSHookFunction_ = dlsym(RTLD_DEFAULT, "MSHookFunction");
        MSHookFunction_(_target, _replacement, orig);
#endif
    } else {
        redirectFunction(_target, _replacement);
    }
}


@interface LCSharedUtils : NSObject
+ (NSURL *)appGroupPath;
@end

@interface _LSDefaultsHook : NSObject
@end
@implementation _LSDefaultsHook
- (NSURL *)databaseContainerDirectoryURL {
    static NSURL *dbContainerURL = nil;
    if(!dbContainerURL) {
        NSURL *rootDocURL = [[NSClassFromString(@"LCSharedUtils") appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
        if(!rootDocURL) {
            rootDocURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s/Documents", getenv("LC_HOME_PATH")]];
        }
        dbContainerURL = [rootDocURL URLByAppendingPathComponent:@"lsd"];
        [NSFileManager.defaultManager createDirectoryAtURL:dbContainerURL withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dbContainerURL;
}
- (NSURL *)systemContainerURL {
    return self.databaseContainerDirectoryURL;
}
- (NSURL *)systemGroupContainerURL {
    return self.databaseContainerDirectoryURL;
}
- (NSURL *)userContainerURL {
    return self.databaseContainerDirectoryURL;
}
- (NSURL *)databaseStoreFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServices-6291460-v2.csstore"];
}
- (NSURL *)systemContentDatabaseStoreFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"SystemDataOnly-com.apple.LaunchServices-6291460-v2.csstore"];
}
- (NSURL *)unremappableDatabaseStoreFileURL {
    return [[self databaseStoreFileURL] URLByAppendingPathExtension:@".unremappable"];
}
- (NSURL *)queriedSchemesMapFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.lsdschemes.plist"];
}
- (NSURL *)identifiersFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.lsdidentifiers.plist"];
}
- (NSURL *)preferencesFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServices.plist"];
}
- (NSURL *)securePreferencesFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.launchservices.securepreferences.plist"];
}
- (NSURL *)preSydroFSecurePreferencesFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.launchservices.securepreferences.plist"];
}
- (NSURL *)settingsStoreFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServices.SettingsStore.sql"];
}
- (NSURL *)appProtectionStoreFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServicesAppProtectionStore.plist"];
}
- (NSURL *)dbSentinelFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServices.dirty"];
}
- (NSURL *)dbRecoveryFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServices.error"];
}
- (NSURL *)dbSyncInterruptedFileURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServices.syncInterrupted"];
}
- (NSURL *)installJournalDirectoryURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.LaunchServices.InstallJournal"];
}
- (NSURL *)progressProportionsStateURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"ProgressProporitions.plist"];
}
- (NSURL *)appMarketplacesPreferencesStateURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"com.apple.launchservices.appmarketplaces.plist"];
}
- (NSURL *)specialAppEligibilityStateURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"SpecialAppEligibilityState.plist"];
}
- (NSURL *)defaultAppQueryStateURL {
    return [self.databaseContainerDirectoryURL URLByAppendingPathComponent:@"DefaultAppQueryState.plist"];
}

@end

__attribute__((constructor)) void SwizzleLSDDefaults(void) {
    Class lsdClass = NSClassFromString(@"_LSDefaults");
    uint32_t mc = 0;
    Method *mlist = class_copyMethodList(_LSDefaultsHook.class, &mc);
    for(uint32_t i = 0; i < mc; i++) {
        Method swizzledMethod = mlist[i];
        Method originalMethod = class_getInstanceMethod(lsdClass, method_getName(swizzledMethod));
        method_setImplementation(originalMethod, method_getImplementation(swizzledMethod));
    }
    free(mlist);
}

#if 0

@implementation _LSApplicationRecordEnumerator

// Attempts to get an object at a specific index using the provided context.
- (BOOL)_getObject:(void **)object atIndex:(NSUInteger)index context:(uint64_t)context {
    uint64_t base = self->_internalArray[13];
    NSUInteger count = (self->_internalArray[14] - base) >> 2;
    if (count > index) {
        // Calls an external function to get the application record.
        *object = ExternalGetApplicationRecord(self, context, *(unsigned int *)(base + 4 * index));
        ExternalFunction1();
    }
    return count > index;
}

// Checks whether all bundles should be enumerated.
- (BOOL)_enumerateAllBundles {
    // Masked flag check
    return (~*((uint32_t *)(self + 96)) & 0xD0) == 0;
}

// Prepares the enumerator with a context and error pointer.
- (uint64_t)_prepareWithContext:(uint64_t)context error:(uint64_t)error {
    uint64_t result = ExternalGetContainer(self, self + 16, context, error);
    if ((uint32_t)result) {
        BOOL enumerateAll = [self _enumerateAllBundles];
        uint64_t basePtr = *((uint64_t *)context + 1);
        if (enumerateAll) {
            unsigned int value = *((unsigned int *)context + 5);
            void *block[5] = { _NSConcreteStackBlock, 3221225472LL, Block1, &BlockData1, self };
            ExternalEnumFunction1(basePtr, value, block);
        } else {
            uint64_t offset = *((uint64_t *)context + 95);
            void *block[5] = { _NSConcreteStackBlock, 3221225472LL, Block2, &BlockData2, self };
            ExternalEnumFunction2(basePtr, offset, block);
        }
        if ((unsigned int)ExternalLogFunction(_LSEnumeratorLog, 2LL)) {
            [self _prepareWithContextErrorCold];
        }
    }
    self->_internalArray[11] = 0;
    ExternalFunction2();
    return result;
}

// Initializes the enumerator with a context, volume URL, and options.
- (instancetype)initWithContext:(uint64_t)context volumeURL:(NSURL *)volumeURL options:(uint64_t)options {
    if (self = [super init]) {
        self->_options = options;
        objc_storeStrong((id *)(&self->_volumeURL), volumeURL);
        self->_bundleClass = 2;
    }
    return self;
}

// C++ construct helper (for internal array initialization)
- (void *)cxx_construct {
    self->_internalArray[13] = 0;
    self->_internalArray[14] = 0;
    self->_internalArray[15] = 0;
    return self->_internalArray;
}

// Destructor to clean up resources.
- (void)cxx_destruct {
    void *ptr = *((void **)(self + 104));
    if (ptr) {
        *((void **)(self + 112)) = ptr;
        operator delete(ptr);
    }
    objc_storeStrong((id *)(self + 88), nil);
}

// Makes a copy of the enumerator.
- (id)copyWithZone:(NSZone *)zone {
    _LSApplicationRecordEnumerator *copy = [[_LSApplicationRecordEnumerator allocWithZone:zone] init];
    if (copy) {
        copy->_volumeURL = [self->_volumeURL copyWithZone:zone];
        ExternalFunction1();
        copy->_options = self->_options;
        if (copy != self) {
            std::vector<unsigned int>::__assign_with_size(
                (void **)&copy->_internalArray[13],
                (char **)&self->_internalArray[13],
                self->_internalArray[14],
                self->_internalArray[14] - self->_internalArray[13]
            );
        }
        copy->_someField1 = self->_someField1;
        copy->_bundleClass = self->_bundleClass;
    }
    return copy;
}

- (uint64_t)bundleClass {
    return self->_bundleClass;
}

- (void)setBundleClass:(int)bundleClass {
    self->_bundleClass = bundleClass;
}

// Cold function for error handling/logging.
- (void)_prepareWithContextErrorCold {
    OUTLINED_FUNCTION_0_1();
    OUTLINED_FUNCTION_1_1();
}

@end
#endif
