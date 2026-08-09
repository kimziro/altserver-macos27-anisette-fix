#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

static IMP ALTOriginalMachineSerialNumber = NULL;
static IMP ALTOriginalMachineUDID = NULL;

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

static NSURL *ALTProvisionedIdentityURL(void)
{
    NSArray<NSURL *> *directories = [[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask];
    if (directories.count == 0)
    {
        return nil;
    }

    return [[[directories firstObject]
        URLByAppendingPathComponent:@"AltServer" isDirectory:YES]
        URLByAppendingPathComponent:@"RemoteAnisetteUser.json" isDirectory:NO];
}

// The provisioned identity is written once by AltServerAnisetteHelper and then
// reused, so serialNumber and deviceID can be read straight from disk. Spawning
// the helper again for these would cost two extra processes per anisette fetch.
static NSString *ALTProvisionedIdentityValue(NSString *key)
{
    NSURL *identityURL = ALTProvisionedIdentityURL();
    if (identityURL == nil)
    {
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfURL:identityURL];
    if (data == nil)
    {
        return nil;
    }

    NSDictionary *identity = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:nil];
    if (![identity isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    NSString *value = identity[key];
    if (![value isKindOfClass:[NSString class]] || value.length == 0)
    {
        return nil;
    }

    return value;
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

// AltServer reads the device serial and UDID from AOSKit separately from the OTP
// headers, and on macOS 27 those two calls still succeed and return the host
// Mac's real values. Left alone, AltServer pairs a machineID minted for the
// provisioned identity with the host's serial and UDID, so the outbound request
// describes two different machines. Serve them from the provisioned identity to
// keep the set consistent.
static NSString *ALTProvisionedMachineSerialNumber(id self, SEL selector)
{
    NSString *serialNumber = ALTProvisionedIdentityValue(@"serialNumber");
    if (serialNumber != nil)
    {
        return serialNumber;
    }

    if (ALTOriginalMachineSerialNumber != NULL)
    {
        return ((NSString *(*)(id, SEL))ALTOriginalMachineSerialNumber)(self, selector);
    }

    return nil;
}

static NSString *ALTProvisionedMachineUDID(id self, SEL selector)
{
    NSString *deviceID = ALTProvisionedIdentityValue(@"deviceID");
    if (deviceID != nil)
    {
        return deviceID;
    }

    if (ALTOriginalMachineUDID != NULL)
    {
        return ((NSString *(*)(id, SEL))ALTOriginalMachineUDID)(self, selector);
    }

    return nil;
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

    Method serialNumberMethod = class_getClassMethod(utilitiesClass, @selector(machineSerialNumber));
    if (serialNumberMethod != NULL)
    {
        ALTOriginalMachineSerialNumber = method_setImplementation(
            serialNumberMethod, (IMP)ALTProvisionedMachineSerialNumber);
    }

    Method udidMethod = class_getClassMethod(utilitiesClass, @selector(machineUDID));
    if (udidMethod != NULL)
    {
        ALTOriginalMachineUDID = method_setImplementation(
            udidMethod, (IMP)ALTProvisionedMachineUDID);
    }
}
