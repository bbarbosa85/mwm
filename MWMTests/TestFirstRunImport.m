//
//  TestFirstRunImport.m
//
//  The first launch with the ~/.mwm folder: an existing ~/.mwm.yml moves in, Slate files are converted
//  and never touched. Every test uses a temporary home folder.
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

#import <XCTest/XCTest.h>
#import "MWMProfiles.h"
#import "MWMConfigDocument.h"
#import "MWMLegacyMigration.h"

static NSString *const kSlate = @"config keyboardLayout dvorak\nbind r:cmd relaunch\n";
static NSString *const kYML = @"version: 2\nsettings:\n  keyboardLayout: colemak\nbindings:\n  - key: z\n    action: relaunch\n";

@interface TestFirstRunImport : XCTestCase
@property (copy) NSString *home;
@end

@implementation TestFirstRunImport

- (void)setUp {
  self.home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.home withIntermediateDirectories:YES attributes:nil error:nil];
  [MWMProfiles setHomeDirectory:self.home];
}

- (void)tearDown {
  [MWMProfiles setHomeDirectory:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.home error:nil];
}

- (NSString *)file:(NSString *)name { return [self.home stringByAppendingPathComponent:name]; }
- (void)write:(NSString *)text to:(NSString *)name { [text writeToFile:[self file:name] atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
- (NSString *)read:(NSString *)path { return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]; }
- (BOOL)exists:(NSString *)name { return [[NSFileManager defaultManager] fileExistsAtPath:[self file:name]]; }

- (void)testNothingToImportCreatesNothing {
  XCTAssertNil([MWMLegacyMigration importFirstRunProfiles]);
  XCTAssertFalse([MWMProfiles folderExists]);
}

- (void)testSlateFilesAreConvertedAndLeftExactlyAsTheyWere {
  [self write:kSlate to:@".slate"];
  NSDictionary *result = [MWMLegacyMigration importFirstRunProfiles];
  XCTAssertEqualObjects(result[@"importedName"], @"default");
  XCTAssertFalse([result[@"moved"] boolValue]);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"default"]));
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
  MWMConfigDocument *doc = [MWMConfigDocument documentWithContentsOfFile:[MWMProfiles pathForName:@"default"] error:nil];
  XCTAssertEqualObjects([doc.bindings valueForKey:@"key"], (@[@"r"]));
  XCTAssertEqualObjects([self read:[self file:@".slate"]], kSlate, @"~/.slate is untouched");
  XCTAssertEqualObjects([[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.home error:nil].count > 0 ? @"ok" : @"", @"ok");
  for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.home error:nil]) {
    XCTAssertFalse([file containsString:@"migrated"], @"nothing was renamed: %@", file);
  }
}

- (void)testAnExistingMWMYMLMovesIn {
  [self write:kYML to:@".mwm.yml"];
  NSDictionary *result = [MWMLegacyMigration importFirstRunProfiles];
  XCTAssertTrue([result[@"moved"] boolValue]);
  XCTAssertNil(result[@"importedName"]);
  XCTAssertFalse([self exists:@".mwm.yml"], @"moved, not copied");
  XCTAssertEqualObjects([self read:[MWMProfiles pathForName:@"default"]], kYML);
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
}

- (void)testBothGiveTwoProfilesAndTheMovedOneStaysActive {
  [self write:kYML to:@".mwm.yml"];
  [self write:kSlate to:@".slate"];
  NSDictionary *result = [MWMLegacyMigration importFirstRunProfiles];
  XCTAssertEqualObjects(result[@"importedName"], @"slate-import");
  XCTAssertEqualObjects([MWMProfiles names], (@[@"default", @"slate-import"]));
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
  XCTAssertEqualObjects([self read:[MWMProfiles pathForName:@"default"]], kYML, @"the moved file is exactly as it was");
  XCTAssertEqualObjects([self read:[self file:@".slate"]], kSlate);
}

- (void)testItOnlyHappensTheFirstTime {
  [self write:kSlate to:@".slate"];
  XCTAssertNotNil([MWMLegacyMigration importFirstRunProfiles]);
  XCTAssertNil([MWMLegacyMigration importFirstRunProfiles], @"the folder exists now");
  [MWMProfiles deleteNamed:@"default" error:nil];   // the last one can't go; the folder stays
  [self write:@"bind z:cmd relaunch\n" to:@".slate"];
  XCTAssertNil([MWMLegacyMigration importFirstRunProfiles], @"a changed ~/.slate isn't imported again");
}

- (void)testASlateFileThatCantBeConvertedIsReportedAndStillUntouched {
  [self write:@"bind r:${nope} relaunch\n" to:@".slate"];
  NSDictionary *result = [MWMLegacyMigration importFirstRunProfiles];
  XCTAssertNil(result[@"importedName"]);
  XCTAssertNotNil(result[@"slateProblem"]);
  XCTAssertEqualObjects([self read:[self file:@".slate"]], @"bind r:${nope} relaunch\n");
}

- (void)testASymlinkedMWMYMLMovesAsASymlink {
  [self write:kYML to:@"dotfiles-mwm.yml"];
  [[NSFileManager defaultManager] createSymbolicLinkAtPath:[self file:@".mwm.yml"] withDestinationPath:[self file:@"dotfiles-mwm.yml"] error:nil];
  XCTAssertTrue([[MWMLegacyMigration importFirstRunProfiles][@"moved"] boolValue]);
  XCTAssertEqualObjects([self read:[MWMProfiles pathForName:@"default"]], kYML, @"still reads through to the dotfiles copy");
  XCTAssertTrue([self exists:@"dotfiles-mwm.yml"]);
}

- (void)testTheActiveProfileIsWhatLoads {
  [self write:kYML to:@".mwm.yml"];
  [MWMLegacyMigration importFirstRunProfiles];
  XCTAssertEqualObjects([MWMConfigDocument defaultPath], [MWMProfiles pathForName:@"default"]);
  [MWMProfiles createNamed:@"desk" text:@"version: 2\n" error:nil];
  [MWMProfiles setActiveName:@"desk"];
  XCTAssertEqualObjects([MWMConfigDocument defaultPath], [MWMProfiles pathForName:@"desk"]);
}

@end
