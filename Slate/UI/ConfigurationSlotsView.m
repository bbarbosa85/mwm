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
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationSlotCanvas.h"
#import "SlateConfigDocument.h"
#import "SlateDisplays.h"
#import "SlateSlots.h"


#pragma mark - Gallery cards

// A card in the gallery, picture first: a screen with the slot drawn on it, a size badge,
// a quiet ✕ to remove it, and under it the name and how many shortcuts use it. Clicking
// opens it. The New Slot card has a dashed edge.
@interface ConfigurationSlotCard : ConfigurationBlockView
@property (copy) void (^onOpen)(void);
@property (copy) void (^onRemove)(void);
@property (assign) BOOL isNewCard;
@property (strong) NSView *badgeView;
- (instancetype)initWithName:(NSString *)name badge:(NSString *)badge usage:(NSString *)usage rect:(CGRect)rect valid:(BOOL)valid;
- (instancetype)initNewCard;
@end

@implementation ConfigurationSlotCard

- (instancetype)initWithName:(NSString *)name badge:(NSString *)badge usage:(NSString *)usage rect:(CGRect)rect valid:(BOOL)valid {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    [self setIdentifier:name];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    ConfigurationSlotThumbnail *thumbnail = [[ConfigurationSlotThumbnail alloc] init];
    thumbnail.rect = rect;
    thumbnail.valid = valid;
    [thumbnail setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[thumbnail.heightAnchor constraintGreaterThanOrEqualToConstant:96] setActive:YES];
    NSTextField *title = [NSTextField labelWithString:name];
    [title setFont:[MWMTheme fontBodyStrong]];
    [title setLineBreakMode:NSLineBreakByTruncatingTail];
    NSTextField *detail = [NSTextField labelWithString:usage];
    [detail setFont:[MWMTheme fontCaption]];
    [detail setTextColor:[MWMTheme textSecondary]];
    NSView *gap = [[NSView alloc] init];
    [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *footer = [NSStackView stackViewWithViews:@[title, gap, detail]];
    [footer setAlignment:NSLayoutAttributeFirstBaseline];
    [footer setSpacing:8];
    NSStackView *stack = [NSStackView stackViewWithViews:@[thumbnail, footer]];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setAlignment:NSLayoutAttributeLeading];
    [stack setSpacing:8];
    [stack setEdgeInsets:NSEdgeInsetsMake(10, 10, 12, 10)];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[thumbnail.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-20] setActive:YES];
    [[footer.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-20] setActive:YES];
    [self addSubview:stack];

    // The size, on the picture's top left.
    NSTextField *size = [NSTextField labelWithString:badge];
    [size setFont:[NSFont systemFontOfSize:10 weight:NSFontWeightMedium]];
    [size setTextColor:[MWMTheme textSecondary]];
    [size setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSView *badgeView = [[NSView alloc] init];
    [badgeView setWantsLayer:YES];
    [[badgeView layer] setCornerRadius:9];
    [badgeView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [badgeView addSubview:size];
    [self addSubview:badgeView];

    NSButton *remove = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:@"Remove slot"] target:self action:@selector(removePressed:)];
    [remove setBordered:NO];
    [remove setToolTip:@"Remove this slot"];
    [remove setContentTintColor:[MWMTheme textTertiary]];
    [remove setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:remove];
    [NSLayoutConstraint activateConstraints:@[
      [stack.topAnchor constraintEqualToAnchor:self.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [size.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor constant:8], [size.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:-8],
      [size.topAnchor constraintEqualToAnchor:badgeView.topAnchor constant:2], [size.bottomAnchor constraintEqualToAnchor:badgeView.bottomAnchor constant:-2],
      [badgeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18], [badgeView.topAnchor constraintEqualToAnchor:self.topAnchor constant:18],
      [remove.topAnchor constraintEqualToAnchor:self.topAnchor constant:14], [remove.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
    ]];
    _badgeView = badgeView;
  }
  return self;
}

- (instancetype)initNewCard {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _isNewCard = YES;
    [self setIdentifier:@"+new"];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSImageView *plus = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:nil]];
    [plus setSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:22 weight:NSFontWeightRegular]];
    [plus setContentTintColor:[MWMTheme textSecondary]];
    NSTextField *label = [NSTextField labelWithString:@"New Slot"];
    [label setTextColor:[MWMTheme textSecondary]];
    NSStackView *stack = [NSStackView stackViewWithViews:@[plus, label]];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setSpacing:4];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
      [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [self.heightAnchor constraintGreaterThanOrEqualToConstant:150],
    ]];
  }
  return self;
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self.badgeView layer] setBackgroundColor:[[[NSColor windowBackgroundColor] colorWithAlphaComponent:0.9] CGColor]];
  }];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event { if (self.onOpen) self.onOpen(); }
- (void)removePressed:(id)sender { if (self.onRemove) self.onRemove(); }

- (void)drawRect:(NSRect)dirtyRect {
  if (!self.isNewCard) return;
  NSBezierPath *edge = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect([self bounds], 1, 1) xRadius:12 yRadius:12];
  CGFloat dash[2] = {5, 4};
  [edge setLineDash:dash count:2 phase:0];
  [edge setLineWidth:1.5];
  [[MWMTheme textTertiary] setStroke];
  [edge stroke];
}

@end

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
@property (assign) CGRect originalRect;
@end

@implementation ConfigurationSlotsView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) [self buildInterface];
  return self;
}

#pragma mark - Interface

- (NSButton *)buttonTitled:(NSString *)title action:(SEL)action {
  NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
  [button setBezelStyle:NSBezelStyleRounded];
  return button;
}

- (NSTextField *)captionLabel:(NSString *)text {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[MWMTheme fontCaption]];
  [label setTextColor:[MWMTheme textSecondary]];
  return label;
}

// A small caption above a control.
- (NSStackView *)captioned:(NSView *)control with:(NSString *)caption {
  NSStackView *stack = [NSStackView stackViewWithViews:@[[self captionLabel:caption], control]];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:3];
  [[control.widthAnchor constraintEqualToAnchor:stack.widthAnchor] setActive:YES];
  return stack;
}

- (NSTextField *)valueField:(NSString *)identifier {
  NSTextField *field = [NSTextField textFieldWithString:@""];
  [field setIdentifier:identifier];
  [field setDelegate:self];
  [field setTarget:self];
  [field setAction:@selector(valueEdited:)];
  [[field cell] setSendsActionOnEndEditing:YES];
  return field;
}

- (void)pinView:(NSView *)view toEdgesOf:(NSView *)container {
  [view setTranslatesAutoresizingMaskIntoConstraints:NO];
  [container addSubview:view];
  [NSLayoutConstraint activateConstraints:@[
    [view.topAnchor constraintEqualToAnchor:container.topAnchor], [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    [view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor], [view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
  ]];
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
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *top = [NSStackView stackViewWithViews:@[spacer, self.search]];

  self.galleryRows = [NSStackView stackViewWithViews:@[]];
  [self.galleryRows setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.galleryRows setAlignment:NSLayoutAttributeLeading];
  [self.galleryRows setSpacing:12];
  [self.galleryRows setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *document = [[ConfigurationFlippedView alloc] init];
  [document setTranslatesAutoresizingMaskIntoConstraints:NO];
  [document addSubview:self.galleryRows];
  NSScrollView *scroll = [[NSScrollView alloc] init];
  [scroll setHasVerticalScroller:YES];
  [scroll setAutohidesScrollers:YES];
  [scroll setDrawsBackground:NO];
  NSClipView *clip = [[NSClipView alloc] init];
  [clip setDrawsBackground:NO];
  [scroll setContentView:clip];
  [scroll setDocumentView:document];
  [scroll setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[
    [self.galleryRows.topAnchor constraintEqualToAnchor:document.topAnchor], [self.galleryRows.bottomAnchor constraintEqualToAnchor:document.bottomAnchor],
    [self.galleryRows.leadingAnchor constraintEqualToAnchor:document.leadingAnchor], [self.galleryRows.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
    [document.topAnchor constraintEqualToAnchor:clip.topAnchor], [document.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
    [document.trailingAnchor constraintEqualToAnchor:clip.trailingAnchor],
  ]];

  NSStackView *page = [NSStackView stackViewWithViews:@[top, scroll]];
  [page setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [page setAlignment:NSLayoutAttributeLeading];
  [page setSpacing:12];
  [page setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 20)];
  [page setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[top, scroll]) [[view.widthAnchor constraintEqualToAnchor:page.widthAnchor constant:-40] setActive:YES];
  [[self.galleryRows.widthAnchor constraintEqualToAnchor:scroll.widthAnchor] setActive:YES];
  self.galleryPage = [[NSView alloc] init];
  [self pinView:page toEdgesOf:self.galleryPage];
}

// The editor: a header with the back button and the title, a card with the form on the
// left, the canvas and its view toolbar on the right, and under a line the save bar.
- (void)buildEditorPage {
  NSButton *back = [NSButton buttonWithTitle:@"Slots" target:self action:@selector(backPressed:)];
  [back setImage:[NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Back"]];
  [back setImagePosition:NSImageLeft];
  [back setBordered:NO];
  [back setContentTintColor:[MWMTheme accent]];
  [back setFont:[MWMTheme fontHeading]];
  self.editorTitle = [NSTextField labelWithString:@"Editing Slot"];
  [self.editorTitle setFont:[MWMTheme fontTitle]];
  NSView *headerSpacer = [[NSView alloc] init];
  [headerSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *header = [NSStackView stackViewWithViews:@[back, self.editorTitle, headerSpacer]];
  [header setSpacing:14];
  [header setAlignment:NSLayoutAttributeCenterY];
  [header setEdgeInsets:NSEdgeInsetsMake(14, 20, 4, 20)];

  // Left: the form card.
  self.nameField = [NSTextField textFieldWithString:@""];
  [self.nameField setPlaceholderString:@"Name this slot"];
  [self.nameField setDelegate:self];
  NSStackView *nameBlock = [self captioned:self.nameField with:@"Name"];
  self.valueFields = @[[self valueField:@"x"], [self valueField:@"y"], [self valueField:@"width"], [self valueField:@"height"]];
  NSArray *captions = @[@"x (from left)", @"y (from top)", @"Width", @"Height"];
  NSMutableArray *captioned = [NSMutableArray array];
  for (NSUInteger i = 0; i < 4; i++) [captioned addObject:[self captioned:self.valueFields[i] with:captions[i]]];
  NSStackView *positionRow = [NSStackView stackViewWithViews:@[captioned[0], captioned[1]]];
  NSStackView *sizeRow = [NSStackView stackViewWithViews:@[captioned[2], captioned[3]]];
  for (NSStackView *row in @[positionRow, sizeRow]) { [row setDistribution:NSStackViewDistributionFillEqually]; [row setSpacing:10]; [row setAlignment:NSLayoutAttributeTop]; }
  NSBox *cardLine = [[NSBox alloc] init];
  [cardLine setBoxType:NSBoxSeparator];
  self.messageLabel = [NSTextField wrappingLabelWithString:@""];
  [self.messageLabel setFont:[MWMTheme fontCaption]];
  NSStackView *cardContent = [NSStackView stackViewWithViews:@[nameBlock, cardLine, positionRow, sizeRow, self.messageLabel]];
  [cardContent setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [cardContent setAlignment:NSLayoutAttributeLeading];
  [cardContent setSpacing:12];
  [cardContent setEdgeInsets:NSEdgeInsetsMake(14, 14, 14, 14)];
  [cardContent setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[nameBlock, cardLine, positionRow, sizeRow, self.messageLabel]) [[view.widthAnchor constraintEqualToAnchor:cardContent.widthAnchor constant:-28] setActive:YES];
  ConfigurationBlockView *card = [[ConfigurationBlockView alloc] init];
  [card setTranslatesAutoresizingMaskIntoConstraints:NO];
  [card addSubview:cardContent];
  // The card is exactly as tall as its content, whatever room the page has.
  [cardContent setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
  [NSLayoutConstraint activateConstraints:@[
    [cardContent.topAnchor constraintEqualToAnchor:card.topAnchor],
    [cardContent.leadingAnchor constraintEqualToAnchor:card.leadingAnchor], [cardContent.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
    [card.heightAnchor constraintEqualToAnchor:cardContent.heightAnchor],
    [card.widthAnchor constraintEqualToConstant:230],
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
  NSView *toolbarSpacer = [[NSView alloc] init];
  [toolbarSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *toolbarRow = [NSStackView stackViewWithViews:@[[self captionLabel:@"Preview on"], self.screenPopup, toolbarSpacer, [self captionLabel:@"Grid"], self.gridControl]];
  [toolbarRow setSpacing:8];
  [toolbarRow setAlignment:NSLayoutAttributeCenterY];
  [toolbarRow setEdgeInsets:NSEdgeInsetsMake(6, 10, 6, 10)];
  [toolbarRow setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationBlockView *toolbar = [[ConfigurationBlockView alloc] init];
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
    [cardHolder.widthAnchor constraintEqualToConstant:230],
  ]];
  NSStackView *columns = [NSStackView stackViewWithViews:@[cardHolder, canvasColumn]];
  [columns setSpacing:16];
  [columns setAlignment:NSLayoutAttributeTop];
  // Both columns start at the top and take the height their content needs.
  [[cardHolder.topAnchor constraintEqualToAnchor:columns.topAnchor] setActive:YES];
  [[canvasColumn.topAnchor constraintEqualToAnchor:columns.topAnchor] setActive:YES];
  [columns setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 20)];
  [columns setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];

  // The save bar, under a line: whether there's anything to save, then Cancel and Save.
  NSBox *saveLine = [[NSBox alloc] init];
  [saveLine setBoxType:NSBoxSeparator];
  self.changesChip = [MWMChipView chipWithText:@"No changes" color:nil];
  self.cancelButton = [self buttonTitled:@"Cancel" action:@selector(cancelPressed:)];
  self.saveButton = [self buttonTitled:@"Save" action:@selector(savePressed:)];
  [self.saveButton setKeyEquivalent:@"\r"];
  NSView *barSpacer = [[NSView alloc] init];
  [barSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *saveBar = [NSStackView stackViewWithViews:@[self.changesChip, barSpacer, self.cancelButton, self.saveButton]];
  [saveBar setSpacing:8];
  [saveBar setAlignment:NSLayoutAttributeCenterY];
  [saveBar setEdgeInsets:NSEdgeInsetsMake(10, 20, 12, 20)];

  // Laid out with constraints: the columns take whatever height is left between the header and the save bar.
  self.editorPage = [[NSView alloc] init];
  for (NSView *view in @[header, columns, saveLine, saveBar]) {
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.editorPage addSubview:view];
    [[view.leadingAnchor constraintEqualToAnchor:self.editorPage.leadingAnchor] setActive:YES];
    [[view.trailingAnchor constraintEqualToAnchor:self.editorPage.trailingAnchor] setActive:YES];
  }
  [NSLayoutConstraint activateConstraints:@[
    [header.topAnchor constraintEqualToAnchor:self.editorPage.topAnchor],
    [columns.topAnchor constraintEqualToAnchor:header.bottomAnchor],
    [columns.bottomAnchor constraintEqualToAnchor:saveLine.topAnchor],
    [saveLine.bottomAnchor constraintEqualToAnchor:saveBar.topAnchor],
    [saveBar.bottomAnchor constraintEqualToAnchor:self.editorPage.bottomAnchor],
    [header.heightAnchor constraintEqualToConstant:48],   // fixed, so the columns are the part that stretches
    [saveBar.heightAnchor constraintEqualToConstant:48],
  ]];
}

#pragma mark - Model

- (void)setDocument:(SlateConfigDocument *)document {
  _document = document;
  self.selectedName = nil;
  self.selectedIsNew = NO;
  [self reloadScreens];
  [self reload];
}

// The file's own slots, with the area they stand for when it can be worked out.
- (NSArray<SlateSlot *> *)customSlots {
  NSMutableArray *slots = [NSMutableArray array];
  for (SlateConfigEntry *entry in self.document.positions) {
    CGRect rect = CGRectZero;
    BOOL readable = [SlateSlots getRect:&rect fromFormula:[entry.value description]];
    SlateSlot *preset = [SlateSlots presetNamed:entry.name];
    if (preset != nil && readable && [SlateSlots rect:rect isSameAreaAs:preset.rect]) continue;  // it's the preset itself
    SlateSlot *slot = [SlateSlot slotNamed:entry.name rect:readable ? rect : CGRectNull preset:NO];
    [slots addObject:slot];
  }
  return slots;
}

- (SlateConfigEntry *)positionNamed:(NSString *)name {
  for (SlateConfigEntry *entry in self.document.positions) if ([entry.name isEqualToString:name]) return entry;
  return nil;
}

- (NSSet<NSString *> *)allNamesExcept:(NSString *)own {
  NSMutableSet *names = [NSMutableSet set];
  for (NSArray *section in @[self.document.modifiers, self.document.monitors, self.document.positions, self.document.aliases]) {
    for (SlateConfigEntry *entry in section) [names addObject:entry.name];
  }
  if (own != nil) [names removeObject:own];
  return names;
}

- (BOOL)hasUnsavedChanges {
  if (self.selectedName == nil) return NO;
  if (self.selectedIsNew) return YES;
  return ![self.draftName ?: @"" isEqualToString:self.originalName ?: @""] || ![SlateSlots rect:self.draftRect isSameAreaAs:self.originalRect];
}

- (NSString *)problem {
  if (![self hasUnsavedChanges]) return nil;
  NSMutableArray *others = [NSMutableArray array];
  for (SlateSlot *slot in [self customSlots]) {
    if ([slot.name isEqualToString:self.originalName ?: @""] || CGRectIsNull(slot.rect)) continue;
    [others addObject:slot];
  }
  return [SlateSlots problemWithName:self.draftName ?: @"" rect:self.draftRect otherSlots:others takenNames:[self allNamesExcept:self.originalName]];
}

#pragma mark - Selecting

- (void)selectSlotNamed:(NSString *)name {
  SlateSlot *preset = [SlateSlots presetNamed:name];
  SlateConfigEntry *entry = [self positionNamed:name];
  CGRect rect = CGRectZero;
  if (entry == nil) return;  // presets are for reading, not editing
  if (![SlateSlots getRect:&rect fromFormula:[entry.value description]]) return;  // a formula: nothing to draw
  if (preset != nil && [SlateSlots rect:rect isSameAreaAs:preset.rect]) return;   // it's the preset itself
  self.selectedName = name;
  self.selectedIsNew = NO;
  self.originalName = name;
  self.draftName = name;
  self.draftRect = rect;
  self.originalRect = self.draftRect;
  [self refresh];
}

- (void)startNewSlot {
  NSString *name = @"slot";
  NSSet *taken = [self allNamesExcept:nil];
  for (NSUInteger i = 2; [taken containsObject:name] || [SlateSlots presetNamed:name]; i++) name = [NSString stringWithFormat:@"slot%lu", (unsigned long)i];
  // Start in the middle, moved aside until it isn't the same as a slot that already exists.
  CGRect rect = CGRectMake(0.25, 0.25, 0.5, 0.5);
  for (NSUInteger tries = 0; tries < 20 && [SlateSlots problemWithName:name rect:rect otherSlots:[self customSlots] takenNames:taken] != nil; tries++) {
    rect.size.width = MAX(0.1, rect.size.width - 0.03);
    rect.size.height = MAX(0.1, rect.size.height - 0.03);
  }
  self.selectedName = name;
  self.selectedIsNew = YES;
  self.originalName = nil;
  self.draftName = name;
  self.draftRect = rect;
  self.originalRect = rect;
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
  for (SlateSlot *slot in [self customSlots]) {
    if ([query length] > 0 && ![slot.name.lowercaseString containsString:query]) continue;
    BOOL valid = !CGRectIsNull(slot.rect);
    NSString *badge = valid ? [NSString stringWithFormat:@"%@ × %@", [self wholePercent:slot.rect.size.width], [self wholePercent:slot.rect.size.height]] : @"formula";
    ConfigurationSlotCard *card = [[ConfigurationSlotCard alloc] initWithName:slot.name badge:badge usage:[self usageTextForSlotNamed:slot.name]
                                                                         rect:slot.rect valid:valid];
    NSString *name = slot.name;
    if (valid) card.onOpen = ^{ [weakSelf selectSlotNamed:name]; };
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
  for (SlateDisplay *display in [SlateDisplays connected]) {
    [self.screenPopup addItemWithTitle:[NSString stringWithFormat:@"%@ · %@", display.builtIn ? @"Built-in" : display.name, [display sizeText]]];
    [[self.screenPopup lastItem] setRepresentedObject:@((CGFloat)display.width / MAX(display.height, 1))];
  }
  if ([self.screenPopup numberOfItems] == 0) {
    [self.screenPopup addItemWithTitle:@"16:9 screen"];
    [[self.screenPopup lastItem] setRepresentedObject:@(16.0 / 9.0)];
  }
  [self screenChanged:self.screenPopup];
}

- (void)screenChanged:(id)sender {
  CGFloat aspect = [[[self.screenPopup selectedItem] representedObject] doubleValue];
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
  self.canvas.editable = has;
  self.canvas.title = self.draftName;
  if (has) self.canvas.rect = self.draftRect;
  [self.editorTitle setStringValue:self.selectedIsNew ? @"New Slot" : @"Editing Slot"];
  BOOL dirty = [self hasUnsavedChanges];
  NSString *problem = [self problem];
  [self.saveButton setEnabled:dirty && problem == nil];
  self.changesChip.text = dirty ? @"● Unsaved changes" : @"No changes";
  self.changesChip.color = dirty ? [MWMTheme warning] : nil;
  if (has && [self.nameField currentEditor] == nil && ![[self.nameField stringValue] isEqualToString:self.draftName ?: @""]) [self.nameField setStringValue:self.draftName ?: @""];
  if (has) {
    NSArray *numbers = @[@(self.draftRect.origin.x), @(self.draftRect.origin.y), @(self.draftRect.size.width), @(self.draftRect.size.height)];
    for (NSUInteger i = 0; i < 4; i++) {
      NSTextField *field = self.valueFields[i];
      if ([field currentEditor] == nil) [field setStringValue:[self percentText:[numbers[i] doubleValue]]];
    }
  }
  if (!dirty) {
    [self.messageLabel setStringValue:@"Drag the slot on the canvas, or type exact values."];
    [self.messageLabel setTextColor:[MWMTheme textTertiary]];
  } else if (problem != nil) {
    [self.messageLabel setStringValue:problem];
    [self.messageLabel setTextColor:[MWMTheme warning]];
  } else {
    [self.messageLabel setStringValue:@"Name is free · Area is new"];
    [self.messageLabel setTextColor:[MWMTheme success]];
  }
}

- (NSString *)percentText:(CGFloat)fraction {
  double percent = round(fraction * 10000) / 100;
  return percent == floor(percent) ? [NSString stringWithFormat:@"%.0f%%", percent] : [NSString stringWithFormat:@"%.2f%%", percent];
}

#pragma mark - Editing

- (void)slotCanvas:(ConfigurationSlotCanvas *)canvas didChangeRect:(CGRect)rect {
  self.draftRect = rect;
  [self refresh];
}

- (void)controlTextDidChange:(NSNotification *)notification {
  if ([notification object] == self.nameField) {
    self.draftName = [self.nameField stringValue];
    self.canvas.title = self.draftName;
    [self refreshEditor];
  } else if ([notification object] == self.search) {
    [self rebuildGallery];
  }
}

// A typed value: "25", "25%", "33.3". Out-of-range values are kept inside the screen.
- (void)valueEdited:(NSTextField *)field {
  NSString *text = [[[field stringValue] stringByReplacingOccurrencesOfString:@"%" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if ([text length] == 0) { [self refreshEditor]; return; }
  CGFloat v = [text doubleValue] / 100;
  CGRect r = self.draftRect;
  NSString *which = [field identifier];
  if ([which isEqualToString:@"x"]) r.origin.x = MIN(MAX(v, 0), 1 - r.size.width);
  else if ([which isEqualToString:@"y"]) r.origin.y = MIN(MAX(v, 0), 1 - r.size.height);
  else if ([which isEqualToString:@"width"]) r.size.width = MIN(MAX(v, 0.01), 1 - r.origin.x);
  else r.size.height = MIN(MAX(v, 0.01), 1 - r.origin.y);
  self.draftRect = r;
  [self refresh];
}

- (void)gridChanged:(id)sender {
  static const NSInteger kDivisions[] = {0, 2, 3, 4, 6, 8, 12};
  NSInteger segment = [self.gridControl selectedSegment];
  self.canvas.gridDivisions = segment >= 0 && segment < 7 ? kDivisions[segment] : 4;
}
- (void)newSlotPressed:(id)sender { [self startNewSlot]; }
- (void)cancelPressed:(id)sender { [self closeEditor]; }

// Back to the gallery, throwing away what was changed.
- (void)closeEditor {
  if (!self.selectedIsNew) {
    self.draftName = self.originalName;
    self.draftRect = self.originalRect;
  }
  self.selectedName = nil;
  self.selectedIsNew = NO;
  [self.nameField setStringValue:@""];
  [self refresh];
}

// The back arrow: asks first when there's something to lose.
- (void)backPressed:(id)sender {
  if ([self hasUnsavedChanges]) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Discard your changes?"];
    [alert setInformativeText:@"This slot has changes that haven't been saved."];
    [alert addButtonWithTitle:@"Keep Editing"];
    [alert addButtonWithTitle:@"Discard"];
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
  self.draftRect = self.originalRect;
  [self.nameField setStringValue:self.draftName ?: @""];
  [self refresh];
}

// Renaming a slot renames it wherever a shortcut or alias uses it.
- (void)renameReferencesFrom:(NSString *)from to:(NSString *)to {
  NSString *old = [NSString stringWithFormat:@"${%@}", from], *new = [NSString stringWithFormat:@"${%@}", to];
  for (SlateBindingEntry *binding in self.document.bindings) {
    binding.action = [binding.action stringByReplacingOccurrencesOfString:old withString:new];
    if (binding.key) binding.key = [binding.key stringByReplacingOccurrencesOfString:old withString:new];
    if (binding.modifiers) binding.modifiers = [binding.modifiers stringByReplacingOccurrencesOfString:old withString:new];
  }
  for (NSArray *section in @[self.document.modifiers, self.document.monitors, self.document.positions, self.document.aliases]) {
    for (SlateConfigEntry *entry in section) {
      if ([entry.value isKindOfClass:[NSString class]]) entry.value = [entry.value stringByReplacingOccurrencesOfString:old withString:new];
    }
  }
}

- (void)save {
  if (![self hasUnsavedChanges] || [self problem] != nil) return;
  NSString *name = [self.draftName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *formula = [SlateSlots formulaForRect:self.draftRect];
  if (self.selectedIsNew) {
    [self.document.positions addObject:[SlateConfigEntry entryWithName:name value:formula]];
  } else {
    SlateConfigEntry *entry = [self positionNamed:self.originalName];
    if (entry == nil) return;
    if (![name isEqualToString:self.originalName]) [self renameReferencesFrom:self.originalName to:name];
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
  for (SlateBindingEntry *binding in self.document.bindings) if ([binding.action containsString:reference]) uses++;
  for (SlateConfigEntry *entry in self.document.aliases) if ([[entry.value description] containsString:reference]) uses++;
  return uses;
}

// Removes a custom slot, unless a shortcut moves windows to it.
- (void)removeSlotNamed:(NSString *)name {
  SlateConfigEntry *entry = [self positionNamed:name];
  if (entry == nil) return;
  NSUInteger uses = [self usesOfSlotNamed:entry.name];
  if (uses > 0) {
    NSAlert *alert = [[NSAlert alloc] init];
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
