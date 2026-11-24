//
//  TestMWMBackup.m
//
//  Backups: the environment file, the names, which one matches the displays, and the gist API
//  (against a small fake of GitHub).
//
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
#import "MWMBackup.h"
#import "MWMDisplays.h"
#import "MWMGist.h"
#import "TestFakeGitHub.h"

@interface TestMWMBackup : XCTestCase
@property (strong) TestFakeGitHub *github;
@end

@implementation TestMWMBackup

- (void)setUp {
  [MWMGist useMemoryStorage:YES];
  self.github = [[TestFakeGitHub alloc] init];
  [self.github install];
  [MWMGist setToken:@"ghp_test"];
}

- (void)tearDown {
  [MWMGist setTransport:nil];
  [MWMGist useMemoryStorage:NO];
}

- (NSArray<MWMDisplay *> *)desk {
  return @[[MWMDisplay displayNamed:@"Samsung Odyssey G9" width:5120 height:1440 builtIn:NO x:0 y:0], [MWMDisplay displayNamed:@"Built-in" width:3024 height:1964 builtIn:YES x:-3024 y:0]];
}

- (MWMBackupEnvironment *)environmentNamed:(NSString *)name text:(NSString *)text date:(NSDate *)date {
  return [MWMBackupEnvironment environmentNamed:name configText:text snapshots:@{@"coding": @{@"name": @"coding"}} displays:[self desk] date:date];
}

- (NSString *)configText { return @"version: 2\n\nmodifiers:\n  hyper: [ctrl, alt, cmd]\n"; }

#pragma mark - The file

- (void)testAnEnvironmentSurvivesItsFile {
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:1700000000];
  MWMBackupEnvironment *environment = [self environmentNamed:@"  Desk  " text:[self configText] date:date];
  XCTAssertEqualObjects(environment.name, @"Desk");
  MWMBackupEnvironment *back = [MWMBackupEnvironment environmentFromFileData:[environment fileData]];
  XCTAssertNotNil(back);
  XCTAssertEqualObjects(back.name, @"Desk");
  XCTAssertEqualObjects(back.configText, [self configText]);
  XCTAssertEqualObjects(back.snapshots, environment.snapshots);
  XCTAssertEqual(back.snapshotCount, 1u);
  XCTAssertEqual([back.savedAt timeIntervalSince1970], 1700000000);
  XCTAssertEqual([back.displays count], 2u);
  XCTAssertEqualObjects([back.displays[0] name], @"Samsung Odyssey G9");
  XCTAssertEqual([back.displays[0] width], 5120);
  XCTAssertTrue([back.displays[1] builtIn]);
}

- (void)testTheCountsComeFromTheConfiguration {
  MWMBackupEnvironment *environment = [self environmentNamed:@"Desk" text:[self configText] date:[NSDate date]];
  XCTAssertEqual(environment.modifierCount, 1u);
  XCTAssertEqual(environment.shortcutCount, 0u);
}

- (void)testAFileThatIsNotABackupIsRefused {
  XCTAssertNil([MWMBackupEnvironment environmentFromFileData:[@"nope" dataUsingEncoding:NSUTF8StringEncoding]]);
  XCTAssertNil([MWMBackupEnvironment environmentFromFileData:[@"{\"name\": \"x\"}" dataUsingEncoding:NSUTF8StringEncoding]]);
  XCTAssertNil([MWMBackupEnvironment environmentFromFileData:nil]);
}

#pragma mark - Names and files

- (void)testTheSameNameAlwaysGivesTheSameFile {
  XCTAssertEqualObjects([MWMBackupEnvironment fileNameForName:@"Desk"], [MWMBackupEnvironment fileNameForName:@" desk "]);
  XCTAssertNotEqualObjects([MWMBackupEnvironment fileNameForName:@"Desk"], [MWMBackupEnvironment fileNameForName:@"Laptop"]);
  XCTAssertTrue([MWMBackupEnvironment isEnvironmentFileName:[MWMBackupEnvironment fileNameForName:@"Desk"]]);
  XCTAssertFalse([MWMBackupEnvironment isEnvironmentFileName:@"README.md"]);
}

- (void)testNamesNeedSomethingToShow {
  XCTAssertNotNil([MWMBackupEnvironment problemWithName:@"   "]);
  XCTAssertNotNil([MWMBackupEnvironment problemWithName:[@"" stringByPaddingToLength:61 withString:@"a" startingAtIndex:0]]);
  XCTAssertNil([MWMBackupEnvironment problemWithName:@"Desk, two monitors"]);
}

#pragma mark - Matching the displays

- (void)testItMatchesTheSameDisplaysInAnyOrder {
  MWMBackupEnvironment *environment = [self environmentNamed:@"Desk" text:@"" date:[NSDate date]];
  XCTAssertTrue([environment matchesDisplays:[[self desk] reverseObjectEnumerator].allObjects]);
  MWMDisplay *builtIn = [self desk][1];
  MWMDisplay *narrow = [MWMDisplay displayNamed:@"Samsung Odyssey G9" width:2560 height:1440 builtIn:NO x:0 y:0];
  XCTAssertFalse([environment matchesDisplays:@[builtIn]]);
  NSArray *different = @[builtIn, narrow];
  XCTAssertFalse([environment matchesDisplays:different]);
}

- (void)testDisplaysReadWithTheirSize {
  XCTAssertEqualObjects([MWMBackupEnvironment descriptionOfDisplay:[self desk][0]], @"Samsung Odyssey G9 (5120 × 1440)");
}

#pragma mark - The gist

- (void)wait:(void (^)(XCTestExpectation *))body {
  XCTestExpectation *expectation = [self expectationWithDescription:@"gist"];
  body(expectation);
  [self waitForExpectations:@[expectation] timeout:5];
}

- (NSArray<MWMBackupEnvironment *> *)listed {
  __block NSArray *result;
  [self wait:^(XCTestExpectation *e) {
    [MWMGist listEnvironments:^(NSArray *environments, NSString *problem) { XCTAssertNil(problem); result = environments; [e fulfill]; }];
  }];
  return result;
}

- (void)save:(MWMBackupEnvironment *)environment {
  [self wait:^(XCTestExpectation *e) {
    [MWMGist saveEnvironment:environment completion:^(NSString *problem) { XCTAssertNil(problem); [e fulfill]; }];
  }];
}

- (void)testNothingIsListedBeforeTheFirstBackup {
  XCTAssertEqual([[self listed] count], 0u);
  XCTAssertEqual(self.github.gists.count, 0u);
}

- (void)testTheFirstBackupMakesAPrivateGist {
  [self save:[self environmentNamed:@"Desk" text:[self configText] date:[NSDate date]]];
  XCTAssertEqual(self.github.gists.count, 1u);
  NSDictionary *gist = [self.github.gists allValues][0];
  XCTAssertEqualObjects(gist[@"public"], @NO);
  XCTAssertEqualObjects(gist[@"description"], @"MWM backup");
  XCTAssertEqual([[self listed] count], 1u);
  XCTAssertEqualObjects([self listed][0].name, @"Desk");
}

- (void)testTheSameNameReplacesAndANewNameAdds {
  [self save:[self environmentNamed:@"Desk" text:@"version: 2\n" date:[NSDate dateWithTimeIntervalSince1970:100]]];
  [self save:[self environmentNamed:@"desk" text:[self configText] date:[NSDate dateWithTimeIntervalSince1970:200]]];
  NSArray *listed = [self listed];
  XCTAssertEqual([listed count], 1u);
  XCTAssertEqualObjects([listed[0] configText], [self configText]);
  [self save:[self environmentNamed:@"Laptop" text:@"" date:[NSDate dateWithTimeIntervalSince1970:300]]];
  listed = [self listed];
  XCTAssertEqual([listed count], 2u);
  XCTAssertEqualObjects([listed[0] name], @"Laptop", @"newest first");
  XCTAssertEqual(self.github.gists.count, 1u, @"one gist holds every environment");
}

- (void)testDeletingRemovesOnlyThatEnvironment {
  [self save:[self environmentNamed:@"Desk" text:@"" date:[NSDate date]]];
  [self save:[self environmentNamed:@"Laptop" text:@"" date:[NSDate date]]];
  [self wait:^(XCTestExpectation *e) {
    [MWMGist deleteEnvironmentNamed:@"Desk" completion:^(NSString *problem) { XCTAssertNil(problem); [e fulfill]; }];
  }];
  NSArray *listed = [self listed];
  XCTAssertEqual([listed count], 1u);
  XCTAssertEqualObjects([listed[0] name], @"Laptop");
}

- (void)testOtherFilesInTheGistAreIgnored {
  [self save:[self environmentNamed:@"Desk" text:@"" date:[NSDate date]]];
  [self.github addFile:@"notes.txt" content:@"hello" toGistWithDescription:@"MWM backup"];
  XCTAssertEqual([[self listed] count], 1u);
}

- (void)testAForgottenGistIsFoundAgainByItsDescription {
  [self save:[self environmentNamed:@"Desk" text:@"" date:[NSDate date]]];
  [MWMGist useMemoryStorage:YES];   // forgets the remembered gist (and the token)
  [MWMGist setToken:@"ghp_test"];
  XCTAssertEqual([[self listed] count], 1u);
  [self save:[self environmentNamed:@"Laptop" text:@"" date:[NSDate date]]];
  XCTAssertEqual(self.github.gists.count, 1u, @"no second gist");
}

- (void)testAPublicGistWithTheSameNameIsNeverUsed {
  [self.github addPublicGistNamed:@"MWM backup"];
  XCTAssertEqual([[self listed] count], 0u);
  [self save:[self environmentNamed:@"Desk" text:@"" date:[NSDate date]]];
  XCTAssertEqual(self.github.gists.count, 2u);
}

- (void)testProblemsAreSaidInPlainWords {
  self.github.status = 401;
  [self wait:^(XCTestExpectation *e) {
    [MWMGist checkToken:@"bad" completion:^(NSString *problem) { XCTAssertTrue([problem containsString:@"didn't accept the token"]); [e fulfill]; }];
  }];
  self.github.status = 500;
  [self wait:^(XCTestExpectation *e) {
    [MWMGist listEnvironments:^(NSArray *environments, NSString *problem) { XCTAssertTrue([problem containsString:@"500"]); [e fulfill]; }];
  }];
  [MWMGist setToken:nil];
  [self wait:^(XCTestExpectation *e) {
    [MWMGist listEnvironments:^(NSArray *environments, NSString *problem) { XCTAssertEqualObjects(problem, @"Add a GitHub token first."); [e fulfill]; }];
  }];
}

- (void)testTheTokenIsSentAndNothingElseIdentifiesThePerson {
  [self save:[self environmentNamed:@"Desk" text:@"" date:[NSDate date]]];
  for (NSURLRequest *request in self.github.requests) {
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Authorization"], @"Bearer ghp_test");
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"User-Agent"], @"MWM");
  }
}

@end
