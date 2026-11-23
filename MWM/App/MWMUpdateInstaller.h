//
//  MWMUpdateInstaller.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MWMUpdateInstallerErrorDomain;

// Brings a new version into place: downloads MWM-<version>.zip from the release folder, checks it against
// SHA256SUMS.txt, unpacks it, checks that it is MWM, that it is that version and that the same developer
// signed it, and, when the user agrees, swaps it for the running app and opens it. Every step that fails says
// why in words a person can read.
@interface MWMUpdateInstaller : NSObject
@property (copy, readonly) NSString *version;
// Where the files are: the zip and SHA256SUMS.txt. The site's downloads folder unless a test changes it.
@property (copy) NSURL *baseURL;
// The app that gets replaced, the running one unless a test changes it.
@property (copy) NSString *appPath;
// Tests turn this off for an app that isn't signed.
@property (assign) BOOL requiresSignature;
// The new app, once prepared.
@property (copy, readonly, nullable) NSString *stagedAppPath;

- (instancetype)initWithVersion:(NSString *)version;

// Downloads, checks and unpacks. progress is 0 to 1 while downloading; completion gets nil on success.
// Both run on the main queue.
- (void)prepareWithProgress:(nullable void (^)(double fraction))progress completion:(void (^)(NSError *_Nullable error))completion;
- (void)cancel;
// Removes what was downloaded and unpacked.
- (void)discard;

// Swaps the staged app for the running one after this process exits, and opens it. Call it, then quit.
// NO with an error when nothing could be started.
- (BOOL)installAfterQuit:(NSError **)error;

// Can this app be replaced by this user (is it somewhere they may write)?
+ (BOOL)canReplaceAppAtPath:(NSString *)path;
+ (NSURL *)zipURLForVersion:(NSString *)version baseURL:(NSURL *)baseURL;
+ (nullable NSString *)sha256OfFileAtPath:(NSString *)path;
// The checksum listed for a file in the text of SHA256SUMS.txt ("<hash>  <name>" per line), or nil.
+ (nullable NSString *)checksumForFileNamed:(NSString *)name inSums:(NSString *)sums;
// The shell script that swaps the apps once the process is gone, restoring the old one if the new one can't
// be put in place.
+ (NSString *)installScript;
@end

NS_ASSUME_NONNULL_END
