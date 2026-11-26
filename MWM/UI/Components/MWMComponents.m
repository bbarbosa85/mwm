//
//  MWMComponents.m
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

#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "MWMTheme.h"

@interface MWMChipView ()
@property (strong) NSTextField *label;
@end

@interface MWMAccentButton : NSButton
@property (strong) NSColor *fill;   // the accent color unless set
@end

@implementation MWMAccentButton
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setBordered:NO];
    [self setButtonType:NSButtonTypeMomentaryChange];
    [self setWantsLayer:YES];
    [self setImagePosition:NSImageLeft];
    [self setImageHugsTitle:YES];
    [self setContentTintColor:[NSColor whiteColor]];
  }
  return self;
}
- (NSSize)intrinsicContentSize {
  NSSize size = [super intrinsicContentSize];
  return NSMakeSize(size.width + 16, MAX(size.height + 4, 24));
}
- (void)updateColors {
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self layer] setCornerRadius:MWMRadiusS];
    [[self layer] setBackgroundColor:[[(self.fill ?: [MWMTheme accent]) colorWithAlphaComponent:self.isHighlighted ? 0.75 : 1] CGColor]];
  }];
}
- (void)setHighlighted:(BOOL)flag { [super setHighlighted:flag]; [self updateColors]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateColors]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self updateColors]; }
@end

@interface MWMDashedCardView : NSView
@end

// One choice: the tile with its icon, and the name under it.
@interface MWMOptionCard : NSView
@property (assign, nonatomic) BOOL selected;
@property (copy) void (^onClick)(void);
@property (strong) NSTextField *label;
@end

static const CGFloat kOptionTileWidth = 84, kOptionTileHeight = 54;

@implementation MWMOptionCard
- (BOOL)isFlipped { return YES; }
- (instancetype)initWithTitle:(NSString *)title symbol:(NSString *)symbol {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
    [icon setSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightRegular]];
    [icon setContentTintColor:[MWMTheme textSecondary]];
    [icon setTranslatesAutoresizingMaskIntoConstraints:NO];
    self.label = [NSTextField labelWithString:title];
    [self.label setFont:[MWMTheme fontSmall]];
    [self.label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:icon];
    [self addSubview:self.label];
    [NSLayoutConstraint activateConstraints:@[
      [self.widthAnchor constraintEqualToConstant:kOptionTileWidth + 8],
      [self.heightAnchor constraintEqualToConstant:kOptionTileHeight + 26],
      [icon.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [icon.centerYAnchor constraintEqualToAnchor:self.topAnchor constant:kOptionTileHeight / 2],
      [self.label.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [self.label.topAnchor constraintEqualToAnchor:self.topAnchor constant:kOptionTileHeight + 6],
    ]];
    [self setSelected:NO];
  }
  return self;
}
- (void)setSelected:(BOOL)selected {
  _selected = selected;
  [self.label setFont:selected ? [MWMTheme fontBodyStrong] : [MWMTheme fontSmall]];
  [self.label setTextColor:selected ? [MWMTheme textPrimary] : [MWMTheme textSecondary]];
  [self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirty {
  NSRect tile = NSMakeRect(4, 2, kOptionTileWidth, kOptionTileHeight - 4);
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:tile xRadius:MWMRadiusM yRadius:MWMRadiusM];
  [[MWMTheme surfaceStrong] setFill];
  [path fill];
  [(self.selected ? [MWMTheme accent] : [MWMTheme stroke]) setStroke];
  [path setLineWidth:self.selected ? 2 : 1];
  [path stroke];
}
- (void)mouseDown:(NSEvent *)event { if (self.onClick) self.onClick(); }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
@end

@implementation MWMOptionCards
+ (instancetype)cardsWithTitles:(NSArray<NSString *> *)titles symbols:(NSArray<NSString *> *)symbols selectedIndex:(NSInteger)index onChange:(void (^)(NSInteger))onChange {
  MWMOptionCards *cards = [[self alloc] init];
  [cards setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
  [cards setSpacing:MWMSpacingS];
  [cards setAlignment:NSLayoutAttributeTop];
  [cards setTranslatesAutoresizingMaskIntoConstraints:NO];
  cards.onChange = onChange;
  for (NSUInteger i = 0; i < [titles count]; i++) {
    MWMOptionCard *card = [[MWMOptionCard alloc] initWithTitle:titles[i] symbol:symbols[i]];
    __weak MWMOptionCards *weakCards = cards;
    NSInteger at = (NSInteger)i;
    card.onClick = ^{
      if (weakCards.selectedIndex == at) return;
      weakCards.selectedIndex = at;
      if (weakCards.onChange) weakCards.onChange(at);
    };
    [card setIdentifier:[NSString stringWithFormat:@"option-%lu", (unsigned long)i]];
    [cards addArrangedSubview:card];
  }
  cards.selectedIndex = index;
  return cards;
}
- (void)setSelectedIndex:(NSInteger)selectedIndex {
  _selectedIndex = selectedIndex;
  NSInteger i = 0;
  for (MWMOptionCard *card in self.arrangedSubviews) card.selected = i++ == selectedIndex;
}
@end

// The cell centres the text vertically and keeps it off the rounded edge.
@interface MWMNameFieldCell : NSTextFieldCell
@property (assign) CGFloat inset;
@end

@implementation MWMNameFieldCell
- (NSRect)drawingRectForBounds:(NSRect)rect {
  NSRect inner = [super drawingRectForBounds:rect];
  NSSize size = [self cellSizeForBounds:rect];
  inner.origin.y += floor((inner.size.height - size.height) / 2);
  inner.size.height = size.height;
  return NSInsetRect(inner, self.inset, 0);
}
- (void)editWithFrame:(NSRect)rect inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate event:(NSEvent *)event {
  [super editWithFrame:[self drawingRectForBounds:rect] inView:view editor:editor delegate:delegate event:event];
}
- (void)selectWithFrame:(NSRect)rect inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate start:(NSInteger)start length:(NSInteger)length {
  [super selectWithFrame:[self drawingRectForBounds:rect] inView:view editor:editor delegate:delegate start:start length:length];
}
@end

@interface MWMNameField ()
@property (assign) BOOL focused;
@end

@implementation MWMNameField

+ (Class)cellClass { return [MWMNameFieldCell class]; }

// The box is drawn edge to edge: no bezel padding to line up around.
- (NSEdgeInsets)alignmentRectInsets { return NSEdgeInsetsZero; }

+ (instancetype)nameFieldWithPlaceholder:(NSString *)placeholder identifier:(NSString *)identifier compact:(BOOL)compact {
  MWMNameField *field = [[self alloc] initWithFrame:NSZeroRect];
  field->_compact = compact;
  [(MWMNameFieldCell *)field.cell setInset:compact ? MWMSpacingS : MWMSpacingM + 2];
  [field setFont:compact ? [MWMTheme fontBodyStrong] : [MWMTheme fontTitle]];
  [field setTranslatesAutoresizingMaskIntoConstraints:NO];
  [field setPlaceholderString:placeholder];
  if (identifier != nil) [field setIdentifier:identifier];
  [[field.heightAnchor constraintEqualToConstant:compact ? 26 : 44] setActive:YES];
  [field setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  return field;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setBezeled:NO];
    [self setBordered:NO];
    [self setDrawsBackground:NO];
    [self setFocusRingType:NSFocusRingTypeNone];
    [self setTextColor:[MWMTheme textPrimary]];
    [self setWantsLayer:YES];
    [self.layer setMasksToBounds:YES];
    [self restyle];
  }
  return self;
}

- (void)restyle {
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    BOOL ring = self.focused || self.invalid;
    NSColor *line = self.invalid ? [MWMTheme danger] : (self.focused ? [MWMTheme accent] : [MWMTheme stroke]);
    [self.layer setCornerRadius:self.compact ? MWMRadiusS : MWMRadiusM];
    [self.layer setBorderWidth:ring ? 1.5 : 1];
    [self.layer setBorderColor:[line CGColor]];
    [self.layer setBackgroundColor:[(self.focused ? [MWMTheme surface] : [MWMTheme tint:[MWMTheme textPrimary] opacity:MWMOpacityWash]) CGColor]];
  }];
}

- (void)setInvalid:(BOOL)invalid { _invalid = invalid; [self restyle]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self restyle]; }
- (BOOL)becomeFirstResponder { BOOL ok = [super becomeFirstResponder]; if (ok) { self.focused = YES; [self restyle]; } return ok; }
- (void)textDidEndEditing:(NSNotification *)notification { [super textDidEndEditing:notification]; self.focused = NO; [self restyle]; }

@end

@implementation MWMDashedCardView
- (void)drawRect:(NSRect)dirtyRect {
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect([self bounds], 1, 1) xRadius:MWMRadiusL yRadius:MWMRadiusL];
  CGFloat dash[] = {5, 4};
  [path setLineDash:dash count:2 phase:0];
  [path setLineWidth:1.5];
  [[MWMTheme stroke] setStroke];
  [path stroke];
}
@end

@implementation MWMChipView

+ (instancetype)chipWithText:(NSString *)text color:(NSColor *)color {
  MWMChipView *chip = [[self alloc] init];
  chip.text = text;
  chip.color = color;
  return chip;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setWantsLayer:YES];
    [[self layer] setCornerRadius:10];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    _label = [MWMComponents labelWithText:@"" font:[MWMTheme fontCaptionStrong] color:[MWMTheme textTertiary]];
    [_label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:_label];
    [NSLayoutConstraint activateConstraints:@[
      [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10], [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
      [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:3], [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3],
    ]];
  }
  return self;
}

- (void)setText:(NSString *)text { _text = [text copy]; [self.label setStringValue:text ?: @""]; }
- (void)setColor:(NSColor *)color { _color = color; [self updateColors]; }

- (void)updateColors {
  [self.label setTextColor:self.color ?: [MWMTheme textTertiary]];
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self layer] setBackgroundColor:self.color != nil ? [[MWMTheme tint:self.color opacity:MWMOpacitySelected] CGColor] : [[NSColor clearColor] CGColor]];
  }];
}
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateColors]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self updateColors]; }

@end

@implementation MWMSublevelHeader

+ (instancetype)headerWithBackTitle:(NSString *)backTitle title:(NSString *)title target:(id)target action:(SEL)action {
  MWMSublevelHeader *header = [[self alloc] init];
  [header setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSButton *back = [NSButton buttonWithTitle:backTitle target:target action:action];
  [back setImage:[NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Back"]];
  [back setImagePosition:NSImageLeft];
  [back setBordered:NO];
  [back setContentTintColor:[MWMTheme accent]];
  [back setFont:[MWMTheme fontHeading]];
  header->_backButton = back;
  header->_titleLabel = [MWMComponents titleLabel:title];
  NSStackView *stack = [NSStackView stackViewWithViews:@[back, header->_titleLabel, [MWMComponents spacer]]];
  [stack setSpacing:14];
  [stack setAlignment:NSLayoutAttributeCenterY];
  [stack setEdgeInsets:NSEdgeInsetsMake(14, MWMSpacingXL, 4, MWMSpacingXL)];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [header addSubview:stack];
  [MWMComponents pinView:stack toEdgesOf:header insets:NSEdgeInsetsMake(0, 0, 0, 0)];
  [[header.heightAnchor constraintEqualToConstant:48] setActive:YES];   // fixed, so the page below is the part that stretches
  return header;
}

@end

@implementation MWMSaveBar

+ (instancetype)barWithTarget:(id)target cancel:(SEL)cancel save:(SEL)save {
  MWMSaveBar *bar = [[self alloc] init];
  [bar setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *line = [MWMComponents separator];
  bar->_chip = [MWMChipView chipWithText:@"No changes" color:nil];
  bar->_messageLabel = [MWMComponents labelWithText:@"" font:[MWMTheme fontCaption] color:[MWMTheme textTertiary]];
  [bar->_messageLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
  bar->_cancelButton = [MWMComponents secondaryButtonWithTitle:@"Cancel" target:target action:cancel];
  bar->_saveButton = [MWMComponents primaryButtonWithTitle:@"Save" target:target action:save];
  // Save first, then the way out: the same order as the window's bottom bar (Apply and Restart, Save, Close).
  NSStackView *stack = [NSStackView stackViewWithViews:@[bar->_chip, [MWMComponents spacer], bar->_messageLabel, bar->_saveButton, bar->_cancelButton]];
  [stack setSpacing:MWMSpacingS];
  [stack setCustomSpacing:MWMSpacingL afterView:bar->_messageLabel];   // room between the message and Save
  [stack setAlignment:NSLayoutAttributeCenterY];
  [stack setEdgeInsets:NSEdgeInsetsMake(10, MWMSpacingXL, 12, MWMSpacingXL)];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [bar addSubview:line];
  [bar addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [line.topAnchor constraintEqualToAnchor:bar.topAnchor], [line.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor], [line.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
    [stack.topAnchor constraintEqualToAnchor:line.bottomAnchor], [stack.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
    [stack.heightAnchor constraintEqualToConstant:48],
  ]];
  return bar;
}

- (void)setDirty:(BOOL)dirty canSave:(BOOL)canSave {
  self.chip.text = dirty ? @"● Unsaved changes" : @"No changes";
  self.chip.color = dirty ? [MWMTheme warning] : nil;
  [self.saveButton setEnabled:dirty && canSave];
}

@end

@implementation MWMComponents

+ (NSTextField *)labelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
  NSTextField *label = [NSTextField labelWithString:text ?: @""];
  [label setFont:font];
  [label setTextColor:color];
  [label setLineBreakMode:NSLineBreakByTruncatingTail];
  return label;
}

+ (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  return [self labelWithText:text font:[NSFont systemFontOfSize:size weight:weight] color:color];
}

+ (NSTextField *)wrappingLabelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  NSTextField *label = [NSTextField wrappingLabelWithString:text ?: @""];
  [label setFont:[NSFont systemFontOfSize:size weight:weight]];
  [label setTextColor:color];
  [label setSelectable:NO];
  return label;
}

+ (NSTextField *)secondaryLabel:(NSString *)text { return [self labelWithText:text font:[MWMTheme fontSmall] color:[MWMTheme textSecondary]]; }
+ (NSTextField *)captionLabel:(NSString *)text { return [self labelWithText:text font:[MWMTheme fontCaption] color:[MWMTheme textTertiary]]; }
+ (NSTextField *)titleLabel:(NSString *)text { return [self labelWithText:text font:[MWMTheme fontTitle] color:[MWMTheme textPrimary]]; }

+ (NSView *)card {
  NSView *card = [[ConfigurationBlockView alloc] init];
  [card setTranslatesAutoresizingMaskIntoConstraints:NO];
  return card;
}

+ (NSView *)dashedCard {
  NSView *card = [[MWMDashedCardView alloc] init];
  [card setTranslatesAutoresizingMaskIntoConstraints:NO];
  return card;
}

+ (NSView *)separator {
  NSBox *line = [[NSBox alloc] init];
  [line setBoxType:NSBoxSeparator];
  [line setTranslatesAutoresizingMaskIntoConstraints:NO];
  return line;
}

+ (NSTextField *)sectionHeading:(NSString *)text {
  return [self labelWithText:text size:11 color:[MWMTheme textTertiary] weight:NSFontWeightSemibold];
}

+ (NSScrollView *)scrollViewWithContent:(NSView *)content {
  return [self scrollViewWithContent:content trailingRoom:0];
}

+ (NSScrollView *)scrollViewWithContent:(NSView *)content trailingRoom:(CGFloat)room {
  ConfigurationFlippedView *document = [[ConfigurationFlippedView alloc] init];
  [document setTranslatesAutoresizingMaskIntoConstraints:NO];
  [content setTranslatesAutoresizingMaskIntoConstraints:NO];
  [document addSubview:content];
  NSScrollView *scroll = [[NSScrollView alloc] init];
  [scroll setTranslatesAutoresizingMaskIntoConstraints:NO];
  [scroll setHasVerticalScroller:YES];
  [scroll setAutohidesScrollers:YES];
  [scroll setDrawsBackground:NO];
  NSClipView *clip = [[NSClipView alloc] init];
  [clip setDrawsBackground:NO];
  [scroll setContentView:clip];
  [scroll setDocumentView:document];
  [self pinView:content toEdgesOf:document insets:NSEdgeInsetsMake(0, 0, 0, room)];
  [NSLayoutConstraint activateConstraints:@[
    [document.topAnchor constraintEqualToAnchor:clip.topAnchor], [document.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
    [document.trailingAnchor constraintEqualToAnchor:clip.trailingAnchor],
  ]];
  return scroll;
}

+ (NSView *)iconTileWithSymbol:(NSString *)symbolName color:(NSColor *)color size:(CGFloat)size {
  NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil]];
  [icon setContentTintColor:color];
  [icon setSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:size * 0.44 weight:NSFontWeightRegular]];
  [icon setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *tile = [self card];
  [tile addSubview:icon];
  [NSLayoutConstraint activateConstraints:@[
    [tile.widthAnchor constraintEqualToConstant:size], [tile.heightAnchor constraintEqualToConstant:size],
    [icon.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor], [icon.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
  ]];
  return tile;
}

+ (NSButton *)secondaryButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
  NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
  [button setBezelStyle:NSBezelStyleRounded];
  return button;
}

+ (NSButton *)secondaryButtonWithTitle:(NSString *)title symbol:(NSString *)symbolName target:(id)target action:(SEL)action {
  NSButton *button = [self secondaryButtonWithTitle:title target:target action:action];
  [button setImage:[NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil]];
  [button setImagePosition:NSImageLeft];
  return button;
}

+ (NSButton *)accentButtonWithTitle:(NSString *)title symbol:(NSString *)symbolName target:(id)target action:(SEL)action {
  MWMAccentButton *button = [[MWMAccentButton alloc] init];
  [button setTarget:target];
  [button setAction:action];
  [button setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName: [MWMTheme fontSmall], NSForegroundColorAttributeName: [NSColor whiteColor]}]];
  if (symbolName != nil) {
    // Drawn at the text's size and weight, so the icon and the label sit on the same line.
    NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightMedium scale:NSImageSymbolScaleSmall];
    NSImage *image = [[NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil] imageWithSymbolConfiguration:configuration];
    [image setTemplate:YES];
    [button setImage:image];
    [button setImageScaling:NSImageScaleNone];
  }
  return button;
}

+ (NSButton *)primaryButtonWithTitle:(NSString *)title symbol:(NSString *)symbolName target:(id)target action:(SEL)action {
  NSButton *button = [self primaryButtonWithTitle:title target:target action:action];
  [button setImage:[NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil]];
  [button setImagePosition:NSImageLeft];
  return button;
}

+ (NSButton *)primaryButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
  NSButton *button = [self secondaryButtonWithTitle:title target:target action:action];
  [button setKeyEquivalent:@"\r"];
  return button;
}

+ (NSButton *)dangerButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
  NSButton *button = [self accentButtonWithTitle:title symbol:nil target:target action:action];
  [(MWMAccentButton *)button setFill:[MWMTheme danger]];
  return button;
}

+ (NSStackView *)fieldWithCaption:(NSString *)caption control:(NSView *)control {
  NSTextField *label = [self labelWithText:caption font:[MWMTheme fontCaption] color:[MWMTheme textSecondary]];
  return [self columnWithViews:@[label, control] spacing:3 insets:NSEdgeInsetsZero];
}

+ (NSStackView *)nameBlockWithField:(MWMNameField *)field width:(CGFloat)width {
  NSTextField *caption = [self captionLabel:@"Name"];
  NSStackView *block = [self columnWithViews:@[caption, field] spacing:MWMSpacingXS insets:NSEdgeInsetsZero];
  [[field.widthAnchor constraintEqualToConstant:width] setActive:width > 0];
  [[field.widthAnchor constraintEqualToAnchor:block.widthAnchor] setActive:width <= 0];
  return block;
}

+ (NSStackView *)columnWithViews:(NSArray<NSView *> *)views spacing:(CGFloat)spacing insets:(NSEdgeInsets)insets {
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:spacing];
  [stack setEdgeInsets:insets];
  for (NSView *view in views) [[view.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-(insets.left + insets.right)] setActive:YES];
  return stack;
}

+ (NSStackView *)equalRowWithViews:(NSArray<NSView *> *)views spacing:(CGFloat)spacing {
  NSStackView *row = [NSStackView stackViewWithViews:views];
  [row setDistribution:NSStackViewDistributionFillEqually];
  [row setSpacing:spacing];
  [row setAlignment:NSLayoutAttributeTop];
  return row;
}

+ (NSView *)groupBoxWithTitle:(NSString *)title views:(NSArray<NSView *> *)views accessory:(NSView *)accessory {
  NSTextField *titleLabel = [self labelWithText:title size:12 color:[MWMTheme textPrimary] weight:NSFontWeightMedium];
  NSView *header = accessory != nil ? [NSStackView stackViewWithViews:@[titleLabel, [self spacer], accessory]] : titleLabel;
  NSStackView *content = [self columnWithViews:[@[header] arrayByAddingObjectsFromArray:views] spacing:MWMSpacingM insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  NSView *box = [self card];
  [box addSubview:content];
  [self pinView:content toEdgesOf:box insets:NSEdgeInsetsZero];
  return box;
}

+ (void)pinView:(NSView *)view toEdgesOf:(NSView *)container insets:(NSEdgeInsets)insets {
  [view setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[
    [view.topAnchor constraintEqualToAnchor:container.topAnchor constant:insets.top], [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-insets.bottom],
    [view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:insets.left], [view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-insets.right],
  ]];
}

+ (NSView *)selectableRowWithContent:(NSView *)content insets:(NSEdgeInsets)insets selected:(BOOL)selected onClick:(void (^)(void))onClick {
  return [self selectableRowWithContent:content insets:insets selected:selected selectedColor:nil onClick:onClick];
}

+ (NSView *)selectableRowWithContent:(NSView *)content insets:(NSEdgeInsets)insets selected:(BOOL)selected selectedColor:(NSColor *)selectedColor onClick:(void (^)(void))onClick {
  NSView *row = [[NSView alloc] init];
  [row setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationClickView *click = [[ConfigurationClickView alloc] init];
  click.cornerRadius = MWMRadiusM;
  click.selectedColor = selectedColor;
  click.selected = selected;
  click.onClick = onClick;
  [row addSubview:content];
  [row addSubview:click positioned:NSWindowAbove relativeTo:nil];
  [self pinView:content toEdgesOf:row insets:insets];
  [self pinView:click toEdgesOf:row insets:NSEdgeInsetsMake(0, 0, 0, 0)];
  return row;
}

+ (NSView *)countRowWithTitle:(NSString *)title count:(NSUInteger)count detail:(NSView *)detail detailSpacing:(CGFloat)spacing insets:(NSEdgeInsets)insets
                   boldTitle:(BOOL)boldTitle selected:(BOOL)selected onClick:(void (^)(void))onClick {
  return [self countRowWithTitle:title count:count detail:detail detailSpacing:spacing insets:insets boldTitle:boldTitle selected:selected selectedColor:nil onClick:onClick];
}

+ (NSView *)countRowWithTitle:(NSString *)title count:(NSUInteger)count detail:(NSView *)detail detailSpacing:(CGFloat)spacing insets:(NSEdgeInsets)insets
                   boldTitle:(BOOL)boldTitle selected:(BOOL)selected selectedColor:(NSColor *)selectedColor onClick:(void (^)(void))onClick {
  NSTextField *name = [self labelWithText:title size:13 color:selected ? (selectedColor ?: [MWMTheme accent]) : [MWMTheme textPrimary] weight:(boldTitle || selected) ? NSFontWeightMedium : NSFontWeightRegular];
  NSTextField *number = [self labelWithText:[NSString stringWithFormat:@"%lu", (unsigned long)count] size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  NSStackView *line = [NSStackView stackViewWithViews:@[name, [self spacer], number]];
  [line setAlignment:NSLayoutAttributeFirstBaseline];
  NSMutableArray *views = [NSMutableArray arrayWithObject:line];
  if (detail != nil) [views addObject:detail];
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:spacing];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[line.widthAnchor constraintEqualToAnchor:stack.widthAnchor] setActive:YES];
  return [self selectableRowWithContent:stack insets:insets selected:selected selectedColor:selectedColor onClick:onClick];
}

+ (NSView *)titleWithSubtitle:(NSString *)title subtitle:(NSString *)subtitle {
  NSMutableArray *lines = [NSMutableArray arrayWithObject:[self wrappingLabelWithText:title size:13 color:[MWMTheme textPrimary] weight:NSFontWeightRegular]];
  if ([subtitle length] > 0) [lines addObject:[self wrappingLabelWithText:subtitle size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]];
  NSStackView *stack = [NSStackView stackViewWithViews:lines];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:1];
  return stack;
}

+ (NSView *)controlRowWithTitle:(NSString *)title subtitle:(NSString *)subtitle control:(NSView *)control {
  NSStackView *row = [NSStackView stackViewWithViews:@[[self titleWithSubtitle:title subtitle:subtitle], [self spacer], control]];
  [row setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
  [row setAlignment:NSLayoutAttributeCenterY];
  [row setSpacing:MWMSpacingM];
  [control setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  return row;
}

+ (NSView *)listCardWithRows:(NSArray<NSView *> *)rows {
  NSMutableArray *views = [NSMutableArray array];
  for (NSView *row in rows) {
    if ([views count] > 0) [views addObject:[self separator]];
    [views addObject:row];
  }
  NSStackView *stack = [self columnWithViews:views spacing:MWMSpacingM insets:NSEdgeInsetsMake(MWMSpacingM, MWMSpacingL, MWMSpacingM, MWMSpacingL)];
  NSView *card = [self card];
  [card addSubview:stack];
  [self pinView:stack toEdgesOf:card insets:NSEdgeInsetsZero];
  return card;
}

+ (NSView *)settingsBlockWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle rows:(NSArray<NSView *> *)rows titleColumnWidth:(CGFloat)width {
  NSView *block = [self card];
  NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
  [icon setContentTintColor:[MWMTheme textSecondary]];
  [icon setSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightRegular]];
  [icon setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSView *heading = [self titleWithSubtitle:title subtitle:subtitle];
  [(NSTextField *)[[(NSStackView *)heading arrangedSubviews] firstObject] setFont:[MWMTheme fontBodyStrong]];
  NSStackView *left = [NSStackView stackViewWithViews:@[icon, heading]];
  [left setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
  [left setAlignment:NSLayoutAttributeTop];
  [left setSpacing:10];
  [left setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSStackView *right = [NSStackView stackViewWithViews:rows];
  [right setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [right setAlignment:NSLayoutAttributeLeading];
  [right setSpacing:10];
  [right setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *row in rows) [[row.widthAnchor constraintEqualToAnchor:right.widthAnchor] setActive:YES];

  [block addSubview:left];
  [block addSubview:right];
  [NSLayoutConstraint activateConstraints:@[
    [left.leadingAnchor constraintEqualToAnchor:block.leadingAnchor constant:14],
    [left.topAnchor constraintEqualToAnchor:block.topAnchor constant:14],
    [left.widthAnchor constraintEqualToConstant:width],
    [right.leadingAnchor constraintEqualToAnchor:left.trailingAnchor constant:MWMSpacingL],
    [right.trailingAnchor constraintEqualToAnchor:block.trailingAnchor constant:-14],
    [right.topAnchor constraintEqualToAnchor:block.topAnchor constant:14],
    [right.bottomAnchor constraintEqualToAnchor:block.bottomAnchor constant:-14],
    [block.bottomAnchor constraintGreaterThanOrEqualToAnchor:left.bottomAnchor constant:14],
  ]];
  return block;
}

+ (NSView *)spacer {
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  return spacer;
}

@end
