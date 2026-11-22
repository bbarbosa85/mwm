//
//  TestExampleConfigs.m
//
//  The example configurations on the docs site (docs/examples) must load, and
//  must not break MWM's own rules: no two shortcuts on the same keys, and no
//  keys macOS keeps.
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

#import <XCTest/XCTest.h>
#import "SlateConfigDocument.h"
#import "SlateReservedShortcuts.h"
#import "SlateShortcutIndex.h"

@interface TestExampleConfigs : XCTestCase
@end

@implementation TestExampleConfigs

- (NSArray<NSString *> *)examplePaths {
  NSString *folder = [[[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"docs/examples"];
  NSMutableArray *paths = [NSMutableArray array];
  for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil]) {
    if ([file hasSuffix:@".mwm.yml"]) [paths addObject:[folder stringByAppendingPathComponent:file]];
  }
  return paths;
}

- (void)testThereAreExamples {
  XCTAssertGreaterThanOrEqual([[self examplePaths] count], 5u);
}

- (void)testEveryExampleLoadsAsVersionTwo {
  for (NSString *path in [self examplePaths]) {
    NSError *error = nil;
    SlateConfigDocument *doc = [SlateConfigDocument documentWithContentsOfFile:path error:&error];
    XCTAssertNotNil(doc, @"%@: %@", [path lastPathComponent], error);
    XCTAssertEqual(doc.sourceVersion, 2, @"%@", [path lastPathComponent]);
    XCTAssertGreaterThan([doc.bindings count], 0u, @"%@", [path lastPathComponent]);
  }
}

- (void)testNoExampleHasConflictsOrKeysMacOSKeeps {
  for (NSString *path in [self examplePaths]) {
    SlateConfigDocument *doc = [SlateConfigDocument documentWithContentsOfFile:path error:nil];
    SlateShortcutIndex *index = [SlateShortcutIndex indexForDocument:doc];
    for (SlateShortcutInfo *info in index.shortcuts) {
      if (!info.binding.enabled) continue;
      XCTAssertFalse(info.conflict, @"%@: \"%@\" shares keys with another shortcut", [path lastPathComponent], info.title);
      NSString *reason = [SlateReservedShortcuts reasonForKeyName:info.keyName modifierNames:info.modifierNames];
      XCTAssertNil(reason, @"%@: %@ (%@)", [path lastPathComponent], info.title, reason);
    }
  }
}

- (void)testEveryExampleRoundTripsThroughTheWindowsWriter {
  for (NSString *path in [self examplePaths]) {
    SlateConfigDocument *doc = [SlateConfigDocument documentWithContentsOfFile:path error:nil];
    SlateConfigDocument *again = [SlateConfigDocument documentFromString:[doc stringRepresentation] error:nil];
    XCTAssertNotNil(again, @"%@", [path lastPathComponent]);
    XCTAssertEqualObjects(again.bindings, doc.bindings, @"%@ keeps every shortcut when the window saves it", [path lastPathComponent]);
  }
}

@end
