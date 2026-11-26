//
//  TestMWMSync.m
//
//  Sync against a small fake of GitHub. Two "computers" are two temporary home folders sharing one gist.
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
#import "MWMGist.h"
#import "MWMSnapshots.h"
#import "MWMSync.h"
#import "TestFakeGitHub.h"

@interface TestMWMSync : XCTestCase
@property (strong) TestFakeGitHub *github;
@property (copy) NSString *homeA;
@property (copy) NSString *homeB;
@end

@implementation TestMWMSync

- (NSString *)makeHome {
  NSString *home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:home withIntermediateDirectories:YES attributes:nil error:nil];
  return home;
}

- (void)setUp {
  self.homeA = [self makeHome];
  self.homeB = [self makeHome];
  self.github = [[TestFakeGitHub alloc] init];
  [self.github install];
  [MWMSnapshots setListsOverride:[NSMutableDictionary dictionary]];
  [MWMSync setSnapshotsModifiedOverride:nil];
  [self useA];
}

- (void)tearDown {
  [MWMGist setTransport:nil];
  [MWMGist useMemoryStorage:NO];
  [MWMProfiles setHomeDirectory:nil];
  [MWMSnapshots setListsOverride:nil];
  [MWMSync setSnapshotsModifiedOverride:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.homeA error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.homeB error:nil];
}

// Sitting at one computer or the other: its folder, and a fresh token and memory of the gist.
- (void)useHome:(NSString *)home {
  [MWMProfiles setHomeDirectory:home];
  [MWMGist useMemoryStorage:YES];
  [MWMGist setToken:@"ghp_test"];
}
- (void)useA { [self useHome:self.homeA]; }
- (void)useB { [self useHome:self.homeB]; }

- (void)make:(NSString *)name text:(NSString *)text { XCTAssertTrue([MWMProfiles createNamed:name text:text error:nil]); }
- (NSString *)textOf:(NSString *)name { return [NSString stringWithContentsOfFile:[MWMProfiles pathForName:name] encoding:NSUTF8StringEncoding error:nil]; }
- (void)touch:(NSString *)name daysAgo:(double)days {
  [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: [NSDate dateWithTimeIntervalSinceNow:-86400 * days]} ofItemAtPath:[MWMProfiles pathForName:name] error:nil];
}

- (MWMSyncReport *)sync {
  __block MWMSyncReport *result;
  XCTestExpectation *e = [self expectationWithDescription:@"sync"];
  [MWMSync syncWithCompletion:^(MWMSyncReport *report) { result = report; [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:30];
  return result;
}

- (NSString *)resolve:(NSArray<MWMSyncItem *> *)items keep:(BOOL)keep {
  __block NSString *notes;
  XCTestExpectation *e = [self expectationWithDescription:@"resolve"];
  [MWMSync resolveFlagged:items keep:keep completion:^(NSString *n, NSString *problem) { XCTAssertNil(problem); notes = n; [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:30];
  return notes;
}

- (MWMSyncItem *)item:(NSString *)name in:(MWMSyncReport *)report {
  for (MWMSyncItem *item in report.items) if ([item.name caseInsensitiveCompare:name] == NSOrderedSame) return item;
  return nil;
}

#pragma mark - Sending and receiving

- (void)testTheFirstSyncSendsEveryProfileAsAPlainFile {
  [self make:@"default" text:@"version: 2\n# default\n"];
  [self make:@"desk" text:@"version: 2\n# desk\n"];
  MWMSyncReport *report = [self sync];
  XCTAssertNil(report.problem);
  XCTAssertEqual(report.sent, 2u);
  NSDictionary *files = [self.github backupFiles];
  XCTAssertEqualObjects(files[@"desk.mwm.yaml"], @"version: 2\n# desk\n");
  XCTAssertEqualObjects(files[@"default.mwm.yaml"], @"version: 2\n# default\n");
  XCTAssertNotNil(files[@"mwm-sync.json"]);
  XCTAssertEqual([self.github.gists count], 1u);
  XCTAssertEqualObjects([[self.github.gists allValues][0] objectForKey:@"public"], @NO);
}

- (void)testAnotherComputerReceivesThemAndTheNextSyncHasNothingToDo {
  [self make:@"default" text:@"version: 2\n# default\n"];
  [self make:@"desk" text:@"version: 2\n# desk\n"];
  [self sync];
  [self useB];
  MWMSyncReport *report = [self sync];
  XCTAssertEqual(report.received, 2u);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"default", @"desk"]));
  XCTAssertEqualObjects([self textOf:@"desk"], @"version: 2\n# desk\n");
  MWMSyncReport *again = [self sync];
  XCTAssertEqual(again.sent + again.received, 0u);
  XCTAssertEqual(again.upToDate, 2u);
  XCTAssertNotNil([MWMSync lastSyncDate]);
  XCTAssertEqualObjects([MWMSync lastSummary], @"Sent 0, received 0, 2 up to date");
}

- (void)testTheActiveChoiceStaysOnEachComputer {
  [self make:@"default" text:@"version: 2\n"];
  [self make:@"desk" text:@"version: 2\n# desk\n"];
  [MWMProfiles setActiveName:@"desk"];
  [self sync];
  [self useB];
  [self sync];
  XCTAssertEqualObjects([MWMProfiles activeName], @"default", @"B didn't pick up A's choice");
}

- (void)testAChangeTravelsAndTheReplacedFileKeepsACopy {
  [self make:@"desk" text:@"v1\n"];
  [self sync];
  [self useB];
  [self sync];
  [self useA];
  [MWMProfiles writeText:@"v2\n" named:@"desk" error:nil];
  XCTAssertEqual([self sync].sent, 1u);
  [self useB];
  MWMSyncReport *report = [self sync];
  XCTAssertEqual(report.received, 1u);
  XCTAssertEqualObjects([self textOf:@"desk"], @"v2\n");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[[MWMProfiles pathForName:@"desk"] stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], @"v1\n");
}

- (void)testChangedOnBothSidesTheNewerWinsAndTheOtherIsKept {
  [self make:@"desk" text:@"v1\n"];
  [self sync];
  [self useB];
  [self sync];
  [MWMProfiles writeText:@"from B\n" named:@"desk" error:nil];
  [self touch:@"desk" daysAgo:3];
  [self useA];
  [MWMProfiles writeText:@"from A\n" named:@"desk" error:nil];
  [self touch:@"desk" daysAgo:1];
  XCTAssertEqual([self sync].sent, 1u, @"A is newer, so it is sent");
  [self useB];
  MWMSyncReport *report = [self sync];
  XCTAssertTrue([self item:@"desk" in:report].conflict);
  XCTAssertEqualObjects([self textOf:@"desk"], @"from A\n");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[[MWMProfiles pathForName:@"desk"] stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], @"from B\n", @"what B lost is kept");
}

- (void)testOtherFilesInTheGistAreLeftAlone {
  [self make:@"desk" text:@"v1\n"];
  [self sync];
  [self.github addFile:@"mwm-0123456789abcdef.json" content:@"{\"name\": \"old backup\"}" toGistWithDescription:@"MWM backup"];
  [self.github addFile:@"notes.txt" content:@"hello" toGistWithDescription:@"MWM backup"];
  [self useB];
  MWMSyncReport *report = [self sync];
  XCTAssertEqualObjects([MWMProfiles names], (@[@"desk"]));
  XCTAssertEqual([report.items count], 1u);
  XCTAssertEqualObjects([self.github backupFiles][@"notes.txt"], @"hello");
}

- (void)testItMatchesNamesIgnoringCase {
  [self make:@"Desk" text:@"v1\n"];
  [self sync];
  [self useB];
  [self sync];
  XCTAssertEqualObjects([MWMProfiles names], (@[@"Desk"]));
  XCTAssertEqual([self.github backupFiles].count, 2u, @"one profile file and the manifest");
}

#pragma mark - Deleted profiles

- (MWMSyncReport *)deleteDeskOnAndSync {
  [self make:@"default" text:@"version: 2\n"];
  [self make:@"desk" text:@"v1\n"];
  [self sync];
  XCTAssertTrue([MWMProfiles deleteNamed:@"desk" error:nil]);
  return [self sync];
}

- (void)testADeletedProfileIsFlaggedAndNothingIsDeleted {
  MWMSyncReport *report = [self deleteDeskOnAndSync];
  XCTAssertEqual([report.flagged count], 1u);
  XCTAssertEqual(report.flagged[0].status, MWMSyncStatusDeletedHere);
  XCTAssertNotNil([self.github backupFiles][@"desk.mwm.yaml"], @"the gist still has it");
  XCTAssertEqual([self sync].flagged.count, 1u, @"still flagged until the person chooses");
}

- (void)testKeepingABringsItBackHere {
  MWMSyncReport *report = [self deleteDeskOnAndSync];
  NSString *notes = [self resolve:report.flagged keep:YES];
  XCTAssertTrue([notes containsString:@"back here"], @"%@", notes);
  XCTAssertEqualObjects([self textOf:@"desk"], @"v1\n");
  XCTAssertEqual([self sync].flagged.count, 0u);
}

- (void)testClearingItRemovesItFromTheGistAndTheOtherComputerFlagsIt {
  MWMSyncReport *report = [self deleteDeskOnAndSync];
  [self resolve:report.flagged keep:NO];
  XCTAssertNil([self.github backupFiles][@"desk.mwm.yaml"]);
  XCTAssertNil([self.github backupFiles][@"mwm-sync.json"] ? ([[self.github backupFiles][@"mwm-sync.json"] containsString:@"desk"] ? @"in manifest" : nil) : nil);
}

- (void)testAnotherComputerFlagsWhatWasRemovedFromTheGistAndClearingTrashesItThere {
  [self make:@"default" text:@"version: 2\n"];
  [self make:@"desk" text:@"v1\n"];
  [self sync];
  [self useB];
  [self sync];
  [self useA];
  XCTAssertTrue([MWMProfiles deleteNamed:@"desk" error:nil]);
  [self resolve:[self sync].flagged keep:NO];
  [self useB];
  MWMSyncReport *report = [self sync];
  XCTAssertEqual([report.flagged count], 1u);
  XCTAssertEqual(report.flagged[0].status, MWMSyncStatusDeletedInGist);
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[MWMProfiles pathForName:@"desk"]], @"not removed until the person chooses");
  NSString *notes = [self resolve:report.flagged keep:NO];
  XCTAssertTrue([notes containsString:@"Trash"], @"%@", notes);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"default"]));
}

- (void)testKeepingOneThatWasRemovedFromTheGistSendsItAgain {
  [self make:@"default" text:@"version: 2\n"];
  [self make:@"desk" text:@"v1\n"];
  [self sync];
  [self useB];
  [self sync];
  [self useA];
  [MWMProfiles deleteNamed:@"desk" error:nil];
  [self resolve:[self sync].flagged keep:NO];
  [self useB];
  [self resolve:[self sync].flagged keep:YES];
  XCTAssertEqualObjects([self.github backupFiles][@"desk.mwm.yaml"], @"v1\n");
}

- (void)testAKeptProfileTakesADatedNameWhenTheNameWasUsedMeanwhile {
  MWMSyncReport *report = [self deleteDeskOnAndSync];
  [self make:@"desk" text:@"something new\n"];
  NSString *notes = [self resolve:report.flagged keep:YES];
  XCTAssertEqual([[MWMProfiles names] count], 3u, @"%@", [MWMProfiles names]);
  XCTAssertTrue([notes containsString:@"as “desk ("], @"%@", notes);
  XCTAssertEqualObjects([self textOf:@"desk"], @"something new\n");
}

- (void)testAChangeBeatsADeletion {
  [self make:@"default" text:@"version: 2\n"];
  [self make:@"desk" text:@"v1\n"];
  [self sync];
  [self useB];
  [self sync];
  [MWMProfiles deleteNamed:@"desk" error:nil];
  [self sync];   // flagged on B, left alone
  [self useA];
  [MWMProfiles writeText:@"v2\n" named:@"desk" error:nil];
  [self sync];
  [self useB];
  MWMSyncReport *report = [self sync];
  XCTAssertEqual([report.flagged count], 0u);
  XCTAssertEqualObjects([self textOf:@"desk"], @"v2\n", @"the edit comes back instead of being deleted");
}

#pragma mark - Problems and snapshots

- (void)testAProblemIsReportedInWordsAndNothingChanges {
  [self make:@"desk" text:@"v1\n"];
  self.github.status = 401;
  MWMSyncReport *report = [self sync];
  XCTAssertTrue([report.problem containsString:@"didn't accept the token"], @"%@", report.problem);
  XCTAssertEqual(report.sent + report.received, 0u);
  XCTAssertNil([MWMSync lastSyncDate]);
}

- (void)testPreviewChangesNothing {
  [self make:@"desk" text:@"v1\n"];
  XCTestExpectation *e = [self expectationWithDescription:@"preview"];
  [MWMSync preview:^(NSArray<MWMSyncItem *> *items, NSString *problem) {
    XCTAssertNil(problem);
    XCTAssertEqual(items.count, 1u);
    XCTAssertEqual(items[0].status, MWMSyncStatusOnlyHere);
    [e fulfill];
  }];
  [self waitForExpectations:@[e] timeout:30];
  XCTAssertEqual([self.github.gists count], 0u, @"no gist was made");
  XCTAssertNil([MWMSync lastSyncDate]);
}

- (void)testSnapshotsTravelToo {
  [self make:@"desk" text:@"v1\n"];
  [MWMSnapshots importAll:@{@"work": @{@"name": @"work"}}];
  XCTAssertEqual([[MWMSnapshots exportAll] count], 1u);
  XCTAssertEqual([self sync].sent, 2u);
  XCTAssertNotNil([self.github backupFiles][@"snapshots.json"]);
  [self useB];
  [MWMSnapshots setListsOverride:[NSMutableDictionary dictionary]];
  MWMSyncReport *report = [self sync];
  XCTAssertEqual(report.received, 2u);
  XCTAssertEqualObjects([[MWMSnapshots exportAll] allKeys], @[@"work"]);
}

@end
