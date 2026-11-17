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
#import "SlateConfigDocument.h"
#import "SlateShortcutIndex.h"

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

- (ConfigurationShortcutListView *)listWith:(SlateConfigDocument **)outDoc {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:nil];
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
  SlateConfigDocument *doc;
  ConfigurationShortcutListView *list = [self listWith:&doc];
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-0", @"binding-1", @"binding-2", @"binding-3", @"binding-4"]));
}

- (void)testFiltersNarrowTheList {
  SlateConfigDocument *doc;
  ConfigurationShortcutListView *list = [self listWith:&doc];
  list.groupFilter = @"shyper";
  XCTAssertEqualObjects([self rowIdentifiersIn:list], (@[@"binding-3"]));
  list.groupFilter = nil;
  list.kindFilter = @(SlateShortcutKindFocusApp);
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
  SlateConfigDocument *doc;
  ConfigurationShortcutListView *list = [self listWith:&doc];
  NSSwitch *toggle = nil;
  NSMutableArray *queue = [NSMutableArray arrayWithObject:list];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSSwitch class]] && [(NSSwitch *)view tag] == 4) toggle = (NSSwitch *)view;
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

- (ConfigurationKeyboardMapView *)mapWith:(SlateConfigDocument **)outDoc {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:nil];
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
  SlateConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  XCTAssertEqualObjects(map.groupName, @"hyper");
  XCTAssertNotNil([self viewIn:map identifier:@"group-hyper"]);
  XCTAssertNotNil([self viewIn:map identifier:@"group-shyper"]);
  XCTAssertNotNil([self viewIn:map identifier:@"group-Custom"]);
  XCTAssertNotNil([self viewIn:map identifier:@"key-pad8"], @"the numpad is on the map");
}

- (void)testClickingAKeyShowsWhatItDoes {
  SlateConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  [map selectKeyNamed:@"pad9"];
  NSArray *texts = [self textsIn:map];
  XCTAssertTrue([texts containsObject:@"Move to half"]);
  XCTAssertTrue([texts containsObject:@"To"]);
  XCTAssertTrue([texts containsObject:@"Remove"] || [self viewIn:map identifier:@"x"] == nil);
}

- (void)testAKeyWithTwoShortcutsInAGroupIsAConflictAndSaysSo {
  SlateConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  [map selectKeyNamed:@"pad8"];
  XCTAssertNotNil([self viewIn:map identifier:@"key-pad8"]);
  XCTAssertTrue(map.selectedKeyName != nil);
}

- (void)testAFreeKeyOffersToAddAndAReservedOneExplains {
  SlateConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  [map selectKeyNamed:@"pad1"];
  XCTAssertTrue([[self textsIn:map] containsObject:@"Nothing yet. This key is free in this group."]);
  map.groupName = @"Custom";
  [map selectKeyNamed:@"c"];
  XCTAssertTrue([[self textsIn:map] containsObject:@"To"]);
}

- (void)testRemovingAShortcutFromTheMapSaves {
  SlateConfigDocument *doc;
  ConfigurationKeyboardMapView *map = [self mapWith:&doc];
  NSUInteger before = [doc.bindings count];
  [map selectKeyNamed:@"pad9"];
  [map removeSelected];
  XCTAssertEqual([doc.bindings count], before - 1);
  XCTAssertEqual(self.changes, 1u);
  XCTAssertNil(map.selectedKeyName);
}


#pragma mark - Editor

- (ConfigurationShortcutEditorView *)editorWith:(SlateConfigDocument **)outDoc {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:nil];
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
  SlateConfigDocument *doc;
  ConfigurationShortcutEditorView *editor = [self editorWith:&doc];
  [editor editBindingAtIndex:0];
  XCTAssertFalse(editor.isNew);
  XCTAssertFalse(editor.hasUnsavedChanges);
  XCTAssertNil(editor.problem);
  NSString *keyBefore = editor.draftKeyName;
  [editor selectKind:SlateActionKindRelaunch];
  XCTAssertTrue(editor.hasUnsavedChanges);
  [editor save];
  XCTAssertEqualObjects([[doc.bindings objectAtIndex:0] key], keyBefore);
  XCTAssertEqualObjects([SlateAction parse:[[doc.bindings objectAtIndex:0] action]].string, [SlateAction actionOfKind:SlateActionKindRelaunch].string);
}

- (void)testANewShortcutNeedsKeysAndAnApplicationThenAddsABinding {
  SlateConfigDocument *doc;
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
  SlateBindingEntry *added = [doc.bindings lastObject];
  XCTAssertEqualObjects(added.key, @"j");
  XCTAssertTrue(added.enabled);
  XCTAssertTrue([added.action containsString:@"Finder"]);
}

- (void)testAGroupWritesItsNameAndAReservedComboBlocksSave {
  SlateConfigDocument *doc;
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
  SlateConfigDocument *doc;
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
  SlateConfigDocument *doc;
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
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:nil];
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

@end
