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
  bar->_cancelButton = [MWMComponents secondaryButtonWithTitle:@"Cancel" target:target action:cancel];
  bar->_saveButton = [MWMComponents primaryButtonWithTitle:@"Save" target:target action:save];
  NSStackView *stack = [NSStackView stackViewWithViews:@[bar->_chip, [MWMComponents spacer], bar->_cancelButton, bar->_saveButton]];
  [stack setSpacing:MWMSpacingS];
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

+ (NSTextField *)bodyLabel:(NSString *)text { return [self labelWithText:text font:[MWMTheme fontBody] color:[MWMTheme textPrimary]]; }
+ (NSTextField *)secondaryLabel:(NSString *)text { return [self labelWithText:text font:[MWMTheme fontSmall] color:[MWMTheme textSecondary]]; }
+ (NSTextField *)captionLabel:(NSString *)text { return [self labelWithText:text font:[MWMTheme fontCaption] color:[MWMTheme textTertiary]]; }
+ (NSTextField *)titleLabel:(NSString *)text { return [self labelWithText:text font:[MWMTheme fontTitle] color:[MWMTheme textPrimary]]; }

+ (NSView *)card {
  NSView *card = [[ConfigurationBlockView alloc] init];
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
  [self pinView:content toEdgesOf:document insets:NSEdgeInsetsMake(0, 0, 0, 0)];
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

+ (NSButton *)primaryButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
  NSButton *button = [self secondaryButtonWithTitle:title target:target action:action];
  [button setKeyEquivalent:@"\r"];
  return button;
}

+ (void)pinView:(NSView *)view toEdgesOf:(NSView *)container insets:(NSEdgeInsets)insets {
  [view setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[
    [view.topAnchor constraintEqualToAnchor:container.topAnchor constant:insets.top], [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-insets.bottom],
    [view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:insets.left], [view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-insets.right],
  ]];
}

+ (NSView *)selectableRowWithContent:(NSView *)content insets:(NSEdgeInsets)insets selected:(BOOL)selected onClick:(void (^)(void))onClick {
  NSView *row = [[NSView alloc] init];
  [row setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationClickView *click = [[ConfigurationClickView alloc] init];
  click.cornerRadius = MWMRadiusM;
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
  NSTextField *name = [self labelWithText:title size:13 color:selected ? [MWMTheme accent] : [MWMTheme textPrimary] weight:(boldTitle || selected) ? NSFontWeightMedium : NSFontWeightRegular];
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
  return [self selectableRowWithContent:stack insets:insets selected:selected onClick:onClick];
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
