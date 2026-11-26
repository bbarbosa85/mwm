//
//  TestProfileBackup.m
//
//  The Backup page: connecting with a token, the sync card and the list of where each profile stands.
//  Every test uses a temporary home folder and a fake GitHub, and asks nothing.
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
#import "MWMProfiles.h"
#import "MWMGist.h"
#import "MWMSnapshots.h"
#import "MWMSync.h"
#import "TestFakeGitHub.h"

@interface TestProfileBackup : XCTestCase <ConfigurationBackupViewDelegate>
@property (strong) TestFakeGitHub *github;
@property (copy) NSString *home;
@property (assign) NSUInteger filesChanged;
@end

@implementation TestProfileBackup

- (void)backupViewDidChangeFiles:(ConfigurationBackupView *)view { self.filesChanged++; }

- (void)setUp {
  self.home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.home withIntermediateDirectories:YES attributes:nil error:nil];
  [MWMProfiles setHomeDirectory:self.home];
  [MWMGist useMemoryStorage:YES];
  self.github = [[TestFakeGitHub alloc] init];
  [self.github install];
  [MWMSnapshots setListsOverride:[NSMutableDictionary dictionary]];
  self.filesChanged = 0;
}

- (void)tearDown {
  [MWMGist setTransport:nil];
  [MWMGist useMemoryStorage:NO];
  [MWMSnapshots setListsOverride:nil];
  [MWMProfiles setHomeDirectory:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.home error:nil];
}

- (void)make:(NSString *)name text:(NSString *)text { [MWMProfiles createNamed:name text:text error:nil]; }

- (ConfigurationBackupView *)pageConnected:(BOOL)connected {
  if (connected) [MWMGist setToken:@"ghp_test"];
  ConfigurationBackupView *page = [[ConfigurationBackupView alloc] initWithFrame:NSMakeRect(0, 0, 840, 640)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 840, 640) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:page];
  page.delegate = self;
  page.interactive = NO;
  objc_setAssociatedObject(page, "window", window, OBJC_ASSOCIATION_RETAIN);
  [self refresh:page];
  return page;
}

- (void)refresh:(ConfigurationBackupView *)page {
  XCTestExpectation *e = [self expectationWithDescription:@"refresh"];
  [page refresh:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:30];
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

- (void)sync:(ConfigurationBackupView *)page {
  XCTestExpectation *e = [self expectationWithDescription:@"sync"];
  [page syncWithCompletion:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:30];
  [page.window layoutIfNeeded];
}

#pragma mark - Connecting

- (void)testWithoutATokenOnlyTheStepsShow {
  ConfigurationBackupView *page = [self pageConnected:NO];
  XCTAssertNotNil([self viewIn:page identifier:@"backup-token-card"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-step-1"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-create-token"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-connect"]);
  XCTAssertNil([self viewIn:page identifier:@"backup-sync"]);
}

- (void)testAGoodTokenIsKeptAndShowsTheSyncCard {
  ConfigurationBackupView *page = [self pageConnected:NO];
  XCTestExpectation *e = [self expectationWithDescription:@"connect"];
  [page connectWithToken:@"  ghp_good \n" completion:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:30];
  [page.window layoutIfNeeded];
  XCTAssertEqualObjects([MWMGist token], @"ghp_good");
  XCTAssertNotNil([self viewIn:page identifier:@"backup-sync"]);
  XCTAssertNil([self viewIn:page identifier:@"backup-token-card"]);
}

- (void)testATokenGitHubRefusesIsNotKept {
  ConfigurationBackupView *page = [self pageConnected:NO];
  self.github.status = 401;
  XCTestExpectation *e = [self expectationWithDescription:@"connect"];
  [page connectWithToken:@"ghp_bad" completion:^{ [e fulfill]; }];
  [self waitForExpectations:@[e] timeout:30];
  XCTAssertNil([MWMGist token]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-token-card"]);
}

- (void)testChangeTokenShowsTheStepsAgain {
  ConfigurationBackupView *page = [self pageConnected:YES];
  XCTAssertNil([self viewIn:page identifier:@"backup-token-card"]);
  [(NSButton *)[self viewIn:page identifier:@"backup-change-token"] performClick:nil];
  XCTAssertNotNil([self viewIn:page identifier:@"backup-token-card"]);
}

#pragma mark - The list

- (void)testWithNothingToSyncItSaysSo {
  ConfigurationBackupView *page = [self pageConnected:YES];
  XCTAssertNotNil([self viewIn:page identifier:@"backup-sync"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-empty"]);
}

- (void)testEachProfileIsARowWithItsStatus {
  [self make:@"default" text:@"version: 2\n"];
  [self make:@"desk" text:@"version: 2\n# desk\n"];
  [self.github addBackupGistWithFiles:@{@"default.mwm.yaml": @"version: 2\n", @"laptop.mwm.yaml": @"x\n"}];
  ConfigurationBackupView *page = [self pageConnected:YES];
  for (NSString *name in @[@"default", @"desk", @"laptop"]) XCTAssertNotNil([self viewIn:page identifier:[@"backup-item-" stringByAppendingString:name]], @"%@", name);
  XCTAssertEqual([page.items count], 3u);
  XCTAssertNil(page.problem);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-status-default"], @"the chip");
}

- (void)testNothingIsOfferedPerConfiguration {
  [self make:@"default" text:@"version: 2\n"];
  ConfigurationBackupView *page = [self pageConnected:YES];
  for (NSString *identifier in @[@"backup-name", @"backup-save", @"restore-default", @"delete-default"]) XCTAssertNil([self viewIn:page identifier:identifier], @"%@", identifier);
}

#pragma mark - Syncing

- (void)testSyncNowSendsAndTheListFollows {
  [self make:@"default" text:@"version: 2\n"];
  [self make:@"desk" text:@"version: 2\n# desk\n"];
  ConfigurationBackupView *page = [self pageConnected:YES];
  [self sync:page];
  XCTAssertEqual(page.lastReport.sent, 2u);
  XCTAssertNil(page.lastReport.problem);
  XCTAssertNotNil([self.github backupFiles][@"desk.mwm.yaml"]);
  for (MWMSyncItem *item in page.items) XCTAssertEqual(item.status, MWMSyncStatusSynced);
  XCTAssertEqual(self.filesChanged, 0u, @"nothing came in");
}

- (void)testReceivingTellsTheWindow {
  [self.github addBackupGistWithFiles:@{@"laptop.mwm.yaml": @"x\n"}];
  ConfigurationBackupView *page = [self pageConnected:YES];
  [self sync:page];
  XCTAssertEqual(page.lastReport.received, 1u);
  XCTAssertEqual(self.filesChanged, 1u);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"laptop"]));
}

- (void)testAProblemShowsInWordsWithTryAgain {
  [self make:@"default" text:@"version: 2\n"];
  self.github.status = 500;
  ConfigurationBackupView *page = [self pageConnected:YES];
  XCTAssertTrue([page.problem containsString:@"500"], @"%@", page.problem);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-problem"]);
  XCTAssertNotNil([self viewIn:page identifier:@"backup-retry"]);
  self.github.status = 200;
  [(NSButton *)[self viewIn:page identifier:@"backup-retry"] performClick:nil];
  [self refresh:page];
  XCTAssertNil(page.problem);
}

@end
