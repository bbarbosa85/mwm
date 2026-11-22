//
//  NSFileManager+ApplicationSupport.m
//  Slate
//
//  Created by Jigish Patel on 4/23/12.
//  Copyright 2012 Jigish Patel. All rights reserved.
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

#import "NSFileManager+ApplicationSupport.h"

@implementation NSFileManager (ApplicationSupport)

// The bundle identifier the app had while it was called Slate.
static NSString *const kLegacyBundleIdentifier = @"com.slate.Slate";

- (NSURL *)applicationSupportDirectory {
  NSURL *directory = [self findOrCreateDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask append:[[NSBundle mainBundle] bundleIdentifier] error:nil];
  static dispatch_once_t once;
  dispatch_once(&once, ^{ [self copyLegacySupportFilesInto:directory]; });
  return directory;
}

// One time: carries the files stored under the old bundle identifier (the
// snapshots) over to this one. The old folder is left in place as a backup,
// and files already here are never overwritten.
- (void)copyLegacySupportFilesInto:(NSURL *)directory {
  NSURL *base = [[self URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
  NSURL *legacy = [base URLByAppendingPathComponent:kLegacyBundleIdentifier];
  if (directory == nil || base == nil || [[directory path] isEqualToString:[legacy path]]) return;
  for (NSString *name in [self contentsOfDirectoryAtPath:[legacy path] error:nil]) {
    NSURL *target = [directory URLByAppendingPathComponent:name];
    if ([self fileExistsAtPath:[target path]]) continue;
    [self copyItemAtURL:[legacy URLByAppendingPathComponent:name] toURL:target error:nil];
  }
}

- (NSURL *)findOrCreateDirectory:(NSSearchPathDirectory)searchPathDirectory inDomain:(NSSearchPathDomainMask)domainMask append:(NSString *)appendComponent error:(NSError **)errorOut {
  NSArray *urls = [self URLsForDirectory:searchPathDirectory inDomains:domainMask];
  if ([urls count] == 0) return nil;
  NSURL *url = [urls objectAtIndex:0];

  if (appendComponent) {
    url = [url URLByAppendingPathComponent:appendComponent];
  }
  NSError *error;
  BOOL success = [self createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
  if (!success) {
    if (errorOut) *errorOut = error;
    return nil;
  }
  if (errorOut) *errorOut = nil;
  return url;
}

@end
