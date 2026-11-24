//
//  MWMBackup.m
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

#import "MWMBackup.h"
#import "MWMConfigDocument.h"
#import "MWMDisplays.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *const kFilePrefix = @"mwm-";
static NSString *const kFileSuffix = @".json";

@interface MWMBackupEnvironment ()
@property (assign) NSUInteger shortcutCount;
@property (assign) NSUInteger modifierCount;
@end

@implementation MWMBackupEnvironment

+ (instancetype)environmentNamed:(NSString *)name configText:(NSString *)text snapshots:(NSDictionary *)snapshots displays:(NSArray<MWMDisplay *> *)displays date:(NSDate *)date {
  MWMBackupEnvironment *environment = [[MWMBackupEnvironment alloc] init];
  environment.name = [self trimmedName:name];
  environment.savedAt = date;
  environment.displays = displays;
  environment.configText = text ?: @"";
  environment.snapshots = snapshots ?: @{};
  MWMConfigDocument *document = [MWMConfigDocument documentFromString:environment.configText lenient:YES error:nil];
  environment.shortcutCount = [document.bindings count];
  environment.modifierCount = [document.modifiers count];
  return environment;
}

- (NSUInteger)snapshotCount { return [self.snapshots count]; }

static NSString *DisplayKey(MWMDisplay *display) {
  return [NSString stringWithFormat:@"%@|%ld|%ld|%d", display.name, (long)display.width, (long)display.height, display.builtIn];
}

- (BOOL)matchesDisplays:(NSArray<MWMDisplay *> *)connected {
  NSMutableArray *mine = [NSMutableArray array], *theirs = [NSMutableArray array];
  for (MWMDisplay *display in self.displays) [mine addObject:DisplayKey(display)];
  for (MWMDisplay *display in connected) [theirs addObject:DisplayKey(display)];
  return [[mine sortedArrayUsingSelector:@selector(compare:)] isEqualToArray:[theirs sortedArrayUsingSelector:@selector(compare:)]];
}

+ (NSString *)descriptionOfDisplay:(MWMDisplay *)display {
  return [NSString stringWithFormat:@"%@ (%ld × %ld)", display.name, (long)display.width, (long)display.height];
}

#pragma mark - File

static NSDateFormatter *DateFormatter(void) {
  static NSDateFormatter *formatter;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
  });
  return formatter;
}

- (NSData *)fileData {
  NSMutableArray *displays = [NSMutableArray array];
  for (MWMDisplay *display in self.displays) {
    [displays addObject:@{@"name": display.name, @"width": @(display.width), @"height": @(display.height), @"builtIn": @(display.builtIn), @"x": @(display.originX), @"y": @(display.originY)}];
  }
  NSDictionary *file = @{@"version": @1, @"name": self.name, @"savedAt": [DateFormatter() stringFromDate:self.savedAt], @"displays": displays, @"config": self.configText, @"snapshots": self.snapshots};
  return [NSJSONSerialization dataWithJSONObject:file options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
}

+ (instancetype)environmentFromFileData:(NSData *)data {
  id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
  if (![parsed isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *file = parsed;
  if (![file[@"name"] isKindOfClass:[NSString class]] || ![file[@"config"] isKindOfClass:[NSString class]] || ![file[@"savedAt"] isKindOfClass:[NSString class]]) return nil;
  NSDate *date = [DateFormatter() dateFromString:file[@"savedAt"]];
  if (date == nil) return nil;
  NSDictionary *snapshots = [file[@"snapshots"] isKindOfClass:[NSDictionary class]] ? file[@"snapshots"] : @{};
  NSMutableArray *displays = [NSMutableArray array];
  for (id item in [file[@"displays"] isKindOfClass:[NSArray class]] ? file[@"displays"] : @[]) {
    if (![item isKindOfClass:[NSDictionary class]] || ![item[@"name"] isKindOfClass:[NSString class]]) continue;
    [displays addObject:[MWMDisplay displayNamed:item[@"name"] width:[item[@"width"] integerValue] height:[item[@"height"] integerValue] builtIn:[item[@"builtIn"] boolValue] x:[item[@"x"] doubleValue] y:[item[@"y"] doubleValue]]];
  }
  return [self environmentNamed:file[@"name"] configText:file[@"config"] snapshots:snapshots displays:displays date:date];
}

#pragma mark - Names

+ (NSString *)trimmedName:(NSString *)name {
  return [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)fileNameForName:(NSString *)name {
  NSData *bytes = [[[self trimmedName:name] lowercaseString] dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256([bytes bytes], (CC_LONG)[bytes length], digest);
  NSMutableString *hex = [NSMutableString string];
  for (int i = 0; i < 8; i++) [hex appendFormat:@"%02x", digest[i]];
  return [NSString stringWithFormat:@"%@%@%@", kFilePrefix, hex, kFileSuffix];
}

+ (BOOL)isEnvironmentFileName:(NSString *)fileName {
  return [fileName hasPrefix:kFilePrefix] && [fileName hasSuffix:kFileSuffix];
}

+ (NSString *)problemWithName:(NSString *)name {
  NSString *trimmed = [self trimmedName:name];
  if ([trimmed length] == 0) return @"Give the backup a name.";
  if ([trimmed length] > 60) return @"Use a shorter name (60 characters at most).";
  return nil;
}

@end
