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
#import "ConfigurationBlockView.h"
#import "ConfigurationSlotCanvas.h"
#import "SlateConfigDocument.h"
#import "SlateDisplays.h"
#import "SlateSlots.h"

static const CGFloat kListWidth = 270;

#pragma mark - List cell

// A list row: a small picture of the slot, its name, what size it is, and a remove button for custom ones.
@interface ConfigurationSlotCell : NSTableCellView
@property (assign) CGRect rect;
@property (assign) BOOL valid;
@property (copy) void (^onRemove)(void);
- (instancetype)initWithName:(NSString *)name summary:(NSString *)summary rect:(CGRect)rect valid:(BOOL)valid removable:(BOOL)removable;
@end

@implementation ConfigurationSlotCell

- (instancetype)initWithName:(NSString *)name summary:(NSString *)summary rect:(CGRect)rect valid:(BOOL)valid removable:(BOOL)removable {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _rect = rect;
    _valid = valid;
    [self setIdentifier:name];
    NSTextField *title = [NSTextField labelWithString:name];
    [title setFont:[NSFont systemFontOfSize:13]];
    [title setLineBreakMode:NSLineBreakByTruncatingTail];
    NSTextField *detail = [NSTextField labelWithString:summary];
    [detail setFont:[NSFont systemFontOfSize:11]];
    [detail setTextColor:[NSColor secondaryLabelColor]];
    [detail setLineBreakMode:NSLineBreakByTruncatingTail];
    NSStackView *text = [NSStackView stackViewWithViews:@[title, detail]];
    [text setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [text setAlignment:NSLayoutAttributeLeading];
    [text setSpacing:0];
    [text setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:text];
    [self setTextField:title];
    [NSLayoutConstraint activateConstraints:@[
      [text.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:46],
      [text.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:removable ? -28 : -4],
      [text.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];
    if (removable) {
      NSButton *remove = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"minus.circle" accessibilityDescription:@"Remove slot"] target:self action:@selector(removePressed:)];
      [remove setBordered:NO];
      [remove setToolTip:@"Remove this slot"];
      [remove setTranslatesAutoresizingMaskIntoConstraints:NO];
      [self addSubview:remove];
      [NSLayoutConstraint activateConstraints:@[
        [remove.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2],
        [remove.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      ]];
    }
  }
  return self;
}

- (void)removePressed:(id)sender { if (self.onRemove) self.onRemove(); }

- (void)drawRect:(NSRect)dirtyRect {
  NSRect picture = NSMakeRect(2, (NSHeight([self bounds]) - 22) / 2, 36, 22);
  NSBezierPath *frame = [NSBezierPath bezierPathWithRoundedRect:picture xRadius:3 yRadius:3];
  [[NSColor tertiaryLabelColor] setStroke];
  [frame setLineWidth:1];
  [frame stroke];
  if (!self.valid) return;
  NSRect slot = NSMakeRect(NSMinX(picture) + 2 + self.rect.origin.x * (NSWidth(picture) - 4),
                           NSMaxY(picture) - 2 - (self.rect.origin.y + self.rect.size.height) * (NSHeight(picture) - 4),
                           self.rect.size.width * (NSWidth(picture) - 4), self.rect.size.height * (NSHeight(picture) - 4));
  [[[NSColor controlAccentColor] colorWithAlphaComponent:0.6] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:slot xRadius:1.5 yRadius:1.5] fill];
}

@end

#pragma mark - Presets popover

// The built-in presets, for reading: grouped, each with a picture, its name, and how to use it.
@interface ConfigurationPresetsView : NSView
@end

@implementation ConfigurationPresetsView

- (NSView *)cardForPreset:(SlateSlot *)preset {
  ConfigurationSlotCell *picture = [[ConfigurationSlotCell alloc] initWithName:preset.name summary:[preset summary] rect:preset.rect valid:YES removable:NO];
  [picture setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[picture.widthAnchor constraintEqualToConstant:200] setActive:YES];
  [[picture.heightAnchor constraintEqualToConstant:38] setActive:YES];
  return picture;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSMutableArray *blocks = [NSMutableArray array];
    NSTextField *title = [NSTextField labelWithString:@"Built-in presets"];
    [title setFont:[NSFont systemFontOfSize:15 weight:NSFontWeightSemibold]];
    NSTextField *note = [NSTextField wrappingLabelWithString:@"These work in shortcuts without being in your file, as ${name}. They can't be changed, so custom slots need different names."];
    [note setFont:[NSFont systemFontOfSize:11]];
    [note setTextColor:[NSColor secondaryLabelColor]];
    [blocks addObject:title];
    [blocks addObject:note];
    NSArray *groups = @[@[@"Whole screen", @[@"full"]],
                        @[@"Halves", @[@"lefthalf", @"righthalf", @"tophalf", @"bottomhalf"]],
                        @[@"Thirds, side by side", @[@"third1", @"third2", @"third3"]],
                        @[@"Thirds, stacked", @[@"thirdrow1", @"thirdrow2", @"thirdrow3"]],
                        @[@"Quarters, side by side", @[@"quarter1", @"quarter2", @"quarter3", @"quarter4"]],
                        @[@"Quarters, stacked", @[@"quarterrow1", @"quarterrow2", @"quarterrow3", @"quarterrow4"]]];
    for (NSArray *group in groups) {
      NSTextField *heading = [NSTextField labelWithString:[group[0] uppercaseString]];
      [heading setFont:[NSFont systemFontOfSize:10 weight:NSFontWeightSemibold]];
      [heading setTextColor:[NSColor tertiaryLabelColor]];
      NSMutableArray *cards = [NSMutableArray array];
      for (NSString *name in group[1]) [cards addObject:[self cardForPreset:[SlateSlots presetNamed:name]]];
      // Two cards to a row.
      NSMutableArray *rows = [NSMutableArray array];
      for (NSUInteger i = 0; i < [cards count]; i += 2) {
        NSArray *pair = [cards subarrayWithRange:NSMakeRange(i, MIN(2, [cards count] - i))];
        NSStackView *row = [NSStackView stackViewWithViews:pair];
        [row setSpacing:8];
        [row setAlignment:NSLayoutAttributeTop];
        [rows addObject:row];
      }
      NSStackView *section = [NSStackView stackViewWithViews:[@[heading] arrayByAddingObjectsFromArray:rows]];
      [section setOrientation:NSUserInterfaceLayoutOrientationVertical];
      [section setAlignment:NSLayoutAttributeLeading];
      [section setSpacing:4];
      [blocks addObject:section];
    }
    NSStackView *stack = [NSStackView stackViewWithViews:blocks];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setAlignment:NSLayoutAttributeLeading];
    [stack setSpacing:12];
    [stack setEdgeInsets:NSEdgeInsetsMake(16, 16, 16, 16)];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[note.widthAnchor constraintEqualToConstant:408] setActive:YES];
    [self addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
      [stack.topAnchor constraintEqualToAnchor:self.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];
  }
  return self;
}

@end

#pragma mark - Gallery cards

// A screen with the slot drawn on it.
@interface ConfigurationSlotThumbnail : NSView
@property (assign) CGRect rect;
@property (assign) BOOL valid;
@end

@implementation ConfigurationSlotThumbnail
- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric, 84); }
- (void)drawRect:(NSRect)dirtyRect {
  NSRect bounds = NSInsetRect([self bounds], 1, 1);
  CGFloat height = MIN(NSHeight(bounds), NSWidth(bounds) / 1.7), width = height * 1.7;
  NSRect screen = NSMakeRect(NSMidX(bounds) - width / 2, NSMidY(bounds) - height / 2, width, height);
  NSBezierPath *frame = [NSBezierPath bezierPathWithRoundedRect:screen xRadius:6 yRadius:6];
  [[[NSColor labelColor] colorWithAlphaComponent:0.05] setFill];
  [frame fill];
  [[NSColor tertiaryLabelColor] setStroke];
  [frame setLineWidth:1.2];
  [frame stroke];
  if (!self.valid) return;
  NSRect slot = NSMakeRect(NSMinX(screen) + 3 + self.rect.origin.x * (NSWidth(screen) - 6),
                           NSMaxY(screen) - 3 - (self.rect.origin.y + self.rect.size.height) * (NSHeight(screen) - 6),
                           self.rect.size.width * (NSWidth(screen) - 6), self.rect.size.height * (NSHeight(screen) - 6));
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:slot xRadius:3 yRadius:3];
  [[[NSColor controlAccentColor] colorWithAlphaComponent:0.25] setFill];
  [path fill];
  [[NSColor controlAccentColor] setStroke];
  [path setLineWidth:1.5];
  [path stroke];
}
@end

// A card in the gallery: a picture of the slot, its name and size. Clicking opens it;
// the New slot card has a dashed edge.
@interface ConfigurationSlotCard : ConfigurationBlockView
@property (copy) void (^onOpen)(void);
@property (copy) void (^onRemove)(void);
@property (assign) BOOL isNewCard;
- (instancetype)initWithName:(NSString *)name summary:(NSString *)summary rect:(CGRect)rect valid:(BOOL)valid removable:(BOOL)removable;
- (instancetype)initNewCard;
@end

@implementation ConfigurationSlotCard

- (instancetype)initWithName:(NSString *)name summary:(NSString *)summary rect:(CGRect)rect valid:(BOOL)valid removable:(BOOL)removable {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    [self setIdentifier:name];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    ConfigurationSlotThumbnail *thumbnail = [[ConfigurationSlotThumbnail alloc] init];
    thumbnail.rect = rect;
    thumbnail.valid = valid;
    NSTextField *title = [NSTextField labelWithString:name];
    [title setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
    [title setLineBreakMode:NSLineBreakByTruncatingTail];
    NSTextField *detail = [NSTextField labelWithString:summary];
    [detail setFont:[NSFont systemFontOfSize:11]];
    [detail setTextColor:[NSColor secondaryLabelColor]];
    [detail setLineBreakMode:NSLineBreakByTruncatingTail];
    NSStackView *stack = [NSStackView stackViewWithViews:@[thumbnail, title, detail]];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setAlignment:NSLayoutAttributeLeading];
    [stack setSpacing:2];
    [stack setCustomSpacing:8 afterView:thumbnail];
    [stack setEdgeInsets:NSEdgeInsetsMake(10, 10, 10, 10)];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[thumbnail.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-20] setActive:YES];
    [self addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
      [stack.topAnchor constraintEqualToAnchor:self.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];
    if (removable) {
      NSButton *remove = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"minus.circle.fill" accessibilityDescription:@"Remove slot"] target:self action:@selector(removePressed:)];
      [remove setBordered:NO];
      [remove setToolTip:@"Remove this slot"];
      [remove setContentTintColor:[NSColor tertiaryLabelColor]];
      [remove setTranslatesAutoresizingMaskIntoConstraints:NO];
      [self addSubview:remove];
      [NSLayoutConstraint activateConstraints:@[
        [remove.topAnchor constraintEqualToAnchor:self.topAnchor constant:8], [remove.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
      ]];
    }
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
    [plus setContentTintColor:[NSColor secondaryLabelColor]];
    NSTextField *label = [NSTextField labelWithString:@"New slot"];
    [label setTextColor:[NSColor secondaryLabelColor]];
    NSStackView *stack = [NSStackView stackViewWithViews:@[plus, label]];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setSpacing:4];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
      [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [self.heightAnchor constraintGreaterThanOrEqualToConstant:140],
    ]];
  }
  return self;
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
  [[NSColor tertiaryLabelColor] setStroke];
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
@property (strong) NSPopUpButton *gridPopup;
@property (strong) NSTextField *nameField;
@property (strong) NSArray<NSTextField *> *valueFields;
@property (strong) NSTextField *messageLabel;
@property (strong) NSTextField *hintLabel;
@property (strong) NSButton *cancelButton;
@property (strong) NSButton *saveButton;
@property (strong) NSPopover *presetsPopover;
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
  [label setFont:[NSFont systemFontOfSize:11]];
  [label setTextColor:[NSColor secondaryLabelColor]];
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
// and, under a line, the presets.
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

  // The presets, in a row of their own under a line.
  NSBox *line = [[NSBox alloc] init];
  [line setBoxType:NSBoxSeparator];
  NSImageView *lock = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"lock" accessibilityDescription:nil]];
  [lock setContentTintColor:[NSColor secondaryLabelColor]];
  NSTextField *presetTitle = [NSTextField labelWithString:@"Built-in presets"];
  [presetTitle setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
  NSTextField *presetNote = [self captionLabel:@"Halves, thirds and quarters, ready to use in shortcuts. They can't be changed."];
  NSStackView *presetText = [NSStackView stackViewWithViews:@[presetTitle, presetNote]];
  [presetText setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [presetText setAlignment:NSLayoutAttributeLeading];
  [presetText setSpacing:1];
  NSView *presetSpacer = [[NSView alloc] init];
  [presetSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSButton *presets = [self buttonTitled:@"View Presets" action:@selector(showPresets:)];
  NSStackView *presetRow = [NSStackView stackViewWithViews:@[lock, presetText, presetSpacer, presets]];
  [presetRow setSpacing:10];
  [presetRow setAlignment:NSLayoutAttributeCenterY];

  NSStackView *page = [NSStackView stackViewWithViews:@[top, scroll, line, presetRow]];
  [page setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [page setAlignment:NSLayoutAttributeLeading];
  [page setSpacing:12];
  [page setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 20)];
  [page setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[top, scroll, line, presetRow]) [[view.widthAnchor constraintEqualToAnchor:page.widthAnchor constant:-40] setActive:YES];
  [[self.galleryRows.widthAnchor constraintEqualToAnchor:scroll.widthAnchor] setActive:YES];
  self.galleryPage = [[NSView alloc] init];
  [self pinView:page toEdgesOf:self.galleryPage];
}

// The editor: a back arrow, the preview and drag column on the left, the form on the right.
- (void)buildEditorPage {
  NSButton *back = [NSButton buttonWithTitle:@"Custom slots" target:self action:@selector(backPressed:)];
  [back setImage:[NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Back"]];
  [back setImagePosition:NSImageLeft];
  [back setBordered:NO];
  [back setContentTintColor:[NSColor controlAccentColor]];
  [back setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
  NSView *backSpacer = [[NSView alloc] init];
  [backSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *backRow = [NSStackView stackViewWithViews:@[back, backSpacer]];

  // Left: Preview on and Grid at the top of the canvas.
  self.screenPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  [self.screenPopup setTarget:self];
  [self.screenPopup setAction:@selector(screenChanged:)];
  self.gridPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  for (NSArray *option in @[@[@"Off", @0], @[@"Halves", @2], @[@"Thirds", @3], @[@"Quarters", @4], @[@"Sixths", @6], @[@"Eighths", @8], @[@"Twelfths", @12]]) {
    [self.gridPopup addItemWithTitle:option[0]];
    [[self.gridPopup lastItem] setRepresentedObject:option[1]];
  }
  [self.gridPopup selectItemWithTitle:@"Quarters"];
  [self.gridPopup setTarget:self];
  [self.gridPopup setAction:@selector(gridChanged:)];
  NSStackView *previewRow = [NSStackView stackViewWithViews:@[[self captioned:self.screenPopup with:@"Preview on"], [self captioned:self.gridPopup with:@"Grid"]]];
  [previewRow setSpacing:12];
  [previewRow setDistribution:NSStackViewDistributionFillEqually];
  [previewRow setAlignment:NSLayoutAttributeTop];

  self.canvas = [[ConfigurationSlotCanvas alloc] init];
  [self.canvas setDelegate:self];
  [self.canvas setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[self.canvas.heightAnchor constraintGreaterThanOrEqualToConstant:260] setActive:YES];
  [self.canvas setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  self.hintLabel = [self captionLabel:@"Drag the slot to move it, or its sides and corners to resize it. Hold ⌥ for free movement."];
  [self.hintLabel setTextColor:[NSColor tertiaryLabelColor]];

  NSStackView *previewColumn = [NSStackView stackViewWithViews:@[previewRow, self.canvas, self.hintLabel]];
  [previewColumn setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [previewColumn setAlignment:NSLayoutAttributeLeading];
  [previewColumn setSpacing:10];
  [previewColumn setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[previewRow, self.canvas]) [[view.widthAnchor constraintEqualToAnchor:previewColumn.widthAnchor] setActive:YES];

  // Right: the form, then Cancel and Save.
  self.nameField = [NSTextField textFieldWithString:@""];
  [self.nameField setPlaceholderString:@"Name this slot"];
  [self.nameField setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium]];
  [self.nameField setDelegate:self];
  self.valueFields = @[[self valueField:@"x"], [self valueField:@"y"], [self valueField:@"width"], [self valueField:@"height"]];
  NSArray *captions = @[@"x (from left)", @"y (from top)", @"Width", @"Height"];
  NSMutableArray *captioned = [NSMutableArray array];
  for (NSUInteger i = 0; i < 4; i++) [captioned addObject:[self captioned:self.valueFields[i] with:captions[i]]];
  NSStackView *positionRow = [NSStackView stackViewWithViews:@[captioned[0], captioned[1]]];
  NSStackView *sizeRow = [NSStackView stackViewWithViews:@[captioned[2], captioned[3]]];
  for (NSStackView *row in @[positionRow, sizeRow]) { [row setDistribution:NSStackViewDistributionFillEqually]; [row setSpacing:10]; [row setAlignment:NSLayoutAttributeTop]; }
  NSStackView *nameBlock = [self captioned:self.nameField with:@"Name"];

  self.messageLabel = [NSTextField wrappingLabelWithString:@""];
  [self.messageLabel setFont:[NSFont systemFontOfSize:11]];
  self.cancelButton = [self buttonTitled:@"Cancel" action:@selector(cancelPressed:)];
  self.saveButton = [self buttonTitled:@"Save" action:@selector(savePressed:)];
  [self.saveButton setKeyEquivalent:@"\r"];
  NSStackView *actions = [NSStackView stackViewWithViews:@[self.cancelButton, self.saveButton]];
  [actions setDistribution:NSStackViewDistributionFillEqually];
  [actions setSpacing:8];

  NSView *formSpacer = [[NSView alloc] init];
  [formSpacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  for (NSView *view in @[nameBlock, positionRow, sizeRow, self.messageLabel, actions]) [view setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
  NSStackView *formColumn = [NSStackView stackViewWithViews:@[nameBlock, positionRow, sizeRow, formSpacer, self.messageLabel, actions]];
  [formColumn setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [formColumn setAlignment:NSLayoutAttributeLeading];
  [formColumn setSpacing:14];
  [formColumn setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[formColumn.widthAnchor constraintEqualToConstant:230] setActive:YES];
  for (NSView *view in @[nameBlock, positionRow, sizeRow, self.messageLabel, actions]) [[view.widthAnchor constraintEqualToAnchor:formColumn.widthAnchor] setActive:YES];

  NSStackView *columns = [NSStackView stackViewWithViews:@[previewColumn, formColumn]];
  [columns setSpacing:20];
  [columns setAlignment:NSLayoutAttributeTop];
  [columns setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[formColumn.topAnchor constraintEqualToAnchor:columns.topAnchor] setActive:YES];
  [[formColumn.bottomAnchor constraintEqualToAnchor:columns.bottomAnchor] setActive:YES];
  [[previewColumn.topAnchor constraintEqualToAnchor:columns.topAnchor] setActive:YES];
  [previewColumn setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [columns setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];

  NSStackView *page = [NSStackView stackViewWithViews:@[backRow, columns]];
  [page setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [page setAlignment:NSLayoutAttributeLeading];
  [page setSpacing:10];
  [page setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 20)];
  [page setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[backRow, columns]) [[view.widthAnchor constraintEqualToAnchor:page.widthAnchor constant:-40] setActive:YES];
  self.editorPage = [[NSView alloc] init];
  [self pinView:page toEdgesOf:self.editorPage];
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
    ConfigurationSlotCard *card = [[ConfigurationSlotCard alloc] initWithName:slot.name summary:valid ? [slot summary] : @"Written as a formula"
                                                                         rect:slot.rect valid:valid removable:YES];
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

#pragma mark - Presets

- (void)showPresets:(NSButton *)sender {
  if (self.presetsPopover == nil) {
    NSViewController *controller = [[NSViewController alloc] init];
    ConfigurationPresetsView *content = [[ConfigurationPresetsView alloc] init];
    [controller setView:content];
    self.presetsPopover = [[NSPopover alloc] init];
    [self.presetsPopover setBehavior:NSPopoverBehaviorTransient];
    [self.presetsPopover setContentViewController:controller];
  }
  if ([self.presetsPopover isShown]) { [self.presetsPopover close]; return; }
  [self.presetsPopover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSRectEdgeMaxY];
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
  self.canvas.aspect = [[[self.screenPopup selectedItem] representedObject] doubleValue];
}

// Shows the gallery, or the editor when a slot is open, and fills in the editor.
- (void)refreshEditor {
  BOOL has = self.selectedName != nil;
  [self.galleryPage setHidden:has];
  [self.editorPage setHidden:!has];
  self.canvas.hasSlot = has;
  self.canvas.editable = has;
  self.canvas.title = self.draftName;
  if (has) self.canvas.rect = self.draftRect;
  BOOL dirty = [self hasUnsavedChanges];
  NSString *problem = [self problem];
  [self.saveButton setEnabled:dirty && problem == nil];
  if (has && [self.nameField currentEditor] == nil && ![[self.nameField stringValue] isEqualToString:self.draftName ?: @""]) [self.nameField setStringValue:self.draftName ?: @""];
  if (has) {
    NSArray *numbers = @[@(self.draftRect.origin.x), @(self.draftRect.origin.y), @(self.draftRect.size.width), @(self.draftRect.size.height)];
    for (NSUInteger i = 0; i < 4; i++) {
      NSTextField *field = self.valueFields[i];
      if ([field currentEditor] == nil) [field setStringValue:[self percentText:[numbers[i] doubleValue]]];
    }
  }
  if (!dirty) {
    [self.messageLabel setStringValue:@""];
  } else if (problem != nil) {
    [self.messageLabel setStringValue:problem];
    [self.messageLabel setTextColor:[NSColor systemOrangeColor]];
  } else {
    [self.messageLabel setStringValue:@"Name is free · Area is new"];
    [self.messageLabel setTextColor:[NSColor systemGreenColor]];
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
  self.canvas.gridDivisions = [[[self.gridPopup selectedItem] representedObject] integerValue];
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
