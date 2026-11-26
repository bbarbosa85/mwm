//
//  TestMWMProfiles.m
//
//  The profiles kept in ~/.mwm: listing, the active one, names, and changing them. Every test
//  uses a temporary home folder.
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

@interface TestMWMProfiles : XCTestCase
@property (copy) NSString *home;
@end

@implementation TestMWMProfiles

- (void)setUp {
  self.home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.home withIntermediateDirectories:YES attributes:nil error:nil];
  [MWMProfiles setHomeDirectory:self.home];
}

- (void)tearDown {
  [MWMProfiles setHomeDirectory:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.home error:nil];
}

- (BOOL)make:(NSString *)name { return [MWMProfiles createNamed:name text:[NSString stringWithFormat:@"version: 2\n# %@\n", name] error:nil]; }

#pragma mark - Listing

- (void)testThereAreNoProfilesBeforeTheFirstOne {
  XCTAssertFalse([MWMProfiles folderExists]);
  XCTAssertEqual([[MWMProfiles names] count], 0u);
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
  XCTAssertEqualObjects([MWMProfiles activePath], [self.home stringByAppendingPathComponent:@".mwm/default.mwm.yaml"]);
}

- (void)testFilesAreListedByNameIgnoringTheRest {
  XCTAssertTrue([self make:@"work"]);
  XCTAssertTrue([self make:@"Desk"]);
  NSString *folder = [MWMProfiles folder];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@"starter.mwm.yml"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@"work.mwm.yaml.bak"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@".hidden.mwm.yaml"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@"notes.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertEqualObjects([MWMProfiles names], (@[@"Desk", @"starter", @"work"]));
  XCTAssertEqualObjects([MWMProfiles pathForName:@"starter"], [folder stringByAppendingPathComponent:@"starter.mwm.yml"]);
  XCTAssertEqualObjects([MWMProfiles pathForName:@"work"], [folder stringByAppendingPathComponent:@"work.mwm.yaml"]);
}

#pragma mark - The active one

- (void)testTheActiveOneFallsBackToDefaultThenTheFirst {
  [self make:@"work"];
  XCTAssertEqualObjects([MWMProfiles activeName], @"work", @"the first one when there is no default");
  [self make:@"default"];
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
  XCTAssertTrue([MWMProfiles setActiveName:@"work"]);
  XCTAssertEqualObjects([MWMProfiles activeName], @"work");
  XCTAssertTrue([MWMProfiles setActiveName:@"gone"]);
  XCTAssertEqualObjects([MWMProfiles activeName], @"default", @"a name that no longer exists is ignored");
}

#pragma mark - Names

- (void)testNamesNeedSomethingToShowAndNoPathCharacters {
  XCTAssertNotNil([MWMProfiles problemWithName:@"  " except:nil]);
  XCTAssertNotNil([MWMProfiles problemWithName:@"a/b" except:nil]);
  XCTAssertNotNil([MWMProfiles problemWithName:@"a:b" except:nil]);
  XCTAssertNotNil([MWMProfiles problemWithName:@".hidden" except:nil]);
  XCTAssertNotNil([MWMProfiles problemWithName:[@"" stringByPaddingToLength:61 withString:@"a" startingAtIndex:0] except:nil]);
  XCTAssertNil([MWMProfiles problemWithName:@"Desk, two monitors" except:nil]);
}

- (void)testANameIsTakenIgnoringCaseUnlessItIsBeingRenamed {
  [self make:@"Desk"];
  XCTAssertNotNil([MWMProfiles problemWithName:@"desk" except:nil]);
  XCTAssertNil([MWMProfiles problemWithName:@"desk" except:@"Desk"]);
  XCTAssertNotNil([MWMProfiles problemWithName:@"Desk" except:@"other"]);
}

- (void)testFreeNamesCountUp {
  XCTAssertEqualObjects([MWMProfiles freeNameFrom:@"work"], @"work");
  [self make:@"work"];
  XCTAssertEqualObjects([MWMProfiles freeNameFrom:@"work"], @"work 2");
  [self make:@"work 2"];
  XCTAssertEqualObjects([MWMProfiles freeNameFrom:@"work"], @"work 3");
}

- (void)testABackupNameBecomesASafeFileName {
  XCTAssertEqualObjects([MWMProfiles fileSafeName:@"Desk: two/monitors"], @"Desk- two-monitors");
  XCTAssertEqualObjects([MWMProfiles fileSafeName:@"..."], @"backup");
  XCTAssertNil([MWMProfiles problemWithName:[MWMProfiles fileSafeName:@"a/b:c"] except:nil]);
}

#pragma mark - Changing

- (void)testCreateWritesTheTextAndRefusesATakenName {
  XCTAssertTrue([self make:@"work"]);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[MWMProfiles pathForName:@"work"] encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# work\n");
  NSError *error = nil;
  XCTAssertFalse([MWMProfiles createNamed:@"WORK" text:@"" error:&error]);
  XCTAssertNotNil(error.localizedDescription);
}

- (void)testDuplicateCopiesTheFile {
  [self make:@"work"];
  XCTAssertTrue([MWMProfiles duplicateNamed:@"work" as:@"work copy" error:nil]);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"work", @"work copy"]));
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[MWMProfiles pathForName:@"work copy"] encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# work\n");
}

- (void)testRenameKeepsTheActiveOneActive {
  [self make:@"default"];
  [self make:@"work"];
  [MWMProfiles setActiveName:@"work"];
  XCTAssertTrue([MWMProfiles renameNamed:@"work" to:@"desk" error:nil]);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"default", @"desk"]));
  XCTAssertEqualObjects([MWMProfiles activeName], @"desk");
}

- (void)testRenameCanOnlyChangeTheCase {
  [self make:@"work"];
  XCTAssertTrue([MWMProfiles renameNamed:@"work" to:@"Work" error:nil]);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"Work"]));
}

- (void)testDeleteMovesToTheTrashButNeverTheActiveOrLastOne {
  [self make:@"default"];
  NSError *error = nil;
  XCTAssertFalse([MWMProfiles deleteNamed:@"default" error:&error]);
  XCTAssertNotNil(error);
  [self make:@"work"];
  XCTAssertFalse([MWMProfiles deleteNamed:@"default" error:&error], @"the active one stays");
  XCTAssertTrue([MWMProfiles deleteNamed:@"work" error:&error], @"%@", error);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"default"]));
}

- (void)testImportCopiesAFileInUnderAFreeName {
  NSString *outside = [self.home stringByAppendingPathComponent:@"starter.mwm.yml"];
  [@"version: 2\n" writeToFile:outside atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertEqualObjects([MWMProfiles importFileAtPath:outside error:nil], @"starter");
  XCTAssertEqualObjects([MWMProfiles importFileAtPath:outside error:nil], @"starter 2");
  XCTAssertEqualObjects([MWMProfiles names], (@[@"starter", @"starter 2"]));
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outside], @"the original stays");
}

- (void)testWriteTextKeepsACopyOfTheOldFile {
  [self make:@"work"];
  XCTAssertTrue([MWMProfiles writeText:@"version: 2\n# new\n" named:@"work" error:nil]);
  NSString *path = [MWMProfiles pathForName:@"work"];
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# new\n");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[path stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# work\n");
  XCTAssertEqual([[MWMProfiles names] count], 1u, @"the copy isn't a profile");
}

@end
