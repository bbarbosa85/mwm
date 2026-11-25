//
//  TestMWMConfigurations.m
//
//  The configurations kept in ~/.mwm: listing, the active one, names, and changing them. Every test
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
#import "MWMConfigurations.h"

@interface TestMWMConfigurations : XCTestCase
@property (copy) NSString *home;
@end

@implementation TestMWMConfigurations

- (void)setUp {
  self.home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.home withIntermediateDirectories:YES attributes:nil error:nil];
  [MWMConfigurations setHomeDirectory:self.home];
}

- (void)tearDown {
  [MWMConfigurations setHomeDirectory:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.home error:nil];
}

- (BOOL)make:(NSString *)name { return [MWMConfigurations createNamed:name text:[NSString stringWithFormat:@"version: 2\n# %@\n", name] error:nil]; }

#pragma mark - Listing

- (void)testThereAreNoConfigurationsBeforeTheFirstOne {
  XCTAssertFalse([MWMConfigurations folderExists]);
  XCTAssertEqual([[MWMConfigurations names] count], 0u);
  XCTAssertEqualObjects([MWMConfigurations activeName], @"default");
  XCTAssertEqualObjects([MWMConfigurations activePath], [self.home stringByAppendingPathComponent:@".mwm/default.mwm.yaml"]);
}

- (void)testFilesAreListedByNameIgnoringTheRest {
  XCTAssertTrue([self make:@"work"]);
  XCTAssertTrue([self make:@"Desk"]);
  NSString *folder = [MWMConfigurations folder];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@"starter.mwm.yml"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@"work.mwm.yaml.bak"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@".hidden.mwm.yaml"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [@"x" writeToFile:[folder stringByAppendingPathComponent:@"notes.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"Desk", @"starter", @"work"]));
  XCTAssertEqualObjects([MWMConfigurations pathForName:@"starter"], [folder stringByAppendingPathComponent:@"starter.mwm.yml"]);
  XCTAssertEqualObjects([MWMConfigurations pathForName:@"work"], [folder stringByAppendingPathComponent:@"work.mwm.yaml"]);
}

#pragma mark - The active one

- (void)testTheActiveOneFallsBackToDefaultThenTheFirst {
  [self make:@"work"];
  XCTAssertEqualObjects([MWMConfigurations activeName], @"work", @"the first one when there is no default");
  [self make:@"default"];
  XCTAssertEqualObjects([MWMConfigurations activeName], @"default");
  XCTAssertTrue([MWMConfigurations setActiveName:@"work"]);
  XCTAssertEqualObjects([MWMConfigurations activeName], @"work");
  XCTAssertTrue([MWMConfigurations setActiveName:@"gone"]);
  XCTAssertEqualObjects([MWMConfigurations activeName], @"default", @"a name that no longer exists is ignored");
}

#pragma mark - Names

- (void)testNamesNeedSomethingToShowAndNoPathCharacters {
  XCTAssertNotNil([MWMConfigurations problemWithName:@"  " except:nil]);
  XCTAssertNotNil([MWMConfigurations problemWithName:@"a/b" except:nil]);
  XCTAssertNotNil([MWMConfigurations problemWithName:@"a:b" except:nil]);
  XCTAssertNotNil([MWMConfigurations problemWithName:@".hidden" except:nil]);
  XCTAssertNotNil([MWMConfigurations problemWithName:[@"" stringByPaddingToLength:61 withString:@"a" startingAtIndex:0] except:nil]);
  XCTAssertNil([MWMConfigurations problemWithName:@"Desk, two monitors" except:nil]);
}

- (void)testANameIsTakenIgnoringCaseUnlessItIsBeingRenamed {
  [self make:@"Desk"];
  XCTAssertNotNil([MWMConfigurations problemWithName:@"desk" except:nil]);
  XCTAssertNil([MWMConfigurations problemWithName:@"desk" except:@"Desk"]);
  XCTAssertNotNil([MWMConfigurations problemWithName:@"Desk" except:@"other"]);
}

- (void)testFreeNamesCountUp {
  XCTAssertEqualObjects([MWMConfigurations freeNameFrom:@"work"], @"work");
  [self make:@"work"];
  XCTAssertEqualObjects([MWMConfigurations freeNameFrom:@"work"], @"work 2");
  [self make:@"work 2"];
  XCTAssertEqualObjects([MWMConfigurations freeNameFrom:@"work"], @"work 3");
}

- (void)testABackupNameBecomesASafeFileName {
  XCTAssertEqualObjects([MWMConfigurations fileSafeName:@"Desk: two/monitors"], @"Desk- two-monitors");
  XCTAssertEqualObjects([MWMConfigurations fileSafeName:@"..."], @"backup");
  XCTAssertNil([MWMConfigurations problemWithName:[MWMConfigurations fileSafeName:@"a/b:c"] except:nil]);
}

#pragma mark - Changing

- (void)testCreateWritesTheTextAndRefusesATakenName {
  XCTAssertTrue([self make:@"work"]);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[MWMConfigurations pathForName:@"work"] encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# work\n");
  NSError *error = nil;
  XCTAssertFalse([MWMConfigurations createNamed:@"WORK" text:@"" error:&error]);
  XCTAssertNotNil(error.localizedDescription);
}

- (void)testDuplicateCopiesTheFile {
  [self make:@"work"];
  XCTAssertTrue([MWMConfigurations duplicateNamed:@"work" as:@"work copy" error:nil]);
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"work", @"work copy"]));
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[MWMConfigurations pathForName:@"work copy"] encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# work\n");
}

- (void)testRenameKeepsTheActiveOneActive {
  [self make:@"default"];
  [self make:@"work"];
  [MWMConfigurations setActiveName:@"work"];
  XCTAssertTrue([MWMConfigurations renameNamed:@"work" to:@"desk" error:nil]);
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"default", @"desk"]));
  XCTAssertEqualObjects([MWMConfigurations activeName], @"desk");
}

- (void)testRenameCanOnlyChangeTheCase {
  [self make:@"work"];
  XCTAssertTrue([MWMConfigurations renameNamed:@"work" to:@"Work" error:nil]);
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"Work"]));
}

- (void)testDeleteMovesToTheTrashButNeverTheActiveOrLastOne {
  [self make:@"default"];
  NSError *error = nil;
  XCTAssertFalse([MWMConfigurations deleteNamed:@"default" error:&error]);
  XCTAssertNotNil(error);
  [self make:@"work"];
  XCTAssertFalse([MWMConfigurations deleteNamed:@"default" error:&error], @"the active one stays");
  XCTAssertTrue([MWMConfigurations deleteNamed:@"work" error:&error], @"%@", error);
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"default"]));
}

- (void)testImportCopiesAFileInUnderAFreeName {
  NSString *outside = [self.home stringByAppendingPathComponent:@"starter.mwm.yml"];
  [@"version: 2\n" writeToFile:outside atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertEqualObjects([MWMConfigurations importFileAtPath:outside error:nil], @"starter");
  XCTAssertEqualObjects([MWMConfigurations importFileAtPath:outside error:nil], @"starter 2");
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"starter", @"starter 2"]));
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outside], @"the original stays");
}

- (void)testWriteTextKeepsACopyOfTheOldFile {
  [self make:@"work"];
  XCTAssertTrue([MWMConfigurations writeText:@"version: 2\n# new\n" named:@"work" error:nil]);
  NSString *path = [MWMConfigurations pathForName:@"work"];
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# new\n");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[path stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], @"version: 2\n# work\n");
  XCTAssertEqual([[MWMConfigurations names] count], 1u, @"the copy isn't a configuration");
}

@end
