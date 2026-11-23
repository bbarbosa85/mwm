//
//  TestConfigurationKeyboard.m
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
#import "ConfigurationKeyboardView.h"
#import "ConfigurationShortcutListView.h"
#import "ConfigurationKeyboardMapView.h"
#import "ConfigurationShortcutEditorView.h"
#import "MWMConfigDocument.h"
#import "MWMShortcutIndex.h"

@interface TestConfigurationKeyboard : XCTestCase <ConfigurationKeyboardViewDelegate, ConfigurationKeyboardMapViewDelegate>
@property (assign) NSUInteger changes;
@property (assign) NSUInteger editedIndex;
@property (copy) NSString *addedKey;
@property (copy) NSString *addedGroup;
@end

@implementation TestConfigurationKeyboard

- (void)keyboardViewDidChangeDocument:(ConfigurationKeyboardView *)view { self.changes++; }
- (void)keyboardMapViewDidChangeDocument:(ConfigurationKeyboardMapView *)view { self.changes++; }
- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsToEditBindingAtIndex:(NSUInteger)index { self.editedIndex = index; }
- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsNewShortcutInGroup:(NSString *)groupName keyName:(NSString *)keyName { self.addedKey = keyName; self.addedGroup = groupName; }
- (void)keyboardMapViewWantsGroups:(ConfigurationKeyboardMapView *)view {}

static NSString *const kConfig =
  @"modifiers:\n  hyper: ctrl;alt;cmd\n  shyper: shift;ctrl;alt;cmd\n"
  @"positions:\n  half: move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"bindings:\n"
  @"  - key: pad8\n    mods: ${hyper}\n    action: ${half}\n"
  @"  - key: pad9\n    mods: ${hyper}\n    action: ${half}\n"
  @"  - key: c\n    mods: alt;shift\n    action: focus 'Google Chrome'\n"
  @"  - key: h\n    mods: ${shyper}\n    action: hint ASDF\n"
  @"  - key: pad8\n    mods: ctrl;alt;cmd\n    action: relaunch\n";

- (ConfigurationShortcutListView *)listWith:(MWMConfigDocument **)outDoc {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
  XCTAssertNotNil(doc);
  ConfigurationKeyboardView *keyboard = [[ConfigurationKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 600)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 600) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:keyboard];
  keyboard.delegate = self;
  keyboard.document = doc;
  keyboard.mode = ConfigurationKeyboardModeList;
  [window layoutIfNeeded];
  self.changes = 0;
  *outDoc = doc;
  objc_setAssociatedObject(window, "keyboard", keyboard, OBJC_ASSOCIATION_RETAIN);
  return [keyboard valueForKey:@"listView"];
}

- (NSArray<NSString *> *)rowIdentifiersIn:(NSView *)root {
  NSMutableArray *ids = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([[view identifier] hasPrefix:@"binding-"]) [ids addObject:[view identifier]];
    [queue addObjectsFromArray:[view subviews]];
  }
  return [ids sortedArrayUsingSelector:@selector(compare:)];
}

- (void)testTheListShowsEveryShortcut {
  MWMConfigDocument *doc;
  ConfigurationShortcutListView *list = [self listWith:&doc];
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-0", @"binding-1", @"binding-2", @"binding-3", @"binding-4"]));
}

- (void)testFiltersNarrowTheList {
  MWMConfigDocument *doc;
  ConfigurationShortcutListView *list = [self listWith:&doc];
  list.groupFilter = @"shyper";
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-3"]));
  list.groupFilter = nil;
  list.kindFilter = @(MWMShortcutKindFocusApp);
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-2"]));
  list.kindFilter = nil;
  list.conflictsOnly = YES;
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-0", @"binding-4"]), @"the two with the same keys");
  list.conflictsOnly = NO;
  list.query = @"chrome";
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-2"]));
  list.query = @"hyper";
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-0", @"binding-1", @"binding-3", @"binding-4"]), @"search matches the group name too, and shyper contains hyper");
}

- (void)testSwitchingAShortcutOffSavesAndClearsItsConflict {
  MWMConfigDocument *doc;
  ConfigurationShortcutListView *list = [self listWith:&doc];
  NSButton *toggle = nil;
  NSMutableArray *queue = [NSMutableArray arrayWithObject:list];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSButton class]] && [[view identifier] isEqualToString:@"enabled-4"]) toggle = (NSButton *)view;
    [queue addObjectsFromArray:[view subviews]];
  }
  XCTAssertNotNil(toggle);
  [toggle setState:NSControlStateValueOff];
  [NSApp sendAction:[toggle action] to:[toggle target] from:toggle];
  XCTAssertFalse(doc.bindings[4].enabled);
  XCTAssertEqual(self.changes, 1u);
  list.conflictsOnly = YES;
  XCTAssertEqual([[self rowIdentifiersIn:list] count], 0u, @"no conflict left");
}

#pragma mark - Map

- (ConfigurationKeyboardMapView *)mapWith:(MWMConfigDocument **)outDoc {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
  ConfigurationKeyboardMapView *map = [[ConfigurationKeyboardMapView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 640) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:map];
  map.delegate = self;
  map.confirmsRemoval = NO;
  map.document = doc;
  [window layoutIfNeeded];
  objc_setAssociatedObject(map, "window", window, OBJC_ASSOCIATION_RETAIN);
  self.changes = 0;
  *outDoc = doc;
  return map;
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
    [queue addObjectsFromArray:[view subviews]];
  }
  return texts;
}

- (void)testTheMapStartsOnTheFirstGroupAndListsGroupCards {
  MWMConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  XCTAssertEqualObjects(map.groupName, @"hyper");
  XCTAssertNotNil([self viewIn:map identifier:@"group-hyper"]);
  XCTAssertNotNil([self viewIn:map identifier:@"group-shyper"]);
  XCTAssertNotNil([self viewIn:map identifier:@"group-Custom"]);
  XCTAssertNotNil([self viewIn:map identifier:@"key-pad8"], @"the numpad is on the map");
}

- (void)testClickingAKeyShowsWhatItDoes {
  MWMConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  [map selectKeyNamed:@"pad9"];
  NSArray *texts = [self textsIn:map];
  XCTAssertTrue([texts containsObject:@"Move to half"]);
  XCTAssertTrue([texts containsObject:@"To"]);
  XCTAssertTrue([texts containsObject:@"Remove"] || [self viewIn:map identifier:@"x"] == nil);
}

- (void)testAKeyWithTwoShortcutsInAGroupIsAConflictAndSaysSo {
  MWMConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  [map selectKeyNamed:@"pad8"];
  XCTAssertNotNil([self viewIn:map identifier:@"key-pad8"]);
  XCTAssertTrue(map.selectedKeyName != nil);
}

- (void)testAFreeKeyOffersToAddAndAReservedOneExplains {
  MWMConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  [map selectKeyNamed:@"pad1"];
  XCTAssertTrue([[self textsIn:map] containsObject:@"Nothing yet. This key is free in this group."]);
  map.groupName = @"Custom";
  [map selectKeyNamed:@"c"];
  XCTAssertTrue([[self textsIn:map] containsObject:@"To"]);
}

- (void)testRemovingAShortcutFromTheMapSaves {
  MWMConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  NSUInteger before = [doc.bindings count];
  [map selectKeyNamed:@"pad9"];
  [map removeSelected];
  XCTAssertEqual([doc.bindings count], before - 1);
  XCTAssertEqual(self.changes, 1u);
  XCTAssertNil(map.selectedKeyName);
}


#pragma mark - Editor

- (ConfigurationShortcutEditorView *)editorWith:(MWMConfigDocument **)outDoc {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
  ConfigurationShortcutEditorView *editor = [[ConfigurationShortcutEditorView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 640) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:editor];
  editor.confirmsDiscard = NO;
  editor.document = doc;
  objc_setAssociatedObject(editor, "window", window, OBJC_ASSOCIATION_RETAIN);
  *outDoc = doc;
  return editor;
}

- (void)testEditingAShortcutStartsWithoutChangesAndSavesWhatChanged {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor editBindingAtIndex:0];
  XCTAssertFalse(editor.isNew);
  XCTAssertFalse(editor.hasUnsavedChanges);
  XCTAssertNil(editor.problem);
  NSString *keyBefore = editor.draftKeyName;
  [editor selectKind:MWMActionKindRelaunch];
  XCTAssertTrue(editor.hasUnsavedChanges);
  [editor save];
  XCTAssertEqualObjects([[doc.bindings objectAtIndex:0] key], keyBefore);
  XCTAssertEqualObjects([MWMAction parse:[[doc.bindings objectAtIndex:0] action]].string, [MWMAction actionOfKind:MWMActionKindRelaunch].string);
}

// Lets the editor's deferred refresh run.
- (void)settle { [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]]; }

- (void)testPushShowsItsStyleThicknessAndScreenAsControls {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor selectKind:MWMActionKindPush];
  [self settle];
  XCTAssertEqualObjects(editor.draftAction.b, @"bar-resize:screenSizeX/2");
  XCTAssertNotNil([self viewIn:editor identifier:@"push-style"]);
  XCTAssertNotNil([self viewIn:editor identifier:@"row-thickness"]);
  XCTAssertNil([self viewIn:editor identifier:@"row-options"], @"the text field is only for text the controls can't show");
  NSSegmentedControl *unit = (NSSegmentedControl *)[self viewIn:editor identifier:@"push-unit"];
  [unit setSelectedSegment:0];   // % keeps the size: half the screen
  [NSApp sendAction:[unit action] to:[unit target] from:unit];
  [self settle];
  XCTAssertEqualObjects(editor.draftAction.b, @"bar-resize:screenSizeX*50/100");
  NSTextField *thickness = (NSTextField *)[self viewIn:editor identifier:@"push-thickness"];
  [thickness setStringValue:@"30"];
  [NSApp sendAction:[thickness action] to:[thickness target] from:thickness];
  [self settle];
  XCTAssertEqualObjects(editor.draftAction.b, @"bar-resize:screenSizeX*30/100");
}

- (void)testChangingThePushDirectionMovesTheThicknessToTheOtherSide {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor selectKind:MWMActionKindPush];
  [self settle];
  NSPopUpButton *direction = [self popupIn:[self viewIn:editor identifier:@"row-direction"]];
  XCTAssertNotNil(direction);
  [direction selectItemWithTitle:@"up"];
  [NSApp sendAction:[direction action] to:[direction target] from:direction];
  [self settle];
  XCTAssertEqualObjects(editor.draftAction.a, @"up");
  XCTAssertEqualObjects(editor.draftAction.b, @"bar-resize:screenSizeY/2", @"half the height now");
}

- (NSPopUpButton *)popupIn:(NSView *)root {
  if ([root isKindOfClass:[NSPopUpButton class]]) return (NSPopUpButton *)root;
  for (NSView *view in root.subviews) { NSPopUpButton *found = [self popupIn:view]; if (found != nil) return found; }
  return nil;
}

- (void)testAThicknessTheControlsCanNotShowStaysAsText {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor selectKind:MWMActionKindPush];
  editor.draftAction.b = @"bar-resize:(screenSizeX/3)+20";
  [editor performSelector:NSSelectorFromString(@"refresh")];
  XCTAssertNotNil([self viewIn:editor identifier:@"row-options"]);
  XCTAssertNil([self viewIn:editor identifier:@"push-style"]);
}

- (void)testAThicknessOfZeroBlocksSave {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor useKeyName:@"j" modifierNames:@[@"ctrl", @"alt"] groupName:nil];
  [editor selectKind:MWMActionKindPush];
  XCTAssertNil(editor.problem);
  editor.draftAction.b = @"bar-resize:screenSizeX/0";
  XCTAssertTrue([editor.problem containsString:@"more than zero"], @"%@", editor.problem);
}

- (void)testAnAdvancedMoveShowsWhereItGoesAndNamesMistakes {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor useKeyName:@"j" modifierNames:@[@"ctrl", @"alt"] groupName:nil];
  [editor selectKind:MWMActionKindCustom];
  editor.draftAction.a = @"chain push up | push right";
  [editor performSelector:NSSelectorFromString(@"refresh")];
  XCTAssertNil([self viewIn:editor identifier:@"custom-check"], @"other operations keep the plain field");
  XCTAssertNil(editor.problem);
  editor.draftAction.a = @"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY";
  [editor performSelector:NSSelectorFromString(@"refresh")];
  XCTAssertTrue([[(NSTextField *)[self viewIn:editor identifier:@"custom-check"] stringValue] hasPrefix:@"No problems"]);
  XCTAssertNotNil([self viewIn:editor identifier:@"formula-help"]);
  XCTAssertNil(editor.problem);
  editor.draftAction.a = @"move screenOriginX;screenOriginY screenSizeX / 2;screenSizeY";
  [editor performSelector:NSSelectorFromString(@"refresh")];
  XCTAssertTrue([[(NSTextField *)[self viewIn:editor identifier:@"custom-check"] stringValue] containsString:@"spaces"]);
  XCTAssertTrue([editor.problem containsString:@"spaces"], @"%@", editor.problem);
}

- (void)testANewShortcutNeedsKeysAndAnApplicationThenAddsABinding {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  NSUInteger before = [doc.bindings count];
  [editor startNewWithGroup:nil keyName:nil];
  XCTAssertTrue(editor.isNew);
  XCTAssertNotNil(editor.problem, @"no keys yet");
  [editor useKeyName:@"j" modifierNames:@[@"ctrl", @"alt"] groupName:nil];
  XCTAssertNotNil(editor.problem, @"no application yet");
  editor.draftAction.a = @"Finder";
  XCTAssertNil(editor.problem);
  [editor save];
  XCTAssertEqual([doc.bindings count], before + 1);
  MWMBindingEntry *added = [doc.bindings lastObject];
  XCTAssertEqualObjects(added.key, @"j");
  XCTAssertTrue(added.enabled);
  XCTAssertTrue([added.action containsString:@"Finder"]);
}

- (void)testAGroupWritesItsNameAndAReservedComboBlocksSave {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:@"hyper" keyName:@"j"];
  editor.draftAction.a = @"Finder";
  XCTAssertNil(editor.problem);
  [editor save];
  XCTAssertEqualObjects([[doc.bindings lastObject] modifiers], @"${hyper}");
  [editor startNewWithGroup:nil keyName:nil];
  editor.draftAction.a = @"Finder";
  [editor useKeyName:@"s" modifierNames:@[@"cmd"] groupName:nil];
  XCTAssertNotNil(editor.problem, @"cmd+S belongs to macOS");
}

- (void)testRecordingTakesKeysOnEnterAndEscapeCancels {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor beginRecording];
  XCTAssertTrue(editor.recording);
  [editor recordKeyCode:38 modifierFlags:NSEventModifierFlagControl | NSEventModifierFlagOption];   // J
  XCTAssertNil(editor.draftKeyName, @"nothing is taken until Enter");
  [editor recordKeyCode:36 modifierFlags:0];
  XCTAssertFalse(editor.recording);
  XCTAssertEqualObjects(editor.draftKeyName, @"j");
  XCTAssertEqualObjects(editor.draftModifierNames, (@[@"ctrl", @"alt"]));
  [editor beginRecording];
  [editor recordKeyCode:40 modifierFlags:NSEventModifierFlagControl];
  [editor recordKeyCode:53 modifierFlags:0];
  XCTAssertFalse(editor.recording);
  XCTAssertEqualObjects(editor.draftKeyName, @"j", @"Esc keeps the old keys");
}

- (void)testEnterDoesNotTakeAKeyMacOSKeeps {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor beginRecording];
  [editor recordKeyCode:1 modifierFlags:NSEventModifierFlagCommand];   // cmd+S
  [editor recordKeyCode:36 modifierFlags:0];
  XCTAssertTrue(editor.recording, @"still waiting");
  XCTAssertNil(editor.draftKeyName);
  [editor cancelRecording];
}

- (void)testTheKeyboardViewOpensTheEditorAndShowsThePageAgainAfterSaving {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
  ConfigurationKeyboardView *keyboard = [[ConfigurationKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
  keyboard.delegate = self;
  keyboard.document = doc;
  [keyboard openBindingAtIndex:0];
  XCTAssertTrue(keyboard.isEditing);
  XCTAssertFalse([keyboard.editor isHidden]);
  [keyboard.editor close];
  XCTAssertFalse(keyboard.isEditing);
  [keyboard startNewShortcutInGroup:@"hyper" keyName:@"j"];
  XCTAssertTrue(keyboard.editor.isNew);
  XCTAssertEqualObjects(keyboard.editor.draftKeyName, @"j");
}


- (NSUInteger)slotRowsIn:(NSView *)root {
  NSUInteger count = 0;
  NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([[view identifier] hasPrefix:@"slot-"] && ![[view identifier] isEqualToString:@"slot-search"] && ![[view identifier] isEqualToString:@"slot-filter"] && ![[view identifier] isEqualToString:@"slot-list"]) count++;
    [queue addObjectsFromArray:[view subviews]];
  }
  return count;
}

- (void)testTheSlotPickerListsSlotsFiltersThemAndPicksOne {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor selectKind:MWMActionKindMove];
  [[editor window] layoutIfNeeded];
  NSUInteger all = [self slotRowsIn:editor];
  XCTAssertGreaterThanOrEqual(all, 19u, @"the presets are all there");
  NSSearchField *search = (NSSearchField *)[self viewIn:editor identifier:@"slot-search"];
  XCTAssertNotNil(search);
  [search setStringValue:@"third"];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:search];
  NSUInteger filtered = [self slotRowsIn:editor];
  XCTAssertLessThan(filtered, all);
  XCTAssertGreaterThan(filtered, 0u);
  [editor chooseSlotNamed:@"lefthalf"];
  XCTAssertEqualObjects(editor.draftAction.a, @"lefthalf");
}


- (void)testTheEditorOffersSnapshotActions {
  MWMConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor startNewWithGroup:nil keyName:nil];
  [editor useKeyName:@"j" modifierNames:@[@"ctrl", @"alt"] groupName:nil];
  [editor selectKind:MWMActionKindSnapshot];
  XCTAssertNotNil(editor.problem, @"a snapshot needs a name");
  editor.draftAction.a = @"two words";
  XCTAssertTrue([editor.problem containsString:@"spaces"]);
  editor.draftAction.a = @"work";
  XCTAssertNil(editor.problem);
  [editor save];
  XCTAssertEqualObjects([[doc.bindings lastObject] action], @"snapshot work save-to-disk");
  [editor startNewWithGroup:nil keyName:nil];
  [editor useKeyName:@"k" modifierNames:@[@"ctrl", @"alt"] groupName:nil];
  [editor selectKind:MWMActionKindRestoreSnapshot];
  editor.draftAction.a = @"work";
  [editor save];
  XCTAssertEqualObjects([[doc.bindings lastObject] action], @"activate-snapshot work");
}

@end
