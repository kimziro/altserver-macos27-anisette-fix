#import <Foundation/Foundation.h>
#import <objc/runtime.h>

extern BOOL ALTInstallGetterHookForTest(Class targetClass);

@interface ALTAnisetteData : NSObject
@property (nonatomic, copy) NSString *deviceDescription;
@property (nonatomic, copy) NSString *oneTimePassword;
@end

@implementation ALTAnisetteData
@end

@interface WrongABIAnisetteData : NSObject
- (NSInteger)deviceDescription;
@end

@implementation WrongABIAnisetteData
- (NSInteger)deviceDescription
{
    return 41;
}
@end

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool {
        ALTAnisetteData *data = [ALTAnisetteData new];
        data.deviceDescription = @"<Mac> <macOS;27;build> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
        data.oneTimePassword = @"synthetic-otp-sentinel";
        NSString *originalDescription = data.deviceDescription;

        Require(ALTInstallGetterHookForTest(ALTAnisetteData.class),
                @"object getter ABI should install");
        Require([data.deviceDescription isEqualToString:
                 @"<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"] ,
                @"getter should return only the Android descriptor");
        Require([data.oneTimePassword isEqualToString:@"synthetic-otp-sentinel"],
                @"other anisette fields should remain unchanged");
        data.deviceDescription = originalDescription;
        Require([data.deviceDescription isEqualToString:
                 @"<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"] ,
                @"setter should preserve stored value while getter override is active");

        WrongABIAnisetteData *wrong = [WrongABIAnisetteData new];
        Method wrongGetter = class_getInstanceMethod(WrongABIAnisetteData.class,
                                                      sel_registerName("deviceDescription"));
        const char *encoding = method_getTypeEncoding(wrongGetter);
        Require(encoding != NULL && encoding[0] != '@',
                @"negative-control getter should have a mismatched return ABI");
        Require(!ALTInstallGetterHookForTest(WrongABIAnisetteData.class),
                @"mismatched getter ABI must not be hooked");
        Require([wrong deviceDescription] == 41,
                @"mismatched getter implementation should remain intact");

        NSLog(@"PASS: getter-only descriptor override, preserved fields/setter, and ABI fail-closed control.");
    }
    return 0;
}
