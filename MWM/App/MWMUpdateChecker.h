//
//  MWMUpdateChecker.h
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
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// What a check found. The keys of a result: kind, version, notesURL, message.
extern NSString *const MWMUpdateKindNewer;    // a newer version exists
extern NSString *const MWMUpdateKindCurrent;  // the running version is the latest
extern NSString *const MWMUpdateKindError;    // the check failed

@interface MWMUpdateChecker : NSObject

+ (instancetype)shared;

// "1.0.1" is newer than "1.0", "1.10" than "1.9". A leading "v" is ignored; text that isn't a version is never newer.
+ (BOOL)version:(NSString *)candidate isNewerThan:(NSString *)current;
// The version and release page from GitHub's "latest release" JSON, or nil if it isn't one.
+ (nullable NSDictionary *)latestFromReleaseJSON:(NSData *)data;

// Where the latest release is read from, the running version, and the user defaults used to remember
// which version it last told the user about. Tests change these; the app leaves them alone.
@property (copy) NSURL *releasesURL;
@property (copy) NSString *currentVersion;
@property (strong) NSUserDefaults *defaults;
// Shows a result. The default shows an MWM alert; tests capture it instead.
@property (copy, nullable) void (^presenter)(NSDictionary *result);

// From the menu: always says something (a new version, "up to date", or what went wrong).
- (void)checkNow;
// When MWM opens, and only then: does nothing if the setting is off. Otherwise it checks, and speaks up only
// when there is a newer version it hasn't told the user about yet.
- (void)checkAutomatically;
- (BOOL)automaticCheckIsEnabled;

// Handles a finished check (exposed for tests).
- (void)handleResult:(NSDictionary *)result manual:(BOOL)manual;

@end

NS_ASSUME_NONNULL_END
