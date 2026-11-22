//
//  TestMWMShortcutIndex.m
//  Slate
//
//  Tests for understanding a configuration's shortcuts (groups, kinds, titles,
//  conflicts) and for the combos MWM won't allow.
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
#import "MWMShortcutIndex.h"
#import "MWMReservedShortcuts.h"
#import "MWMConfigDocument.h"

@interface TestMWMShortcutIndex : XCTestCase
@end

@implementation TestMWMShortcutIndex

static NSString *const kConfig =
  @"modifiers:\n  hyper: ctrl;alt;cmd\n  shyper: shift;ctrl;alt;cmd\n"
  @"monitors:\n  monitor-samsung: \"0\"\n"
  @"positions:\n  half: move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"bindings:\n"
  @"  - key: pad8\n    mods: ${hyper}\n    action: ${half} ${monitor-samsung}\n"
  @"  - key: pad8\n    mods: ctrl;alt;cmd\n    action: relaunch\n"
  @"  - key: c\n    mods: alt;shift\n    action: focus 'Google Chrome'\n"
  @"  - key: h\n    mods: ${shyper}\n    action: hint ASDF\n"
  @"  - key: left\n    mods: ctrl;cmd\n    action: focus left\n"
  @"  - key: r\n    mods: ${hyper}\n    action: relaunch\n    enabled: false\n";

- (MWMShortcutIndex *)index {
  NSError *error = nil;
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  return [MWMShortcutIndex indexForDocument:doc];
}

- (void)testGroupsComeFromTheModifierEntries {
  MWMShortcutIndex *index = [self index];
  NSArray *names = [index.groups valueForKey:@"name"];
  XCTAssertEqualObjects(names, (@[@"hyper", @"shyper", @"Custom"]), @"file order, then Custom for sets no group names");
  XCTAssertEqualObjects(((MWMModifierGroup *)index.groups[0]).modifierNames, (@[@"ctrl", @"alt", @"cmd"]));
  XCTAssertEqualObjects(((MWMModifierGroup *)index.groups[1]).modifierNames, (@[@"ctrl", @"alt", @"shift", @"cmd"]), @"always ctrl, alt, shift, cmd");
  XCTAssertEqual(((MWMModifierGroup *)index.groups[0]).count, 3u, @"two written as ${hyper}, one written out that is the same set");
  XCTAssertEqual(((MWMModifierGroup *)index.groups[2]).count, 2u);
}

- (void)testAWrittenOutSetThatAGroupNamesIsThatGroup {
  MWMShortcutInfo *info = [[self index] shortcutAtBindingIndex:1];
  XCTAssertEqualObjects(info.groupName, @"hyper");
  XCTAssertEqualObjects(info.modifierNames, (@[@"ctrl", @"alt", @"cmd"]));
}

- (void)testKindsAndTitles {
  MWMShortcutIndex *index = [self index];
  MWMShortcutInfo *move = [index shortcutAtBindingIndex:0];
  XCTAssertEqual(move.kind, MWMShortcutKindMoveToSlot);
  XCTAssertEqualObjects(move.title, @"Move to half");
  XCTAssertEqualObjects(move.detail, @"on Samsung");
  XCTAssertEqualObjects([index shortcutAtBindingIndex:2].title, @"Focus Google Chrome");
  XCTAssertEqual([index shortcutAtBindingIndex:3].kind, MWMShortcutKindFeature);
  XCTAssertEqual([index shortcutAtBindingIndex:4].kind, MWMShortcutKindFocusWindow);
  XCTAssertEqual([index countOfKind:MWMShortcutKindFeature], 3u, @"two relaunches and the hint");
}

- (void)testSameKeysInDifferentWaysAreConflicts {
  MWMShortcutIndex *index = [self index];
  XCTAssertTrue([index shortcutAtBindingIndex:0].conflict, @"${hyper} and ctrl;alt;cmd are the same keys");
  XCTAssertTrue([index shortcutAtBindingIndex:1].conflict);
  XCTAssertFalse([index shortcutAtBindingIndex:5].conflict, @"a disabled shortcut conflicts with nothing");
  XCTAssertEqual(index.conflictCount, 1u);
}

- (void)testLookingUpAKey {
  MWMShortcutIndex *index = [self index];
  NSArray *altShift = @[@"alt", @"shift"], *shiftAlt = @[@"shift", @"alt"], *cmd = @[@"cmd"];
  XCTAssertEqual([index shortcutForKeyName:@"c" modifierNames:altShift].index, 2u);
  XCTAssertEqual([index shortcutForKeyName:@"c" modifierNames:shiftAlt].index, 2u, @"modifier order doesn't matter");
  XCTAssertNil([index shortcutForKeyName:@"c" modifierNames:cmd]);
  XCTAssertEqual([[index shortcutsInGroup:@"shyper"] count], 1u);
  XCTAssertEqual([[index shortcutsInGroup:nil] count], 6u);
}

- (void)testReservedCombosAreRefusedWithAReason {
  NSArray *cmd = @[@"cmd"], *cmdShift = @[@"cmd", @"shift"], *ctrl = @[@"ctrl"], *none = @[];
  XCTAssertTrue([[MWMReservedShortcuts reasonForKeyName:@"s" modifierNames:cmd] containsString:@"⌘S saves"]);
  XCTAssertTrue([[MWMReservedShortcuts reasonForKeyName:@"tab" modifierNames:cmd] containsString:@"switches apps"]);
  XCTAssertNotNil([MWMReservedShortcuts reasonForKeyName:@"4" modifierNames:cmdShift], @"order doesn't matter");
  XCTAssertNotNil([MWMReservedShortcuts reasonForKeyName:@"left" modifierNames:ctrl]);
  XCTAssertTrue([[MWMReservedShortcuts reasonForKeyName:@"c" modifierNames:none] containsString:@"no modifier"]);
}

- (void)testHyperAndOtherCombosAreAllowed {
  NSArray *hyper = @[@"ctrl", @"alt", @"cmd"], *shyper = @[@"ctrl", @"alt", @"shift", @"cmd"], *altCmd = @[@"alt", @"cmd"], *altShift = @[@"alt", @"shift"];
  XCTAssertNil([MWMReservedShortcuts reasonForKeyName:@"s" modifierNames:hyper], @"hyper is never blocked");
  XCTAssertNil([MWMReservedShortcuts reasonForKeyName:@"s" modifierNames:shyper]);
  XCTAssertNil([MWMReservedShortcuts reasonForKeyName:@"s" modifierNames:altCmd], @"only the listed combos");
  XCTAssertNil([MWMReservedShortcuts reasonForKeyName:@"c" modifierNames:altShift]);
}


- (void)testSnapshotShortcutsAreFeaturesWithTheirNames {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:@"bindings:\n  - key: s\n    mods: ctrl;cmd\n    action: snapshot work save-to-disk\n  - key: a\n    mods: ctrl;cmd\n    action: activate-snapshot work\n" error:nil];
  MWMShortcutIndex *index = [MWMShortcutIndex indexForDocument:doc];
  XCTAssertEqual(index.shortcuts[0].kind, MWMShortcutKindFeature);
  XCTAssertEqualObjects(index.shortcuts[0].title, @"Save snapshot work");
  XCTAssertEqualObjects(index.shortcuts[1].title, @"Restore snapshot work");
}

@end
