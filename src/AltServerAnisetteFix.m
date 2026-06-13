#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

static NSURL *ALTAnisetteHelperURL(void)
{
    Dl_info info;
    if (dladdr((const void *)&ALTAnisetteHelperURL, &info) == 0)
    {
        return nil;
    }

    NSURL *libraryURL = [NSURL fileURLWithPath:@(info.dli_fname)];
    return [[libraryURL URLByDeletingLastPathComponent]
        URLByAppendingPathComponent:@"AltServerAnisetteHelper"];
}

static NSDictionary *ALTRequestRemoteAnisetteHeaders(id self, SEL selector, NSString *dsid)
{
    (void)self;
    (void)selector;
    (void)dsid;

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = ALTAnisetteHelperURL();

    NSPipe *outputPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    task.standardError = [NSPipe pipe];

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError])
    {
        return nil;
    }

    [task waitUntilExit];
    if (task.terminationStatus != 0)
    {
        return nil;
    }

    NSData *data = [outputPipe.fileHandleForReading readDataToEndOfFile];
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![response isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    NSString *machineID = response[@"X-Apple-I-MD-M"];
    NSString *oneTimePassword = response[@"X-Apple-I-MD"];
    if (machineID.length == 0 || oneTimePassword.length == 0)
    {
        return nil;
    }

    NSMutableDictionary *headers = [response mutableCopy];
    headers[@"X-Apple-MD-M"] = machineID;
    headers[@"X-Apple-MD"] = oneTimePassword;
    return headers;
}

__attribute__((constructor))
static void ALTInstallAnisetteFix(void)
{
    dlopen("/System/Library/PrivateFrameworks/AOSKit.framework/AOSKit", RTLD_NOW);

    Class utilitiesClass = NSClassFromString(@"AOSUtilities");
    Method method = class_getClassMethod(utilitiesClass, @selector(retrieveOTPHeadersForDSID:));
    if (method == NULL)
    {
        return;
    }

    method_setImplementation(method, (IMP)ALTRequestRemoteAnisetteHeaders);
}
