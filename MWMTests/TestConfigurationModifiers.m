//
//  TestConfigurationModifiers.m
//
//  The Modifiers page: group cards, and the editor where a group is built on the keyboard.
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
#import "ConfigurationModifiersView.h"
#import "ConfigurationMacKeyboard.h"
#import "MWMConfigDocument.h"

@interface TestConfigurationModifiers : XCTestCase <ConfigurationModifiersViewDelegate>
@property (strong) ConfigurationModifiersView *view;
@property (strong) MWMConfigDocument *doc;
@property (assign) NSUInteger changes;
@property (strong) NSMutableArray *editingStates;
@end

@implementation TestConfigurationModifiers

- (void)setUp {
  NSString *yaml =
    @"modifiers:\n"
    @"  hyper: ctrl;alt;cmd\n"
    @"  shyper: shift;ctrl;alt;cmd\n"
    @"positions:\n"
    @"  centre: move screenOriginX;screenOriginY screenSizeX;screenSizeY\n"
    @"bindings:\n"
    @"  - key: r\n"
    @"    mods: ${hyper}\n"
    @"    action: relaunch\n"
    @"  - key: h\n"
    @"    mods: ${hyper}\n"
    @"    action: hint\n"
    @"  - key: r\n"
    @"    mods: ctrl;alt\n"
    @"    action: undo\n"
    @"  - key: q\n"
    @"    mods: ${hyper}\n"
    @"    action: grid\n";
  self.doc = [MWMConfigDocument documentFromString:yaml error:nil];
  XCTAssertNotNil(self.doc);
  self.editingStates = [NSMutableArray array];
  self.view = [[ConfigurationModifiersView alloc] initWithFrame:NSMakeRect(0, 0, 900, 600)];
  self.view.delegate = self;
  self.view.showsAlerts = NO;
  self.view.document = self.doc;
}

- (void)modifiersViewDidChangeDocument:(ConfigurationModifiersView *)view { self.changes++; }
- (void)modifiersView:(ConfigurationModifiersView *)view didChangeEditing:(BOOL)editing { [self.editingStates addObject:@(editing)]; }

- (NSView *)find:(NSString *)identifier in:(NSView *)root {
  if ([root.identifier isEqualToString:identifier]) return root;
  for (NSView *sub in root.subviews) { NSView *found = [self find:identifier in:sub]; if (found) return found; }
  return nil;
}

- (ConfigurationMapKey *)keyNamed:(NSString *)name {
  return (ConfigurationMapKey *)[self find:[@"modifier-" stringByAppendingString:name] in:self.view];
}

- (void)testEachGroupIsACard {
  XCTAssertNotNil([self find:@"group-hyper" in:self.view]);
  XCTAssertNotNil([self find:@"group-shyper" in:self.view]);
  XCTAssertNotNil([self find:@"new-group" in:self.view]);
  XCTAssertFalse(self.view.editing);
}

#pragma mark - Building a group

- (void)testClickingModifierKeysBuildsAnOrderedCombination {
  [self.view startNewGroup];
  XCTAssertTrue(self.view.editing);
  XCTAssertEqualObjects(self.editingStates, (@[@YES]), @"the window hides its header and bar");
  ConfigurationMapKey *cmd = [self keyNamed:@"cmdL"], *ctrl = [self keyNamed:@"ctrlL"];
  XCTAssertNotNil(cmd); XCTAssertNotNil(ctrl);
  cmd.onClick();
  ctrl.onClick();
  XCTAssertEqualObjects(self.view.draftModifiers, (@[@"ctrl", @"cmd"]), @"always ctrl, alt, shift, cmd order");
  XCTAssertEqual(cmd.state, MapKeyStateOn);
  ctrl.onClick();
  XCTAssertEqualObjects(self.view.draftModifiers, (@[@"cmd"]));
  XCTAssertNotEqual(ctrl.state, MapKeyStateOn);
}

- (void)testOnlyTheLeftModifierKeysAreClickable {
  [self.view startNewGroup];
  for (NSString *name in @[@"ctrlL", @"optL", @"shiftL", @"cmdL"]) {
    XCTAssertNotNil([self keyNamed:name].modifierName, @"%@", name);
    XCTAssertTrue([self keyNamed:name].clickable, @"%@", name);
  }
  for (NSString *name in @[@"optR", @"shiftR", @"cmdR"]) {
    ConfigurationMapKey *key = [self keyNamed:name];
    XCTAssertNil(key.modifierName, @"%@ only repeats the left one", name);
    XCTAssertFalse(key.clickable);
    XCTAssertNil(key.onClick);
  }
  [self keyNamed:@"optL"].onClick();
  XCTAssertEqualObjects(self.view.draftModifiers, (@[@"alt"]));
  XCTAssertEqual([self keyNamed:@"optL"].state, MapKeyStateOn);
  XCTAssertNotEqual([self keyNamed:@"optR"].state, MapKeyStateOn, @"the right side isn't lit, which would confuse");
}

- (void)testOnlyModifierKeysTakeClicksInTheEditor {
  [self.view startNewGroup];
  ConfigurationMapKey *fn = [self keyNamed:@"fn"];
  XCTAssertNotNil(fn);
  XCTAssertNil(fn.modifierName, @"fn isn't offered as a group modifier");
  XCTAssertNil(fn.onClick);
  }

#pragma mark - Rules

- (void)testASaveNeedsANameAKeyAndNothingAlreadyTaken {
  [self.view startNewGroup];
  XCTAssertEqualObjects(self.view.problem, @"Give the group a name.");
  self.view.draftName = @"mini";
  XCTAssertEqualObjects(self.view.problem, @"Click at least one modifier key.");
  self.view.draftName = @"hyper";
  [self.view toggleModifier:@"alt"];
  XCTAssertEqualObjects(self.view.problem, @"The name \"hyper\" is already used.");
  self.view.draftName = @"centre";
  XCTAssertEqualObjects(self.view.problem, @"The name \"centre\" is already used.", @"slots and groups share names");
  self.view.draftName = @"my group";
  XCTAssertNotNil(self.view.problem, @"no spaces in a name");
  self.view.draftName = @"mini";
  XCTAssertNil(self.view.problem);
  [self.view toggleModifier:@"alt"];
  for (NSString *name in @[@"ctrl", @"alt", @"cmd"]) [self.view toggleModifier:name];
  XCTAssertEqualObjects(self.view.problem, @"Same keys as \"hyper\".");
}

- (void)testSavingANewGroupAddsItAndGoesBackToTheList {
  [self.view startNewGroup];
  self.view.draftName = @"mini";
  [self.view toggleModifier:@"shift"];
  [self.view toggleModifier:@"alt"];
  [self.view save];
  MWMConfigEntry *entry = self.doc.modifiers.lastObject;
  XCTAssertEqualObjects(entry.name, @"mini");
  XCTAssertEqualObjects(entry.value, @"alt;shift");
  XCTAssertEqual(self.changes, 1u);
  XCTAssertFalse(self.view.editing);
  XCTAssertEqualObjects(self.editingStates, (@[@YES, @NO]));
  XCTAssertNotNil([self find:@"group-mini" in:self.view], @"the list shows it");
}

- (void)testAnInvalidGroupIsNotSaved {
  [self.view startNewGroup];
  self.view.draftName = @"hyper";
  [self.view toggleModifier:@"alt"];
  [self.view save];
  XCTAssertEqual([self.doc.modifiers count], 2u);
  XCTAssertEqual(self.changes, 0u);
  XCTAssertTrue(self.view.editing);
}

#pragma mark - Editing

- (void)testEditingStartsWithoutChangesAndSavesTheNewKeys {
  [self.view editGroupNamed:@"hyper"];
  XCTAssertFalse(self.view.hasUnsavedChanges);
  XCTAssertEqualObjects(self.view.draftModifiers, (@[@"ctrl", @"alt", @"cmd"]));
  XCTAssertEqual([self keyNamed:@"cmdL"].state, MapKeyStateOn);
  [self.view toggleModifier:@"cmd"];
  XCTAssertTrue(self.view.hasUnsavedChanges);
  [self.view save];
  XCTAssertEqualObjects([self.doc.modifiers[0] value], @"ctrl;alt");
}

- (void)testRenamingAGroupRenamesWhereShortcutsUseIt {
  [self.view editGroupNamed:@"hyper"];
  self.view.draftName = @"super";
  [self.view save];
  XCTAssertEqualObjects([self.doc.modifiers[0] name], @"super");
  XCTAssertEqualObjects(self.doc.bindings[0].modifiers, @"${super}");
  XCTAssertEqualObjects(self.doc.bindings[1].modifiers, @"${super}");
}

- (void)testCancelAndBackGoBackToTheListWithoutSaving {
  [self.view editGroupNamed:@"hyper"];
  [self.view toggleModifier:@"shift"];
  [self.view performSelector:NSSelectorFromString(@"cancelPressed:") withObject:nil];
  XCTAssertFalse(self.view.editing, @"Cancel goes back to the list");
  XCTAssertEqualObjects([self.doc.modifiers[0] value], @"ctrl;alt;cmd");
  [self.view editGroupNamed:@"hyper"];
  [self.view toggleModifier:@"shift"];
  [self.view performSelector:NSSelectorFromString(@"backPressed:") withObject:nil];
  XCTAssertFalse(self.view.editing);
  XCTAssertEqualObjects([self.doc.modifiers[0] value], @"ctrl;alt;cmd", @"nothing was written");
  XCTAssertEqual(self.changes, 0u);
}

#pragma mark - What a change would cause

- (void)testChangingAGroupWarnsWhenShortcutsWouldShareKeys {
  [self.view editGroupNamed:@"hyper"];
  XCTAssertEqual([self.view.warnings count], 0u, @"nothing changed, nothing to warn about");
  [self.view toggleModifier:@"cmd"];   // hyper becomes ctrl;alt, which "undo" already uses on R
  NSString *all = [self.view.warnings componentsJoinedByString:@"\n"];
  XCTAssertTrue([all containsString:@"fire for"], @"%@", all);
  XCTAssertTrue([all containsString:@"Only one can work"], @"%@", all);
  XCTAssertNil(self.view.problem, @"it's a warning: Save still works");
  [self.view save];
  XCTAssertEqualObjects([self.doc.modifiers[0] value], @"ctrl;alt");
}

- (void)testChangingAGroupWarnsWhenAShortcutLandsOnKeysMacOSKeeps {
  [self.view editGroupNamed:@"hyper"];
  [self.view toggleModifier:@"ctrl"];
  [self.view toggleModifier:@"alt"];   // hyper becomes ⌘ alone: ⌘Q and ⌘H belong to macOS
  NSString *all = [self.view.warnings componentsJoinedByString:@"\n"];
  XCTAssertTrue([all containsString:@"macOS keeps"], @"%@", all);
}

- (NSString *)message {
  return [(NSTextField *)[self.view valueForKey:@"messageLabel"] stringValue];
}

// The ⚠ mark is part of a warning, so with nothing to warn about the line is empty.
- (void)testTheWarningLineIsEmptyUnlessThereIsAWarning {
  [self.view editGroupNamed:@"hyper"];
  XCTAssertEqualObjects([self message], @"");
  [self.view toggleModifier:@"shift"];   // blocked: a problem, shown without a mark
  XCTAssertEqualObjects([self message], @"Same keys as \"shyper\".");
  [self.view toggleModifier:@"shift"];
  XCTAssertEqualObjects([self message], @"");
  [self.view toggleModifier:@"cmd"];     // a warning
  XCTAssertTrue([[self message] hasPrefix:@"⚠︎ "], @"%@", [self message]);
  [self.view toggleModifier:@"cmd"];
  XCTAssertEqualObjects([self message], @"", @"back to the saved keys: no mark left behind");
}

- (void)testAWarningOnlyListsWhatTheChangeCauses {
  [self.view editGroupNamed:@"hyper"];
  [self.view toggleModifier:@"shift"];  // ctrl;alt;shift;cmd: nobody else has it, so no new conflicts (it equals shyper: blocked instead)
  XCTAssertEqualObjects(self.view.problem, @"Same keys as \"shyper\".");
  XCTAssertEqual([self.view.warnings count], 0u);
}

#pragma mark - Removing

- (void)testAnUnusedGroupCanBeRemovedAndAUsedOneCannot {
  [self.view removeGroupNamed:@"hyper"];
  XCTAssertEqual([self.doc.modifiers count], 2u, @"two shortcuts use it");
  [self.view removeGroupNamed:@"shyper"];
  XCTAssertEqual([self.doc.modifiers count], 1u);
  XCTAssertEqual(self.changes, 1u);
  XCTAssertNil([self find:@"group-shyper" in:self.view]);
}

- (void)testSettingTheDocumentAgainClosesTheEditor {
  [self.view startNewGroup];
  self.view.document = nil;
  XCTAssertFalse(self.view.editing);
  XCTAssertEqualObjects(self.editingStates, (@[@YES, @NO]));
}

@end
