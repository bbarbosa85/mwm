//
//  TestConfigurationSnapshots.m
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
#import <objc/runtime.h>
#import "ConfigurationSnapshotsView.h"
#import "MWMSnapshots.h"
#import "Snapshot.h"
#import "SnapshotList.h"
#import "WindowSnapshot.h"

@interface TestConfigurationSnapshots : XCTestCase <ConfigurationSnapshotsViewDelegate>
@property (strong) NSMutableDictionary *lists;
@property (assign) NSUInteger changes;
@end

@implementation TestConfigurationSnapshots

- (void)snapshotsViewDidChange:(ConfigurationSnapshotsView *)view { self.changes++; }

- (SnapshotList *)listNamed:(NSString *)name keep:(BOOL)keep apps:(NSArray<NSString *> *)apps {
  Snapshot *snapshot = [[Snapshot alloc] init];
  CGFloat x = 0;
  for (NSString *app in apps) {
    [snapshot addWindow:[[WindowSnapshot alloc] initWithAppName:app title:@"w" topLeft:NSMakePoint(x, 0) size:NSMakeSize(500, 600)] app:app];
    x += 500;
  }
  snapshot.screens = @[@{@"name": @"Built-in", @"width": @1512, @"height": @982, @"x": @0, @"y": @0, @"builtIn": @YES}];
  SnapshotList *list = [[SnapshotList alloc] initWithName:name saveToDisk:keep isStack:NO];
  [list addSnapshot:snapshot];
  return list;
}

- (void)setUp {
  self.lists = [NSMutableDictionary dictionary];
  self.lists[@"work"] = [self listNamed:@"work" keep:YES apps:@[@"Google Chrome", @"Warp", @"Spotify"]];
  self.lists[@"couch"] = [self listNamed:@"couch" keep:NO apps:@[@"Safari"]];
  [MWMSnapshots setListsOverride:self.lists];
  self.changes = 0;
}

- (void)tearDown { [MWMSnapshots setListsOverride:nil]; }

- (ConfigurationSnapshotsView *)page {
  ConfigurationSnapshotsView *page = [[ConfigurationSnapshotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 640) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:page];
  page.delegate = self;
  page.confirmsDeleting = NO;
  [page reload];
  [window layoutIfNeeded];
  objc_setAssociatedObject(page, "window", window, OBJC_ASSOCIATION_RETAIN);
  return page;
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

- (NSArray<NSString *> *)textsIn:(NSView *)root {
  NSMutableArray *texts = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSTextField class]]) [texts addObject:[(NSTextField *)view stringValue]];
    if ([view isKindOfClass:[NSButton class]]) [texts addObject:[(NSButton *)view title]];
    [queue addObjectsFromArray:[view subviews]];
  }
  return texts;
}

- (void)testEachSnapshotIsARowWithItsDetails {
  ConfigurationSnapshotsView *page = [self page];
  NSView *work = [self viewIn:page identifier:@"snapshot-work"];
  NSView *couch = [self viewIn:page identifier:@"snapshot-couch"];
  XCTAssertNotNil(work);
  XCTAssertNotNil(couch);
  NSArray *texts = [self textsIn:work];
  XCTAssertTrue([texts containsObject:@"work"]);
  XCTAssertTrue([texts containsObject:@"3 windows · kept"], @"%@", texts);
  XCTAssertTrue([texts containsObject:@"Restore"]);
  XCTAssertNotNil([self viewIn:work identifier:@"keep-work"], @"the pin that keeps it after a restart");
  XCTAssertNotNil([self viewIn:work identifier:@"restore-work"]);
  XCTAssertTrue([texts containsObject:@"Laptop"], @"taken with only the built-in screen");
  XCTAssertNil([self viewIn:page identifier:@"snapshots-empty"]);
}

- (void)testWithNoSnapshotsThePageShowsTheNewSnapshotCardAndAFewWords {
  [self.lists removeAllObjects];
  ConfigurationSnapshotsView *page = [self page];
  XCTAssertNotNil([self viewIn:page identifier:@"snapshots-empty"]);
  XCTAssertNotNil([self viewIn:page identifier:@"snapshot-new"]);
  XCTAssertNotNil([self viewIn:page identifier:@"snapshot-save"]);
}

- (void)testTheNewSnapshotCardIsAlwaysLastAndSuggestsAName {
  ConfigurationSnapshotsView *page = [self page];
  XCTAssertNotNil([self viewIn:page identifier:@"snapshot-new"], @"it stays, with snapshots too");
  XCTAssertNotNil([self viewIn:page identifier:@"snapshot-live"], @"a live picture of the windows now");
  XCTAssertEqualObjects([[page.nameField placeholderString] copy], @"snapshot1");
  self.lists[@"snapshot1"] = [self listNamed:@"snapshot1" keep:NO apps:@[@"Safari"]];
  [page reload];
  XCTAssertEqualObjects([[page.nameField placeholderString] copy], @"snapshot2", @"a name that isn't taken");
}

- (void)testThePinKeepsOrForgetsTheSnapshot {
  ConfigurationSnapshotsView *page = [self page];
  NSButton *pin = (NSButton *)[self viewIn:page identifier:@"keep-couch"];
  XCTAssertNotNil(pin);
  XCTAssertFalse([self.lists[@"couch"] saveToDisk]);
  [NSApp sendAction:[pin action] to:[pin target] from:pin];
  XCTAssertTrue([self.lists[@"couch"] saveToDisk]);
  XCTAssertTrue([[self textsIn:[self viewIn:page identifier:@"snapshot-couch"]] containsObject:@"1 window · kept"]);
  pin = (NSButton *)[self viewIn:page identifier:@"keep-couch"];
  [NSApp sendAction:[pin action] to:[pin target] from:pin];
  XCTAssertFalse([self.lists[@"couch"] saveToDisk]);
}

- (void)testACardWithAMissingScreenSaysSo {
  Snapshot *snapshot = [[self.lists[@"couch"] snapshots] firstObject];
  snapshot.screens = @[@{@"name": @"Desk", @"width": @2560, @"height": @1440, @"x": @0, @"y": @0, @"builtIn": @NO}];
  ConfigurationSnapshotsView *page = [self page];
  XCTAssertTrue([[self textsIn:[self viewIn:page identifier:@"snapshot-couch"]] containsObject:@"1 window · screen missing"], @"%@", [self textsIn:page]);
}

- (void)testDeletingARowRemovesItAndTellsTheWindow {
  ConfigurationSnapshotsView *page = [self page];
  [page deleteNamed:@"work"];
  XCTAssertNil(self.lists[@"work"]);
  XCTAssertNil([self viewIn:page identifier:@"snapshot-work"]);
  XCTAssertNotNil([self viewIn:page identifier:@"snapshot-couch"]);
  XCTAssertEqual(self.changes, 1u);
}

- (void)testSaveIsOffForANameThatIsTaken {
  ConfigurationSnapshotsView *page = [self page];
  NSTextField *field = page.nameField;
  [field setStringValue:@"work"];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:field];
  XCTAssertFalse([(NSButton *)[self viewIn:page identifier:@"snapshot-save"] isEnabled]);
  [field setStringValue:@"evening"];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:field];
  XCTAssertTrue([(NSButton *)[self viewIn:page identifier:@"snapshot-save"] isEnabled]);
}

@end
