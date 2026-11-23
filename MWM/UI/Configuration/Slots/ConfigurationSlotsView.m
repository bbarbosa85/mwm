//
//  ConfigurationSlotsView.m
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

#import "ConfigurationSlotsView.h"
#import "MWMAlert.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationSlotCard.h"
#import "ConfigurationFormulaHelp.h"
#import "ConfigurationSlotCanvas.h"
#import "MWMConfigDocument.h"
#import "MWMDisplays.h"
#import "MWMSlots.h"
#import "MWMSlotShape.h"
#import "MWMFormula.h"


#pragma mark - Page

@interface ConfigurationSlotsView () <ConfigurationSlotCanvasDelegate, NSTextFieldDelegate, NSSearchFieldDelegate>
@property (strong) NSView *galleryPage;
@property (strong) NSView *editorPage;
@property (strong) NSStackView *galleryRows;
@property (strong) ConfigurationSlotCanvas *canvas;
@property (strong) NSSearchField *search;
@property (strong) NSPopUpButton *screenPopup;
@property (strong) NSSegmentedControl *gridControl;
@property (strong) NSTextField *editorTitle;
@property (strong) MWMChipView *changesChip;
@property (strong) MWMSaveBar *saveBar;
@property (strong) NSLayoutConstraint *canvasHeight;
@property (strong) NSTextField *nameField;
@property (strong) NSArray<NSTextField *> *valueFields;
@property (strong) NSTextField *messageLabel;
@property (strong) NSButton *cancelButton;
@property (strong) NSButton *saveButton;
@property (assign) BOOL lastEditing;
// What's being edited: an existing custom slot, or a new one. Nothing selected means the gallery shows.
@property (copy) NSString *selectedName;
@property (assign) BOOL selectedIsNew;
@property (copy) NSString *originalName;
// What the slot was when it was opened: its shape, or for a custom formula its text.
@property (strong) MWMSlotShape *originalShape;
@property (copy) NSString *originalFormulaText;
@property (readwrite) BOOL customMode;
@property (strong) NSSegmentedControl *widthUnit;
@property (strong) NSSegmentedControl *heightUnit;
@property (strong) NSArray<NSButton *> *centerBoxes;
@property (strong) NSArray<NSTextField *> *marginFields;
@property (strong) NSStackView *fieldsBlock;
@property (strong) NSStackView *customBlock;
@property (strong) NSArray<NSTextField *> *resultFields;   // x, y, width, height of a formula, in pixels on the preview screen
@property (strong) NSTextField *checkLabel;
@property (strong) MWMChipView *customChip;
@property (strong) NSPopover *helpPopover;
@property (strong) NSSegmentedControl *modeControl;   // Simple / Advanced, for a slot that is being created
@property (strong) NSTextField *formulaField;
@end

@implementation ConfigurationSlotsView

@synthesize draftShape = _draftShape, draftFormulaText = _draftFormulaText;

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) [self buildInterface];
  return self;
}

#pragma mark - Interface

- (NSSegmentedControl *)unitControl:(NSString *)identifier {
  NSSegmentedControl *control = [NSSegmentedControl segmentedControlWithLabels:@[@"%", @"px"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(unitChanged:)];
  [control setIdentifier:identifier];
  [control setControlSize:NSControlSizeSmall];
  return control;
}

- (NSTextField *)valueField:(NSString *)identifier {
  NSTextField *field = [NSTextField textFieldWithString:@""];
  [field setIdentifier:identifier];
  [field setDelegate:self];
  [field setTarget:self];
  [field setAction:@selector(valueEdited:)];
  [[field cell] setSendsActionOnEndEditing:YES];
  // Fields share a row equally, so they give way before the row grows wider than the card.
  [field setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
  [[field.widthAnchor constraintGreaterThanOrEqualToConstant:30] setActive:YES];
  return field;
}

- (void)pinView:(NSView *)view toEdgesOf:(NSView *)container {
  [container addSubview:view];
  [MWMComponents pinView:view toEdgesOf:container insets:NSEdgeInsetsZero];
}

- (void)buildInterface {
  [self buildGalleryPage];
  [self buildEditorPage];
  [self pinView:self.galleryPage toEdgesOf:self];
  [self pinView:self.editorPage toEdgesOf:self];
  [self.editorPage setHidden:YES];
}

// The gallery: search on top, a card for each slot and one to make a new one,

- (void)buildGalleryPage {
  self.search = [[NSSearchField alloc] init];
  [self.search setPlaceholderString:@"Search slots"];
  [self.search setDelegate:self];
  [[self.search.widthAnchor constraintEqualToConstant:220] setActive:YES];
  NSView *spacer = [MWMComponents spacer];
  NSStackView *top = [NSStackView stackViewWithViews:@[spacer, self.search]];

  self.galleryRows = [NSStackView stackViewWithViews:@[]];
  [self.galleryRows setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.galleryRows setAlignment:NSLayoutAttributeLeading];
  [self.galleryRows setSpacing:12];
  [self.galleryRows setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSScrollView *scroll = [MWMComponents scrollViewWithContent:self.galleryRows];

  NSStackView *page = [MWMComponents columnWithViews:@[top, scroll] spacing:12 insets:NSEdgeInsetsMake(8, 20, 16, 20)];
  [[self.galleryRows.widthAnchor constraintEqualToAnchor:scroll.widthAnchor] setActive:YES];
  self.galleryPage = [[NSView alloc] init];
  [self pinView:page toEdgesOf:self.galleryPage];
}

// The editor: a header with the back button and the title, a card with the form on the
// left, the canvas and its view toolbar on the right, and under a line the save bar.
- (void)buildEditorPage {
  MWMSublevelHeader *header = [MWMSublevelHeader headerWithBackTitle:@"Slots" title:@"Editing Slot" target:self action:@selector(backPressed:)];
  self.editorTitle = header.titleLabel;

  // Left: the form card.
  self.nameField = [NSTextField textFieldWithString:@""];
  [self.nameField setPlaceholderString:@"Name this slot"];
  [self.nameField setDelegate:self];
  NSStackView *nameBlock = [MWMComponents fieldWithCaption:@"Name" control:self.nameField];
  self.valueFields = @[[self valueField:@"x"], [self valueField:@"y"], [self valueField:@"width"], [self valueField:@"height"]];
  NSArray *captions = @[@"x (from left)", @"y (from top)", @"Width", @"Height"];
  NSMutableArray *captioned = [NSMutableArray array];
  for (NSUInteger i = 0; i < 4; i++) [captioned addObject:[MWMComponents fieldWithCaption:captions[i] control:self.valueFields[i]]];
  NSStackView *positionRow = [MWMComponents equalRowWithViews:@[captioned[0], captioned[1]] spacing:10];
  NSStackView *sizeRow = [MWMComponents equalRowWithViews:@[captioned[2], captioned[3]] spacing:10];
  // Units: a size can be a percent of the screen or a number of pixels; a start can be centered.
  self.widthUnit = [self unitControl:@"width-unit"];
  self.heightUnit = [self unitControl:@"height-unit"];
  NSStackView *unitRow = [MWMComponents equalRowWithViews:@[[MWMComponents fieldWithCaption:@"Width in" control:self.widthUnit], [MWMComponents fieldWithCaption:@"Height in" control:self.heightUnit]] spacing:10];
  NSButton *centerX = [NSButton checkboxWithTitle:@"Center across" target:self action:@selector(centeredChanged:)];
  NSButton *centerY = [NSButton checkboxWithTitle:@"Center down" target:self action:@selector(centeredChanged:)];
  [centerX setIdentifier:@"center-x"]; [centerY setIdentifier:@"center-y"];
  self.centerBoxes = @[centerX, centerY];
  NSStackView *centerRow = [MWMComponents columnWithViews:@[centerX, centerY] spacing:6 insets:NSEdgeInsetsZero];   // side by side they are wider than the card
  // Margins: pixels of space left inside the slot's edges.
  NSArray *marginNames = @[@"margin-left", @"margin-top", @"margin-right", @"margin-bottom"];
  NSArray *marginCaptions = @[@"Left", @"Top", @"Right", @"Bottom"];
  NSMutableArray *marginViews = [NSMutableArray array], *marginFields = [NSMutableArray array];
  for (NSUInteger i = 0; i < 4; i++) {
    NSTextField *field = [self valueField:marginNames[i]];
    [field setAction:@selector(marginEdited:)];
    [marginFields addObject:field];
    [marginViews addObject:[MWMComponents fieldWithCaption:marginCaptions[i] control:field]];
  }
  self.marginFields = marginFields;
  NSStackView *marginRow = [MWMComponents equalRowWithViews:marginViews spacing:10];
  // Three boxes, one topic each: where it starts, how big it is, and the space kept free.
  NSView *positionGroup = [MWMComponents groupBoxWithTitle:@"Position" views:@[positionRow, centerRow] accessory:nil];
  NSView *sizeGroup = [MWMComponents groupBoxWithTitle:@"Size" views:@[sizeRow, unitRow] accessory:nil];
  NSView *marginGroup = [MWMComponents groupBoxWithTitle:@"Margins in pixels" views:@[marginRow] accessory:nil];
  self.fieldsBlock = [MWMComponents columnWithViews:@[positionGroup, sizeGroup, marginGroup] spacing:10 insets:NSEdgeInsetsZero];

  // A formula written by hand that the fields can't show: its text, edited as text.
  self.formulaField = [NSTextField textFieldWithString:@""];
  [self.formulaField setIdentifier:@"formula"];
  [self.formulaField setFont:[MWMTheme fontMono]];
  [self.formulaField setDelegate:self];
  [[self.formulaField cell] setWraps:YES];
  [[self.formulaField cell] setScrollable:NO];
  [self.formulaField setUsesSingleLineMode:NO];
  [[self.formulaField.heightAnchor constraintGreaterThanOrEqualToConstant:64] setActive:YES];
  self.customChip = [MWMChipView chipWithText:@"Custom formula" color:[MWMTheme warning]];
  NSButton *helpButton = [NSButton buttonWithTitle:@"?" target:self action:@selector(showFormulaHelp:)];
  [helpButton setBezelStyle:NSBezelStyleHelpButton];
  [helpButton setTitle:@""];
  [helpButton setToolTip:@"Names you can use in a formula"];
  NSStackView *accessories = [NSStackView stackViewWithViews:@[self.customChip, helpButton]];
  [accessories setSpacing:6];
  NSTextField *customHelp = [NSTextField wrappingLabelWithString:@"Write move x;y width;height. No spaces inside a number."];
  [customHelp setFont:[MWMTheme fontCaption]];
  [customHelp setTextColor:[MWMTheme textSecondary]];
  NSView *formulaGroup = [MWMComponents groupBoxWithTitle:@"Formula" views:@[self.formulaField, customHelp] accessory:accessories];
  // What the formula comes to on the screen being previewed.
  NSMutableArray *results = [NSMutableArray array], *resultViews = [NSMutableArray array];
  NSArray *resultNames = @[@"result-x", @"result-y", @"result-width", @"result-height"], *resultCaptions = @[@"x", @"y", @"Width", @"Height"];
  for (NSUInteger i = 0; i < 4; i++) {
    NSTextField *value = [NSTextField labelWithString:@""];
    [value setIdentifier:resultNames[i]];
    [results addObject:value];
    [resultViews addObject:[MWMComponents fieldWithCaption:resultCaptions[i] control:value]];
  }
  self.resultFields = results;
  NSStackView *resultTop = [MWMComponents equalRowWithViews:@[resultViews[0], resultViews[1]] spacing:10];
  NSStackView *resultBottom = [MWMComponents equalRowWithViews:@[resultViews[2], resultViews[3]] spacing:10];
  NSView *resultGroup = [MWMComponents groupBoxWithTitle:@"On this screen" views:@[resultTop, resultBottom] accessory:nil];
  self.checkLabel = [NSTextField wrappingLabelWithString:@""];
  [self.checkLabel setFont:[MWMTheme fontCaption]];
  [self.checkLabel setIdentifier:@"check"];
  NSView *checksGroup = [MWMComponents groupBoxWithTitle:@"Checks" views:@[self.checkLabel] accessory:nil];
  self.customBlock = [MWMComponents columnWithViews:@[formulaGroup, resultGroup, checksGroup] spacing:10 insets:NSEdgeInsetsZero];
  [self.customBlock setHidden:YES];
  self.modeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Simple", @"Advanced (formula)"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(modeChanged:)];
  [self.modeControl setIdentifier:@"mode"];
  [self.modeControl setSelectedSegment:0];
  [self.modeControl setSegmentDistribution:NSSegmentDistributionFillEqually];
  [self.modeControl setToolTip:@"Simple: fields for position, size and margins. Advanced: write the formula yourself."];
  NSView *cardLine = [MWMComponents separator];
  self.messageLabel = [NSTextField wrappingLabelWithString:@""];
  [self.messageLabel setFont:[MWMTheme fontCaption]];
  NSStackView *cardContent = [MWMComponents columnWithViews:@[nameBlock, cardLine, self.modeControl, self.fieldsBlock, self.customBlock, self.messageLabel] spacing:14 insets:NSEdgeInsetsMake(14, 14, 14, 14)];
  [cardContent setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *card = [MWMComponents card];
  [card addSubview:cardContent];
  // The card is exactly as tall as its content, whatever room the page has.
  [cardContent setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
  [NSLayoutConstraint activateConstraints:@[
    [cardContent.topAnchor constraintEqualToAnchor:card.topAnchor],
    [cardContent.leadingAnchor constraintEqualToAnchor:card.leadingAnchor], [cardContent.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
    [card.heightAnchor constraintEqualToAnchor:cardContent.heightAnchor],
    [card.widthAnchor constraintEqualToConstant:300],
  ]];

  // Right: the canvas, and under it one line for the preview screen and the grid.
  self.canvas = [[ConfigurationSlotCanvas alloc] init];
  [self.canvas setDelegate:self];
  [self.canvas setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.canvas setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];

  self.screenPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  [self.screenPopup setControlSize:NSControlSizeSmall];
  [self.screenPopup setTarget:self];
  [self.screenPopup setAction:@selector(screenChanged:)];
  self.gridControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Off", @"2", @"3", @"4", @"6", @"8", @"12"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(gridChanged:)];
  [self.gridControl setControlSize:NSControlSizeSmall];
  [self.gridControl setSelectedSegment:3];  // quarters
  [self.gridControl setToolTip:@"The grid is made of this many equal parts, and the slot snaps to its lines"];
  NSView *toolbarSpacer = [MWMComponents spacer];
  NSStackView *toolbarRow = [NSStackView stackViewWithViews:@[[MWMComponents secondaryLabel:@"Preview on"], self.screenPopup, toolbarSpacer, [MWMComponents secondaryLabel:@"Grid"], self.gridControl]];
  [toolbarRow setSpacing:8];
  [toolbarRow setAlignment:NSLayoutAttributeCenterY];
  [toolbarRow setEdgeInsets:NSEdgeInsetsMake(6, 10, 6, 10)];
  [toolbarRow setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *toolbar = [MWMComponents card];
  [toolbar setTranslatesAutoresizingMaskIntoConstraints:NO];
  [toolbar addSubview:toolbarRow];
  [NSLayoutConstraint activateConstraints:@[
    [toolbarRow.topAnchor constraintEqualToAnchor:toolbar.topAnchor], [toolbarRow.bottomAnchor constraintEqualToAnchor:toolbar.bottomAnchor],
    [toolbarRow.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor], [toolbarRow.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor],
  ]];
  NSStackView *canvasColumn = [NSStackView stackViewWithViews:@[self.canvas, toolbar]];
  [canvasColumn setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [canvasColumn setAlignment:NSLayoutAttributeLeading];
  [canvasColumn setSpacing:8];
  for (NSView *view in @[self.canvas, toolbar]) [[view.widthAnchor constraintEqualToAnchor:canvasColumn.widthAnchor] setActive:YES];

  // The card keeps the height of its content, at the top; the space below it stays empty.
  NSView *cardHolder = [[NSView alloc] init];
  [cardHolder setTranslatesAutoresizingMaskIntoConstraints:NO];
  [cardHolder addSubview:card];
  [NSLayoutConstraint activateConstraints:@[
    [card.topAnchor constraintEqualToAnchor:cardHolder.topAnchor], [card.leadingAnchor constraintEqualToAnchor:cardHolder.leadingAnchor],
    [card.trailingAnchor constraintEqualToAnchor:cardHolder.trailingAnchor],
    [cardHolder.widthAnchor constraintEqualToConstant:300],
  ]];
  NSStackView *columns = [NSStackView stackViewWithViews:@[cardHolder, canvasColumn]];
  [columns setSpacing:16];
  [columns setAlignment:NSLayoutAttributeTop];
  // Both columns start at the top and take the height their content needs.
  [[cardHolder.topAnchor constraintEqualToAnchor:columns.topAnchor] setActive:YES];
  [[canvasColumn.topAnchor constraintEqualToAnchor:columns.topAnchor] setActive:YES];
  [columns setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 20)];
  [columns setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];

  // The save bar, under a line: whether there is anything to save, then Save and Cancel.
  MWMSaveBar *saveBar = [MWMSaveBar barWithTarget:self cancel:@selector(cancelPressed:) save:@selector(savePressed:)];
  self.saveBar = saveBar;
  self.changesChip = saveBar.chip;
  self.cancelButton = saveBar.cancelButton;
  self.saveButton = saveBar.saveButton;

  // Laid out with constraints: the columns take whatever height is left between the header and the save bar.
  self.editorPage = [[NSView alloc] init];
  for (NSView *view in @[header, columns, saveBar]) {
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.editorPage addSubview:view];
    [[view.leadingAnchor constraintEqualToAnchor:self.editorPage.leadingAnchor] setActive:YES];
    [[view.trailingAnchor constraintEqualToAnchor:self.editorPage.trailingAnchor] setActive:YES];
  }
  [NSLayoutConstraint activateConstraints:@[
    [header.topAnchor constraintEqualToAnchor:self.editorPage.topAnchor],
    [columns.topAnchor constraintEqualToAnchor:header.bottomAnchor],
    [columns.bottomAnchor constraintEqualToAnchor:saveBar.topAnchor],
    [saveBar.bottomAnchor constraintEqualToAnchor:self.editorPage.bottomAnchor],
  ]];
}

#pragma mark - Model

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
  self.selectedName = nil;
  self.selectedIsNew = NO;
  [self reloadScreens];
  [self reload];
}

// The size of the screen the editor previews on, in points.
- (CGSize)previewScreenSize {
  NSValue *size = [[[self.screenPopup selectedItem] representedObject] objectForKey:@"size"];
  return size != nil ? [size sizeValue] : CGSizeMake(1600, 900);
}

// Works a formula out on the preview screen, in pixels, with a sample window for the names that mean the window.
// Says what is wrong with it when it can't be.
- (BOOL)evaluateFormula:(NSString *)formula rect:(CGRect *)rect error:(NSString **)error {
  CGSize screen = [self previewScreenSize];
  NSString *expanded = [self.document expandAliases:formula];
  return [MWMFormula getRect:rect fromMoveText:expanded screenSize:screen window:[MWMFormula sampleWindowForScreenSize:screen] error:error];
}

// The area a stored formula stands for on the preview screen, as fractions of it, when it can be worked out
// (nothing for a formula with a mistake).
- (CGRect)fractionRectForFormula:(NSString *)formula {
  MWMSlotShape *shape = [MWMSlotShape shapeFromFormula:formula];
  CGSize screen = [self previewScreenSize];
  if (shape != nil) return [shape fractionRectForScreenSize:screen];
  CGRect rect = CGRectZero;
  if (![self evaluateFormula:formula rect:&rect error:nil]) return CGRectNull;
  return CGRectMake(rect.origin.x / screen.width, rect.origin.y / screen.height, rect.size.width / screen.width, rect.size.height / screen.height);
}

// The file's own slots, with the area they stand for when it can be worked out.
- (NSArray<MWMSlot *> *)customSlots {
  NSMutableArray *slots = [NSMutableArray array];
  for (MWMConfigEntry *entry in self.document.positions) {
    CGRect rect = [self fractionRectForFormula:[entry.value description]];
    MWMSlot *preset = [MWMSlots presetNamed:entry.name];
    if (preset != nil && !CGRectIsNull(rect) && [MWMSlots rect:rect isSameAreaAs:preset.rect]) continue;  // it's the preset itself
    [slots addObject:[MWMSlot slotNamed:entry.name rect:rect preset:NO]];
  }
  return slots;
}

- (MWMConfigEntry *)positionNamed:(NSString *)name {
  for (MWMConfigEntry *entry in self.document.positions) if ([entry.name isEqualToString:name]) return entry;
  return nil;
}

- (NSSet<NSString *> *)allNamesExcept:(NSString *)own {
  NSMutableSet *names = [NSMutableSet set];
  for (NSArray *section in @[self.document.modifiers, self.document.monitors, self.document.positions, self.document.aliases]) {
    for (MWMConfigEntry *entry in section) [names addObject:entry.name];
  }
  if (own != nil) [names removeObject:own];
  return names;
}

#pragma mark - The slot being edited

- (CGRect)draftRect {
  if (_draftShape == nil) return CGRectNull;
  return CGRectMake(_draftShape.horizontal.position, _draftShape.vertical.position, _draftShape.horizontal.sizeFraction, _draftShape.vertical.sizeFraction);
}

// A new start and size in percent; pixels, centering and margins stay as they are.
- (void)setDraftRect:(CGRect)rect {
  if (_draftShape == nil) _draftShape = [MWMSlotShape shapeFromRect:rect];
  _draftShape.horizontal.position = rect.origin.x; _draftShape.vertical.position = rect.origin.y;
  _draftShape.horizontal.sizeFraction = rect.size.width; _draftShape.vertical.sizeFraction = rect.size.height;
}

- (MWMSlotShape *)draftShape { return _draftShape; }
- (void)setDraftShape:(MWMSlotShape *)shape {
  _draftShape = shape;
  _customMode = shape == nil;
  if (self.selectedName != nil) [self refresh];
}

- (NSString *)draftFormulaText { return _draftFormulaText; }
- (void)setDraftFormulaText:(NSString *)text {
  _draftFormulaText = [text copy];
  if (self.selectedName != nil) [self refresh];
}

// What Save would write.
- (NSString *)draftFormula {
  return self.customMode ? ([self.draftFormulaText ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) : [self.draftShape formula];
}

- (BOOL)hasUnsavedChanges {
  if (self.selectedName == nil) return NO;
  if (self.selectedIsNew) return YES;
  if (![self.draftName ?: @"" isEqualToString:self.originalName ?: @""]) return YES;
  if (self.customMode) return ![[self draftFormula] isEqualToString:self.originalFormulaText ?: @""];
  return ![self.draftShape isEqualToShape:self.originalShape];
}

// The area on the preview screen as fractions, for checking against other slots.
- (CGRect)draftFractionRect {
  if (self.customMode) return [self fractionRectForFormula:[self draftFormula]];
  return [self.draftShape fractionRectForScreenSize:[self previewScreenSize]];
}

- (NSString *)problem {
  if (![self hasUnsavedChanges]) return nil;
  NSSet *taken = [self allNamesExcept:self.originalName];
  NSString *nameProblem = [MWMSlots problemWithName:self.draftName ?: @"" takenNames:taken];
  if (nameProblem != nil) return nameProblem;
  if (self.customMode) {
    // A formula left as it was isn't checked again, so its slot can still be renamed.
    if ([[self draftFormula] isEqualToString:self.originalFormulaText ?: @""]) return nil;
    CGRect rect;
    NSString *error = nil;
    if (![self evaluateFormula:[self draftFormula] rect:&rect error:&error]) return error ?: @"This isn't a formula MWM can work out.";
    if (rect.size.width <= 0 || rect.size.height <= 0) return @"The slot needs some width and height.";
    return nil;
  }
  NSString *shapeProblem = [self.draftShape problem];
  if (shapeProblem != nil) return shapeProblem;
  if ([self.draftShape isPlainPercent]) {
    NSMutableArray *others = [NSMutableArray array];
    for (MWMSlot *slot in [self customSlots]) {
      if ([slot.name isEqualToString:self.originalName ?: @""] || CGRectIsNull(slot.rect)) continue;
      [others addObject:slot];
    }
    return [MWMSlots problemWithName:self.draftName ?: @"" rect:self.draftRect otherSlots:others takenNames:taken];
  }
  return nil;
}

#pragma mark - Selecting

- (void)selectSlotNamed:(NSString *)name {
  MWMSlot *preset = [MWMSlots presetNamed:name];
  MWMConfigEntry *entry = [self positionNamed:name];
  if (entry == nil) return;  // presets are for reading, not editing
  NSString *formula = [[entry.value description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  MWMSlotShape *shape = [MWMSlotShape shapeFromFormula:formula];
  CGRect rect = CGRectZero;
  if (shape == nil && [MWMSlots getRect:&rect fromFormula:formula]) shape = [MWMSlotShape shapeFromRect:rect];  // the same thing written differently
  if (shape != nil && [shape isPlainPercent] && preset != nil && [MWMSlots rect:[shape fractionRectForScreenSize:CGSizeMake(1000, 1000)] isSameAreaAs:preset.rect]) return;  // it's the preset itself
  self.selectedName = name;
  self.selectedIsNew = NO;
  self.originalName = name;
  self.draftName = name;
  _draftShape = shape;
  _customMode = shape == nil;
  self.originalShape = [shape copy];
  _draftFormulaText = shape == nil ? formula : nil;
  self.originalFormulaText = shape == nil ? formula : nil;
  [self refresh];
}

- (void)startNewSlot {
  NSString *name = @"slot";
  NSSet *taken = [self allNamesExcept:nil];
  for (NSUInteger i = 2; [taken containsObject:name] || [MWMSlots presetNamed:name]; i++) name = [NSString stringWithFormat:@"slot%lu", (unsigned long)i];
  // Start in the middle, moved aside until it isn't the same as a slot that already exists.
  CGRect rect = CGRectMake(0.25, 0.25, 0.5, 0.5);
  for (NSUInteger tries = 0; tries < 20 && [MWMSlots problemWithName:name rect:rect otherSlots:[self customSlots] takenNames:taken] != nil; tries++) {
    rect.size.width = MAX(0.1, rect.size.width - 0.03);
    rect.size.height = MAX(0.1, rect.size.height - 0.03);
  }
  self.selectedName = name;
  self.selectedIsNew = YES;
  self.originalName = nil;
  self.draftName = name;
  _draftShape = [MWMSlotShape shapeFromRect:rect];
  _customMode = NO;
  self.originalShape = [_draftShape copy];
  _draftFormulaText = nil;
  self.originalFormulaText = nil;
  [self refresh];
}

#pragma mark - The gallery

- (void)reload {
  if (self.document == nil) return;
  [self rebuildGallery];
  [self refreshEditor];
}

- (void)refresh {
  [self rebuildGallery];
  [self refreshEditor];
}

// A card for each custom slot that matches the search, then the New slot card, three to a row.
- (void)rebuildGallery {
  for (NSView *row in [[self.galleryRows arrangedSubviews] copy]) {
    [self.galleryRows removeArrangedSubview:row];
    [row removeFromSuperview];
  }
  NSString *query = [[self.search stringValue] lowercaseString];
  NSMutableArray *cards = [NSMutableArray array];
  __weak ConfigurationSlotsView *weakSelf = self;
  for (MWMSlot *slot in [self customSlots]) {
    if ([query length] > 0 && ![slot.name.lowercaseString containsString:query]) continue;
    BOOL valid = !CGRectIsNull(slot.rect);
    MWMConfigEntry *entry = [self positionNamed:slot.name];
    MWMSlotShape *shape = [MWMSlotShape shapeFromFormula:[entry.value description]];
    NSString *badge;
    if (shape == nil && !valid) badge = @"formula";
    else if (shape == nil) badge = @"custom formula";
    else if (![shape isPlainPercent]) badge = @"margins / pixels";
    else badge = [NSString stringWithFormat:@"%@ × %@", [self wholePercent:slot.rect.size.width], [self wholePercent:slot.rect.size.height]];
    ConfigurationSlotCard *card = [[ConfigurationSlotCard alloc] initWithName:slot.name badge:badge usage:[self usageTextForSlotNamed:slot.name]
                                                                         rect:slot.rect valid:valid];
    NSString *name = slot.name;
    card.onOpen = ^{ [weakSelf selectSlotNamed:name]; };
    card.onRemove = ^{ [weakSelf removeSlotNamed:name]; };
    [cards addObject:card];
  }
  ConfigurationSlotCard *newCard = [[ConfigurationSlotCard alloc] initNewCard];
  newCard.onOpen = ^{ [weakSelf startNewSlot]; };
  [cards addObject:newCard];

  for (NSUInteger i = 0; i < [cards count]; i += 3) {
    NSMutableArray *rowViews = [NSMutableArray arrayWithArray:[cards subarrayWithRange:NSMakeRange(i, MIN(3, [cards count] - i))]];
    while ([rowViews count] < 3) {  // keep the last row's cards the same width as the others
      NSView *blank = [[NSView alloc] init];
      [blank setTranslatesAutoresizingMaskIntoConstraints:NO];
      [rowViews addObject:blank];
    }
    NSStackView *row = [NSStackView stackViewWithViews:rowViews];
    [row setDistribution:NSStackViewDistributionFillEqually];
    [row setSpacing:12];
    [row setAlignment:NSLayoutAttributeTop];
    [self.galleryRows addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToAnchor:self.galleryRows.widthAnchor] setActive:YES];
  }
}

// "50" for half of the screen, "33.3" for a third, as a size badge.
- (NSString *)wholePercent:(CGFloat)fraction {
  double percent = round(fraction * 1000) / 10;
  return percent == floor(percent) ? [NSString stringWithFormat:@"%.0f", percent] : [NSString stringWithFormat:@"%.1f", percent];
}

// "3 shortcuts", "1 shortcut", or "Not used yet".
- (NSString *)usageTextForSlotNamed:(NSString *)name {
  NSUInteger uses = [self usesOfSlotNamed:name];
  if (uses == 0) return @"Not used yet";
  return [NSString stringWithFormat:@"%lu shortcut%@", (unsigned long)uses, uses == 1 ? @"" : @"s"];
}

#pragma mark - The editor

- (void)reloadScreens {
  [self.screenPopup removeAllItems];
  for (MWMDisplay *display in [MWMDisplays connected]) {
    [self.screenPopup addItemWithTitle:[NSString stringWithFormat:@"%@ · %@", display.builtIn ? @"Built-in" : display.name, [display sizeText]]];
    [[self.screenPopup lastItem] setRepresentedObject:@{@"aspect": @((CGFloat)display.width / MAX(display.height, 1)), @"size": [NSValue valueWithSize:NSMakeSize(display.width, display.height)]}];
  }
  if ([self.screenPopup numberOfItems] == 0) {
    [self.screenPopup addItemWithTitle:@"16:9 screen"];
    [[self.screenPopup lastItem] setRepresentedObject:@{@"aspect": @(16.0 / 9.0), @"size": [NSValue valueWithSize:NSMakeSize(1600, 900)]}];
  }
  [self screenChanged:self.screenPopup];
}

- (void)screenChanged:(id)sender {
  CGFloat aspect = [[[[self.screenPopup selectedItem] representedObject] objectForKey:@"aspect"] doubleValue];
  self.canvas.aspect = aspect;
  // The canvas is as tall as the screen it shows (plus the ruler), not as tall as the window.
  if (self.canvasHeight != nil) self.canvasHeight.active = NO;
  self.canvasHeight = [self.canvas.heightAnchor constraintEqualToAnchor:self.canvas.widthAnchor multiplier:1 / MAX(self.canvas.aspect, 0.2) constant:36];
  self.canvasHeight.active = YES;
}

// Shows the gallery, or the editor when a slot is open, and fills in the editor.
- (void)refreshEditor {
  BOOL has = self.selectedName != nil;
  [self.galleryPage setHidden:has];
  [self.editorPage setHidden:!has];
  if (has != self.lastEditing) {
    self.lastEditing = has;
    if ([self.delegate respondsToSelector:@selector(slotsView:didChangeEditing:)]) [self.delegate slotsView:self didChangeEditing:has];  // the window hides its header and bottom bar while a slot is open
  }
  self.canvas.hasSlot = has;
  self.canvas.title = self.draftName;
  BOOL plain = has && !self.customMode && [self.draftShape isPlainPercent];
  self.canvas.editable = plain;
  if (has) {
    CGRect shown = [self draftFractionRect];
    self.canvas.hasSlot = !CGRectIsNull(shown);
    if (!CGRectIsNull(shown)) self.canvas.rect = shown;
  }
  [self.editorTitle setStringValue:self.selectedIsNew ? @"New Slot" : @"Editing Slot"];
  BOOL dirty = [self hasUnsavedChanges];
  NSString *problem = [self problem];
  [self.saveBar setDirty:dirty canSave:problem == nil];
  if (has && [self.nameField currentEditor] == nil && ![[self.nameField stringValue] isEqualToString:self.draftName ?: @""]) [self.nameField setStringValue:self.draftName ?: @""];
  [self.modeControl setHidden:!self.selectedIsNew];   // an existing slot opens the way it is written
  [self.modeControl setSelectedSegment:self.customMode ? 1 : 0];
  [self.fieldsBlock setHidden:self.customMode];
  [self.customBlock setHidden:!self.customMode];
  if (has && self.customMode && [self.formulaField currentEditor] == nil && ![[self.formulaField stringValue] isEqualToString:self.draftFormulaText ?: @""]) [self.formulaField setStringValue:self.draftFormulaText ?: @""];
  if (has && !self.customMode) [self fillFieldsFromShape];
  [self.messageLabel setHidden:self.customMode];   // a formula has its own Checks box
  [self.customChip setHidden:self.selectedIsNew];
  if (has && self.customMode) [self fillResultAndChecks:problem];
  if (self.customMode) {
    // shown in the Checks box
  } else if (problem != nil && dirty) {
    [self.messageLabel setStringValue:problem];
    [self.messageLabel setTextColor:[MWMTheme warning]];
  } else if (!plain && has) {
    [self.messageLabel setStringValue:@"The canvas shows the result. Dragging is off while pixels, centering or margins are used."];
    [self.messageLabel setTextColor:[MWMTheme textTertiary]];
  } else if (!dirty) {
    [self.messageLabel setStringValue:@"Drag the slot on the canvas, or type exact values."];
    [self.messageLabel setTextColor:[MWMTheme textTertiary]];
  } else {
    [self.messageLabel setStringValue:@"Name is free · Area is new"];
    [self.messageLabel setTextColor:[MWMTheme success]];
  }
}

// The formula in pixels on the preview screen, and what is wrong with it, if anything.
- (void)fillResultAndChecks:(NSString *)problem {
  CGSize screen = [self previewScreenSize];
  CGRect rect = CGRectNull;
  NSString *error = nil;
  BOOL worked = [self evaluateFormula:[self draftFormula] rect:&rect error:&error];
  NSArray *values = worked ? @[@(rect.origin.x), @(rect.origin.y), @(rect.size.width), @(rect.size.height)] : nil;
  for (NSUInteger i = 0; i < 4; i++) [self.resultFields[i] setStringValue:values ? [NSString stringWithFormat:@"%ld px", (long)lround([values[i] doubleValue])] : @"–"];
  NSString *text;
  NSColor *color;
  if (problem != nil) { text = problem; color = [MWMTheme warning]; }
  else if (!worked) { text = error ?: @"This isn't a formula MWM can work out."; color = [MWMTheme warning]; }
  else if (CGRectGetMinX(rect) < -0.5 || CGRectGetMinY(rect) < -0.5 || CGRectGetMaxX(rect) > screen.width + 0.5 || CGRectGetMaxY(rect) > screen.height + 0.5) { text = @"Part of the slot falls outside this screen."; color = [MWMTheme warning]; }
  else { text = @"No problems. The canvas shows the area."; color = [MWMTheme success]; }
  [self.checkLabel setStringValue:text];
  [self.checkLabel setTextColor:color];
}

// The list of names a formula can use, in a popover from the "?" button.
- (void)showFormulaHelp:(NSButton *)sender {
  if (self.helpPopover.shown) { [self.helpPopover close]; return; }
  self.helpPopover = [ConfigurationFormulaHelp popover];
  [self.helpPopover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSRectEdgeMaxY];
}

- (NSString *)numberText:(NSInteger)n { return [NSString stringWithFormat:@"%ld", (long)n]; }

// The fields show the shape: percent or pixels for each size, the start (or "centered"), the margins.
- (void)fillFieldsFromShape {
  MWMSlotShape *shape = self.draftShape;
  NSArray *axes = @[shape.horizontal, shape.vertical];
  void (^set)(NSTextField *, NSString *) = ^(NSTextField *field, NSString *text) { if ([field currentEditor] == nil) [field setStringValue:text]; };
  for (NSUInteger i = 0; i < 2; i++) {
    MWMSlotAxis *axis = axes[i];
    NSTextField *start = self.valueFields[i], *size = self.valueFields[2 + i];
    [start setEnabled:!axis.centered];
    set(start, axis.centered ? @"centered" : [self percentText:axis.position]);
    set(size, axis.sizeInPixels ? [self numberText:axis.sizePixels] : [self percentText:axis.sizeFraction]);
    NSSegmentedControl *unit = i == 0 ? self.widthUnit : self.heightUnit;
    [unit setSelectedSegment:axis.sizeInPixels ? 1 : 0];
    [self.centerBoxes[i] setState:axis.centered ? NSControlStateValueOn : NSControlStateValueOff];
  }
  NSArray *margins = @[@(shape.horizontal.marginStart), @(shape.vertical.marginStart), @(shape.horizontal.marginEnd), @(shape.vertical.marginEnd)];
  for (NSUInteger i = 0; i < 4; i++) set(self.marginFields[i], [self numberText:[margins[i] integerValue]]);
}

- (NSString *)percentText:(CGFloat)fraction {
  double percent = round(fraction * 10000) / 100;
  return percent == floor(percent) ? [NSString stringWithFormat:@"%.0f%%", percent] : [NSString stringWithFormat:@"%.2f%%", percent];
}

#pragma mark - Editing

- (void)slotCanvas:(ConfigurationSlotCanvas *)canvas didChangeRect:(CGRect)rect {
  if (self.draftShape == nil || ![self.draftShape isPlainPercent]) return;
  self.draftRect = rect;
  [self refresh];
}

- (void)controlTextDidChange:(NSNotification *)notification {
  if ([notification object] == self.nameField) {
    self.draftName = [self.nameField stringValue];
    self.canvas.title = self.draftName;
    [self refreshEditor];
  } else if ([notification object] == self.formulaField) {
    _draftFormulaText = [[self.formulaField stringValue] copy];
    [self refreshEditor];
  } else if ([notification object] == self.search) {
    [self rebuildGallery];
  }
}

// A typed value: "25", "25%", "33.3" for a percent, or a number of pixels when the size is in pixels.
// Out-of-range percents are kept inside the screen.
- (void)valueEdited:(NSTextField *)field {
  if (self.draftShape == nil) return;
  NSString *text = [[[field stringValue] stringByReplacingOccurrencesOfString:@"%" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if ([text length] == 0 || [text isEqualToString:@"centered"]) { [self refreshEditor]; return; }
  NSString *which = [field identifier];
  BOOL horizontal = [which isEqualToString:@"x"] || [which isEqualToString:@"width"];
  MWMSlotAxis *axis = horizontal ? self.draftShape.horizontal : self.draftShape.vertical;
  BOOL isSize = [which isEqualToString:@"width"] || [which isEqualToString:@"height"];
  if (isSize && axis.sizeInPixels) {
    axis.sizePixels = MAX(1, (NSInteger)round([text doubleValue]));
    [self refresh];
    return;
  }
  CGFloat v = [text doubleValue] / 100;
  if (isSize) axis.sizeFraction = MIN(MAX(v, 0.01), axis.centered ? 1 : 1 - axis.position);
  else axis.position = MIN(MAX(v, 0), 1 - (axis.sizeInPixels ? 0 : axis.sizeFraction));
  [self refresh];
}

// Pixels or a percent for a size: the number is converted so the area stays about the same.
- (void)unitChanged:(NSSegmentedControl *)control {
  if (self.draftShape == nil) return;
  BOOL horizontal = [[control identifier] isEqualToString:@"width-unit"];
  MWMSlotAxis *axis = horizontal ? self.draftShape.horizontal : self.draftShape.vertical;
  CGSize screen = [self previewScreenSize];
  CGFloat total = horizontal ? screen.width : screen.height;
  BOOL pixels = [control selectedSegment] == 1;
  if (pixels && !axis.sizeInPixels) axis.sizePixels = MAX(1, (NSInteger)round(axis.sizeFraction * total));
  if (!pixels && axis.sizeInPixels) axis.sizeFraction = MIN(1, MAX(0.01, axis.sizePixels / total));
  axis.sizeInPixels = pixels;
  [self refresh];
}

- (void)centeredChanged:(NSButton *)box {
  if (self.draftShape == nil) return;
  MWMSlotAxis *axis = [[box identifier] isEqualToString:@"center-x"] ? self.draftShape.horizontal : self.draftShape.vertical;
  axis.centered = [box state] == NSControlStateValueOn;
  [self refresh];
}

- (void)marginEdited:(NSTextField *)field {
  if (self.draftShape == nil) return;
  NSInteger pixels = MAX(0, (NSInteger)round([[field stringValue] doubleValue]));
  NSString *which = [field identifier];
  if ([which isEqualToString:@"margin-left"]) self.draftShape.horizontal.marginStart = pixels;
  else if ([which isEqualToString:@"margin-right"]) self.draftShape.horizontal.marginEnd = pixels;
  else if ([which isEqualToString:@"margin-top"]) self.draftShape.vertical.marginStart = pixels;
  else self.draftShape.vertical.marginEnd = pixels;
  [self refresh];
}

- (void)gridChanged:(id)sender {
  static const NSInteger kDivisions[] = {0, 2, 3, 4, 6, 8, 12};
  NSInteger segment = [self.gridControl selectedSegment];
  self.canvas.gridDivisions = segment >= 0 && segment < 7 ? kDivisions[segment] : 4;
}
// Switching a new slot between the fields and the formula text keeps what was drawn so far.
- (void)modeChanged:(id)sender {
  BOOL advanced = [self.modeControl selectedSegment] == 1;
  if (advanced == _customMode) return;
  if (advanced) {
    _draftFormulaText = [[self.draftShape formula] copy] ?: @"";
    _customMode = YES;
  } else {
    MWMSlotShape *shape = [MWMSlotShape shapeFromFormula:[self.document expandAliases:_draftFormulaText ?: @""]];
    if (shape != nil) _draftShape = shape;   // otherwise the fields go back to what they showed before
    _customMode = NO;
  }
  [self refresh];
}

- (void)newSlotPressed:(id)sender { [self startNewSlot]; }
- (void)cancelPressed:(id)sender { [self closeEditor]; }

// Back to the gallery, throwing away what was changed.
- (void)closeEditor {
  if (!self.selectedIsNew) self.draftName = self.originalName;
  self.selectedName = nil;
  self.selectedIsNew = NO;
  [self.nameField setStringValue:@""];
  [self refresh];
}

// The back arrow: asks first when there's something to lose.
- (void)backPressed:(id)sender {
  if ([self hasUnsavedChanges]) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindConfirm];
    [alert setMessageText:@"Discard your changes?"];
    [alert setInformativeText:@"This slot has changes that haven't been saved."];
    [alert addButtonWithTitle:@"Keep editing"];
    [alert addDestructiveButtonWithTitle:@"Discard"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  [self closeEditor];
}

- (void)savePressed:(id)sender { [self save]; }

- (void)revert {
  if (self.selectedIsNew) {
    self.selectedName = nil;
    self.selectedIsNew = NO;
    [self refresh];
    return;
  }
  self.draftName = self.originalName;
  _draftShape = [self.originalShape copy];
  _customMode = self.originalShape == nil;
  _draftFormulaText = self.originalFormulaText;
  [self.nameField setStringValue:self.draftName ?: @""];
  [self refresh];
}

- (void)save {
  if (![self hasUnsavedChanges] || [self problem] != nil) return;
  NSString *name = [self.draftName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *formula = [self draftFormula];
  if (self.selectedIsNew) {
    [self.document.positions addObject:[MWMConfigEntry entryWithName:name value:formula]];
  } else {
    MWMConfigEntry *entry = [self positionNamed:self.originalName];
    if (entry == nil) return;
    if (![name isEqualToString:self.originalName]) [self.document renameReferencesFrom:self.originalName to:name];
    entry.name = name;
    entry.value = formula;
  }
  [self.delegate slotsViewDidChangeDocument:self];
  self.selectedName = nil;
  self.selectedIsNew = NO;
  [self refresh];
}

- (NSUInteger)usesOfSlotNamed:(NSString *)name {
  NSString *reference = [NSString stringWithFormat:@"${%@}", name];
  NSUInteger uses = 0;
  for (MWMBindingEntry *binding in self.document.bindings) if ([binding.action containsString:reference]) uses++;
  for (MWMConfigEntry *entry in self.document.aliases) if ([[entry.value description] containsString:reference]) uses++;
  return uses;
}

// Removes a custom slot, unless a shortcut moves windows to it.
- (void)removeSlotNamed:(NSString *)name {
  MWMConfigEntry *entry = [self positionNamed:name];
  if (entry == nil) return;
  NSUInteger uses = [self usesOfSlotNamed:entry.name];
  if (uses > 0) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setMessageText:[NSString stringWithFormat:@"\"%@\" is in use", entry.name]];
    [alert setInformativeText:[NSString stringWithFormat:@"%lu shortcut%@ move%@ windows to it. Change %@ first, then remove the slot.", (unsigned long)uses, uses == 1 ? @"" : @"s", uses == 1 ? @"s" : @"", uses == 1 ? @"it" : @"them"]];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    return;
  }
  [self.document.positions removeObjectIdenticalTo:entry];
  [self.delegate slotsViewDidChangeDocument:self];
  if ([self.selectedName isEqualToString:name]) self.selectedName = nil;
  [self refresh];
}

@end
