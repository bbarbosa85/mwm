//
//  MWMUpdateChecker.m
//  MWM
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

#import "MWMUpdateChecker.h"
#import "MWMConfig.h"
#import "Constants.h"
#import "MWMAlert.h"
#import "MWMUpdateInstaller.h"

NSString *const MWMUpdateKindNewer = @"newer";
NSString *const MWMUpdateKindCurrent = @"current";
NSString *const MWMUpdateKindError = @"error";

static NSString *const kLatestReleaseURL = @"https://api.github.com/repos/bbarbosa85/mwm/releases/latest";
static NSString *const kDownloadPage = @"https://bbarbosa85.github.io/mwm/#download";
static NSString *const kLastNotified = @"MWMLastNotifiedVersion";

// "v1.2.3-beta" -> @[1, 2, 3]; nil when there is no number at the start.
static NSArray<NSNumber *> *VersionParts(NSString *text) {
  NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([trimmed hasPrefix:@"v"] || [trimmed hasPrefix:@"V"]) trimmed = [trimmed substringFromIndex:1];
  NSMutableArray *parts = [NSMutableArray array];
  for (NSString *piece in [trimmed componentsSeparatedByString:@"."]) {
    NSScanner *scanner = [NSScanner scannerWithString:piece];
    NSInteger value = 0;
    if (![scanner scanInteger:&value]) break;
    [parts addObject:@(value)];
  }
  return [parts count] > 0 ? parts : nil;
}

@interface MWMUpdateChecker ()
@property (strong) MWMUpdateInstaller *installer;   // the update in progress
@end

@implementation MWMUpdateChecker

+ (instancetype)shared {
  static MWMUpdateChecker *checker;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ checker = [[MWMUpdateChecker alloc] init]; });
  return checker;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _releasesURL = [NSURL URLWithString:kLatestReleaseURL];
    _currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
    _defaults = [NSUserDefaults standardUserDefaults];
  }
  return self;
}

#pragma mark - Reading a release

+ (BOOL)version:(NSString *)candidate isNewerThan:(NSString *)current {
  NSArray *a = VersionParts(candidate), *b = VersionParts(current);
  if (a == nil || b == nil) return NO;
  NSUInteger count = MAX([a count], [b count]);
  for (NSUInteger i = 0; i < count; i++) {
    NSInteger x = i < [a count] ? [a[i] integerValue] : 0, y = i < [b count] ? [b[i] integerValue] : 0;
    if (x != y) return x > y;
  }
  return NO;
}

+ (NSDictionary *)latestFromReleaseJSON:(NSData *)data {
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![json isKindOfClass:[NSDictionary class]]) return nil;
  NSString *tag = json[@"tag_name"], *page = json[@"html_url"];
  if (![tag isKindOfClass:[NSString class]] || VersionParts(tag) == nil) return nil;
  NSString *version = [tag hasPrefix:@"v"] ? [tag substringFromIndex:1] : tag;
  return @{@"version": version, @"notesURL": [page isKindOfClass:[NSString class]] ? page : @""};
}

#pragma mark - Checking

- (void)fetch:(void (^)(NSDictionary *result))done {
  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
  configuration.timeoutIntervalForRequest = 15;
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.releasesURL];
  [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
  [request setValue:[NSString stringWithFormat:@"MWM/%@", self.currentVersion] forHTTPHeaderField:@"User-Agent"];
  NSString *current = self.currentVersion;
  [[[NSURLSession sessionWithConfiguration:configuration] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    NSDictionary *result;
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 200;
    NSDictionary *latest = (data != nil && error == nil && status == 200) ? [MWMUpdateChecker latestFromReleaseJSON:data] : nil;
    if (latest == nil) {
      NSString *why = error != nil ? error.localizedDescription : (status != 200 ? [NSString stringWithFormat:@"GitHub answered with status %ld.", (long)status] : @"GitHub's answer wasn't a release.");
      result = @{@"kind": MWMUpdateKindError, @"message": why};
    } else if ([MWMUpdateChecker version:latest[@"version"] isNewerThan:current]) {
      result = @{@"kind": MWMUpdateKindNewer, @"version": latest[@"version"], @"notesURL": latest[@"notesURL"]};
    } else {
      result = @{@"kind": MWMUpdateKindCurrent, @"version": current};
    }
    dispatch_async(dispatch_get_main_queue(), ^{ done(result); });
  }] resume];
}

- (void)checkNow {
  [self fetch:^(NSDictionary *result) { [self handleResult:result manual:YES]; }];
}

- (BOOL)automaticCheckIsEnabled {
  return [[MWMConfig getInstance] getBoolConfig:CHECK_FOR_UPDATES];
}

- (void)checkAutomatically {
  if (![self automaticCheckIsEnabled]) return;
  [self fetch:^(NSDictionary *result) { [self handleResult:result manual:NO]; }];
}

#pragma mark - Telling the user

- (void)handleResult:(NSDictionary *)result manual:(BOOL)manual {
  NSString *kind = result[@"kind"];
  if (!manual) {
    // A check nobody asked for stays quiet unless there is news, and says it once per version.
    if (![kind isEqualToString:MWMUpdateKindNewer]) return;
    if ([[self.defaults stringForKey:kLastNotified] isEqualToString:result[@"version"]]) return;
    [self.defaults setObject:result[@"version"] forKey:kLastNotified];
  }
  if (self.presenter != nil) { self.presenter(result); return; }
  [self showAlertFor:result];
}

#pragma mark - Updating

- (void)openDownloadPage {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kDownloadPage]];
}

// Downloads the new version with a progress window, then asks before restarting into it. If MWM can't replace
// itself where it is, or something goes wrong, the download page is the way out.
- (void)installUpdate:(NSDictionary *)result {
  MWMUpdateInstaller *installer = [[MWMUpdateInstaller alloc] initWithVersion:result[@"version"]];
  if (![MWMUpdateInstaller canReplaceAppAtPath:installer.appPath]) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setShowsAppIcon:YES];
    [alert setKind:MWMAlertKindInfo];
    [alert setMessageText:@"MWM can't update itself here"];
    [alert setInformativeText:@"It isn't in a folder you can change. Download the new version and drag it over the old one in Applications."];
    [alert addButtonWithTitle:@"Open download page"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) [self openDownloadPage];
    return;
  }
  self.installer = installer;
  NSProgressIndicator *bar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 100, 12)];
  [bar setStyle:NSProgressIndicatorStyleBar];
  [bar setIndeterminate:NO];
  [bar setMinValue:0];
  [bar setMaxValue:1];
  MWMAlert *progress = [MWMAlert alert];
  [progress setShowsAppIcon:YES];
  [progress setKind:MWMAlertKindInfo];
  [progress setMessageText:[NSString stringWithFormat:@"Downloading MWM %@", result[@"version"]]];
  [progress setInformativeText:@"This takes a moment. MWM keeps working meanwhile."];
  [progress setAccessoryView:bar];
  [progress addButtonWithTitle:@"Cancel"];
  __weak MWMUpdateChecker *weakSelf = self;
  [progress setButtonHandler:^(NSModalResponse response) {
    [installer cancel];
    [progress dismiss];
    weakSelf.installer = nil;
  }];
  [progress show];
  [installer prepareWithProgress:^(double fraction) { [bar setDoubleValue:fraction]; } completion:^(NSError *error) {
    [progress dismiss];
    if (error != nil) {
      MWMAlert *failed = [MWMAlert alert];
      [failed setShowsAppIcon:YES];
      [failed setKind:MWMAlertKindWarning];
      [failed setMessageText:@"Couldn't update MWM"];
      [failed setInformativeText:[NSString stringWithFormat:@"%@\n\nYou can download the new version yourself.", error.localizedDescription]];
      [failed addButtonWithTitle:@"Open download page"];
      [failed addButtonWithTitle:@"Cancel"];
      if ([failed runModal] == NSAlertFirstButtonReturn) [weakSelf openDownloadPage];
      [installer discard];
      weakSelf.installer = nil;
      return;
    }
    MWMAlert *ready = [MWMAlert alert];
    [ready setShowsAppIcon:YES];
    [ready setKind:MWMAlertKindSuccess];
    [ready setMessageText:[NSString stringWithFormat:@"MWM %@ is ready", result[@"version"]]];
    [ready setInformativeText:@"MWM restarts to finish the update. Your shortcuts stop working for a few seconds."];
    [ready addButtonWithTitle:@"Restart and update"];
    [ready addButtonWithTitle:@"Not now"];
    if ([ready runModal] != NSAlertFirstButtonReturn) {
      [installer discard];
      weakSelf.installer = nil;
      return;
    }
    NSError *installError = nil;
    if ([installer installAfterQuit:&installError]) {
      [NSApp terminate:nil];
    } else {
      MWMAlert *stuck = [MWMAlert alert];
      [stuck setShowsAppIcon:YES];
      [stuck setKind:MWMAlertKindWarning];
      [stuck setMessageText:@"Couldn't update MWM"];
      [stuck setInformativeText:installError.localizedDescription ?: @"The update didn't start."];
      [stuck addButtonWithTitle:@"OK"];
      [stuck runModal];
    }
  }];
}

- (void)showAlertFor:(NSDictionary *)result {
  MWMAlert *alert = [MWMAlert alert];
  [alert setShowsAppIcon:YES];
  NSString *kind = result[@"kind"];
  if ([kind isEqualToString:MWMUpdateKindNewer]) {
    [alert setKind:MWMAlertKindInfo];
    [alert setMessageText:[NSString stringWithFormat:@"MWM %@ is available", result[@"version"]]];
    [alert setInformativeText:[NSString stringWithFormat:@"You have version %@. MWM can download the new one and restart itself with it.", self.currentVersion]];
    [alert addButtonWithTitle:@"Update now"];
    [alert addButtonWithTitle:@"What's new"];
    [alert addButtonWithTitle:@"Not now"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) [self installUpdate:result];
    else if (response == NSAlertSecondButtonReturn && [result[@"notesURL"] length] > 0) [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:result[@"notesURL"]]];
    return;
  }
  if ([kind isEqualToString:MWMUpdateKindCurrent]) {
    [alert setKind:MWMAlertKindSuccess];
    [alert setMessageText:@"MWM is up to date"];
    [alert setInformativeText:[NSString stringWithFormat:@"You have the latest version (%@).", self.currentVersion]];
  } else {
    [alert setMessageText:@"Couldn't check for updates"];
    [alert setInformativeText:[NSString stringWithFormat:@"%@\n\nCheck your internet connection and try again.", result[@"message"] ?: @""]];
    [alert setKind:MWMAlertKindWarning];
  }
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

@end
