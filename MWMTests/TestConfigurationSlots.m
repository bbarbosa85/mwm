//
//  TestConfigurationSlots.m
//  Slate
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
#import "ConfigurationSlotsView.h"
#import "ConfigurationSlotCanvas.h"
#import "MWMConfigDocument.h"
#import "MWMSlots.h"
#import "MWMSlotShape.h"

@interface TestConfigurationSlots : XCTestCase <ConfigurationSlotsViewDelegate>
@property (assign) NSUInteger changes;
@end

@implementation TestConfigurationSlots

- (void)slotsViewDidChangeDocument:(ConfigurationSlotsView *)view { self.changes++; }

- (ConfigurationSlotsView *)pageWithConfig:(NSString *)yaml document:(MWMConfigDocument **)outDoc {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:yaml error:nil];
  XCTAssertNotNil(doc);
  ConfigurationSlotsView *page = [[ConfigurationSlotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 600)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 600) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:page];
  page.delegate = self;
  page.document = doc;
  [window layoutIfNeeded];
  self.changes = 0;
  *outDoc = doc;
  return page;
}

static NSString *const kConfig =
  @"positions:\n"
  @"  centre: move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY\n"
  @"  lefthalf: move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"  sized: move 0;0 1;1 5120x1440\n"
  @"bindings:\n"
  @"  - key: a\n    mods: ctrl\n    action: ${centre}\n";

- (BOOL)view:(NSView *)root hasCellNamed:(NSString *)name {
  if ([[root identifier] isEqualToString:name] && [NSStringFromClass([root class]) containsString:@"SlotCard"]) return YES;
  for (NSView *child in [root subviews]) if ([self view:child hasCellNamed:name]) return YES;
  return NO;
}

// The gallery has a card for each slot.
- (BOOL)page:(NSView *)page showsRowNamed:(NSString *)name {
  return [self view:page hasCellNamed:name];
}

- (void)testSearchNarrowsTheGalleryAndNewSlotOpensTheEditor {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:
      @"positions:\n  centre: move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY\n  corner: move screenOriginX+screenSizeX/2;screenOriginY+screenSizeY/2 screenSizeX/2;screenSizeY/2\n" document:&doc];
  XCTAssertTrue([self page:page showsRowNamed:@"centre"]);
  XCTAssertTrue([self page:page showsRowNamed:@"corner"]);
  NSSearchField *search = [page valueForKey:@"search"];
  [search setStringValue:@"cor"];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:search];
  XCTAssertFalse([self page:page showsRowNamed:@"centre"], @"search narrows the list");
  XCTAssertTrue([self page:page showsRowNamed:@"corner"]);
  [search setStringValue:@""];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:search];
  [page startNewSlot];
  XCTAssertEqualObjects(page.selectedName, @"slot", @"the New slot card opens the editor on a new slot");
  XCTAssertTrue([[page valueForKey:@"galleryPage"] isHidden]);
}

- (void)testThePresetsPageListsAllNineteen {
  NSView *page = [[NSClassFromString(@"ConfigurationPresetsView") alloc] initWithFrame:NSMakeRect(0, 0, 700, 600)];
  NSMutableArray *names = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:page];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSButton class]] && [MWMSlots presetNamed:[view identifier]] != nil) [names addObject:[view identifier]];
    [queue addObjectsFromArray:[view subviews]];
  }
  XCTAssertEqual([names count], 19u);
  XCTAssertEqual([[NSSet setWithArray:names] count], 19u);
}

- (void)testClickingAPresetNameCopiesIt {
  NSView *page = [[NSClassFromString(@"ConfigurationPresetsView") alloc] initWithFrame:NSMakeRect(0, 0, 700, 600)];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:page];
  NSButton *third2 = nil;
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSButton class]] && [[view identifier] isEqualToString:@"third2"]) third2 = (NSButton *)view;
    [queue addObjectsFromArray:[view subviews]];
  }
  [NSApp sendAction:[third2 action] to:[third2 target] from:third2];
  XCTAssertEqualObjects([[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString], @"${third2}");
}

- (void)testCardsSayHowManyShortcutsUseTheSlot {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:
      @"positions:\n  used: move screenOriginX;screenOriginY screenSizeX/5;screenSizeY\n  twice: move screenOriginX+screenSizeX/5;screenOriginY screenSizeX/5;screenSizeY\n  idle: move screenOriginX+(2*screenSizeX/5);screenOriginY screenSizeX/5;screenSizeY\n"
       "bindings:\n  - key: a\n    mods: ctrl\n    action: ${used}\n  - key: b\n    mods: ctrl\n    action: ${twice}\n  - key: c\n    mods: ctrl\n    action: ${twice}\n" document:&doc];
  NSMutableArray *texts = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:page];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSTextField class]]) [texts addObject:[(NSTextField *)view stringValue]];
    [queue addObjectsFromArray:[view subviews]];
  }
  XCTAssertTrue([texts containsObject:@"1 shortcut"]);
  XCTAssertTrue([texts containsObject:@"2 shortcuts"]);
  XCTAssertTrue([texts containsObject:@"Not used yet"]);
  XCTAssertTrue([texts containsObject:@"20 × 100"], @"the size badge");
}

- (void)testOpensOnTheGallery {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  XCTAssertNil(page.selectedName, @"nothing is open: the gallery shows");
  XCTAssertFalse(page.canvas.hasSlot);
  XCTAssertFalse(page.hasUnsavedChanges, @"opening the page changes nothing");
  XCTAssertEqual(self.changes, 0u);
  XCTAssertTrue([self page:page showsRowNamed:@"centre"]);
  XCTAssertTrue([self page:page showsRowNamed:@"+new"], @"there's a New slot card");
}

- (void)testClickingACardOpensTheEditorAndSaveReturnsToTheGallery {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  XCTAssertTrue(page.canvas.hasSlot);
  XCTAssertTrue([[page valueForKey:@"galleryPage"] isHidden]);
  XCTAssertFalse([[page valueForKey:@"editorPage"] isHidden]);
  page.draftRect = CGRectMake(0.25, 0.25, 0.5, 0.5);
  [page save];
  XCTAssertNil(page.selectedName, @"saving goes back to the gallery");
  XCTAssertFalse([[page valueForKey:@"galleryPage"] isHidden]);
}

- (NSString *)textOf:(NSString *)key in:(ConfigurationSlotsView *)page {
  return [[page valueForKey:key] stringValue];
}

- (void)testTheEditorTitleAndSaveBarSayWhatIsGoingOn {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  XCTAssertEqualObjects([self textOf:@"editorTitle" in:page], @"Editing Slot");
  XCTAssertEqualObjects([[page valueForKey:@"changesChip"] text], @"No changes");
  XCTAssertFalse([[page valueForKey:@"saveButton"] isEnabled], @"Save is dimmed until something changes");
  page.draftRect = CGRectMake(0.1, 0, 0.5, 1);
  [page performSelector:NSSelectorFromString(@"refresh")];
  XCTAssertTrue([[[page valueForKey:@"changesChip"] text] containsString:@"Unsaved changes"]);
  XCTAssertTrue([[page valueForKey:@"saveButton"] isEnabled]);
  [page startNewSlot];
  XCTAssertEqualObjects([self textOf:@"editorTitle" in:page], @"New Slot");
}

- (void)testTheGridControlSetsTheSnappingGrid {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  NSSegmentedControl *grid = [page valueForKey:@"gridControl"];
  XCTAssertEqual(page.canvas.gridDivisions, 4, @"quarters to start with");
  [grid setSelectedSegment:2];  // 3
  [NSApp sendAction:[grid action] to:[grid target] from:grid];
  XCTAssertEqual(page.canvas.gridDivisions, 3);
  [grid setSelectedSegment:0];  // Off
  [NSApp sendAction:[grid action] to:[grid target] from:grid];
  XCTAssertEqual(page.canvas.gridDivisions, 0);
}

- (void)testCancelThrowsAwayTheChangesAndGoesBack {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  page.draftRect = CGRectMake(0, 0, 0.3, 0.3);
  [page performSelector:@selector(cancelPressed:) withObject:nil];
  XCTAssertNil(page.selectedName);
  XCTAssertEqual(self.changes, 0u);
  XCTAssertEqualObjects([doc.positions[0].value description], @"move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY", @"the file is as it was");
}

- (void)testPresetsAreNotInTheList {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  XCTAssertFalse([self page:page showsRowNamed:@"third2"], @"presets are for reading, in the Presets popover");
  XCTAssertFalse([self page:page showsRowNamed:@"lefthalf"], @"a file entry that is the preset itself isn't a custom slot either");
  XCTAssertTrue([self page:page showsRowNamed:@"centre"]);
  [page selectSlotNamed:@"middle"];
  XCTAssertNil(page.selectedName, @"a preset can't be opened for editing");
  [page selectSlotNamed:@"lefthalf"];
  XCTAssertNil(page.selectedName);
}

- (void)testDraggingOnTheCanvasChangesTheSlotAndSnaps {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  XCTAssertFalse(page.hasUnsavedChanges);
  ConfigurationSlotCanvas *canvas = page.canvas;
  canvas.gridDivisions = 3;
  NSRect slot = [canvas viewRectForSlot:page.draftRect];
  // Pull the right side from 75% to about 66%: it lands on the thirds line.
  NSRect screen = [canvas screenRect];
  NSPoint from = NSMakePoint(NSMaxX(slot), NSMidY(slot));
  [canvas dragFrom:from to:NSMakePoint(NSMinX(screen) + 0.665 * NSWidth(screen), from.y) free:NO];
  XCTAssertEqualWithAccuracy(CGRectGetMaxX(page.draftRect), 2 / 3.0, 1e-9);
  XCTAssertEqualWithAccuracy(page.draftRect.origin.x, 0.25, 1e-9, @"the other side stays");
  XCTAssertTrue(page.hasUnsavedChanges);
  // Free drag (⌥) doesn't snap.
  [canvas dragFrom:NSMakePoint(NSMinX([canvas viewRectForSlot:page.draftRect]), NSMidY(slot)) to:NSMakePoint(NSMinX(screen) + 0.2 * NSWidth(screen) + 0.4, NSMidY(slot)) free:YES];
  XCTAssertEqualWithAccuracy(page.draftRect.origin.x, 0.2, 0.002);
}

- (void)testMovingTheWholeSlotKeepsItOnTheScreen {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  ConfigurationSlotCanvas *canvas = page.canvas;
  NSRect slot = [canvas viewRectForSlot:page.draftRect];
  NSPoint inside = NSMakePoint(NSMidX(slot), NSMidY(slot));
  [canvas dragFrom:inside to:NSMakePoint(inside.x + 900, inside.y) free:NO];
  XCTAssertEqualWithAccuracy(CGRectGetMaxX(page.draftRect), 1.0, 1e-9, @"stops at the right edge");
  XCTAssertEqualWithAccuracy(page.draftRect.size.width, 0.5, 1e-9, @"keeps its size");
}

- (void)testSavingAnEditedSlotWritesItsFormula {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  page.draftRect = CGRectMake(0.25, 0.25, 0.5, 0.5);
  XCTAssertNil(page.problem);
  [page save];
  MWMConfigEntry *entry = nil;
  for (MWMConfigEntry *e in doc.positions) if ([e.name isEqualToString:@"centre"]) entry = e;
  CGRect read;
  XCTAssertTrue([MWMSlots getRect:&read fromFormula:[entry.value description]]);
  XCTAssertTrue([MWMSlots rect:read isSameAreaAs:CGRectMake(0.25, 0.25, 0.5, 0.5)]);
  XCTAssertEqual(self.changes, 1u);
  XCTAssertFalse(page.hasUnsavedChanges);
}

- (void)testWithoutAGridEdgesLandOnWholePercents {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  ConfigurationSlotCanvas *canvas = page.canvas;
  canvas.gridDivisions = 0;
  NSRect slot = [canvas viewRectForSlot:page.draftRect], screen = [canvas screenRect];
  NSPoint from = NSMakePoint(NSMaxX(slot), NSMidY(slot));
  [canvas dragFrom:from to:NSMakePoint(NSMinX(screen) + 0.6663 * NSWidth(screen), from.y) free:NO];
  XCTAssertEqualWithAccuracy(CGRectGetMaxX(page.draftRect), 0.67, 1e-9, @"no grid line to snap to");
}

- (void)testCustomSlotsCanBeRemovedFromTheList {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:@"positions:\n  spare: move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY\n  used: move screenOriginX;screenOriginY screenSizeX/5;screenSizeY\nbindings:\n  - key: a\n    mods: ctrl\n    action: ${used}\n" document:&doc];
  [page removeSlotNamed:@"spare"];
  XCTAssertEqualObjects([doc.positions valueForKey:@"name"], @[@"used"]);
  XCTAssertEqual(self.changes, 1u);
}

- (void)testRevertGoesBack {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  page.draftRect = CGRectMake(0, 0, 0.3, 0.3);
  page.draftName = @"other";
  XCTAssertTrue(page.hasUnsavedChanges);
  [page revert];
  XCTAssertFalse(page.hasUnsavedChanges);
  XCTAssertEqualObjects(page.draftName, @"centre");
  XCTAssertEqual(self.changes, 0u);
}

- (void)testNewSlotsNeedAGoodNameAndANewArea {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page startNewSlot];
  XCTAssertTrue(page.hasUnsavedChanges, @"a new slot is unsaved from the start");
  XCTAssertNil(page.problem, @"it starts with a free name and area");
  page.draftName = @"third1";
  XCTAssertTrue([page.problem containsString:@"preset"]);
  page.draftName = @"centre";
  XCTAssertTrue([page.problem containsString:@"already used"]);
  page.draftName = @"corner";
  page.draftRect = CGRectMake(0.25, 0, 0.5, 1);
  XCTAssertTrue([page.problem containsString:@"Same area as \"centre\""], @"%@", page.problem);
  page.draftRect = CGRectMake(0.5, 0.5, 0.5, 0.5);
  XCTAssertNil(page.problem);
  [page save];
  XCTAssertEqualObjects([doc.positions.lastObject name], @"corner");
  XCTAssertEqual(self.changes, 1u);
}

- (void)testRenamingUpdatesTheShortcutsThatUseTheSlot {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kConfig document:&doc];
  [page selectSlotNamed:@"centre"];
  page.draftName = @"focus";
  [page save];
  XCTAssertEqualObjects(doc.bindings[0].action, @"${focus}");
  XCTAssertNotNil([MWMConfigDocument documentFromString:[doc stringRepresentation] error:nil], @"the file is still valid");
}

static NSString *const kFormulas =
  @"aliases:\n"
  @"  gap: \"14\"\n"
  @"positions:\n"
  @"  rightfourfifths: move (screenOriginX+screenSizeX/5)+14;screenOriginY (4*screenSizeX/5)-14;screenSizeY\n"
  @"  middle: move screenOriginX+(screenSizeX/3);screenOriginY screenSizeX/3;screenSizeY\n"
  @"  floating: move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeY/2\n"
  @"  padded: move screenOriginX+${gap};screenOriginY+${gap} screenSizeX-2*${gap};screenSizeY-2*${gap}\n"
  @"bindings:\n"
  @"  - key: a\n    mods: ctrl\n    action: ${rightfourfifths}\n";

// A formula the fields can't show opens as text, with nothing to save until it is changed.
- (void)testACustomFormulaOpensAsText {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page selectSlotNamed:@"floating"];
  XCTAssertEqualObjects(page.selectedName, @"floating");
  XCTAssertTrue(page.customMode);
  XCTAssertNil(page.draftShape);
  XCTAssertEqualObjects(page.draftFormulaText, @"move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeY/2");
  XCTAssertFalse(page.hasUnsavedChanges);
  XCTAssertFalse(page.canvas.editable, @"the area follows the formula, it can't be dragged");
}

- (void)testEditingACustomFormulaSavesTheExactTextOnceItIsRight {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page selectSlotNamed:@"floating"];
  page.draftFormulaText = @"move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeZ";
  XCTAssertTrue(page.hasUnsavedChanges);
  XCTAssertTrue([page.problem hasPrefix:@"Height: "], @"%@", page.problem);
  XCTAssertTrue([page.problem containsString:@"isn't a name MWM knows"], @"%@", page.problem);
  [page save];
  XCTAssertEqual(self.changes, 0u, @"a formula with a mistake isn't saved");
  page.draftFormulaText = @"move windowTopLeftX;windowTopLeftY screenSizeX/4;screenSizeY/2";
  XCTAssertNil(page.problem);
  [page save];
  XCTAssertEqualObjects([[doc.positions[2] value] description], @"move windowTopLeftX;windowTopLeftY screenSizeX/4;screenSizeY/2");
  XCTAssertEqual(self.changes, 1u);
}

- (void)testAFormulaCanUseAnAliasTheDocumentDefines {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page selectSlotNamed:@"padded"];
  XCTAssertTrue(page.customMode);
  page.draftFormulaText = @"move screenOriginX+${gap};screenOriginY+${gap} screenSizeX-2*${gap};screenSizeY-2*${gap} ";
  XCTAssertNil(page.problem, @"${gap} is worked out from the aliases");
  page.draftFormulaText = @"move screenOriginX+${nope};screenOriginY screenSizeX;screenSizeY";
  XCTAssertNotNil(page.problem);
  XCTAssertTrue([page.problem containsString:@"${nope}"], @"%@", page.problem);
}

// A formula with margins opens in the fields.
- (void)testAMarginSlotOpensInTheFieldsAndSavesNewMargins {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page selectSlotNamed:@"rightfourfifths"];
  XCTAssertFalse(page.customMode);
  XCTAssertEqual(page.draftShape.horizontal.marginStart, 14);
  XCTAssertFalse(page.hasUnsavedChanges);
  XCTAssertFalse(page.canvas.editable, @"margins are set with the fields, not by dragging");
  MWMSlotShape *shape = [page.draftShape copy];
  shape.horizontal.marginStart = 20;
  shape.vertical.marginStart = 8; shape.vertical.marginEnd = 8;
  page.draftShape = shape;
  XCTAssertTrue(page.hasUnsavedChanges);
  XCTAssertNil(page.problem);
  [page save];
  XCTAssertEqualObjects([[doc.positions[0] value] description], @"move (screenOriginX+screenSizeX/5)+20;screenOriginY+8 (4*screenSizeX/5)-20;screenSizeY-16");
}

- (void)testPixelsAndCenteringBecomeAFormula {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page startNewSlot];
  MWMSlotShape *shape = [[MWMSlotShape alloc] init];
  shape.horizontal.sizeInPixels = YES; shape.horizontal.sizePixels = 1200; shape.horizontal.centered = YES;
  shape.vertical.sizeInPixels = YES; shape.vertical.sizePixels = 800; shape.vertical.centered = YES;
  page.draftShape = shape;
  page.draftName = @"dialog";
  XCTAssertNil(page.problem, @"a pixel size isn't checked against the preview screen's size");
  [page save];
  XCTAssertEqualObjects([[doc.positions.lastObject value] description], @"move screenOriginX+(screenSizeX-1200)/2;screenOriginY+(screenSizeY-800)/2 1200;800");
  [page selectSlotNamed:@"dialog"];
  XCTAssertFalse(page.customMode, @"what the fields wrote opens in the fields");
  XCTAssertTrue(page.draftShape.horizontal.centered);
}

- (void)testMarginsThatLeaveNothingAreRefused {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page selectSlotNamed:@"rightfourfifths"];
  MWMSlotShape *shape = [page.draftShape copy];
  shape.horizontal.marginStart = 2000;
  page.draftShape = shape;
  XCTAssertNotNil(page.problem);
}

- (void)testAPlainSlotStaysDraggableAndKeepsItsText {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page selectSlotNamed:@"middle"];
  XCTAssertFalse(page.customMode, @"middle is a plain third, written with extra parentheses");
  XCTAssertTrue(page.canvas.editable);
  XCTAssertFalse(page.hasUnsavedChanges, @"opening it changes nothing");
  [page save];
  XCTAssertEqualObjects([[doc.positions[1] value] description], @"move screenOriginX+(screenSizeX/3);screenOriginY screenSizeX/3;screenSizeY");
}

- (void)testRenamingAMarginSlotKeepsTheShortcutsPointingAtIt {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  [page selectSlotNamed:@"rightfourfifths"];
  page.draftName = @"right";
  [page save];
  XCTAssertEqualObjects(doc.bindings[0].action, @"${right}");
  XCTAssertEqualObjects([[doc.positions[0] value] description], @"move (screenOriginX+screenSizeX/5)+14;screenOriginY (4*screenSizeX/5)-14;screenSizeY", @"the formula is untouched");
}

// At the window's narrowest the editor still keeps its margin on the left, and nothing is wider than its card.
- (void)testTheEditorKeepsItsPaddingAtTheNarrowestWindow {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kFormulas error:nil];
  ConfigurationSlotsView *page = [[ConfigurationSlotsView alloc] initWithFrame:NSMakeRect(0, 0, 880, 560)];   // the narrowest window (1080) less the 200 pt sidebar
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 880, 560) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:page];
  page.document = doc;
  [page selectSlotNamed:@"rightfourfifths"];
  [window layoutIfNeeded];
  NSView *fields = [page valueForKey:@"fieldsBlock"];
  NSView *editor = [page valueForKey:@"editorPage"];
  XCTAssertLessThanOrEqual([editor fittingSize].width, 880, @"everything in the editor fits the narrowest page");
  NSRect inPage = [page convertRect:[fields bounds] fromView:fields];
  XCTAssertGreaterThanOrEqual(inPage.origin.x, 20, @"the card keeps the page's 20 pt margin: %@", NSStringFromRect(inPage));
  for (NSView *row in fields.subviews) {
    NSRect aligned = [row alignmentRectForFrame:row.frame];   // a label's frame is a little wider than what it lines up with
    XCTAssertLessThanOrEqual(NSMaxX(aligned), NSWidth(fields.bounds) + 0.5, @"a row is wider than the card: %@", NSStringFromRect(aligned));
  }
}

- (void)testEveryFormulaSlotCanBeOpenedFromTheGallery {
  MWMConfigDocument *doc;
  ConfigurationSlotsView *page = [self pageWithConfig:kFormulas document:&doc];
  for (NSString *name in @[@"rightfourfifths", @"middle", @"floating", @"padded"]) XCTAssertTrue([self page:page showsRowNamed:name], @"%@", name);
}

@end
