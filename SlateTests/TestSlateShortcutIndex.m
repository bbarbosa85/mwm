//
//  TestSlateShortcutIndex.m
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
#import "SlateShortcutIndex.h"
#import "SlateReservedShortcuts.h"
#import "SlateConfigDocument.h"

@interface TestSlateShortcutIndex : XCTestCase
@end

@implementation TestSlateShortcutIndex

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

- (SlateShortcutIndex *)index {
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  return [SlateShortcutIndex indexForDocument:doc];
}

- (void)testGroupsComeFromTheModifierEntries {
  SlateShortcutIndex *index = [self index];
  NSArray *names = [index.groups valueForKey:@"name"];
  XCTAssertEqualObjects(names, (@[@"hyper", @"shyper", @"Custom"]), @"file order, then Custom for sets no group names");
  XCTAssertEqualObjects(((SlateModifierGroup *)index.groups[0]).modifierNames, (@[@"ctrl", @"alt", @"cmd"]));
  XCTAssertEqualObjects(((SlateModifierGroup *)index.groups[1]).modifierNames, (@[@"ctrl", @"alt", @"shift", @"cmd"]), @"always ctrl, alt, shift, cmd");
  XCTAssertEqual(((SlateModifierGroup *)index.groups[0]).count, 3u, @"two written as ${hyper}, one written out that is the same set");
  XCTAssertEqual(((SlateModifierGroup *)index.groups[2]).count, 2u);
}

- (void)testAWrittenOutSetThatAGroupNamesIsThatGroup {
  SlateShortcutInfo *info = [[self index] shortcutAtBindingIndex:1];
  XCTAssertEqualObjects(info.groupName, @"hyper");
  XCTAssertEqualObjects(info.modifierNames, (@[@"ctrl", @"alt", @"cmd"]));
}

- (void)testKindsAndTitles {
  SlateShortcutIndex *index = [self index];
  SlateShortcutInfo *move = [index shortcutAtBindingIndex:0];
  XCTAssertEqual(move.kind, SlateShortcutKindMoveToSlot);
  XCTAssertEqualObjects(move.title, @"Move to half");
  XCTAssertEqualObjects(move.detail, @"on Samsung");
  XCTAssertEqualObjects([index shortcutAtBindingIndex:2].title, @"Focus Google Chrome");
  XCTAssertEqual([index shortcutAtBindingIndex:3].kind, SlateShortcutKindFeature);
  XCTAssertEqual([index shortcutAtBindingIndex:4].kind, SlateShortcutKindFocusWindow);
  XCTAssertEqual([index countOfKind:SlateShortcutKindFeature], 3u, @"two relaunches and the hint");
}

- (void)testSameKeysInDifferentWaysAreConflicts {
  SlateShortcutIndex *index = [self index];
  XCTAssertTrue([index shortcutAtBindingIndex:0].conflict, @"${hyper} and ctrl;alt;cmd are the same keys");
  XCTAssertTrue([index shortcutAtBindingIndex:1].conflict);
  XCTAssertFalse([index shortcutAtBindingIndex:5].conflict, @"a disabled shortcut conflicts with nothing");
  XCTAssertEqual(index.conflictCount, 1u);
}

- (void)testLookingUpAKey {
  SlateShortcutIndex *index = [self index];
  NSArray *altShift = @[@"alt", @"shift"], *shiftAlt = @[@"shift", @"alt"], *cmd = @[@"cmd"];
  XCTAssertEqual([index shortcutForKeyName:@"c" modifierNames:altShift].index, 2u);
  XCTAssertEqual([index shortcutForKeyName:@"c" modifierNames:shiftAlt].index, 2u, @"modifier order doesn't matter");
  XCTAssertNil([index shortcutForKeyName:@"c" modifierNames:cmd]);
  XCTAssertEqual([[index shortcutsInGroup:@"shyper"] count], 1u);
  XCTAssertEqual([[index shortcutsInGroup:nil] count], 6u);
}

- (void)testReservedCombosAreRefusedWithAReason {
  NSArray *cmd = @[@"cmd"], *cmdShift = @[@"cmd", @"shift"], *ctrl = @[@"ctrl"], *none = @[];
  XCTAssertTrue([[SlateReservedShortcuts reasonForKeyName:@"s" modifierNames:cmd] containsString:@"⌘S saves"]);
  XCTAssertTrue([[SlateReservedShortcuts reasonForKeyName:@"tab" modifierNames:cmd] containsString:@"switches apps"]);
  XCTAssertNotNil([SlateReservedShortcuts reasonForKeyName:@"4" modifierNames:cmdShift], @"order doesn't matter");
  XCTAssertNotNil([SlateReservedShortcuts reasonForKeyName:@"left" modifierNames:ctrl]);
  XCTAssertTrue([[SlateReservedShortcuts reasonForKeyName:@"c" modifierNames:none] containsString:@"no modifier"]);
}

- (void)testHyperAndOtherCombosAreAllowed {
  NSArray *hyper = @[@"ctrl", @"alt", @"cmd"], *shyper = @[@"ctrl", @"alt", @"shift", @"cmd"], *altCmd = @[@"alt", @"cmd"], *altShift = @[@"alt", @"shift"];
  XCTAssertNil([SlateReservedShortcuts reasonForKeyName:@"s" modifierNames:hyper], @"hyper is never blocked");
  XCTAssertNil([SlateReservedShortcuts reasonForKeyName:@"s" modifierNames:shyper]);
  XCTAssertNil([SlateReservedShortcuts reasonForKeyName:@"s" modifierNames:altCmd], @"only the listed combos");
  XCTAssertNil([SlateReservedShortcuts reasonForKeyName:@"c" modifierNames:altShift]);
}

@end
