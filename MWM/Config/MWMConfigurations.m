//
//  MWMConfigurations.m
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

#import "MWMConfigurations.h"

static NSString *gHome = nil;
static NSString *const kDefaultName = @"default";
static NSString *const kActiveFile = @"active";
static NSString *const kExtensionYAML = @".mwm.yaml";
static NSString *const kExtensionYML = @".mwm.yml";
static NSString *const kErrorDomain = @"MWMConfigurations";
static const NSUInteger kMaxNameLength = 60;

static NSError *ConfigurationError(NSString *message) {
  return [NSError errorWithDomain:kErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation MWMConfigurations

#pragma mark - Where

+ (void)setHomeDirectory:(NSString *)home { gHome = [home copy]; }
// MWM_HOME points development builds at a scratch home folder, so trying the first-run import and switching
// never touches the real ~/.mwm.yml, ~/.slate or ~/.mwm.
+ (NSString *)homeDirectory {
  if (gHome != nil) return gHome;
  NSString *scratch = [[NSProcessInfo processInfo] environment][@"MWM_HOME"];
  return [scratch length] > 0 ? scratch : NSHomeDirectory();
}
+ (NSString *)folder { return [[self homeDirectory] stringByAppendingPathComponent:@".mwm"]; }

+ (BOOL)folderExists {
  BOOL directory = NO;
  return [[NSFileManager defaultManager] fileExistsAtPath:[self folder] isDirectory:&directory] && directory;
}

+ (BOOL)createFolder:(NSError **)error {
  return [[NSFileManager defaultManager] createDirectoryAtPath:[self folder] withIntermediateDirectories:YES attributes:nil error:error];
}

#pragma mark - Listing

// "desk" for desk.mwm.yaml and desk.mwm.yml; nil for anything else.
+ (nullable NSString *)nameForFile:(NSString *)file {
  if ([file hasPrefix:@"."]) return nil;
  for (NSString *extension in @[kExtensionYAML, kExtensionYML]) {
    if ([file.lowercaseString hasSuffix:extension] && [file length] > [extension length]) {
      return [file substringToIndex:[file length] - [extension length]];
    }
  }
  return nil;
}

+ (NSArray<NSString *> *)names {
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self folder] error:nil];
  NSMutableArray *names = [NSMutableArray array];
  for (NSString *file in files) {
    NSString *name = [self nameForFile:file];
    if (name != nil && ![names containsObject:name]) [names addObject:name];
  }
  return [names sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) { return [a caseInsensitiveCompare:b]; }];
}

// The name as it is on disk, matching without regard to case.
+ (nullable NSString *)existingNameMatching:(NSString *)name {
  for (NSString *each in [self names]) if ([each caseInsensitiveCompare:name] == NSOrderedSame) return each;
  return nil;
}

+ (BOOL)existsNamed:(NSString *)name { return [self existingNameMatching:name] != nil; }

+ (NSString *)pathForName:(NSString *)name {
  NSString *folder = [self folder];
  NSString *yaml = [folder stringByAppendingPathComponent:[name stringByAppendingString:kExtensionYAML]];
  NSString *yml = [folder stringByAppendingPathComponent:[name stringByAppendingString:kExtensionYML]];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:yaml] && [fm fileExistsAtPath:yml]) return yml;
  return yaml;
}

+ (NSDate *)modificationDateForName:(NSString *)name {
  NSString *path = [[self pathForName:name] stringByResolvingSymlinksInPath];
  return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil][NSFileModificationDate];
}

#pragma mark - The active one

+ (NSString *)activeName {
  NSString *saved = [NSString stringWithContentsOfFile:[[self folder] stringByAppendingPathComponent:kActiveFile] encoding:NSUTF8StringEncoding error:nil];
  saved = [saved stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *match = [saved length] > 0 ? [self existingNameMatching:saved] : nil;
  if (match != nil) return match;
  match = [self existingNameMatching:kDefaultName];
  if (match != nil) return match;
  return [[self names] firstObject] ?: kDefaultName;
}

+ (NSString *)activePath { return [self pathForName:[self activeName]]; }

+ (BOOL)setActiveName:(NSString *)name {
  if (![self createFolder:nil]) return NO;
  return [[name stringByAppendingString:@"\n"] writeToFile:[[self folder] stringByAppendingPathComponent:kActiveFile] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - Names

+ (NSString *)trimmedName:(NSString *)name {
  return [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)problemWithName:(NSString *)name except:(NSString *)except {
  NSString *trimmed = [self trimmedName:name];
  if ([trimmed length] == 0) return @"Enter a name.";
  if ([trimmed length] > kMaxNameLength) return [NSString stringWithFormat:@"Use a name of %lu characters or fewer.", (unsigned long)kMaxNameLength];
  if ([trimmed rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\:"]].location != NSNotFound) return @"A name can't contain / \\ or :.";
  if ([trimmed hasPrefix:@"."]) return @"A name can't start with a dot.";
  NSString *taken = [self existingNameMatching:trimmed];
  if (taken != nil && (except == nil || [taken caseInsensitiveCompare:except] != NSOrderedSame)) return @"A configuration with that name already exists.";
  return nil;
}

+ (NSString *)freeNameFrom:(NSString *)name {
  NSString *base = [self trimmedName:name];
  if ([base length] == 0) base = @"configuration";
  if (![self existsNamed:base]) return base;
  for (NSUInteger i = 2;; i++) {
    NSString *candidate = [NSString stringWithFormat:@"%@ %lu", base, (unsigned long)i];
    if (![self existsNamed:candidate]) return candidate;
  }
}

+ (NSString *)fileSafeName:(NSString *)name {
  NSMutableString *safe = [NSMutableString string];
  for (NSUInteger i = 0; i < [name length]; i++) {
    unichar c = [name characterAtIndex:i];
    [safe appendString:(c == '/' || c == '\\' || c == ':' || c < 32) ? @"-" : [NSString stringWithCharacters:&c length:1]];
  }
  NSString *trimmed = [safe stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". \t\n"]];
  if ([trimmed length] > kMaxNameLength) trimmed = [[trimmed substringToIndex:kMaxNameLength] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  return [trimmed length] > 0 ? trimmed : @"backup";
}

#pragma mark - Changing

+ (BOOL)createNamed:(NSString *)name text:(NSString *)text error:(NSError **)error {
  NSString *trimmed = [self trimmedName:name];
  NSString *problem = [self problemWithName:trimmed except:nil];
  if (problem != nil) { if (error) *error = ConfigurationError(problem); return NO; }
  if (![self createFolder:error]) return NO;
  return [text writeToFile:[self pathForName:trimmed] atomically:YES encoding:NSUTF8StringEncoding error:error];
}

+ (BOOL)duplicateNamed:(NSString *)name as:(NSString *)copyName error:(NSError **)error {
  NSString *trimmed = [self trimmedName:copyName];
  NSString *problem = [self problemWithName:trimmed except:nil];
  if (problem != nil) { if (error) *error = ConfigurationError(problem); return NO; }
  NSString *source = [[self pathForName:name] stringByResolvingSymlinksInPath];
  if (![[NSFileManager defaultManager] fileExistsAtPath:source]) { if (error) *error = ConfigurationError([NSString stringWithFormat:@"“%@” doesn't exist.", name]); return NO; }
  return [[NSFileManager defaultManager] copyItemAtPath:source toPath:[self pathForName:trimmed] error:error];
}

+ (BOOL)renameNamed:(NSString *)name to:(NSString *)newName error:(NSError **)error {
  NSString *trimmed = [self trimmedName:newName];
  NSString *problem = [self problemWithName:trimmed except:name];
  if (problem != nil) { if (error) *error = ConfigurationError(problem); return NO; }
  if ([trimmed isEqualToString:name]) return YES;
  BOOL wasActive = [[self activeName] caseInsensitiveCompare:name] == NSOrderedSame;
  NSString *from = [self pathForName:name];
  NSString *to = [[self folder] stringByAppendingPathComponent:[trimmed stringByAppendingString:[from.lowercaseString hasSuffix:kExtensionYML] ? kExtensionYML : kExtensionYAML]];
  // A change of case only: the file system sees the same file, so go through a temporary name.
  if ([trimmed caseInsensitiveCompare:name] == NSOrderedSame) {
    NSString *temporary = [from stringByAppendingString:@".renaming"];
    if (![[NSFileManager defaultManager] moveItemAtPath:from toPath:temporary error:error]) return NO;
    if (![[NSFileManager defaultManager] moveItemAtPath:temporary toPath:to error:error]) { [[NSFileManager defaultManager] moveItemAtPath:temporary toPath:from error:nil]; return NO; }
  } else if (![[NSFileManager defaultManager] moveItemAtPath:from toPath:to error:error]) {
    return NO;
  }
  if (wasActive) [self setActiveName:trimmed];
  return YES;
}

+ (BOOL)deleteNamed:(NSString *)name error:(NSError **)error {
  if ([[self activeName] caseInsensitiveCompare:name] == NSOrderedSame) {
    if (error) *error = ConfigurationError(@"The active configuration can't be deleted. Activate another one first.");
    return NO;
  }
  if ([[self names] count] <= 1) {
    if (error) *error = ConfigurationError(@"The last configuration can't be deleted.");
    return NO;
  }
  NSURL *url = [NSURL fileURLWithPath:[self pathForName:name]];
  return [[NSFileManager defaultManager] trashItemAtURL:url resultingItemURL:nil error:error];
}

+ (NSString *)importFileAtPath:(NSString *)path error:(NSError **)error {
  NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
  if (text == nil) return nil;
  NSString *file = [path lastPathComponent];
  NSString *base = [self nameForFile:file];
  if (base == nil) base = [file stringByDeletingPathExtension];
  base = [self fileSafeName:base];
  NSString *name = [self freeNameFrom:base];
  return [self createNamed:name text:text error:error] ? name : nil;
}

+ (BOOL)writeText:(NSString *)text named:(NSString *)name error:(NSError **)error {
  if (![self createFolder:error]) return NO;
  NSString *path = [self pathForName:name];
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:path]) {
    NSString *backup = [path stringByAppendingString:@".bak"];
    [fm removeItemAtPath:backup error:nil];
    [fm copyItemAtPath:path toPath:backup error:nil];
  }
  return [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

@end
