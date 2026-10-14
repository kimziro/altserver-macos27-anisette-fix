#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <string.h>

static NSString *const ALTAndroidClientInfo =
    @"<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";

static id ALTAndroidDescriptionGetter(id self, SEL selector)
{
    (void)self;
    (void)selector;
    return ALTAndroidClientInfo;
}

static BOOL ALTIsObjectGetter(Method method)
{
    if (method == NULL || method_getNumberOfArguments(method) != 2) {
        return NO;
    }

    char *returnType = method_copyReturnType(method);
    char *selfType = method_copyArgumentType(method, 0);
    char *selectorType = method_copyArgumentType(method, 1);
    BOOL matches = returnType != NULL && selfType != NULL && selectorType != NULL &&
        strcmp(returnType, @encode(id)) == 0 &&
        strcmp(selfType, @encode(id)) == 0 &&
        strcmp(selectorType, @encode(SEL)) == 0;

    free(returnType);
    free(selfType);
    free(selectorType);
    return matches;
}

// Returns 1 when installed, 0 while the target class is absent, and -1 when
// the target exists but its getter ABI is not the expected object getter.
static int ALTInstallGetterHook(Class targetClass)
{
    SEL selector = sel_registerName("deviceDescription");
    Method method = class_getInstanceMethod(targetClass, selector);
    if (method == NULL) {
        return 0;
    }

    if (!ALTIsObjectGetter(method)) {
        return -1;
    }

    IMP current = method_getImplementation(method);
    if (current == (IMP)ALTAndroidDescriptionGetter) {
        return 1;
    }

    method_setImplementation(method, (IMP)ALTAndroidDescriptionGetter);
    return 1;
}

#ifdef ALT_HOOK_SYNTHETIC_TEST

BOOL ALTInstallGetterHookForTest(Class targetClass)
{
    return ALTInstallGetterHook(targetClass) == 1;
}

#else

__attribute__((constructor))
static void ALTStartBoundedGetterHook(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        static NSUInteger attempts = 0;
        static const NSUInteger maxAttempts = 20;

        Class targetClass = objc_getClass("ALTAnisetteData");
        if (targetClass != Nil) {
            int result = ALTInstallGetterHook(targetClass);
            if (result == 1) {
                NSLog(@"AltServer 80045 experiment: descriptor getter hook installed.");
                return;
            }
            if (result == -1) {
                NSLog(@"AltServer 80045 experiment: descriptor getter ABI mismatch; hook skipped.");
                return;
            }
        }

        attempts += 1;
        if (attempts >= maxAttempts) {
            NSLog(@"AltServer 80045 experiment: target getter unavailable; hook skipped.");
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC),
                       dispatch_get_main_queue(), ^{
            ALTStartBoundedGetterHook();
        });
    });
}

#endif
