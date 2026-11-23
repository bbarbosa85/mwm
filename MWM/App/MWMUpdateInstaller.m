//
//  MWMUpdateInstaller.m
//  MWM
//
//  Asks GitHub for the latest release and tells the user if it is newer than the running app.
//  MWM isn't notarized, so this is the whole update story: it says a new version exists and
//  sends the user to the download. It can run by itself when MWM opens (the checkForUpdates setting,
//  on by default) or when the user chooses "Check for Updates…" in the menu.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the

#import "MWMUpdateInstaller.h"
#import "MWMLogger.h"
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

NSString *const MWMUpdateInstallerErrorDomain = @"MWMUpdateInstaller";

static NSString *const kDownloadsFolder = @"https://github.com/bbarbosa85/mwm/raw/master/docs/downloads/";

@interface MWMUpdateInstaller () <NSURLSessionDownloadDelegate>
@property (copy, readwrite) NSString *version;
@property (copy, readwrite, nullable) NSString *stagedAppPath;
@property (copy) NSString *workFolder;
@property (strong) NSURLSession *session;
@property (strong) NSURLSessionTask *task;
@property (copy) void (^progress)(double);
@property (copy) void (^completion)(NSError *);
@property (copy) NSString *expectedChecksum;
@property (assign) BOOL cancelled;
@end

@implementation MWMUpdateInstaller

- (instancetype)initWithVersion:(NSString *)version {
  self = [super init];
  if (self) {
    _version = [version copy];
    _baseURL = [NSURL URLWithString:kDownloadsFolder];
    _appPath = [[NSBundle mainBundle] bundlePath];
    _requiresSignature = YES;
  }
  return self;
}

+ (NSError *)errorWithMessage:(NSString *)message {
  return [NSError errorWithDomain:MWMUpdateInstallerErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

#pragma mark - Helpers

+ (BOOL)canReplaceAppAtPath:(NSString *)path {
  NSFileManager *fm = [NSFileManager defaultManager];
  return [fm isWritableFileAtPath:[path stringByDeletingLastPathComponent]] && [fm isWritableFileAtPath:path];
}

+ (NSURL *)zipURLForVersion:(NSString *)version baseURL:(NSURL *)baseURL {
  return [baseURL URLByAppendingPathComponent:[NSString stringWithFormat:@"MWM-%@.zip", version]];
}

+ (NSString *)sha256OfFileAtPath:(NSString *)path {
  NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
  if (file == nil) return nil;
  CC_SHA256_CTX context;
  CC_SHA256_Init(&context);
  for (;;) {
    @autoreleasepool {
      NSData *chunk = [file readDataOfLength:1 << 20];
      if ([chunk length] == 0) break;
      CC_SHA256_Update(&context, [chunk bytes], (CC_LONG)[chunk length]);
    }
  }
  [file closeFile];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256_Final(digest, &context);
  NSMutableString *hex = [NSMutableString string];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
  return hex;
}

+ (NSString *)checksumForFileNamed:(NSString *)name inSums:(NSString *)sums {
  for (NSString *line in [sums componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
    NSArray *parts = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    if ([parts count] == 2 && [parts[1] isEqualToString:name]) return [parts[0] lowercaseString];
  }
  return nil;
}

#pragma mark - Preparing

- (void)finish:(NSError *)error {
  void (^completion)(NSError *) = self.completion;
  self.completion = nil;
  [self.session finishTasksAndInvalidate];
  dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(error); });
}

- (void)prepareWithProgress:(void (^)(double))progress completion:(void (^)(NSError *))completion {
  self.progress = progress;
  self.completion = completion;
  self.cancelled = NO;
  NSString *work = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"MWMUpdate-%@", [[NSUUID UUID] UUIDString]]];
  [[NSFileManager defaultManager] createDirectoryAtPath:work withIntermediateDirectories:YES attributes:nil error:nil];
  self.workFolder = work;
  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
  configuration.timeoutIntervalForRequest = 30;
  self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
  // The checksums first, so a download with nothing to check it against never starts.
  NSURL *sumsURL = [self.baseURL URLByAppendingPathComponent:@"SHA256SUMS.txt"];
  __weak MWMUpdateInstaller *weakSelf = self;
  self.task = [self.session dataTaskWithURL:sumsURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    MWMUpdateInstaller *strongSelf = weakSelf;
    if (strongSelf == nil || strongSelf.cancelled) return;
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 200;
    NSString *sums = data != nil && status == 200 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    NSString *name = [NSString stringWithFormat:@"MWM-%@.zip", strongSelf.version];
    strongSelf.expectedChecksum = sums != nil ? [MWMUpdateInstaller checksumForFileNamed:name inSums:sums] : nil;
    if (strongSelf.expectedChecksum == nil) {
      [strongSelf finish:[MWMUpdateInstaller errorWithMessage:error != nil ? error.localizedDescription : @"MWM couldn't find the checksum for this update, so it won't install it."]];
      return;
    }
    strongSelf.task = [strongSelf.session downloadTaskWithURL:[MWMUpdateInstaller zipURLForVersion:strongSelf.version baseURL:strongSelf.baseURL]];
    [strongSelf.task resume];
  }];
  [self.task resume];
}

- (void)cancel {
  self.cancelled = YES;
  [self.task cancel];
  [self.session invalidateAndCancel];
  self.completion = nil;
  [self discard];
}

- (void)discard {
  if ([self.workFolder length] > 0) [[NSFileManager defaultManager] removeItemAtPath:self.workFolder error:nil];
  self.stagedAppPath = nil;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)written totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
  if (expected > 0 && self.progress) self.progress((double)total / (double)expected);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
  NSInteger status = [downloadTask.response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)downloadTask.response statusCode] : 200;
  if (status != 200) {
    [self finish:[MWMUpdateInstaller errorWithMessage:[NSString stringWithFormat:@"The download wasn't found (status %ld).", (long)status]]];
    return;
  }
  // The file at location goes away when this returns, so it is moved at once.
  NSString *zip = [self.workFolder stringByAppendingPathComponent:@"update.zip"];
  [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:zip error:nil];
  [self finish:[self checkAndUnpack:zip]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
  if (error != nil && !self.cancelled && self.completion != nil && [task isKindOfClass:[NSURLSessionDownloadTask class]]) {
    [self finish:[MWMUpdateInstaller errorWithMessage:error.localizedDescription]];
  }
}

#pragma mark - Checking what arrived

- (NSError *)checkAndUnpack:(NSString *)zip {
  if (![[MWMUpdateInstaller sha256OfFileAtPath:zip] isEqualToString:self.expectedChecksum]) {
    return [MWMUpdateInstaller errorWithMessage:@"The download doesn't match its checksum, so it may be damaged or changed. MWM didn't install it."];
  }
  NSString *unpacked = [self.workFolder stringByAppendingPathComponent:@"unpacked"];
  NSTask *ditto = [[NSTask alloc] init];
  [ditto setLaunchPath:@"/usr/bin/ditto"];
  [ditto setArguments:@[@"-x", @"-k", zip, unpacked]];
  [ditto setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  @try { [ditto launch]; [ditto waitUntilExit]; } @catch (NSException *e) { return [MWMUpdateInstaller errorWithMessage:@"MWM couldn't open the download."]; }
  NSString *app = [unpacked stringByAppendingPathComponent:@"MWM.app"];
  if ([ditto terminationStatus] != 0 || ![[NSFileManager defaultManager] fileExistsAtPath:app]) {
    return [MWMUpdateInstaller errorWithMessage:@"The download didn't contain MWM."];
  }
  NSError *problem = [self checkApp:app];
  if (problem != nil) return problem;
  self.stagedAppPath = app;
  return nil;
}

// That it is MWM, that it is the version asked for, and that whoever signed the running app signed it.
- (NSError *)checkApp:(NSString *)app {
  NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Contents/Info.plist"]];
  NSDictionary *mine = [NSDictionary dictionaryWithContentsOfFile:[self.appPath stringByAppendingPathComponent:@"Contents/Info.plist"]];
  if (![info[@"CFBundleIdentifier"] isEqualToString:mine[@"CFBundleIdentifier"]]) {
    return [MWMUpdateInstaller errorWithMessage:@"The download isn't MWM, so it wasn't installed."];
  }
  if (![info[@"CFBundleShortVersionString"] isEqualToString:self.version]) {
    return [MWMUpdateInstaller errorWithMessage:[NSString stringWithFormat:@"The download is version %@, not %@, so it wasn't installed.", info[@"CFBundleShortVersionString"], self.version]];
  }
  if (!self.requiresSignature) return nil;
  SecStaticCodeRef newCode = NULL, currentCode = NULL;
  SecRequirementRef requirement = NULL;
  NSError *result = nil;
  if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:app], kSecCSDefaultFlags, &newCode) != errSecSuccess ||
      SecStaticCodeCheckValidityWithErrors(newCode, kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode, NULL, NULL) != errSecSuccess) {
    result = [MWMUpdateInstaller errorWithMessage:@"The new version's signature isn't valid, so it wasn't installed."];
  } else if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:self.appPath], kSecCSDefaultFlags, &currentCode) == errSecSuccess &&
             SecCodeCopyDesignatedRequirement(currentCode, kSecCSDefaultFlags, &requirement) == errSecSuccess) {
    // A build signed only for this Mac (no certificate) has nothing to compare against beyond its own hash.
    CFStringRef text = NULL;
    SecRequirementCopyString(requirement, kSecCSDefaultFlags, &text);
    BOOL byCertificate = text != NULL && [(__bridge NSString *)text rangeOfString:@"certificate"].location != NSNotFound;
    if (text != NULL) CFRelease(text);
    if (byCertificate && SecStaticCodeCheckValidityWithErrors(newCode, kSecCSDefaultFlags, requirement, NULL) != errSecSuccess) {
      result = [MWMUpdateInstaller errorWithMessage:@"The new version wasn't signed by the same developer as this one, so it wasn't installed."];
    }
  }
  if (requirement != NULL) CFRelease(requirement);
  if (currentCode != NULL) CFRelease(currentCode);
  if (newCode != NULL) CFRelease(newCode);
  return result;
}

#pragma mark - Installing

+ (NSString *)installScript {
  return @"#!/bin/sh\n"
         @"# usage: install.sh <pid of MWM> <app to replace> <new app> <work folder>\n"
         @"PID=\"$1\"; APP=\"$2\"; NEW=\"$3\"; WORK=\"$4\"\n"
         @"n=0\n"
         @"while kill -0 \"$PID\" 2>/dev/null && [ $n -lt 150 ]; do sleep 0.2; n=$((n+1)); done\n"
         @"BACKUP=\"$WORK/previous.app\"\n"
         @"if mv \"$APP\" \"$BACKUP\"; then\n"
         @"  if mv \"$NEW\" \"$APP\"; then\n"
         @"    xattr -dr com.apple.quarantine \"$APP\" 2>/dev/null\n"
         @"    rm -rf \"$BACKUP\"\n"
         @"    echo installed\n"
         @"  else\n"
         @"    rm -rf \"$APP\"\n"
         @"    mv \"$BACKUP\" \"$APP\"\n"
         @"    echo restored\n"
         @"  fi\n"
         @"else\n"
         @"  echo unchanged\n"
         @"fi\n"
         @"${OPEN_COMMAND:-open} \"$APP\"\n";
}

- (BOOL)installAfterQuit:(NSError **)error {
  if (self.stagedAppPath == nil) {
    if (error) *error = [MWMUpdateInstaller errorWithMessage:@"There is no new version ready."];
    return NO;
  }
  NSString *script = [self.workFolder stringByAppendingPathComponent:@"install.sh"];
  if (![[MWMUpdateInstaller installScript] writeToFile:script atomically:YES encoding:NSUTF8StringEncoding error:error]) return NO;
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:@"/bin/sh"];
  [task setArguments:@[script, [NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]], self.appPath, self.stagedAppPath, self.workFolder]];
  NSString *log = [self.workFolder stringByAppendingPathComponent:@"install.log"];
  [[NSFileManager defaultManager] createFileAtPath:log contents:nil attributes:nil];
  [task setStandardOutput:[NSFileHandle fileHandleForWritingAtPath:log] ?: [NSFileHandle fileHandleWithNullDevice]];
  [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  @try {
    [task launch];
  } @catch (NSException *exception) {
    if (error) *error = [MWMUpdateInstaller errorWithMessage:@"MWM couldn't start the update."];
    return NO;
  }
  MWMLogger(@"Update to %@ started; MWM quits so the new version can take its place.", self.version);
  return YES;
}

@end
