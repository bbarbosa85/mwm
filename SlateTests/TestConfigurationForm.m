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
  NSTableCellView *cell = [table viewAtColumn:[table columnWithIdentifier:@"action"] row:0 makeIfNecessary:YES];
  NSTextField *field = [[cell subviews] firstObject];
  XCTAssertEqualObjects([field stringValue], @"resize +5% +0");

  [field setStringValue:@"resize +10% +0"];
  [form performSelector:@selector(cellEdited:) withObject:field];
  XCTAssertEqualObjects(doc.bindings[3].action, @"resize +10% +0");
  XCTAssertEqual(self.changes, 1u);

  [field setStringValue:@""];
  [form performSelector:@selector(cellEdited:) withObject:field];
  XCTAssertEqualObjects(doc.bindings[3].action, @"resize +10% +0", @"an empty action is refused");
  XCTAssertEqualObjects([field stringValue], @"resize +10% +0");
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

- (void)testRevealSelectsTheRow {
  SlateConfigDocument *doc = [self document];
  ConfigurationFormView *form = [self formWithDocument:doc];
  [form revealBindingAtIndex:5];
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionFeatures);
  XCTAssertEqual([[self tableOf:form] selectedRow], 0);
  [form revealEntryNamed:@"samsung-full"];
  XCTAssertEqual(form.selectedSection, ConfigurationFormSectionPositions);
  XCTAssertEqual([[self tableOf:form] selectedRow], 1);
}

@end
