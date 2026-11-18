//
//  TestSlateSnapshots.m
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
#import "SlateDisplays.h"
#import "SlateSnapshots.h"
#import "Snapshot.h"
#import "SnapshotList.h"
#import "WindowSnapshot.h"

@interface TestSlateSnapshots : XCTestCase
@property (strong) NSMutableDictionary *lists;
@end

@implementation TestSlateSnapshots

- (SnapshotList *)listNamed:(NSString *)name keep:(BOOL)keep windows:(NSArray *)windows screens:(NSArray *)screens {
  Snapshot *snapshot = [[Snapshot alloc] init];
  for (NSArray *w in windows) {
    [snapshot addWindow:[[WindowSnapshot alloc] initWithAppName:w[0] title:w[1] topLeft:NSMakePoint([w[2] doubleValue], [w[3] doubleValue]) size:NSMakeSize([w[4] doubleValue], [w[5] doubleValue])] app:w[0]];
  }
  snapshot.screens = screens;
  SnapshotList *list = [[SnapshotList alloc] initWithName:name saveToDisk:keep isStack:NO];
  [list addSnapshot:snapshot];
  return list;
}

- (NSDictionary *)screen:(NSString *)name width:(NSInteger)w height:(NSInteger)h x:(CGFloat)x builtIn:(BOOL)builtIn {
  return @{@"name": name, @"width": @(w), @"height": @(h), @"x": @(x), @"y": @0, @"builtIn": @(builtIn)};
}

- (void)setUp {
  self.lists = [NSMutableDictionary dictionary];
  self.lists[@"work"] = [self listNamed:@"work" keep:YES windows:@[@[@"Chrome", @"Docs", @0, @0, @1000, @800], @[@"Chrome", @"Mail", @1000, @0, @500, @800], @[@"Warp", @"zsh", @1500, @0, @500, @400]]
                                   screens:@[[self screen:@"Built-in" width:1512 height:982 x:0 builtIn:YES], [self screen:@"Samsung Odyssey" width:5120 height:1440 x:1512 builtIn:NO]]];
  self.lists[@"couch"] = [self listNamed:@"couch" keep:NO windows:@[@[@"Safari", @"News", @10, @10, @800, @600]]
                                   screens:@[[self screen:@"Built-in" width:1512 height:982 x:0 builtIn:YES]]];
  [SlateSnapshots setListsOverride:self.lists];
}

- (void)tearDown { [SlateSnapshots setListsOverride:nil]; }

- (NSArray<SlateDisplay *> *)connectedBuiltInOnly {
  return @[[SlateDisplay displayNamed:@"Built-in" width:1512 height:982 builtIn:YES x:0 y:0]];
}

- (void)testSnapshotsAreListedByNameWithWhatTheyHold {
  NSArray<SlateSnapshotInfo *> *infos = [SlateSnapshots infosForLists:self.lists connected:[self connectedBuiltInOnly]];
  XCTAssertEqualObjects([infos valueForKey:@"name"], (@[@"couch", @"work"]));
  SlateSnapshotInfo *work = infos[1];
  XCTAssertEqual(work.windowCount, 3u);
  XCTAssertEqualObjects(work.appNames, (@[@"Chrome", @"Warp"]), @"most windows first");
  XCTAssertTrue(work.keepAfterRestart);
  XCTAssertEqualObjects(work.screensText, @"Built-in + Samsung Odyssey");
  XCTAssertEqualObjects(work.summary, @"3 windows · Built-in + Samsung Odyssey");
  XCTAssertFalse(work.isLaptop);
  XCTAssertFalse(work.allScreensConnected, @"the Samsung isn't plugged in here");
  XCTAssertEqualObjects(infos[0].summary, @"1 window · Built-in");
  XCTAssertTrue(infos[0].isLaptop);
  XCTAssertTrue(infos[0].allScreensConnected);
  XCTAssertFalse(infos[0].keepAfterRestart);
}

- (void)testTheEnginesInternalSnapshotsAreNotListed {
  self.lists[@"_internal_UndoSnapshot"] = [self listNamed:@"_internal_UndoSnapshot" keep:YES windows:@[@[@"Chrome", @"x", @0, @0, @10, @10]] screens:@[]];
  NSArray *names = [[SlateSnapshots infosForLists:self.lists connected:@[]] valueForKey:@"name"];
  XCTAssertEqualObjects(names, (@[@"couch", @"work"]));
}

- (void)testAnOlderSnapshotUsesTheScreensThatHoldItsWindowsToday {
  self.lists[@"old"] = [self listNamed:@"old" keep:NO windows:@[@[@"Notes", @"x", @100, @100, @400, @300]] screens:@[]];
  NSArray *connected = @[[SlateDisplay displayNamed:@"Built-in" width:1512 height:982 builtIn:YES x:0 y:0],
                         [SlateDisplay displayNamed:@"Desk" width:2560 height:1440 builtIn:NO x:1512 y:0]];
  SlateSnapshotInfo *old = [[SlateSnapshots infosForLists:self.lists connected:connected] firstObject];
  XCTAssertEqualObjects(old.name, @"couch");
  for (SlateSnapshotInfo *info in [SlateSnapshots infosForLists:self.lists connected:connected]) {
    if (![info.name isEqualToString:@"old"]) continue;
    XCTAssertFalse(info.screensKnown);
    XCTAssertEqualObjects(info.screensText, @"Built-in", @"only the screen its window is on");
    XCTAssertFalse(info.isLaptop, @"not claimed when the screens weren't saved");
  }
}

- (void)testNamesNeedToBeUniqueAndWithoutSpaces {
  XCTAssertNotNil([SlateSnapshots problemWithName:@"" except:nil]);
  XCTAssertNotNil([SlateSnapshots problemWithName:@"two words" except:nil]);
  XCTAssertNotNil([SlateSnapshots problemWithName:@"work" except:nil]);
  XCTAssertNil([SlateSnapshots problemWithName:@"work" except:@"work"], @"keeping its own name is fine");
  XCTAssertNil([SlateSnapshots problemWithName:@"evening" except:nil]);
}

- (void)testRenamingMovesTheSnapshotAndRefusesTakenNames {
  XCTAssertFalse([SlateSnapshots renameFrom:@"work" to:@"couch"]);
  XCTAssertTrue([SlateSnapshots renameFrom:@"work" to:@"office"]);
  XCTAssertNil(self.lists[@"work"]);
  XCTAssertEqualObjects([self.lists[@"office"] name], @"office");
  XCTAssertEqual([[SlateSnapshots infosForLists:self.lists connected:@[]] count], 2u);
}

- (void)testDeletingAndKeepingChangeTheList {
  [SlateSnapshots setKeepAfterRestart:YES forName:@"couch"];
  XCTAssertTrue([self.lists[@"couch"] saveToDisk]);
  [SlateSnapshots setKeepAfterRestart:NO forName:@"couch"];
  XCTAssertFalse([self.lists[@"couch"] saveToDisk]);
  [SlateSnapshots deleteName:@"work"];
  XCTAssertNil(self.lists[@"work"]);
  [SlateSnapshots deleteName:@"nothing"];   // no harm
  XCTAssertEqual([self.lists count], 1u);
}

- (void)testScreensSurviveBeingSavedToDiskAndRead {
  Snapshot *original = [[self.lists[@"work"] snapshots] firstObject];
  Snapshot *back = [Snapshot snapshotFromDictionary:[original toDictionary]];
  XCTAssertEqualObjects(back.screens, original.screens);
  XCTAssertEqual([[back.apps allKeys] count], 2u);
}

@end
