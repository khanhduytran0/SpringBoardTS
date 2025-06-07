@import UIKit;

@interface FBScene : NSObject
- (NSString *)identifier;
@end

@interface FBSScene : NSObject
- (NSString *)identifier;
- (id)identity;
- (id)identityToken;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)registerApplicationDictionary:(NSDictionary *)dict;
@end

@interface UIMutableApplicationSceneSettings : NSObject
- (void)setLevel:(CGFloat)level;
@end

@interface UIApplicationSceneSettings : NSObject
- (instancetype)initWithSettings:(id)s;
- (UIMutableApplicationSceneSettings *)mutableCopy;
- (CGFloat)level;
@end

@interface UIWindowScene(private)
- (FBSScene *)_scene;
@end

// LiveContainer API
@interface LCSharedUtils : NSObject
- (NSURL *)appGroupPath;
@end
