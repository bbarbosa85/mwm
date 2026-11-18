//
//  TestStatusMenus.m
//
//  The menu bar menu: Snapshots, Keyboard Shortcuts, Backup and the pages of the window.
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
#import "MWMStatusMenus.h"
#import "SlateSnapshots.h"
#import "Snapshot.h"
#import "SnapshotList.h"
#import "WindowSnapshot.h"

@interface TestStatusMenus : XCTestCase
@property (strong) NSMutableDictionary *lists;
@end

@implementation TestStatusMenus

- (SnapshotList *)listNamed:(NSString *)name keep:(BOOL)keep {
  Snapshot *snapshot = [[Snapshot alloc] init];
  [snapshot addWindow:[[WindowSnapshot alloc] initWithAppName:@"Safari" title:@"x" topLeft:NSMakePoint(0, 0) size:NSMakeSize(100, 100)] app:@"Safari"];
  SnapshotList *list = [[SnapshotList alloc] initWithName:name saveToDisk:keep isStack:NO];
  [list addSnapshot:snapshot];
  return list;
}

- (void)setUp {
  self.lists = [NSMutableDictionary dictionary];
  self.lists[@"work"] = [self listNamed:@"work" keep:YES];
  self.lists[@"couch"] = [self listNamed:@"couch" keep:NO];
  [SlateSnapshots setListsOverride:self.lists];
}

- (void)tearDown { [SlateSnapshots setListsOverride:nil]; }

- (NSArray<NSString *> *)titles:(NSMenu *)menu {
  NSMutableArray *titles = [NSMutableArray array];
  for (NSMenuItem *item in [menu itemArray]) [titles addObject:[item isSeparatorItem] ? @"-" : [item title]];
  return titles;
}

- (void)testTheSnapshotsMenuListsEachSnapshotWithItsOwnSubmenu {
  NSMenu *menu = [[MWMStatusMenus shared] snapshotsMenu];
  [[MWMStatusMenus shared] menuNeedsUpdate:menu];
  XCTAssertEqualObjects([self titles:menu], (@[@"Save Current Windows…", @"-", @"couch", @"work", @"-", @"Manage Snapshots…"]));
  NSMenu *work = [[menu itemWithTitle:@"work"] submenu];
  XCTAssertEqualObjects([self titles:work], (@[@"Restore", @"Update with Current Windows", @"-", @"Keep after Restart", @"-", @"Delete…"]));
  XCTAssertEqual([[work itemWithTitle:@"Keep after Restart"] state], NSControlStateValueOn);
  XCTAssertEqual([[[[menu itemWithTitle:@"couch"] submenu] itemWithTitle:@"Keep after Restart"] state], NSControlStateValueOff);
  XCTAssertEqualObjects([[work itemWithTitle:@"Restore"] representedObject], @"work");
}

- (void)testTheSnapshotsMenuRefreshesWhenItOpens {
  NSMenu *menu = [[MWMStatusMenus shared] snapshotsMenu];
  [[MWMStatusMenus shared] menuNeedsUpdate:menu];
  self.lists[@"focus"] = [self listNamed:@"focus" keep:YES];
  [[MWMStatusMenus shared] menuNeedsUpdate:menu];
  XCTAssertTrue([[self titles:menu] containsObject:@"focus"]);
  [self.lists removeAllObjects];
  [[MWMStatusMenus shared] menuNeedsUpdate:menu];
  XCTAssertTrue([[self titles:menu] containsObject:@"No snapshots yet"]);
  XCTAssertFalse([[menu itemWithTitle:@"No snapshots yet"] isEnabled]);
}

- (void)testChoosingKeepAfterRestartFlipsIt {
  NSMenu *menu = [[MWMStatusMenus shared] menuForSnapshotNamed:@"couch" keep:NO];
  NSMenuItem *keep = [menu itemWithTitle:@"Keep after Restart"];
  [NSApp sendAction:[keep action] to:[keep target] from:keep];
  XCTAssertTrue([self.lists[@"couch"] saveToDisk]);
}

- (void)testThePagesMenuHasEveryPageOfTheWindow {
  NSMenu *menu = [[MWMStatusMenus shared] pagesMenu];
  XCTAssertEqualObjects([self titles:menu], (@[@"Keyboard", @"Modifiers", @"-", @"Displays", @"Slots", @"Snapshots", @"-", @"General", @"Advanced", @"Other Aliases", @"Backup"]));
  XCTAssertNotNil([[menu itemWithTitle:@"Backup"] representedObject]);
  XCTAssertEqualObjects([self titles:[[MWMStatusMenus shared] keyboardMenu]], (@[@"Keyboard Map", @"List of Shortcuts", @"-", @"New Shortcut…", @"Modifier Groups"]));
}

- (void)testTheStatusMenuPutsTheCapabilitiesFirst {
  SEL build = NSSelectorFromString(@"buildStatusMenu");
  id delegate = [NSApp delegate];
  XCTAssertTrue([delegate respondsToSelector:build]);
  NSMenu *menu = [delegate performSelector:build];
  NSArray *titles = [self titles:menu];
  NSUInteger snapshots = [titles indexOfObject:@"Snapshots"], keyboard = [titles indexOfObject:@"Keyboard Shortcuts"], backup = [titles indexOfObject:@"Backup…"], configure = [titles indexOfObject:@"Configure MWM…"];
  XCTAssertTrue(snapshots < keyboard && keyboard < backup && backup < configure, @"%@", titles);
  XCTAssertNotNil([[menu itemWithTitle:@"Snapshots"] submenu]);
  XCTAssertNotNil([[menu itemWithTitle:@"Open Page"] submenu]);
  XCTAssertEqualObjects([titles lastObject], @"Quit MWM");
}

@end
