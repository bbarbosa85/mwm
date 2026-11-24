//
//  TestConfigurationBackup.m
//
//  The Backup page: connecting a token, backing up (a name that exists replaces), restoring and deleting.
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
#import <objc/runtime.h>
#import "ConfigurationBackupView.h"
#import "MWMConfigDocument.h"
#import "MWMDisplays.h"
#import "MWMGist.h"
#import "MWMSnapshots.h"
#import "SnapshotList.h"
#import "TestFakeGitHub.h"

@interface TestConfigurationBackup : XCTestCase <ConfigurationBackupViewDelegate>
@property (strong) TestFakeGitHub *github;
@property (strong) NSMutableDictionary *lists;
@property (copy) NSString *restoredText;
@property (assign) NSUInteger snapshotRestores;
@property (assign) BOOL restoreWorks;
@end

@implementation TestConfigurationBackup

- (BOOL)backupView:(ConfigurationBackupView *)view restoreConfigText:(NSString *)text { self.restoredText = text; return self.restoreWorks; }
- (void)backupViewDidRestoreSnapshots:(ConfigurationBackupView *)view { self.snapshotRestores++; }

- (NSArray<MWMDisplay *> *)desk {
  return @[[MWMDisplay displayNamed:@"Samsung Odyssey G9" width:5120 height:1440 builtIn:NO x:0 y:0], [MWMDisplay displayNamed:@"Built-in" width:3024 height:1964 builtIn:YES x:-3024 y:0]];
}

- (void)setUp {
  [MWMGist useMemoryStorage:YES];
  self.github = [[TestFakeGitHub alloc] init];
  [self.github install];
  self.lists = [NSMutableDictionary dictionary];
  self.lists[@"coding"] = [[SnapshotList alloc] initWithName:@"coding" saveToDisk:YES isStack:NO];
  [MWMSnapshots setListsOverride:self.lists];
  [MWMDisplays setConnectedOverride:[self desk]];
  self.restoreWorks = YES;
  self.restoredText = nil;
  self.snapshotRestores = 0;
}

- (void)tearDown {
  [MWMGist setTransport:nil];
  [MWMGist useMemoryStorage:NO];
  [MWMSnapshots setListsOverride:nil];
  [MWMDisplays setConnectedOverride:nil];
}

- (ConfigurationBackupView *)pageConnected:(BOOL)connected {
  if (connected) [MWMGist setToken:@"ghp_test"];
  ConfigurationBackupView *page = [[ConfigurationBackupView alloc] initWithFrame:NSMakeRect(0, 0, 840, 640)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 840, 640) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:page];
  page.delegate = self;
  page.interactive = NO;
  page.document = [[MWMConfigDocument alloc] init];
  objc_setAssociatedObject(page, "window", window, OBJC_ASSOCIATION_RETAIN);
  [self refresh:page];
  return page;
}

- (void)refresh:(ConfigurationBackupView *)page {
  XCTestExpectation *e = [self expectationWithDescription:@"refresh"];
  [page refresh:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:5];
  [page.window layoutIfNeeded];
}

- (NSView *)viewIn:(NSView *)root identifier:(NSString *)identifier {
  NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([[view identifier] isEqualToString:identifier]) return view;
    [queue addObjectsFromArray:[view subviews]];
  }
  return nil;
}

- (void)backUp:(ConfigurationBackupView *)page as:(NSString *)name {
  XCTestExpectation *e = [self expectationWithDescription:@"backup"];
  [page backUpAs:name completion:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:5];
  [page.window layoutIfNeeded];
}

- (void)testWithoutATokenOnlyTheTokenCardShows {
  ConfigurationBackupView *page = [self pageConnected:NO];
  XCTAssertNotNil([self viewIn:page identifier:@"backup-token-card"]);
  XCTAssertNil([self viewIn:page identifier:@"backup-now"]);
}

- (void)testTheTokenCardGivesThreeStepsAndALinkToGitHub {
  ConfigurationBackupView *page = [self pageConnected:NO];
  for (NSString *step in @[@"backup-step-1", @"backup-step-2", @"backup-step-3"]) XCTAssertNotNil([self viewIn:page identifier:step], @"%@", step);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-create-token"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-keychain-note"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-token"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-connect"]);
}

- (void)testConnectingKeepsTheTokenAndShowsThePage {
  ConfigurationBackupView *page = [self pageConnected:NO];
  XCTestExpectation *e = [self expectationWithDescription:@"connect"];
  [page connectWithToken:@"  ghp_new  " completion:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:5];
  XCTAssertEqualObjects([MWMGist token], @"ghp_new");
  XCTAssertNil([self viewIn:page identifier:@"backup-token-card"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-now"]);
}

- (void)testATokenGitHubRefusesIsNotKept {
  ConfigurationBackupView *page = [self pageConnected:NO];
  self.github.status = 401;
  XCTestExpectation *e = [self expectationWithDescription:@"connect"];
  [page connectWithToken:@"bad" completion:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:5];
  XCTAssertNil([MWMGist token]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-token-card"]);
}

- (void)testThisComputerListsItsDisplaysAndCounts {
  ConfigurationBackupView *page = [self pageConnected:YES];
  NSView *facts = [self viewIn:page identifier:@"backup-now-facts"];
  XCTAssertNotNil(facts);
  NSView *counts = [self viewIn:facts identifier:@"backup-counts"];
  NSMutableArray *texts = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:facts];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSTextField class]]) [texts addObject:[(NSTextField *)view stringValue]];
    [queue addObjectsFromArray:[view subviews]];
  }
  XCTAssertNotNil(counts);
  XCTAssertTrue([texts containsObject:@"Samsung Odyssey G9 (5120 × 1440)"] || [[texts componentsJoinedByString:@"|"] containsString:@"Samsung Odyssey G9"]);
  XCTAssertTrue([texts containsObject:@"0 shortcuts"]);
  XCTAssertTrue([texts containsObject:@"0 modifiers"]);
  XCTAssertTrue([texts containsObject:@"1 snapshot"]);
}

- (void)testBackingUpMakesACardThatMatchesTheDisplays {
  ConfigurationBackupView *page = [self pageConnected:YES];
  XCTAssertNotNil([self viewIn:page identifier:@"backup-empty"]);
  [self backUp:page as:@"Desk, two monitors"];
  XCTAssertEqual([page.environments count], 1u);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-Desk, two monitors"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-matches"]);
  XCTAssertNil([self viewIn:page identifier:@"backup-empty"]);
}

- (void)testAnotherSetOfDisplaysDoesNotMatch {
  ConfigurationBackupView *page = [self pageConnected:YES];
  [self backUp:page as:@"Desk"];
  [MWMDisplays setConnectedOverride:@[[self desk][1]]];
  [self refresh:page];
  XCTAssertNil([self viewIn:page identifier:@"backup-matches"]);
}

- (void)testTheSameNameReplacesTheBackup {
  ConfigurationBackupView *page = [self pageConnected:YES];
  [self backUp:page as:@"Desk"];
  [self backUp:page as:@" Desk "];
  XCTAssertEqual([page.environments count], 1u);
  [self backUp:page as:@"Laptop"];
  XCTAssertEqual([page.environments count], 2u);
}

- (void)testRestoringHandsTheConfigurationBackAndBringsTheSnapshots {
  ConfigurationBackupView *page = [self pageConnected:YES];
  [self backUp:page as:@"Desk"];
  [self.lists removeAllObjects];
  [page restoreNamed:@"Desk"];
  XCTAssertNotNil(self.restoredText);
  XCTAssertEqualObjects(self.restoredText, [page.document stringRepresentation]);
  XCTAssertNotNil(self.lists[@"coding"]);
  XCTAssertEqual(self.snapshotRestores, 1u);
}

- (void)testSnapshotsStayWhenTheConfigurationCantBeRestored {
  ConfigurationBackupView *page = [self pageConnected:YES];
  [self backUp:page as:@"Desk"];
  [self.lists removeAllObjects];
  self.restoreWorks = NO;
  [page restoreNamed:@"Desk"];
  XCTAssertEqual([self.lists count], 0u);
  XCTAssertEqual(self.snapshotRestores, 0u);
}

- (void)testDeletingRemovesTheCard {
  ConfigurationBackupView *page = [self pageConnected:YES];
  [self backUp:page as:@"Desk"];
  XCTestExpectation *e = [self expectationWithDescription:@"delete"];
  [page deleteNamed:@"Desk" completion:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:5];
  XCTAssertEqual([page.environments count], 0u);
  XCTAssertNil([self viewIn:page identifier:@"backup-Desk"]);
}

- (void)testAProblemIsShownWithTryAgain {
  ConfigurationBackupView *page = [self pageConnected:YES];
  self.github.status = 500;
  [self refresh:page];
  XCTAssertNotNil(page.problem);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-problem"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-retry"]);
  self.github.status = 200;
  [self refresh:page];
  XCTAssertNil(page.problem);
}

- (void)testBackUpWaitsForAName {
  ConfigurationBackupView *page = [self pageConnected:YES];
  NSButton *save = (NSButton *)[self viewIn:page identifier:@"backup-save"];
  XCTAssertTrue([save isEnabled]);
  [page.nameField setStringValue:@"  "];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:page.nameField];
  XCTAssertFalse([save isEnabled]);
}

@end
