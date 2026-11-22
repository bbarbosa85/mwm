//
//  TestConfigurationForm.m
//  Slate
//
//  Tests for the Form view's model support (categories, lenient reading,
//  alias expansion) and for its add/remove/edit flows.
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
#import "SlateConfigDocument.h"
#import "ConfigurationFormView.h"

@interface TestConfigurationForm : XCTestCase <ConfigurationFormViewDelegate>
@property (assign) NSUInteger changes;
@end

@implementation TestConfigurationForm

static NSString *const kConfig =
  @"settings:\n"
  @"  defaultToCurrentScreen: true\n"
  @"modifiers:\n"
  @"  hyper: ctrl;alt;cmd\n"
  @"monitors:\n"
  @"  monitor-samsung: \"0\"\n"
  @"  monitor-samsung-size: 5120x1440\n"
  @"positions:\n"
  @"  lefthalf: move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"  samsung-full: move 0;0 1;1 ${monitor-samsung-size}\n"
  @"aliases:\n"
  @"  full: ${lefthalf}\n"
  @"bindings:\n"
  @"  - key: c\n    mods: alt;shift\n    action: focus 'Google Chrome'\n"
  @"  - key: pad4\n    mods: ${hyper}\n    action: ${lefthalf} ${monitor-samsung}\n"
  @"  - key: pad5\n    mods: ${hyper}\n    action: ${full}\n"
  @"  - key: right\n    mods: ctrl;cmd\n    action: resize +5% +0\n"
  @"  - key: pad6\n    mods: cmd;ctrl\n    action: focus right\n    enabled: false\n"
  @"  - key: h\n    mods: cmd;shift\n    action: hint ASDF\n"
  @"  - key: r\n    mods: ${hyper}\n    action: relaunch\n";

- (void)formViewDidChangeDocument:(ConfigurationFormView *)formView { self.changes++; }
- (void)formViewWantsTextEditor:(ConfigurationFormView *)formView {}
- (void)formViewWantsReload:(ConfigurationFormView *)formView {}

- (SlateConfigDocument *)document {
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  return doc;
}

#pragma mark - Model

- (void)testCategories {
  SlateConfigDocument *doc = [self document];
  NSMutableArray *categories = [NSMutableArray array];
  for (SlateBindingEntry *b in doc.bindings) [categories addObject:@([doc categoryOfBinding:b])];
  XCTAssertEqualObjects(categories, (@[@(SlateBindingCategoryApps), @(SlateBindingCategoryLayout), @(SlateBindingCategoryLayout),
                                       @(SlateBindingCategoryWindowActions), @(SlateBindingCategoryWindowActions),
                                       @(SlateBindingCategoryFeatures), @(SlateBindingCategoryFeatures)]),
                        @"aliases are expanded (nested ${full} -> ${lefthalf} -> move) before categorizing");
}

- (void)testExpandAliases {
  SlateConfigDocument *doc = [self document];
  XCTAssertEqualObjects([doc expandAliases:@"${samsung-full} ${nope}"], @"move 0;0 1;1 5120x1440 ${nope}",
                        @"nested references expand; unknown ones stay as written");
}

- (void)testLenientReadAllowsUnknownAliases {
  NSString *source = [kConfig stringByReplacingOccurrencesOfString:@"action: ${full}" withString:@"action: ${fulll}"];
  NSError *error = nil;
  XCTAssertNil([SlateConfigDocument documentFromString:source error:&error]);
  XCTAssertEqual(error.code, SlateConfigDocumentErrorInvalid);
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:source lenient:YES error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  XCTAssertEqualObjects(doc.bindings[2].action, @"${fulll}");

  NSString *broken = [kConfig stringByReplacingOccurrencesOfString:@"  - key: c\n    mods" withString:@"  - mods"];
  XCTAssertNil([SlateConfigDocument documentFromString:broken lenient:YES error:&error], @"structure is still checked");
}

#pragma mark - Form view

- (ConfigurationFormView *)formWithDocument:(SlateConfigDocument *)doc {
  ConfigurationFormView *form = [[ConfigurationFormView alloc] initWithFrame:NSMakeRect(0, 0, 900, 500)];
  form.delegate = self;
  form.document = doc;
  self.changes = 0;
  return form;
}

- (NSTableView *)tableOf:(ConfigurationFormView *)form {
  return [form valueForKey:@"table"];
}

- (void)testSectionsShowTheirRows {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  NSDictionary *expected = @{
    @(ConfigurationFormSectionGeneral): @1, @(ConfigurationFormSectionModifiers): @1, @(ConfigurationFormSectionMonitors): @2,
    @(ConfigurationFormSectionPositions): @2, @(ConfigurationFormSectionAliases): @1, @(ConfigurationFormSectionApps): @1,
    @(ConfigurationFormSectionLayout): @2, @(ConfigurationFormSectionWindowActions): @2, @(ConfigurationFormSectionFeatures): @2,
  };
  for (NSNumber *section in expected) {
    form.selectedSection = [section integerValue];
    XCTAssertEqual([[self tableOf:form] numberOfRows], [expected[section] integerValue], @"section %@", section);
  }
}

- (void)testAddAndRemoveBinding {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionApps;
  [form performSelector:@selector(add:) withObject:nil];
  XCTAssertEqual([doc.bindings count], 8u);
  XCTAssertEqual(self.changes, 1u);
  SlateBindingEntry *added = doc.bindings[1];
  XCTAssertEqual([doc categoryOfBinding:added], SlateBindingCategoryApps, @"inserted after the section's last binding");
  XCTAssertEqual([[self tableOf:form] numberOfRows], 2);

  [[self tableOf:form] selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
  [form performSelector:@selector(remove:) withObject:nil];
  XCTAssertEqual([doc.bindings count], 7u);
  XCTAssertFalse([doc.bindings containsObject:added]);
  XCTAssertEqual(self.changes, 2u);
}

- (void)testAddedAliasGetsUniqueName {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionModifiers;
  [form performSelector:@selector(add:) withObject:nil];
  [form performSelector:@selector(add:) withObject:nil];
  XCTAssertEqualObjects([doc.modifiers valueForKey:@"name"], (@[@"hyper", @"modifier", @"modifier2"]));
}

- (void)testEditingACellUpdatesTheDocument {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionWindowActions;
  NSTableView *table = [self tableOf:form];
  NSView *cell = [table viewAtColumn:[table columnWithIdentifier:@"action"] row:0 makeIfNecessary:YES];
  XCTAssertEqualObjects(doc.bindings[3].action, @"resize +5% +0");

  // The action is edited with fields: "resize" has an x and a y.
  NSMutableArray<NSTextField *> *fields = [NSMutableArray array];
  for (NSView *v in [(NSStackView *)[[cell subviews] firstObject] arrangedSubviews]) {
    if ([v isKindOfClass:[NSTextField class]] && [(NSTextField *)v isEditable]) [fields addObject:(NSTextField *)v];
  }
  XCTAssertEqual([fields count], 2u);
  XCTAssertEqualObjects([fields[0] stringValue], @"+5%");
  [fields[0] setStringValue:@"+10%"];
  [NSApp sendAction:[fields[0] action] to:[fields[0] target] from:fields[0]];
  XCTAssertEqualObjects(doc.bindings[3].action, @"resize +10% +0");
  XCTAssertEqual(self.changes, 1u);
}

- (void)testToggleBindingAndSetting {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionWindowActions;
  NSTableView *table = [self tableOf:form];
  NSButton *box = [[[table viewAtColumn:[table columnWithIdentifier:@"enabled"] row:1 makeIfNecessary:YES] subviews] firstObject];
  XCTAssertEqual([box state], NSControlStateValueOff);
  [box setState:NSControlStateValueOn];
  [form performSelector:@selector(enabledToggled:) withObject:box];
  XCTAssertTrue(doc.bindings[4].enabled);

  form.selectedSection = ConfigurationFormSectionGeneral;
  box = [[[table viewAtColumn:[table columnWithIdentifier:@"value"] row:0 makeIfNecessary:YES] subviews] firstObject];
  XCTAssertTrue([box isKindOfClass:[NSButton class]], @"boolean settings are checkboxes");
  [box setState:NSControlStateValueOff];
  [form performSelector:@selector(settingToggled:) withObject:box];
  XCTAssertEqualObjects(doc.settings[0], [SlateConfigEntry entryWithName:@"defaultToCurrentScreen" value:@NO]);
  XCTAssertTrue([[doc stringRepresentation] containsString:@"defaultToCurrentScreen: false\n"]);
}

#pragma mark - Shell

- (NSTableView *)sidebarOf:(ConfigurationFormView *)form {
  return [form valueForKey:@"sidebar"];
}

- (void)testSidebarGroupsPages {
  ConfigurationFormView *form = [self formWithDocument:[self document]];
  NSTableView *sidebar = [self sidebarOf:form];
  NSMutableArray *headers = [NSMutableArray array];
  for (NSInteger row = 0; row < [sidebar numberOfRows]; row++) {
    if ([form tableView:sidebar isGroupRow:row]) [headers addObject:@(row)];
  }
  XCTAssertEqualObjects(headers, (@[@0, @3, @7]), @"Shortcuts, Screens and Settings headings");
  XCTAssertFalse([form tableView:sidebar shouldSelectRow:0], @"headings can't be selected");
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionKeyboard, @"opens on the keyboard page");
  XCTAssertEqual([sidebar selectedRow], 1);
}

- (void)testClickingAPageShowsIt {
  ConfigurationFormView *form = [self formWithDocument:[self document]];
  NSTableView *sidebar = [self sidebarOf:form];
  [sidebar selectRowIndexes:[NSIndexSet indexSetWithIndex:5] byExtendingSelection:NO];  // Slots
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionPositions);
  XCTAssertEqual([[self tableOf:form] numberOfRows], 2);
  form.selectedSection = ConfigurationFormSectionMonitors;
  XCTAssertEqual([sidebar selectedRow], 4, @"choosing a page from code moves the highlight");
}

- (void)testKeyboardPageFiltersByKind {
  ConfigurationFormView *form = [self formWithDocument:[self document]];
  form.selectedSection = ConfigurationFormSectionKeyboard;
  XCTAssertEqual([[self tableOf:form] numberOfRows], 7, @"all shortcuts");
  form.keyboardFilter = SlateBindingCategoryLayout;
  XCTAssertEqual([[self tableOf:form] numberOfRows], 2);
  form.keyboardFilter = SlateBindingCategoryFeatures;
  XCTAssertEqual([[self tableOf:form] numberOfRows], 2);
  form.keyboardFilter = -1;
  XCTAssertEqual([[self tableOf:form] numberOfRows], 7);
}

- (void)testSettingsAreSplitBetweenGeneralAndAdvanced {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:
      @"settings:\n  defaultToCurrentScreen: true\n  windowHintsSpread: true\n  secondsBeforeRepeat: 0.4\n  nudgePercentOf: screenSize\n" error:nil];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionGeneral;
  XCTAssertEqual([[self tableOf:form] numberOfRows], 2);
  form.selectedSection = ConfigurationFormSectionAdvanced;
  XCTAssertEqual([[self tableOf:form] numberOfRows], 2);
  [form revealEntryNamed:@"secondsBeforeRepeat"];
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionAdvanced);
  [form revealEntryNamed:@"windowHintsSpread"];
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionGeneral);
}

- (NSArray *)subviewsOf:(NSView *)view ofClass:(Class)cls {
  NSMutableArray *found = [NSMutableArray array];
  if ([view isKindOfClass:cls]) [found addObject:view];
  for (NSView *child in [view subviews]) [found addObjectsFromArray:[self subviewsOf:child ofClass:cls]];
  return found;
}

- (void)testGeneralPageHasSwitchesNotATable {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionGeneral;
  NSView *general = [form valueForKey:@"settingsView"];
  XCTAssertFalse([general isHidden]);
  XCTAssertTrue([[form valueForKey:@"tableScroll"] isHidden]);
  NSMutableArray *ids = [NSMutableArray array];
  for (NSSwitch *toggle in [self subviewsOf:general ofClass:[NSSwitch class]]) [ids addObject:[toggle identifier]];
  XCTAssertEqualObjects(ids, (@[@"launchAtLogin", @"defaultToCurrentScreen", @"windowHintsShowIcons", @"windowHintsSpread", @"windowHintsIgnoreHiddenWindows"]));
}

- (ConfigurationFormView *)advancedFormWithSettings:(NSString *)settings document:(SlateConfigDocument **)outDoc {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:[@"settings:\n" stringByAppendingString:settings] error:nil];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionAdvanced;
  *outDoc = doc;
  return form;
}

- (id)controlIn:(NSView *)root ofClass:(Class)cls identifier:(NSString *)identifier {
  for (NSView *view in [self subviewsOf:root ofClass:cls]) {
    if ([[view identifier] isEqualToString:identifier]) return view;
  }
  return nil;
}

- (void)testAdvancedPageEditsPercentagesAndRepeat {
  SlateConfigDocument *doc = nil;
  ConfigurationFormView *form = [self advancedFormWithSettings:@"  secondsBeforeRepeat: 0.4\n" document:&doc];
  XCTAssertTrue([[form valueForKey:@"tableScroll"] isHidden]);
  NSView *page = [form valueForKey:@"settingsView"];

  NSSegmentedControl *nudge = [self controlIn:page ofClass:[NSSegmentedControl class] identifier:@"nudgePercentOf"];
  XCTAssertEqual([nudge selectedSegment], 0, @"screen size is the default");
  [nudge setSelectedSegment:1];
  [NSApp sendAction:[nudge action] to:[nudge target] from:nudge];
  XCTAssertEqualObjects([doc.settings lastObject], [SlateConfigEntry entryWithName:@"nudgePercentOf" value:@"windowSize"]);

  NSSlider *before = [self controlIn:page ofClass:[NSSlider class] identifier:@"secondsBeforeRepeat"];
  XCTAssertEqualWithAccuracy([before doubleValue], 0.4, 0.001);
  [before setDoubleValue:0.55];
  [NSApp sendAction:[before action] to:[before target] from:before];
  XCTAssertEqualObjects(doc.settings[0], [SlateConfigEntry entryWithName:@"secondsBeforeRepeat" value:@0.55]);
}

- (void)testOtherSettingsAreEditedAndRemoved {
  SlateConfigDocument *doc = nil;
  ConfigurationFormView *form = [self advancedFormWithSettings:@"  orderScreensLeftToRight: true\n  madeUpSetting: 3\n  defaultToCurrentScreen: true\n" document:&doc];
  NSView *page = [form valueForKey:@"settingsView"];
  XCTAssertNil([self controlIn:page ofClass:[NSTextField class] identifier:@"defaultToCurrentScreen"], @"everyday settings stay on General");

  NSTextField *order = [self controlIn:page ofClass:[NSTextField class] identifier:@"orderScreensLeftToRight"];
  XCTAssertEqualObjects([order stringValue], @"true");
  [order setStringValue:@"false"];
  [NSApp sendAction:[order action] to:[order target] from:order];
  XCTAssertEqualObjects(doc.settings[0], [SlateConfigEntry entryWithName:@"orderScreensLeftToRight" value:@NO]);

  NSButton *remove = [self controlIn:page ofClass:[NSButton class] identifier:@"madeUpSetting"];
  [NSApp sendAction:[remove action] to:[remove target] from:remove];
  XCTAssertEqual([doc.settings count], 2u);
  XCTAssertEqualObjects([doc.settings valueForKey:@"name"], (@[@"orderScreensLeftToRight", @"defaultToCurrentScreen"]));
}

- (void)testGeneralRowsStartAtTheTop {
  ConfigurationFormView *form = [[ConfigurationFormView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 700)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 700) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:form];
  form.document = [self document];
  form.selectedSection = ConfigurationFormSectionGeneral;
  [window layoutIfNeeded];
  NSView *general = [form valueForKey:@"settingsView"];
  NSStackView *stack = [general valueForKey:@"stack"];
  NSView *first = [[stack arrangedSubviews] firstObject];
  NSRect inGeneral = [general convertRect:[first frame] fromView:stack];
  CGFloat gapAbove = NSHeight([general bounds]) - NSMaxY(inGeneral);
  if ([general isFlipped]) gapAbove = NSMinY(inGeneral);
  XCTAssertLessThan(gapAbove, 40, @"the first row is at the top, not pushed down by empty space");
}

- (void)testTogglingAGeneralSettingEditsTheDocument {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionGeneral;
  NSView *general = [form valueForKey:@"settingsView"];
  NSSwitch *screen = nil, *spread = nil;
  for (NSSwitch *toggle in [self subviewsOf:general ofClass:[NSSwitch class]]) {
    if ([[toggle identifier] isEqualToString:@"defaultToCurrentScreen"]) screen = toggle;
    if ([[toggle identifier] isEqualToString:@"windowHintsSpread"]) spread = toggle;
  }
  XCTAssertEqual([screen state], NSControlStateValueOn, @"the file says true");
  [screen setState:NSControlStateValueOff];
  [NSApp sendAction:[screen action] to:[screen target] from:screen];
  XCTAssertEqualObjects(doc.settings[0], [SlateConfigEntry entryWithName:@"defaultToCurrentScreen" value:@NO]);
  XCTAssertEqual(self.changes, 1u);

  // A setting the file doesn't have yet is added when switched.
  XCTAssertNotNil(spread);
  [spread setState:NSControlStateValueOff];
  [NSApp sendAction:[spread action] to:[spread target] from:spread];
  XCTAssertEqualObjects([doc.settings lastObject], [SlateConfigEntry entryWithName:@"windowHintsSpread" value:@NO]);
  XCTAssertTrue([[doc stringRepresentation] containsString:@"windowHintsSpread: false\n"]);
}

- (void)testKeyboardLayoutIsChosenFromAList {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  form.selectedSection = ConfigurationFormSectionGeneral;
  NSPopUpButton *popup = [[self subviewsOf:[form valueForKey:@"settingsView"] ofClass:[NSPopUpButton class]] firstObject];
  XCTAssertEqualObjects([popup titleOfSelectedItem], @"QWERTY", @"the default when the file doesn't say");
  [popup selectItemWithTitle:@"DVORAK"];
  [NSApp sendAction:[popup action] to:[popup target] from:popup];
  XCTAssertEqualObjects([doc.settings lastObject], [SlateConfigEntry entryWithName:@"keyboardLayout" value:@"dvorak"]);
}

- (void)testSlotsPageSwitchesBetweenCustomAndPresets {
  ConfigurationFormView *form = [self formWithDocument:[self document]];
  NSSegmentedControl *switcher = [form valueForKey:@"slotsSwitcher"];
  XCTAssertTrue([switcher isHidden], @"only the Slots page has the switcher");
  form.selectedSection = ConfigurationFormSectionPositions;
  XCTAssertFalse([switcher isHidden]);
  XCTAssertEqualObjects([switcher labelForSegment:0], @"Custom");
  XCTAssertEqualObjects([switcher labelForSegment:1], @"Presets");
  XCTAssertFalse([[form valueForKey:@"slotsView"] isHidden]);
  XCTAssertTrue([[form valueForKey:@"presetsView"] isHidden]);
  [switcher setSelectedSegment:1];
  [NSApp sendAction:[switcher action] to:[switcher target] from:switcher];
  XCTAssertTrue([[form valueForKey:@"slotsView"] isHidden]);
  XCTAssertFalse([[form valueForKey:@"presetsView"] isHidden], @"the read-only presets");
  [switcher setSelectedSegment:0];
  [NSApp sendAction:[switcher action] to:[switcher target] from:switcher];
  XCTAssertFalse([[form valueForKey:@"slotsView"] isHidden]);
  form.selectedSection = ConfigurationFormSectionGeneral;
  XCTAssertTrue([switcher isHidden]);
}

- (void)testEachPageShowsItsOwnView {
  ConfigurationFormView *form = [self formWithDocument:[self document]];
  form.selectedSection = ConfigurationFormSectionSnapshots;
  XCTAssertFalse([[form valueForKey:@"snapshotsView"] isHidden], @"Snapshots has its own page");
  form.selectedSection = ConfigurationFormSectionKeyboard;
  XCTAssertFalse([[form valueForKey:@"keyboardView"] isHidden], @"the Keyboard page has its own view");
  form.selectedSection = ConfigurationFormSectionModifiers;
  XCTAssertFalse([[form valueForKey:@"tableScroll"] isHidden]);
  XCTAssertTrue([[form valueForKey:@"keyboardView"] isHidden]);
}

- (void)testRevealSelectsTheRow {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  [form revealBindingAtIndex:5];
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionKeyboard);
  XCTAssertEqual([[self tableOf:form] selectedRow], 5, @"the Keyboard page lists every shortcut");
  [form revealEntryNamed:@"samsung-full"];
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionPositions);
  XCTAssertEqual([[self tableOf:form] selectedRow], 1);
}

@end
