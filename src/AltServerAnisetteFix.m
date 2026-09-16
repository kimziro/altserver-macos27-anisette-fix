#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach/mach_time.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#include <dispatch/dispatch.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

extern char **environ;

#ifndef ALT_EXPECTED_HELPER_SHA256
#error "ALT_EXPECTED_HELPER_SHA256 must be supplied by the build"
#endif

#define ALT_SHA256_HEX_CHAR(c) \
    (((c) >= '0' && (c) <= '9') || ((c) >= 'a' && (c) <= 'f'))
_Static_assert(sizeof(ALT_EXPECTED_HELPER_SHA256) == 65,
               "ALT_EXPECTED_HELPER_SHA256 must be 64 lowercase hex characters");
_Static_assert(ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[0]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[1]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[2]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[3]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[4]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[5]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[6]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[7]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[8]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[9]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[10]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[11]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[12]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[13]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[14]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[15]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[16]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[17]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[18]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[19]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[20]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[21]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[22]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[23]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[24]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[25]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[26]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[27]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[28]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[29]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[30]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[31]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[32]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[33]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[34]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[35]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[36]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[37]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[38]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[39]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[40]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[41]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[42]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[43]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[44]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[45]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[46]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[47]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[48]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[49]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[50]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[51]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[52]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[53]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[54]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[55]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[56]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[57]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[58]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[59]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[60]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[61]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[62]) && \
               ALT_SHA256_HEX_CHAR(ALT_EXPECTED_HELPER_SHA256[63]),
               "ALT_EXPECTED_HELPER_SHA256 must be lowercase hexadecimal");
static const char ALTExpectedHelperSHA256[] = ALT_EXPECTED_HELPER_SHA256;
#undef ALT_SHA256_HEX_CHAR

static const char *const ALTAnisetteDataInitializerEncoding =
    "@96@0:8@16@24@32Q40@48@56@64@72@80@88";
static const char *const ALTAnisetteDataDescriptionSetterEncoding =
    "v24@0:8@16";
static const char *const ALTAOSUtilitiesHeadersEncoding = "@24@0:8@16";

typedef id (*ALTAnisetteDataInitializerIMP)(id,
                                             SEL,
                                             id,
                                             id,
                                             id,
                                             uint64_t,
                                             id,
                                             id,
                                             id,
                                             id,
                                             id,
                                             id);
typedef void (*ALTAnisetteDataDescriptionSetterIMP)(id, SEL, id);
typedef NSDictionary *(*ALTAOSUtilitiesHeadersIMP)(id, SEL, NSString *);

static pthread_mutex_t ALTAnisetteFixLock = PTHREAD_MUTEX_INITIALIZER;
static NSString *ALTAnisetteClientInfo;
static ALTAnisetteDataInitializerIMP ALTOriginalAnisetteDataInitializer;
static ALTAnisetteDataDescriptionSetterIMP ALTOriginalAnisetteDataDescriptionSetter;
static ALTAOSUtilitiesHeadersIMP ALTOriginalAOSUtilitiesHeaders;
static BOOL ALTAnisetteDataHooksInstalled;
static BOOL ALTAnisetteInitializerHookInstalled;
static BOOL ALTAnisetteSetterHookInstalled;
static BOOL ALTAnisetteDataHookRetryScheduled;
static BOOL ALTAnisetteUtilitiesHookInstalled;
static NSUInteger ALTAnisetteHookRetryCount;

static const NSUInteger ALTAnisetteHookRetryLimit = 3;
static const NSTimeInterval ALTAnisetteHelperTimeout = 15.0;
static pthread_mutex_t ALTAnisetteHelperLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t ALTAnisetteHelperCondition = PTHREAD_COND_INITIALIZER;
static BOOL ALTAnisetteHelperInFlight;
static NSUInteger ALTAnisetteHelperGeneration;
static NSDictionary *ALTAnisetteHelperResult;
static BOOL ALTAnisetteHelperResultAvailable;
static NSDate *ALTAnisetteHelperResultDate;
static const NSTimeInterval ALTAnisetteHelperCoalesceWindow = 0.25;
static const NSUInteger ALTAnisetteHelperStdoutLimit = 1024 * 1024;
static const NSUInteger ALTAnisetteHelperStderrLimit = 1024 * 1024;
static const NSUInteger ALTAnisetteHelperTotalOutputLimit = 2 * 1024 * 1024;

static void ALTStoreClientInfo(NSString *clientInfo)
{
    if (![clientInfo isKindOfClass:[NSString class]] ||
        [clientInfo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0)
    {
        return;
    }

    pthread_mutex_lock(&ALTAnisetteFixLock);
    ALTAnisetteClientInfo = [clientInfo copy];
    pthread_mutex_unlock(&ALTAnisetteFixLock);
}

static NSString *ALTCurrentClientInfo(void)
{
    pthread_mutex_lock(&ALTAnisetteFixLock);
    NSString *clientInfo = [ALTAnisetteClientInfo copy];
    pthread_mutex_unlock(&ALTAnisetteFixLock);
    return clientInfo;
}

static BOOL ALTNonemptyString(id value)
{
    if (![value isKindOfClass:[NSString class]])
    {
        return NO;
    }

    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
}

static id ALTHeaderValue(NSDictionary *headers, NSString *name)
{
    if (![headers isKindOfClass:[NSDictionary class]] || name.length == 0)
    {
        return nil;
    }

    for (id key in headers)
    {
        if ([key isKindOfClass:[NSString class]] &&
            [(NSString *)key caseInsensitiveCompare:name] == NSOrderedSame)
        {
            return headers[key];
        }
    }

    return nil;
}

typedef struct
{
    id value;
    NSUInteger count;
    BOOL invalid;
    BOOL conflict;
} ALTHeaderMatch;

static ALTHeaderMatch ALTMatchHeader(NSDictionary *headers, NSString *name)
{
    ALTHeaderMatch match = { nil, 0, NO, NO };
    if (![headers isKindOfClass:[NSDictionary class]] || name.length == 0)
    {
        return match;
    }

    for (id key in headers)
    {
        if (![key isKindOfClass:[NSString class]] ||
            [(NSString *)key caseInsensitiveCompare:name] != NSOrderedSame)
        {
            continue;
        }

        id value = headers[key];
        match.count += 1;
        if (!ALTNonemptyString(value))
        {
            match.invalid = YES;
            continue;
        }

        if (match.value == nil)
        {
            match.value = value;
        }
        else if (![match.value isEqual:value])
        {
            match.conflict = YES;
        }
    }

    return match;
}

static BOOL ALTHeaderMatchValid(ALTHeaderMatch match)
{
    return match.count > 0 && !match.invalid && !match.conflict && match.value != nil;
}

static BOOL ALTHeaderPairValid(ALTHeaderMatch machineID, ALTHeaderMatch oneTimePassword)
{
    return ALTHeaderMatchValid(machineID) && ALTHeaderMatchValid(oneTimePassword);
}

static BOOL ALTStrictHeaderValue(id value)
{
    if (![value isKindOfClass:[NSString class]])
    {
        return NO;
    }

    NSString *string = (NSString *)value;
    if (string.length == 0)
    {
        return NO;
    }

    return [string rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location == NSNotFound;
}

static ALTHeaderMatch ALTMatchHeaderStrict(NSDictionary *headers, NSString *name)
{
    ALTHeaderMatch match = { nil, 0, NO, NO };
    if (![headers isKindOfClass:[NSDictionary class]] || name.length == 0)
    {
        return match;
    }

    for (id key in headers)
    {
        if (![key isKindOfClass:[NSString class]] ||
            [(NSString *)key caseInsensitiveCompare:name] != NSOrderedSame)
        {
            continue;
        }

        id value = headers[key];
        match.count += 1;
        if (!ALTStrictHeaderValue(value))
        {
            match.invalid = YES;
            continue;
        }

        if (match.value == nil)
        {
            match.value = value;
        }
        else if ([match.value isEqual:value])
        {
            // A case-variant duplicate is ambiguous even when its value agrees.
            match.invalid = YES;
        }
        else
        {
            match.conflict = YES;
        }
    }

    return match;
}

static void ALTRemoveHeaderAliases(NSMutableDictionary *headers, NSString *name)
{
    NSArray *keys = [headers.allKeys copy];
    for (id key in keys)
    {
        if ([key isKindOfClass:[NSString class]] &&
            [(NSString *)key caseInsensitiveCompare:name] == NSOrderedSame)
        {
            [headers removeObjectForKey:key];
        }
    }
}

static void ALTSetNormalizedHeader(NSMutableDictionary *headers, NSString *name, id value)
{
    if (value == nil)
    {
        return;
    }

    ALTRemoveHeaderAliases(headers, name);
    headers[name] = value;
}

static NSDictionary *ALTNormalizeOfficialHeaders(NSDictionary *response,
                                                  ALTHeaderMatch machineID,
                                                  ALTHeaderMatch oneTimePassword)
{
    if (![response isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    if (!ALTHeaderPairValid(machineID, oneTimePassword))
    {
        return nil;
    }

    NSMutableDictionary *headers = [response mutableCopy];
    if (headers == nil)
    {
        return nil;
    }

    ALTSetNormalizedHeader(headers, @"X-Apple-MD-M", machineID.value);
    ALTSetNormalizedHeader(headers, @"X-Apple-MD", oneTimePassword.value);
    return headers;
}

static NSDictionary *ALTNormalizeAnisetteHeaders(NSDictionary *response,
                                                  ALTHeaderMatch machineID,
                                                  ALTHeaderMatch oneTimePassword)
{
    if (![response isKindOfClass:[NSDictionary class]] ||
        !ALTHeaderPairValid(machineID, oneTimePassword))
    {
        return nil;
    }

    NSMutableDictionary *headers = [response mutableCopy];
    if (headers == nil)
    {
        return nil;
    }

    ALTSetNormalizedHeader(headers, @"X-Apple-MD-M", machineID.value);
    ALTSetNormalizedHeader(headers, @"X-Apple-MD", oneTimePassword.value);
    ALTSetNormalizedHeader(headers, @"X-Apple-I-MD-M", machineID.value);
    ALTSetNormalizedHeader(headers, @"X-Apple-I-MD", oneTimePassword.value);
    return headers;
}

static ALTAOSUtilitiesHeadersIMP ALTCurrentAOSUtilitiesHeadersIMP(void)
{
    pthread_mutex_lock(&ALTAnisetteFixLock);
    ALTAOSUtilitiesHeadersIMP original = ALTOriginalAOSUtilitiesHeaders;
    pthread_mutex_unlock(&ALTAnisetteFixLock);
    return original;
}

static ALTAnisetteDataInitializerIMP ALTCurrentAnisetteDataInitializerIMP(void)
{
    pthread_mutex_lock(&ALTAnisetteFixLock);
    ALTAnisetteDataInitializerIMP original = ALTOriginalAnisetteDataInitializer;
    pthread_mutex_unlock(&ALTAnisetteFixLock);
    return original;
}

static ALTAnisetteDataDescriptionSetterIMP ALTCurrentAnisetteDataDescriptionSetterIMP(void)
{
    pthread_mutex_lock(&ALTAnisetteFixLock);
    ALTAnisetteDataDescriptionSetterIMP original = ALTOriginalAnisetteDataDescriptionSetter;
    pthread_mutex_unlock(&ALTAnisetteFixLock);
    return original;
}

static BOOL ALTShouldReplaceDescription(id deviceDescription)
{
    if (deviceDescription == nil || deviceDescription == [NSNull null])
    {
        return YES;
    }

    if (![deviceDescription isKindOfClass:[NSString class]])
    {
        return NO;
    }

    return [(NSString *)deviceDescription rangeOfString:@"3594.4.19"].location != NSNotFound;
}

static id ALTDescriptionForAnisetteData(id deviceDescription)
{
    NSString *clientInfo = ALTCurrentClientInfo();
    if (clientInfo != nil && ALTShouldReplaceDescription(deviceDescription))
    {
        return clientInfo;
    }

    return deviceDescription;
}

static void ALTInstallAnisetteDataHooks(void);
static void ALTHandleImageAdded(const struct mach_header *header, intptr_t slide);
static void ALTScheduleAnisetteHookRetry(void);

typedef struct
{
    dev_t device;
    ino_t inode;
    uid_t owner;
    gid_t group;
} ALTAnisetteFileIdentity;

typedef struct
{
    ALTAnisetteFileIdentity file;
    ALTAnisetteFileIdentity parent;
} ALTAnisetteHelperSnapshot;

typedef struct
{
    pthread_mutex_t lock;
    NSUInteger stdoutBytes;
    NSUInteger stderrBytes;
    NSUInteger totalBytes;
    BOOL exceeded;
    BOOL terminationRequested;
} ALTAnisetteHelperOutputState;

static BOOL ALTAnisetteFileIdentityEqual(ALTAnisetteFileIdentity first,
                                         ALTAnisetteFileIdentity second)
{
    return first.device == second.device &&
           first.inode == second.inode &&
           first.owner == second.owner &&
           first.group == second.group;
}

static BOOL ALTReadAnisettePathIdentity(const char *path,
                                        BOOL requireDirectory,
                                        ALTAnisetteFileIdentity *identity)
{
    if (path == NULL || identity == NULL)
    {
        return NO;
    }

    struct stat info;
    if (lstat(path, &info) != 0 ||
        S_ISLNK(info.st_mode) ||
        (requireDirectory ? !S_ISDIR(info.st_mode) : !S_ISREG(info.st_mode)))
    {
        return NO;
    }

    identity->device = info.st_dev;
    identity->inode = info.st_ino;
    identity->owner = info.st_uid;
    identity->group = info.st_gid;
    return YES;
}

static BOOL ALTReadAnisetteFDIdentity(int fileDescriptor,
                                      BOOL requireDirectory,
                                      ALTAnisetteFileIdentity *identity,
                                      struct stat *statInfo)
{
    if (fileDescriptor < 0 || identity == NULL)
    {
        return NO;
    }

    struct stat localInfo;
    if (fstat(fileDescriptor, &localInfo) != 0 ||
        (requireDirectory ? !S_ISDIR(localInfo.st_mode) : !S_ISREG(localInfo.st_mode)))
    {
        return NO;
    }

    identity->device = localInfo.st_dev;
    identity->inode = localInfo.st_ino;
    identity->owner = localInfo.st_uid;
    identity->group = localInfo.st_gid;
    if (statInfo != NULL)
    {
        *statInfo = localInfo;
    }
    return YES;
}

static BOOL ALTValidateAnisetteHelperSignature(NSString *path)
{
    if (![path isKindOfClass:[NSString class]] || path.length == 0)
    {
        return NO;
    }

    NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
    if (url == nil)
    {
        return NO;
    }

    SecStaticCodeRef staticCode = NULL;
    OSStatus status = SecStaticCodeCreateWithPath((__bridge CFURLRef)url,
                                                   kSecCSDefaultFlags,
                                                   &staticCode);
    if (status != errSecSuccess || staticCode == NULL)
    {
        if (staticCode != NULL)
        {
            CFRelease(staticCode);
        }
        return NO;
    }

    status = SecStaticCodeCheckValidity(staticCode,
                                        kSecCSStrictValidate | kSecCSCheckAllArchitectures,
                                        NULL);
    CFRelease(staticCode);
    return status == errSecSuccess;
}

static NSURL *ALTAnisetteHelperURL(void)
{
    Dl_info info;
    if (dladdr((const void *)&ALTAnisetteHelperURL, &info) == 0 || info.dli_fname == NULL)
    {
        return nil;
    }

    char canonicalLibraryPath[PATH_MAX];
    if (realpath(info.dli_fname, canonicalLibraryPath) == NULL)
    {
        return nil;
    }

    NSString *libraryPath = [NSString stringWithUTF8String:canonicalLibraryPath];
    if (libraryPath == nil ||
        ![libraryPath.lastPathComponent isEqualToString:@"AltServerAnisetteFix.dylib"])
    {
        return nil;
    }

    NSArray<NSString *> *components = libraryPath.pathComponents;
    if (components.count < 4 ||
        ![components[components.count - 2] isEqualToString:@"Frameworks"] ||
        ![components[components.count - 3] isEqualToString:@"Contents"] ||
        ![components[components.count - 4].pathExtension isEqualToString:@"app"])
    {
        return nil;
    }

    ALTAnisetteFileIdentity libraryIdentity;
    if (!ALTReadAnisettePathIdentity(libraryPath.fileSystemRepresentation,
                                     NO,
                                     &libraryIdentity))
    {
        return nil;
    }

    NSString *frameworksPath = [libraryPath stringByDeletingLastPathComponent];
    NSString *helperPath = [frameworksPath stringByAppendingPathComponent:@"AltServerAnisetteHelper"];
    char canonicalHelperPath[PATH_MAX];
    if (realpath(helperPath.fileSystemRepresentation, canonicalHelperPath) == NULL ||
        strcmp(canonicalHelperPath, helperPath.fileSystemRepresentation) != 0)
    {
        return nil;
    }

    return [NSURL fileURLWithPath:helperPath isDirectory:NO];
}

static BOOL ALTValidateAnisetteHelperFD(int helperFD,
                                        NSString *helperPath,
                                        ALTAnisetteHelperSnapshot *snapshot)
{
    if (helperFD < 0 || ![helperPath isKindOfClass:[NSString class]] ||
        helperPath.length == 0 || snapshot == NULL)
    {
        return NO;
    }

    struct stat fileInfo;
    ALTAnisetteFileIdentity fileIdentity;
    if (!ALTReadAnisetteFDIdentity(helperFD, NO, &fileIdentity, &fileInfo) ||
        (fileInfo.st_mode & 07777) != 0755 ||
        (fileInfo.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) == 0)
    {
        return NO;
    }

    NSString *parentPath = [helperPath stringByDeletingLastPathComponent];
    char canonicalParentPath[PATH_MAX];
    if (realpath(parentPath.fileSystemRepresentation, canonicalParentPath) == NULL ||
        strcmp(canonicalParentPath, parentPath.fileSystemRepresentation) != 0)
    {
        return NO;
    }

    ALTAnisetteFileIdentity parentIdentity;
    struct stat parentInfo;
    if (!ALTReadAnisettePathIdentity(parentPath.fileSystemRepresentation,
                                     YES,
                                     &parentIdentity) ||
        lstat(parentPath.fileSystemRepresentation, &parentInfo) != 0 ||
        (parentInfo.st_mode & (S_IWGRP | S_IWOTH)) != 0 ||
        fileIdentity.owner != parentIdentity.owner ||
        fileIdentity.group != parentIdentity.group)
    {
        return NO;
    }

    snapshot->file = fileIdentity;
    snapshot->parent = parentIdentity;
    return YES;
}

static BOOL ALTExpectedHelperDigest(const unsigned char digest[CC_SHA256_DIGEST_LENGTH])
{
    static const char hex[] = "0123456789abcdef";
    char actual[(CC_SHA256_DIGEST_LENGTH * 2) + 1];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++)
    {
        actual[index * 2] = hex[(digest[index] >> 4) & 0x0f];
        actual[index * 2 + 1] = hex[digest[index] & 0x0f];
    }
    actual[sizeof(actual) - 1] = '\0';
    return memcmp(actual, ALTExpectedHelperSHA256, sizeof(actual) - 1) == 0;
}

static BOOL ALTHashHelperFD(int helperFD,
                            unsigned char digest[CC_SHA256_DIGEST_LENGTH])
{
    if (helperFD < 0 || digest == NULL)
    {
        return NO;
    }

    CC_SHA256_CTX context;
    if (CC_SHA256_Init(&context) != 1)
    {
        return NO;
    }

    unsigned char buffer[64 * 1024];
    off_t offset = 0;
    while (YES)
    {
        ssize_t count = pread(helperFD, buffer, sizeof(buffer), offset);
        if (count < 0)
        {
            if (errno == EINTR)
            {
                continue;
            }
            return NO;
        }
        if (count == 0)
        {
            break;
        }
        if (CC_SHA256_Update(&context, buffer, (CC_LONG)count) != 1)
        {
            return NO;
        }
        offset += count;
    }

    return CC_SHA256_Final(digest, &context) == 1;
}

static BOOL ALTWriteAll(int fileDescriptor, const unsigned char *bytes, size_t length)
{
    size_t offset = 0;
    while (offset < length)
    {
        ssize_t written = write(fileDescriptor, bytes + offset, length - offset);
        if (written < 0)
        {
            if (errno == EINTR)
            {
                continue;
            }
            return NO;
        }
        if (written == 0)
        {
            return NO;
        }
        offset += (size_t)written;
    }
    return YES;
}

static BOOL ALTCopyAndHashHelperFD(int sourceFD,
                                   int destinationFD,
                                   unsigned char digest[CC_SHA256_DIGEST_LENGTH])
{
    if (sourceFD < 0 || destinationFD < 0 || digest == NULL ||
        ftruncate(destinationFD, 0) != 0 || lseek(destinationFD, 0, SEEK_SET) < 0)
    {
        return NO;
    }

    CC_SHA256_CTX context;
    if (CC_SHA256_Init(&context) != 1)
    {
        return NO;
    }

    unsigned char buffer[64 * 1024];
    off_t offset = 0;
    while (YES)
    {
        ssize_t count = pread(sourceFD, buffer, sizeof(buffer), offset);
        if (count < 0)
        {
            if (errno == EINTR)
            {
                continue;
            }
            return NO;
        }
        if (count == 0)
        {
            break;
        }
        if (CC_SHA256_Update(&context, buffer, (CC_LONG)count) != 1 ||
            !ALTWriteAll(destinationFD, buffer, (size_t)count))
        {
            return NO;
        }
        offset += count;
    }

    return CC_SHA256_Final(digest, &context) == 1 && fsync(destinationFD) == 0;
}

static void ALTCleanupPrivateHelper(char *directoryPath,
                                    char *helperPath,
                                    int directoryFD,
                                    int helperFD)
{
    ALTAnisetteFileIdentity helperIdentity;
    BOOL helperPathMatches = NO;
    if (helperFD >= 0 &&
        ALTReadAnisetteFDIdentity(helperFD, NO, &helperIdentity, NULL) &&
        helperPath != NULL)
    {
        ALTAnisetteFileIdentity pathIdentity;
        helperPathMatches = ALTReadAnisettePathIdentity(helperPath, NO, &pathIdentity) &&
                            ALTAnisetteFileIdentityEqual(helperIdentity, pathIdentity);
    }
    if (helperFD >= 0)
    {
        (void)fchflags(helperFD, 0);
        close(helperFD);
    }
    if (helperPathMatches)
    {
        (void)unlink(helperPath);
    }
    if (directoryFD >= 0)
    {
        (void)fchflags(directoryFD, 0);
        close(directoryFD);
    }
    if (directoryPath != NULL)
    {
        (void)rmdir(directoryPath);
    }
}

static BOOL ALTPreparePrivateHelperCopy(int sourceFD,
                                        char *directoryPath,
                                        size_t directoryCapacity,
                                        char *helperPath,
                                        size_t helperCapacity,
                                        int *directoryFDOut,
                                        int *helperFDOut)
{
    if (sourceFD < 0 || directoryPath == NULL || helperPath == NULL ||
        directoryFDOut == NULL || helperFDOut == NULL)
    {
        return NO;
    }
    *directoryFDOut = -1;
    *helperFDOut = -1;

    NSString *temporaryDirectory = NSTemporaryDirectory();
    const char *temporaryPath = temporaryDirectory.fileSystemRepresentation;
    if (temporaryPath == NULL ||
        snprintf(directoryPath,
                 directoryCapacity,
                 "%s/.altserver-anisette-helper.XXXXXX",
                 temporaryPath) < 0 ||
        strlen(directoryPath) >= directoryCapacity ||
        mkdtemp(directoryPath) == NULL)
    {
        return NO;
    }

    // NSTemporaryDirectory() returns the non-canonical /var/... path, and
    // /var is a standard, root-owned, immutable symlink to /private/var on
    // every stock macOS install. Resolving it here (after we already own the
    // freshly created directory) is safe and lets O_NOFOLLOW_ANY reject only
    // symlinks an attacker could actually control; without this the open
    // below fails ELOOP on every stock install, not just macOS 27.
    char canonicalDirectoryPath[PATH_MAX];
    if (realpath(directoryPath, canonicalDirectoryPath) == NULL ||
        strlen(canonicalDirectoryPath) >= directoryCapacity)
    {
        (void)rmdir(directoryPath);
        return NO;
    }
    strlcpy(directoryPath, canonicalDirectoryPath, directoryCapacity);

    int directoryFD = open(directoryPath,
                            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY);
    if (directoryFD < 0 ||
        snprintf(helperPath,
                 helperCapacity,
                 "%s/AltServerAnisetteHelper",
                 directoryPath) < 0 ||
        strlen(helperPath) >= helperCapacity)
    {
        if (directoryFD >= 0)
        {
            close(directoryFD);
        }
        (void)rmdir(directoryPath);
        return NO;
    }

    // Darwin 27 exposes no fexecve/execveat. Bind the validated bytes to an
    // owner-private file and directory before Security validation and exec;
    // UF_IMMUTABLE is required so ordinary same-UID writes/renames fail.
    int helperFD = open(helperPath,
                        O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC | O_NOFOLLOW |
                            O_UNIQUE | O_EXLOCK,
                        0700);
    if (helperFD < 0)
    {
        close(directoryFD);
        (void)rmdir(directoryPath);
        return NO;
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    if (!ALTCopyAndHashHelperFD(sourceFD, helperFD, digest) ||
        !ALTExpectedHelperDigest(digest) ||
        fchmod(helperFD, 0755) != 0 ||
        fchflags(helperFD, UF_IMMUTABLE) != 0 ||
        fchflags(directoryFD, UF_IMMUTABLE) != 0)
    {
        ALTCleanupPrivateHelper(directoryPath, helperPath, directoryFD, helperFD);
        return NO;
    }

    ALTAnisetteFileIdentity pinnedIdentity;
    ALTAnisetteFileIdentity pathIdentity;
    if (!ALTReadAnisetteFDIdentity(helperFD, NO, &pinnedIdentity, NULL) ||
        !ALTReadAnisettePathIdentity(helperPath, NO, &pathIdentity) ||
        !ALTAnisetteFileIdentityEqual(pinnedIdentity, pathIdentity) ||
        !ALTValidateAnisetteHelperSignature([NSString stringWithUTF8String:helperPath]) ||
        !ALTHashHelperFD(helperFD, digest) ||
        !ALTExpectedHelperDigest(digest))
    {
        ALTCleanupPrivateHelper(directoryPath, helperPath, directoryFD, helperFD);
        return NO;
    }

    struct stat helperInfo;
    struct stat directoryInfo;
    ALTAnisetteFileIdentity finalIdentity;
    if (fstat(helperFD, &helperInfo) != 0 ||
        fstat(directoryFD, &directoryInfo) != 0 ||
        !ALTReadAnisetteFDIdentity(helperFD, NO, &finalIdentity, NULL) ||
        !ALTAnisetteFileIdentityEqual(pinnedIdentity, finalIdentity) ||
        (helperInfo.st_flags & UF_IMMUTABLE) == 0 ||
        (directoryInfo.st_flags & UF_IMMUTABLE) == 0)
    {
        ALTCleanupPrivateHelper(directoryPath, helperPath, directoryFD, helperFD);
        return NO;
    }

    *directoryFDOut = directoryFD;
    *helperFDOut = helperFD;
    return YES;
}

static BOOL ALTOutputExceeded(ALTAnisetteHelperOutputState *state)
{
    BOOL exceeded = NO;
    pthread_mutex_lock(&state->lock);
    exceeded = state->exceeded;
    pthread_mutex_unlock(&state->lock);
    return exceeded;
}

static BOOL ALTSetCloseOnExec(int fileDescriptor)
{
    int flags = fcntl(fileDescriptor, F_GETFD);
    return flags >= 0 && fcntl(fileDescriptor, F_SETFD, flags | FD_CLOEXEC) == 0;
}

static void ALTDrainHelperDescriptor(int fileDescriptor,
                                     pid_t processIdentifier,
                                     ALTAnisetteHelperOutputState *state,
                                     NSMutableData *outputData,
                                     BOOL isStandardOutput)
{
    unsigned char chunk[4096];
    while (YES)
    {
        ssize_t count = read(fileDescriptor, chunk, sizeof(chunk));
        if (count == 0)
        {
            break;
        }
        if (count < 0)
        {
            if (errno == EINTR)
            {
                continue;
            }
            break;
        }

        NSUInteger acceptedLength = 0;
        BOOL requestTermination = NO;
        pthread_mutex_lock(&state->lock);
        if (!state->exceeded)
        {
            NSUInteger streamBytes = isStandardOutput ? state->stdoutBytes : state->stderrBytes;
            NSUInteger streamLimit = isStandardOutput
                ? ALTAnisetteHelperStdoutLimit
                : ALTAnisetteHelperStderrLimit;
            NSUInteger streamRemaining = streamBytes < streamLimit
                ? streamLimit - streamBytes
                : 0;
            NSUInteger totalRemaining = state->totalBytes < ALTAnisetteHelperTotalOutputLimit
                ? ALTAnisetteHelperTotalOutputLimit - state->totalBytes
                : 0;
            acceptedLength = MIN((NSUInteger)count, MIN(streamRemaining, totalRemaining));
            if (isStandardOutput)
            {
                state->stdoutBytes += acceptedLength;
            }
            else
            {
                state->stderrBytes += acceptedLength;
            }
            state->totalBytes += acceptedLength;
            if (acceptedLength < (NSUInteger)count)
            {
                state->exceeded = YES;
                if (!state->terminationRequested)
                {
                    state->terminationRequested = YES;
                    requestTermination = YES;
                }
            }
        }
        pthread_mutex_unlock(&state->lock);

        if (acceptedLength > 0 && outputData != nil)
        {
            [outputData appendBytes:chunk length:acceptedLength];
        }
        if (requestTermination)
        {
            (void)kill(processIdentifier, SIGTERM);
        }
    }
    close(fileDescriptor);
}

static uint64_t ALTMonotonicNanos(void)
{
    mach_timebase_info_data_t timebase = { 0, 0 };
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.denom == 0)
    {
        return 0;
    }
    uint64_t ticks = mach_continuous_time();
    __uint128_t nanos = (__uint128_t)ticks * timebase.numer;
    nanos /= timebase.denom;
    return nanos > UINT64_MAX ? UINT64_MAX : (uint64_t)nanos;
}

static BOOL ALTWaitForHelperProcess(pid_t processIdentifier,
                                    uint64_t deadline,
                                    ALTAnisetteHelperOutputState *state,
                                    int *waitStatus)
{
    BOOL reaped = NO;
    while (!reaped)
    {
        pid_t result = waitpid(processIdentifier, waitStatus, WNOHANG);
        if (result == processIdentifier)
        {
            reaped = YES;
            break;
        }
        if (result < 0)
        {
            if (errno == EINTR)
            {
                continue;
            }
            return NO;
        }
        if (ALTOutputExceeded(state) || ALTMonotonicNanos() >= deadline)
        {
            break;
        }
        usleep(10000);
    }

    if (reaped)
    {
        return YES;
    }

    (void)kill(processIdentifier, SIGTERM);
    uint64_t graceDeadline = ALTMonotonicNanos() + 250000000ULL;
    while (ALTMonotonicNanos() < graceDeadline)
    {
        pid_t result = waitpid(processIdentifier, waitStatus, WNOHANG);
        if (result == processIdentifier)
        {
            return NO;
        }
        if (result < 0 && errno != EINTR)
        {
            return NO;
        }
        usleep(10000);
    }

    (void)kill(processIdentifier, SIGKILL);
    while (waitpid(processIdentifier, waitStatus, 0) < 0)
    {
        if (errno != EINTR)
        {
            return NO;
        }
    }
    return NO;
}

// The parent process launches with DYLD_INSERT_LIBRARIES set to an
// @executable_path-relative path to this very dylib. execve() with the
// inherited environ propagates that variable to the relocated helper copy,
// whose @executable_path no longer has a sibling Frameworks/ directory;
// dyld then hard-aborts instead of silently skipping the missing insert.
// Strip DYLD_* variables so the helper launches with a clean environment.
static char **ALTChildEnvironmentWithoutDYLD(void)
{
    NSUInteger count = 0;
    for (char **entry = environ; *entry != NULL; entry++)
    {
        count += 1;
    }

    char **filtered = calloc(count + 1, sizeof(char *));
    if (filtered == NULL)
    {
        return NULL;
    }

    NSUInteger writeIndex = 0;
    for (char **entry = environ; *entry != NULL; entry++)
    {
        if (strncmp(*entry, "DYLD_", 5) != 0)
        {
            filtered[writeIndex++] = *entry;
        }
    }
    filtered[writeIndex] = NULL;
    return filtered;
}

static NSDictionary *ALTRequestRemoteAnisetteHeadersUncoalesced(void)
{
    ALTInstallAnisetteDataHooks();

    NSURL *helperURL = ALTAnisetteHelperURL();
    NSString *helperPathObject = helperURL.path;
    const char *helperPath = helperPathObject.fileSystemRepresentation;
    if (helperURL == nil || helperPath == NULL || helperPathObject.length == 0)
    {
        return nil;
    }

    int sourceFD = open(helperPath,
                        O_RDONLY | O_CLOEXEC | O_NOFOLLOW_ANY | O_UNIQUE);
    if (sourceFD < 0)
    {
        return nil;
    }

    ALTAnisetteHelperSnapshot sourceSnapshot;
    if (!ALTValidateAnisetteHelperFD(sourceFD, helperPathObject, &sourceSnapshot))
    {
        close(sourceFD);
        return nil;
    }

    char privateDirectoryPath[PATH_MAX] = { 0 };
    char privateHelperPath[PATH_MAX] = { 0 };
    int privateDirectoryFD = -1;
    int privateHelperFD = -1;
    if (!ALTPreparePrivateHelperCopy(sourceFD,
                                     privateDirectoryPath,
                                     sizeof(privateDirectoryPath),
                                     privateHelperPath,
                                     sizeof(privateHelperPath),
                                     &privateDirectoryFD,
                                     &privateHelperFD))
    {
        close(sourceFD);
        return nil;
    }
    close(sourceFD);

    NSMutableData *outputData = [NSMutableData data];
    if (outputData == nil)
    {
        ALTCleanupPrivateHelper(privateDirectoryPath,
                                privateHelperPath,
                                privateDirectoryFD,
                                privateHelperFD);
        return nil;
    }
    ALTAnisetteHelperOutputState *outputState = calloc(1, sizeof(*outputState));
    if (outputState == NULL || pthread_mutex_init(&outputState->lock, NULL) != 0)
    {
        free(outputState);
        ALTCleanupPrivateHelper(privateDirectoryPath,
                                privateHelperPath,
                                privateDirectoryFD,
                                privateHelperFD);
        return nil;
    }

    int outputPipe[2] = { -1, -1 };
    int errorPipe[2] = { -1, -1 };
    if (pipe(outputPipe) != 0 || pipe(errorPipe) != 0 ||
        !ALTSetCloseOnExec(outputPipe[0]) || !ALTSetCloseOnExec(outputPipe[1]) ||
        !ALTSetCloseOnExec(errorPipe[0]) || !ALTSetCloseOnExec(errorPipe[1]))
    {
        if (outputPipe[0] >= 0) close(outputPipe[0]);
        if (outputPipe[1] >= 0) close(outputPipe[1]);
        if (errorPipe[0] >= 0) close(errorPipe[0]);
        if (errorPipe[1] >= 0) close(errorPipe[1]);
        pthread_mutex_destroy(&outputState->lock);
        free(outputState);
        ALTCleanupPrivateHelper(privateDirectoryPath,
                                privateHelperPath,
                                privateDirectoryFD,
                                privateHelperFD);
        return nil;
    }

    dispatch_group_t drainGroup = dispatch_group_create();
    dispatch_queue_t drainQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    if (drainGroup == nil)
    {
        close(outputPipe[0]);
        close(outputPipe[1]);
        close(errorPipe[0]);
        close(errorPipe[1]);
        pthread_mutex_destroy(&outputState->lock);
        free(outputState);
        ALTCleanupPrivateHelper(privateDirectoryPath,
                                privateHelperPath,
                                privateDirectoryFD,
                                privateHelperFD);
        return nil;
    }

    char **childEnviron = ALTChildEnvironmentWithoutDYLD();
    if (childEnviron == NULL)
    {
        close(outputPipe[0]);
        close(outputPipe[1]);
        close(errorPipe[0]);
        close(errorPipe[1]);
        pthread_mutex_destroy(&outputState->lock);
        free(outputState);
        ALTCleanupPrivateHelper(privateDirectoryPath,
                                privateHelperPath,
                                privateDirectoryFD,
                                privateHelperFD);
        return nil;
    }

    pid_t childPID = fork();
    if (childPID < 0)
    {
        free(childEnviron);
        close(outputPipe[0]);
        close(outputPipe[1]);
        close(errorPipe[0]);
        close(errorPipe[1]);
        pthread_mutex_destroy(&outputState->lock);
        free(outputState);
        ALTCleanupPrivateHelper(privateDirectoryPath,
                                privateHelperPath,
                                privateDirectoryFD,
                                privateHelperFD);
        return nil;
    }

    if (childPID == 0)
    {
        if (dup2(outputPipe[1], STDOUT_FILENO) < 0 ||
            dup2(errorPipe[1], STDERR_FILENO) < 0)
        {
            _exit(126);
        }
        if (outputPipe[0] > STDERR_FILENO) close(outputPipe[0]);
        if (outputPipe[1] > STDERR_FILENO) close(outputPipe[1]);
        if (errorPipe[0] > STDERR_FILENO) close(errorPipe[0]);
        if (errorPipe[1] > STDERR_FILENO) close(errorPipe[1]);
        if (privateDirectoryFD > STDERR_FILENO) close(privateDirectoryFD);
        if (privateHelperFD > STDERR_FILENO) close(privateHelperFD);
        char *arguments[] = { (char *)"AltServerAnisetteHelper", NULL };
        execve(privateHelperPath, arguments, childEnviron);
        _exit(127);
    }

    free(childEnviron);
    close(outputPipe[1]);
    outputPipe[1] = -1;
    close(errorPipe[1]);
    errorPipe[1] = -1;

    int outputReadFD = outputPipe[0];
    int errorReadFD = errorPipe[0];
    dispatch_group_async(drainGroup, drainQueue, ^{
        ALTDrainHelperDescriptor(outputReadFD,
                                 childPID,
                                 outputState,
                                 outputData,
                                 YES);
    });
    dispatch_group_async(drainGroup, drainQueue, ^{
        ALTDrainHelperDescriptor(errorReadFD,
                                 childPID,
                                 outputState,
                                 nil,
                                 NO);
    });

    uint64_t now = ALTMonotonicNanos();
    uint64_t deadline = now > UINT64_MAX - (uint64_t)(ALTAnisetteHelperTimeout * 1000000000.0)
        ? UINT64_MAX
        : now + (uint64_t)(ALTAnisetteHelperTimeout * 1000000000.0);
    int waitStatus = 0;
    BOOL completed = ALTWaitForHelperProcess(childPID,
                                             deadline,
                                             outputState,
                                             &waitStatus);
    long drainResult = dispatch_group_wait(drainGroup,
                                            dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
    BOOL drainsComplete = drainResult == 0;
    if (drainResult != 0)
    {
        close(outputPipe[0]);
        outputPipe[0] = -1;
        close(errorPipe[0]);
        errorPipe[0] = -1;
        drainsComplete = dispatch_group_wait(drainGroup,
                                              dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) == 0;
    }

    if (!drainsComplete)
    {
        dispatch_group_notify(drainGroup, drainQueue, ^{
            pthread_mutex_destroy(&outputState->lock);
            free(outputState);
        });
        ALTCleanupPrivateHelper(privateDirectoryPath,
                                privateHelperPath,
                                privateDirectoryFD,
                                privateHelperFD);
        return nil;
    }

    pthread_mutex_lock(&outputState->lock);
    BOOL outputExceeded = outputState->exceeded;
    pthread_mutex_unlock(&outputState->lock);
    pthread_mutex_destroy(&outputState->lock);
    free(outputState);

    ALTCleanupPrivateHelper(privateDirectoryPath,
                            privateHelperPath,
                            privateDirectoryFD,
                            privateHelperFD);

    if (!completed || outputExceeded || !drainsComplete ||
        !WIFEXITED(waitStatus) || WEXITSTATUS(waitStatus) != 0)
    {
        return nil;
    }

    NSData *data = [outputData copy];
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![response isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    ALTHeaderMatch officialMachineID = ALTMatchHeaderStrict(response, @"X-Apple-MD-M");
    ALTHeaderMatch officialOneTimePassword = ALTMatchHeaderStrict(response, @"X-Apple-MD");
    ALTHeaderMatch prefixedMachineID = ALTMatchHeaderStrict(response, @"X-Apple-I-MD-M");
    ALTHeaderMatch prefixedOneTimePassword = ALTMatchHeaderStrict(response, @"X-Apple-I-MD");
    BOOL officialPairValid = ALTHeaderPairValid(officialMachineID, officialOneTimePassword);
    BOOL prefixedPairValid = ALTHeaderPairValid(prefixedMachineID, prefixedOneTimePassword);
    if (!officialPairValid && !prefixedPairValid)
    {
        return nil;
    }

    NSDictionary *headers = officialPairValid
        ? ALTNormalizeAnisetteHeaders(response, officialMachineID, officialOneTimePassword)
        : ALTNormalizeAnisetteHeaders(response, prefixedMachineID, prefixedOneTimePassword);
    if (headers == nil)
    {
        return nil;
    }

    ALTStoreClientInfo(ALTHeaderValue(response, @"X-Mme-Client-Info"));
    ALTInstallAnisetteDataHooks();
    return headers;
}

static NSDictionary *ALTRequestRemoteAnisetteHeadersFromHelper(void)
{
    ALTInstallAnisetteDataHooks();

    pthread_mutex_lock(&ALTAnisetteHelperLock);
    if (!ALTAnisetteHelperInFlight && ALTAnisetteHelperResultAvailable &&
        ALTAnisetteHelperResultDate != nil &&
        [[NSDate date] timeIntervalSinceDate:ALTAnisetteHelperResultDate] < ALTAnisetteHelperCoalesceWindow)
    {
        NSDictionary *result = [ALTAnisetteHelperResult copy];
        pthread_mutex_unlock(&ALTAnisetteHelperLock);
        return result;
    }

    NSUInteger observedGeneration = ALTAnisetteHelperGeneration;
    while (ALTAnisetteHelperInFlight)
    {
        pthread_cond_wait(&ALTAnisetteHelperCondition, &ALTAnisetteHelperLock);
        if (!ALTAnisetteHelperInFlight &&
            ALTAnisetteHelperResultAvailable &&
            ALTAnisetteHelperGeneration != observedGeneration)
        {
            NSDictionary *result = [ALTAnisetteHelperResult copy];
            pthread_mutex_unlock(&ALTAnisetteHelperLock);
            return result;
        }
    }

    ALTAnisetteHelperInFlight = YES;
    ALTAnisetteHelperResultAvailable = NO;
    ALTAnisetteHelperResultDate = nil;
    pthread_mutex_unlock(&ALTAnisetteHelperLock);

    NSDictionary *result = nil;
    @try
    {
        result = ALTRequestRemoteAnisetteHeadersUncoalesced();
    }
    @catch (NSException *exception)
    {
        (void)exception;
    }

    pthread_mutex_lock(&ALTAnisetteHelperLock);
    ALTAnisetteHelperResult = [result copy];
    ALTAnisetteHelperResultDate = [NSDate date];
    ALTAnisetteHelperResultAvailable = YES;
    ALTAnisetteHelperGeneration += 1;
    ALTAnisetteHelperInFlight = NO;
    pthread_cond_broadcast(&ALTAnisetteHelperCondition);
    pthread_mutex_unlock(&ALTAnisetteHelperLock);
    return result;
}

static NSDictionary *ALTRequestRemoteAnisetteHeaders(id self, SEL selector, NSString *dsid)
{
    ALTAOSUtilitiesHeadersIMP original = ALTCurrentAOSUtilitiesHeadersIMP();
    id originalResponse = nil;
    NSDictionary *originalHeaders = nil;

    if (original != NULL && original != (ALTAOSUtilitiesHeadersIMP)ALTRequestRemoteAnisetteHeaders)
    {
        @try
        {
            id response = original(self, selector, dsid);
            originalResponse = response;
            originalHeaders = [response isKindOfClass:[NSDictionary class]] ? response : nil;
        }
        @catch (NSException *exception)
        {
            (void)exception;
        }
    }

    ALTInstallAnisetteDataHooks();

    ALTHeaderMatch officialMachineID = ALTMatchHeader(originalHeaders, @"X-Apple-MD-M");
    ALTHeaderMatch officialOneTimePassword = ALTMatchHeader(originalHeaders, @"X-Apple-MD");
    ALTHeaderMatch prefixedMachineID = ALTMatchHeader(originalHeaders, @"X-Apple-I-MD-M");
    ALTHeaderMatch prefixedOneTimePassword = ALTMatchHeader(originalHeaders, @"X-Apple-I-MD");

    if (ALTHeaderPairValid(officialMachineID, officialOneTimePassword))
    {
        id exactMachineID = [originalHeaders objectForKey:@"X-Apple-MD-M"];
        id exactOneTimePassword = [originalHeaders objectForKey:@"X-Apple-MD"];
        if (ALTNonemptyString(exactMachineID) && ALTNonemptyString(exactOneTimePassword))
        {
            ALTStoreClientInfo(ALTHeaderValue(originalHeaders, @"X-Mme-Client-Info"));
            return originalResponse;
        }

        NSDictionary *normalizedResponse = ALTNormalizeOfficialHeaders(originalHeaders,
                                                                        officialMachineID,
                                                                        officialOneTimePassword);
        if (normalizedResponse != nil)
        {
            ALTStoreClientInfo(ALTHeaderValue(originalHeaders, @"X-Mme-Client-Info"));
            return normalizedResponse;
        }
    }

    if (ALTHeaderPairValid(prefixedMachineID, prefixedOneTimePassword))
    {
        NSDictionary *normalizedResponse = ALTNormalizeAnisetteHeaders(originalHeaders,
                                                                        prefixedMachineID,
                                                                        prefixedOneTimePassword);
        if (normalizedResponse != nil)
        {
            ALTStoreClientInfo(ALTHeaderValue(originalHeaders, @"X-Mme-Client-Info"));
            return normalizedResponse;
        }
    }

    NSDictionary *fallbackResponse = nil;
    @try
    {
        fallbackResponse = ALTRequestRemoteAnisetteHeadersFromHelper();
    }
    @catch (NSException *exception)
    {
        (void)exception;
    }
    if (fallbackResponse != nil)
    {
        return fallbackResponse;
    }

    // Leave an unavailable or partial official response untouched so the
    // caller can report the same missing-value error as the original path.
    return originalResponse;
}

static id ALTAnisetteDataInitWithDescriptionHook(id self,
                                                 SEL selector,
                                                 id machineID,
                                                 id oneTimePassword,
                                                 id localUserID,
                                                 uint64_t routingInfo,
                                                 id deviceUniqueIdentifier,
                                                 id deviceSerialNumber,
                                                 id deviceDescription,
                                                 id date,
                                                 id locale,
                                                 id timeZone)
{
    ALTAnisetteDataInitializerIMP original = ALTCurrentAnisetteDataInitializerIMP();
    if (original == NULL)
    {
        return nil;
    }

    id description = ALTDescriptionForAnisetteData(deviceDescription);
    return original(self,
                    selector,
                    machineID,
                    oneTimePassword,
                    localUserID,
                    routingInfo,
                    deviceUniqueIdentifier,
                    deviceSerialNumber,
                    description,
                    date,
                    locale,
                    timeZone);
}

static void ALTAnisetteDataSetDescriptionHook(id self, SEL selector, id deviceDescription)
{
    ALTAnisetteDataDescriptionSetterIMP original = ALTCurrentAnisetteDataDescriptionSetterIMP();
    if (original == NULL)
    {
        return;
    }

    id description = ALTDescriptionForAnisetteData(deviceDescription);
    original(self, selector, description);
}

static void ALTInstallAnisetteDataHooks(void)
{
    pthread_mutex_lock(&ALTAnisetteFixLock);

    Class anisetteDataClass = NSClassFromString(@"ALTAnisetteData");
    SEL initializerSelector = @selector(initWithMachineID:oneTimePassword:localUserID:routingInfo:deviceUniqueIdentifier:deviceSerialNumber:deviceDescription:date:locale:timeZone:);
    Method initializer = anisetteDataClass ? class_getInstanceMethod(anisetteDataClass, initializerSelector) : NULL;
    const char *initializerEncoding = initializer ? method_getTypeEncoding(initializer) : NULL;

    if (initializer != NULL && initializerEncoding != NULL &&
        strcmp(initializerEncoding, ALTAnisetteDataInitializerEncoding) == 0 &&
        !ALTAnisetteInitializerHookInstalled)
    {
        IMP implementation = method_getImplementation(initializer);
        if (implementation == (IMP)ALTAnisetteDataInitWithDescriptionHook)
        {
            if (ALTOriginalAnisetteDataInitializer != NULL)
            {
                ALTAnisetteInitializerHookInstalled = YES;
            }
        }
        else if (implementation != NULL)
        {
            ALTOriginalAnisetteDataInitializer = (ALTAnisetteDataInitializerIMP)implementation;
            method_setImplementation(initializer, (IMP)ALTAnisetteDataInitWithDescriptionHook);
            ALTAnisetteInitializerHookInstalled = YES;
        }
    }

    SEL setterSelector = @selector(setDeviceDescription:);
    Method setter = class_getInstanceMethod(anisetteDataClass, setterSelector);
    const char *setterEncoding = setter ? method_getTypeEncoding(setter) : NULL;
    if (setter != NULL && setterEncoding != NULL &&
        strcmp(setterEncoding, ALTAnisetteDataDescriptionSetterEncoding) == 0 &&
        !ALTAnisetteSetterHookInstalled)
    {
        IMP implementation = method_getImplementation(setter);
        if (implementation == (IMP)ALTAnisetteDataSetDescriptionHook)
        {
            if (ALTOriginalAnisetteDataDescriptionSetter != NULL)
            {
                ALTAnisetteSetterHookInstalled = YES;
            }
        }
        else if (implementation != NULL)
        {
            ALTOriginalAnisetteDataDescriptionSetter = (ALTAnisetteDataDescriptionSetterIMP)implementation;
            method_setImplementation(setter, (IMP)ALTAnisetteDataSetDescriptionHook);
            ALTAnisetteSetterHookInstalled = YES;
        }
    }

    ALTAnisetteDataHooksInstalled = ALTAnisetteInitializerHookInstalled &&
                                    ALTAnisetteSetterHookInstalled;

    pthread_mutex_unlock(&ALTAnisetteFixLock);
}

static void ALTInstallAOSUtilitiesHook(void)
{
    pthread_mutex_lock(&ALTAnisetteFixLock);

    Class utilitiesClass = NSClassFromString(@"AOSUtilities");
    SEL selector = @selector(retrieveOTPHeadersForDSID:);
    Method method = utilitiesClass ? class_getClassMethod(utilitiesClass, selector) : NULL;
    const char *encoding = method ? method_getTypeEncoding(method) : NULL;
    if (method != NULL && encoding != NULL && strcmp(encoding, ALTAOSUtilitiesHeadersEncoding) == 0 && !ALTAnisetteUtilitiesHookInstalled)
    {
        IMP implementation = method_getImplementation(method);
        if (implementation == (IMP)ALTRequestRemoteAnisetteHeaders)
        {
            // Another invocation of this library already installed the hook.
            // Without the saved original, replacing it would recurse forever.
            if (ALTOriginalAOSUtilitiesHeaders == NULL)
            {
                pthread_mutex_unlock(&ALTAnisetteFixLock);
                return;
            }
        }
        else if (implementation != NULL)
        {
            ALTOriginalAOSUtilitiesHeaders = (ALTAOSUtilitiesHeadersIMP)implementation;
            method_setImplementation(method, (IMP)ALTRequestRemoteAnisetteHeaders);
        }
        else
        {
            pthread_mutex_unlock(&ALTAnisetteFixLock);
            return;
        }
        ALTAnisetteUtilitiesHookInstalled = YES;
    }

    pthread_mutex_unlock(&ALTAnisetteFixLock);
}

static void ALTScheduleAnisetteHookRetry(void)
{
    pthread_mutex_lock(&ALTAnisetteFixLock);
    BOOL hooksMissing = !ALTAnisetteDataHooksInstalled || !ALTAnisetteUtilitiesHookInstalled;
    if (!hooksMissing || ALTAnisetteDataHookRetryScheduled || ALTAnisetteHookRetryCount >= ALTAnisetteHookRetryLimit)
    {
        pthread_mutex_unlock(&ALTAnisetteFixLock);
        return;
    }

    ALTAnisetteDataHookRetryScheduled = YES;
    ALTAnisetteHookRetryCount += 1;
    NSUInteger attempt = ALTAnisetteHookRetryCount;
    pthread_mutex_unlock(&ALTAnisetteFixLock);

    uint64_t delayNanoseconds = attempt == 1 ? 0 : (attempt == 2 ? 20 : 100) * NSEC_PER_MSEC;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delayNanoseconds),
                   dispatch_get_main_queue(), ^{
        pthread_mutex_lock(&ALTAnisetteFixLock);
        ALTAnisetteDataHookRetryScheduled = NO;
        pthread_mutex_unlock(&ALTAnisetteFixLock);

        ALTInstallAOSUtilitiesHook();
        ALTInstallAnisetteDataHooks();
        ALTScheduleAnisetteHookRetry();
    });
}

static BOOL ALTIsRelevantImage(const struct mach_header *header)
{
    if (header == NULL)
    {
        return NO;
    }

    uint32_t imageCount = _dyld_image_count();
    for (uint32_t index = 0; index < imageCount; index++)
    {
        if (_dyld_get_image_header(index) != header)
        {
            continue;
        }

        const char *imagePath = _dyld_get_image_name(index);
        if (imagePath == NULL)
        {
            return NO;
        }

        return strstr(imagePath, "AOSKit.framework") != NULL ||
               strstr(imagePath, "AltSign") != NULL ||
               strstr(imagePath, "/AltServer") != NULL;
    }

    return NO;
}

static void ALTHandleImageAdded(const struct mach_header *header, intptr_t slide)
{
    (void)slide;

    if (!ALTIsRelevantImage(header))
    {
        return;
    }

    ALTInstallAOSUtilitiesHook();
    ALTInstallAnisetteDataHooks();
    ALTScheduleAnisetteHookRetry();
}

__attribute__((constructor))
static void ALTInstallAnisetteFix(void)
{
    _dyld_register_func_for_add_image(ALTHandleImageAdded);
    dlopen("/System/Library/PrivateFrameworks/AOSKit.framework/AOSKit", RTLD_NOW);

    ALTInstallAOSUtilitiesHook();
    ALTInstallAnisetteDataHooks();
    ALTScheduleAnisetteHookRetry();
}
