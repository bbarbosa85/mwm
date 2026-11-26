//
//  TestMWMSyncPlan.m
//
//  What a sync decides for each file, from the two sides and the last-synced base.
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
#import "MWMSyncPlan.h"

@interface TestMWMSyncPlan : XCTestCase
@end

@implementation TestMWMSyncPlan

- (NSDate *)day:(NSInteger)n { return [NSDate dateWithTimeIntervalSince1970:86400.0 * n]; }
- (MWMSyncFile *)file:(NSString *)name text:(NSString *)text day:(NSInteger)day { return [MWMSyncFile fileNamed:name text:text modified:[self day:day]]; }
- (NSDictionary *)baseOf:(NSDictionary<NSString *, NSString *> *)texts {
  NSMutableDictionary *base = [NSMutableDictionary dictionary];
  for (NSString *name in texts) base[name] = [MWMSyncFile hashOfText:texts[name]];
  return base;
}
- (MWMSyncItem *)itemFor:(NSString *)name in:(NSArray<MWMSyncItem *> *)items {
  for (MWMSyncItem *item in items) if ([item.name isEqualToString:name]) return item;
  return nil;
}

#pragma mark - Hash

- (void)testTheHashIsSHA256OfTheText {
  XCTAssertEqualObjects([MWMSyncFile hashOfText:@"abc"], @"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  XCTAssertEqualObjects([MWMSyncFile hashOfText:@""], @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
}

#pragma mark - Nothing in common yet

- (void)testFirstSyncSendsWhatOnlyIsHereAndReceivesWhatOnlyIsInTheGist {
  NSArray *items = [MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"a" day:1]] remote:@[[self file:@"laptop" text:@"b" day:1]] base:@{}];
  XCTAssertEqual([self itemFor:@"desk" in:items].status, MWMSyncStatusOnlyHere);
  XCTAssertTrue([self itemFor:@"desk" in:items].willSend);
  XCTAssertEqual([self itemFor:@"laptop" in:items].status, MWMSyncStatusOnlyInGist);
  XCTAssertTrue([self itemFor:@"laptop" in:items].willReceive);
}

- (void)testIdenticalFilesAreSyncedEvenWithoutABase {
  NSArray *items = [MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"a" day:1]] remote:@[[self file:@"desk" text:@"a" day:5]] base:@{}];
  XCTAssertEqual([self itemFor:@"desk" in:items].status, MWMSyncStatusSynced);
  XCTAssertFalse([self itemFor:@"desk" in:items].willSend || [self itemFor:@"desk" in:items].willReceive);
}

- (void)testDifferentFilesOnAFirstSyncAreAConflictWonByTheNewer {
  NSArray *hereNewer = [MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"mine" day:5]] remote:@[[self file:@"desk" text:@"theirs" day:2]] base:@{}];
  XCTAssertEqual([self itemFor:@"desk" in:hereNewer].status, MWMSyncStatusChangedHere);
  XCTAssertTrue([self itemFor:@"desk" in:hereNewer].conflict);
  NSArray *gistNewer = [MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"mine" day:2]] remote:@[[self file:@"desk" text:@"theirs" day:5]] base:@{}];
  XCTAssertEqual([self itemFor:@"desk" in:gistNewer].status, MWMSyncStatusNewerInGist);
}

#pragma mark - After a sync

- (void)testOnlyThisSideChangedMeansSendAndOnlyTheOtherMeansReceive {
  NSDictionary *base = [self baseOf:@{@"desk": @"v1"}];
  NSArray *here = [MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"v2" day:9]] remote:@[[self file:@"desk" text:@"v1" day:1]] base:base];
  XCTAssertEqual([self itemFor:@"desk" in:here].status, MWMSyncStatusChangedHere);
  XCTAssertFalse([self itemFor:@"desk" in:here].conflict);
  NSArray *there = [MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"v1" day:1]] remote:@[[self file:@"desk" text:@"v2" day:9]] base:base];
  XCTAssertEqual([self itemFor:@"desk" in:there].status, MWMSyncStatusNewerInGist);
  XCTAssertFalse([self itemFor:@"desk" in:there].conflict);
}

- (void)testChangedOnBothSidesTheNewerWinsAndATieGoesToThisComputer {
  NSDictionary *base = [self baseOf:@{@"desk": @"v1"}];
  MWMSyncItem *remoteNewer = [self itemFor:@"desk" in:[MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"mine" day:3]] remote:@[[self file:@"desk" text:@"theirs" day:4]] base:base]];
  XCTAssertEqual(remoteNewer.status, MWMSyncStatusNewerInGist);
  XCTAssertTrue(remoteNewer.conflict);
  MWMSyncItem *localNewer = [self itemFor:@"desk" in:[MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"mine" day:4]] remote:@[[self file:@"desk" text:@"theirs" day:3]] base:base]];
  XCTAssertEqual(localNewer.status, MWMSyncStatusChangedHere);
  MWMSyncItem *tie = [self itemFor:@"desk" in:[MWMSyncPlan planForLocal:@[[self file:@"desk" text:@"mine" day:4]] remote:@[[self file:@"desk" text:@"theirs" day:4]] base:base]];
  XCTAssertEqual(tie.status, MWMSyncStatusChangedHere);
}

#pragma mark - Deletions

- (void)testAFileGoneHereButUnchangedInTheGistIsFlagged {
  NSDictionary *base = [self baseOf:@{@"old": @"x"}];
  MWMSyncItem *item = [self itemFor:@"old" in:[MWMSyncPlan planForLocal:@[] remote:@[[self file:@"old" text:@"x" day:1]] base:base]];
  XCTAssertEqual(item.status, MWMSyncStatusDeletedHere);
  XCTAssertTrue(item.flagged);
  XCTAssertFalse(item.willSend || item.willReceive, @"nothing is done until the person chooses");
}

- (void)testAFileGoneFromTheGistButUnchangedHereIsFlagged {
  NSDictionary *base = [self baseOf:@{@"old": @"x"}];
  MWMSyncItem *item = [self itemFor:@"old" in:[MWMSyncPlan planForLocal:@[[self file:@"old" text:@"x" day:1]] remote:@[] base:base]];
  XCTAssertEqual(item.status, MWMSyncStatusDeletedInGist);
  XCTAssertTrue(item.flagged);
}

- (void)testAChangeBeatsADeletionOnTheOtherSide {
  NSDictionary *base = [self baseOf:@{@"old": @"x"}];
  MWMSyncItem *editedHere = [self itemFor:@"old" in:[MWMSyncPlan planForLocal:@[[self file:@"old" text:@"edited" day:2]] remote:@[] base:base]];
  XCTAssertEqual(editedHere.status, MWMSyncStatusOnlyHere, @"it is sent again, not deleted");
  XCTAssertFalse(editedHere.flagged);
  MWMSyncItem *editedThere = [self itemFor:@"old" in:[MWMSyncPlan planForLocal:@[] remote:@[[self file:@"old" text:@"edited" day:2]] base:base]];
  XCTAssertTrue(editedThere.willReceive, @"it comes back");
  XCTAssertFalse(editedThere.flagged);
}

#pragma mark - Snapshots

- (void)testSnapshotsAreNeverFlaggedAsDeleted {
  NSString *name = [MWMSyncPlan snapshotsName];
  NSDictionary *base = [self baseOf:@{name: @"{}"}];
  MWMSyncItem *missingHere = [self itemFor:name in:[MWMSyncPlan planForLocal:@[] remote:@[[self file:name text:@"{}" day:1]] base:base]];
  XCTAssertEqual(missingHere.status, MWMSyncStatusOnlyInGist);
  XCTAssertTrue(missingHere.isSnapshots);
  MWMSyncItem *missingThere = [self itemFor:name in:[MWMSyncPlan planForLocal:@[[self file:name text:@"{}" day:1]] remote:@[] base:base]];
  XCTAssertEqual(missingThere.status, MWMSyncStatusOnlyHere);
}

#pragma mark - Order

- (void)testProfilesComeByNameAndSnapshotsLast {
  NSString *snap = [MWMSyncPlan snapshotsName];
  NSArray *items = [MWMSyncPlan planForLocal:@[[self file:snap text:@"{}" day:1], [self file:@"b" text:@"1" day:1], [self file:@"A" text:@"1" day:1]] remote:@[] base:@{}];
  XCTAssertEqualObjects([items valueForKey:@"name"], (@[@"A", @"b", snap]));
}

@end
