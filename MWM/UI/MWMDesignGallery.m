//
//  MWMDesignGallery.m
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

#import "MWMDesignGallery.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "MWMComponents.h"
#import "MWMTheme.h"
#import "MWMShortcutIndex.h"

// A rectangle whose colors are resolved when it is drawn, so it follows light and dark.
@interface MWMSwatchView : NSView
@property (strong, nullable) NSColor *fill;
@property (strong, nullable) NSColor *outline;
@property (assign) CGFloat outlineWidth;
@property (assign) CGFloat radius;
@end

@implementation MWMSwatchView
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) { [self setWantsLayer:YES]; [self setTranslatesAutoresizingMaskIntoConstraints:NO]; }
  return self;
}
- (void)update {
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self layer] setCornerRadius:self.radius];
    [[self layer] setBackgroundColor:self.fill != nil ? [self.fill CGColor] : [[NSColor clearColor] CGColor]];
    [[self layer] setBorderWidth:self.outline != nil ? self.outlineWidth : 0];
    [[self layer] setBorderColor:[self.outline CGColor]];
  }];
}
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self update]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self update]; }
@end

static MWMSwatchView *Swatch(NSColor *fill, NSColor *outline, CGFloat outlineWidth, CGFloat radius, CGFloat width, CGFloat height) {
  MWMSwatchView *view = [[MWMSwatchView alloc] init];
  view.fill = fill;
  view.outline = outline;
  view.outlineWidth = outlineWidth;
  view.radius = radius;
  [NSLayoutConstraint activateConstraints:@[[view.widthAnchor constraintEqualToConstant:width], [view.heightAnchor constraintEqualToConstant:height]]];
  return view;
}

static NSStackView *VerticalStack(NSArray<NSView *> *views, CGFloat spacing) {
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:spacing];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  return stack;
}

static NSStackView *HorizontalStack(NSArray<NSView *> *views, CGFloat spacing) {
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  [stack setSpacing:spacing];
  [stack setAlignment:NSLayoutAttributeCenterY];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  return stack;
}

@implementation MWMDesignGallery

+ (NSView *)swatch:(NSColor *)color name:(NSString *)name {
  NSView *chip = Swatch(color, [MWMTheme stroke], 1, MWMRadiusS, 56, 36);
  [chip setIdentifier:name];
  NSTextField *label = [MWMComponents captionLabel:name];
  NSStackView *item = VerticalStack(@[chip, label], 4);
  [item setAlignment:NSLayoutAttributeCenterX];
  return item;
}

+ (NSView *)section:(NSString *)title content:(NSView *)content {
  NSTextField *heading = [MWMComponents labelWithText:title font:[MWMTheme fontCaptionStrong] color:[MWMTheme textTertiary]];
  heading.stringValue = [title uppercaseString];
  NSView *card = [MWMComponents card];
  [content setTranslatesAutoresizingMaskIntoConstraints:NO];
  [card addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:MWMSpacingL], [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-MWMSpacingL],
    [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:MWMSpacingL], [content.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-MWMSpacingL],
  ]];
  NSStackView *section = VerticalStack(@[heading, card], MWMSpacingS);
  [[card.widthAnchor constraintEqualToAnchor:section.widthAnchor] setActive:YES];
  return section;
}

+ (NSView *)colorsSection {
  NSArray *surfaces = @[@[@"surface", [MWMTheme surface]], @[@"surfaceStrong", [MWMTheme surfaceStrong]], @[@"stroke", [MWMTheme stroke]],
                        @[@"textPrimary", [MWMTheme textPrimary]], @[@"textSecondary", [MWMTheme textSecondary]], @[@"textTertiary", [MWMTheme textTertiary]]];
  NSArray *meaning = @[@[@"accent", [MWMTheme accent]], @[@"success", [MWMTheme success]], @[@"feature", [MWMTheme feature]],
                       @[@"warning", [MWMTheme warning]], @[@"reserved", [MWMTheme reserved]], @[@"danger", [MWMTheme danger]]];
  NSMutableArray *rows = [NSMutableArray array];
  for (NSArray *group in @[surfaces, meaning]) {
    NSMutableArray *swatches = [NSMutableArray array];
    for (NSArray *entry in group) [swatches addObject:[self swatch:entry[1] name:entry[0]]];
    [rows addObject:HorizontalStack(swatches, MWMSpacingL)];
  }
  return VerticalStack(rows, MWMSpacingL);
}

+ (NSView *)typeSection {
  NSArray *entries = @[@[@"Title 17", [MWMTheme fontTitle], @"Editing Shortcut"], @[@"Heading 15", [MWMTheme fontHeading], @"Keyboard"],
                       @[@"Body strong 13", [MWMTheme fontBodyStrong], @"Move to middlequarter"], @[@"Body 13", [MWMTheme fontBody], @"Every shortcut, by the keys that trigger it."],
                       @[@"Small 12", [MWMTheme fontSmall], @"on Samsung"], @[@"Caption strong 11", [MWMTheme fontCaptionStrong], @"● Unsaved changes"],
                       @[@"Caption 11", [MWMTheme fontCaption], @"Dashed keys are modifiers."], @[@"Mono 12", [MWMTheme fontMono], @"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY"]];
  NSMutableArray *rows = [NSMutableArray array];
  for (NSArray *entry in entries) {
    NSTextField *name = [MWMComponents captionLabel:entry[0]];
    [[name.widthAnchor constraintEqualToConstant:120] setActive:YES];
    NSTextField *sample = [MWMComponents labelWithText:entry[2] font:entry[1] color:[MWMTheme textPrimary]];
    [rows addObject:HorizontalStack(@[name, sample], MWMSpacingM)];
  }
  return VerticalStack(rows, MWMSpacingS);
}

+ (NSView *)spacingSection {
  NSArray *spaces = @[@[@"XS 4", @(MWMSpacingXS)], @[@"S 8", @(MWMSpacingS)], @[@"M 12", @(MWMSpacingM)], @[@"L 16", @(MWMSpacingL)], @[@"XL 20", @(MWMSpacingXL)]];
  NSMutableArray *bars = [NSMutableArray array];
  for (NSArray *entry in spaces) {
    NSView *bar = Swatch([MWMTheme tint:[MWMTheme accent] opacity:MWMOpacityStrong], nil, 0, 0, [entry[1] doubleValue] * 4, 16);
    NSStackView *item = VerticalStack(@[bar, [MWMComponents captionLabel:entry[0]]], 4);
    [bars addObject:item];
  }
  NSArray *radii = @[@[@"S 6", @(MWMRadiusS)], @[@"M 10", @(MWMRadiusM)], @[@"L 12", @(MWMRadiusL)]];
  NSMutableArray *boxes = [NSMutableArray array];
  for (NSArray *entry in radii) {
    NSView *box = Swatch(nil, [MWMTheme accent], 1.5, [entry[1] doubleValue], 48, 36);
    [boxes addObject:VerticalStack(@[box, [MWMComponents captionLabel:entry[0]]], 4)];
  }
  NSStackView *barRow = HorizontalStack(bars, MWMSpacingXL);
  [barRow setAlignment:NSLayoutAttributeBottom];
  NSStackView *boxRow = HorizontalStack(boxes, MWMSpacingXL);
  [boxRow setAlignment:NSLayoutAttributeTop];
  return VerticalStack(@[barRow, boxRow], MWMSpacingL);
}

+ (NSView *)componentsSection {
  // Chips.
  NSStackView *chips = HorizontalStack(@[[MWMChipView chipWithText:@"No changes" color:nil], [MWMChipView chipWithText:@"● Unsaved changes" color:[MWMTheme warning]],
                                         [MWMChipView chipWithText:@"⚠ Same keys as \"Focus Finder\". Only one can work." color:[MWMTheme warning]]], MWMSpacingM);
  // Buttons.
  NSStackView *buttons = HorizontalStack(@[[MWMComponents secondaryButtonWithTitle:@"Cancel" target:nil action:nil], [MWMComponents primaryButtonWithTitle:@"Save" target:nil action:nil], [MWMComponents accentButtonWithTitle:@"Restore" symbol:@"play.fill" target:nil action:nil]], MWMSpacingS);
  // Icon tiles by what a shortcut does.
  NSArray *kinds = @[@(MWMShortcutKindMoveToSlot), @(MWMShortcutKindFocusApp), @(MWMShortcutKindFeature), @(MWMShortcutKindResizeNudge)];
  NSMutableArray *tiles = [NSMutableArray array];
  for (NSNumber *kind in kinds) {
    MWMShortcutKind k = (MWMShortcutKind)[kind integerValue];
    [tiles addObject:[MWMComponents iconTileWithSymbol:[ConfigurationKeyViews symbolForKind:k] color:[ConfigurationKeyViews colorForKind:k] size:34]];
  }
  NSStackView *tileRow = HorizontalStack(tiles, MWMSpacingM);
  // Keys.
  NSStackView *keys = HorizontalStack(@[[ConfigurationKeyViews pillWithText:@"hyper"], [ConfigurationKeyViews keyCapsForModifiers:@[@"ctrl", @"alt", @"cmd"] keyName:@"pad8" size:26],
                                        [ConfigurationKeyViews pillWithText:@"hyper" tint:[MWMTheme warning]], [ConfigurationKeyViews keyCapsForModifiers:@[@"ctrl", @"alt"] keyName:@"j" size:26 tint:[MWMTheme warning]]], MWMSpacingM);
  // A slot preview and a text field.
  ConfigurationSlotThumbnail *thumb = [[ConfigurationSlotThumbnail alloc] init];
  thumb.rect = CGRectMake(0.5, 0, 0.5, 1);
  thumb.valid = YES;
  [thumb setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[[thumb.widthAnchor constraintEqualToConstant:84], [thumb.heightAnchor constraintEqualToConstant:50]]];
  NSTextField *field = [NSTextField textFieldWithString:@"+10%"];
  [field setFont:[MWMTheme fontMono]];
  [[field.widthAnchor constraintEqualToConstant:100] setActive:YES];
  NSStackView *misc = HorizontalStack(@[thumb, field], MWMSpacingL);
  // A selectable row, selected and not.
  NSMutableArray *rowViews = [NSMutableArray array];
  for (NSNumber *selected in @[@NO, @YES]) {
    ConfigurationClickView *row = [[ConfigurationClickView alloc] init];
    row.cornerRadius = MWMRadiusM;
    row.selected = [selected boolValue];
    NSTextField *label = [MWMComponents labelWithText:[selected boolValue] ? @"hyper (selected)" : @"shyper" font:[MWMTheme fontBodyStrong] color:[selected boolValue] ? [MWMTheme accent] : [MWMTheme textPrimary]];
    [label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [row addSubview:label];
    [row setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
      [row.widthAnchor constraintEqualToConstant:180], [row.heightAnchor constraintEqualToConstant:36],
      [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:MWMSpacingM], [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    [rowViews addObject:row];
  }
  NSStackView *rows = HorizontalStack(rowViews, MWMSpacingM);
  // List rows with a count, and a settings block.
  NSMutableArray *countRows = [NSMutableArray array];
  for (NSNumber *selected in @[@NO, @YES]) {
    NSView *row = [MWMComponents countRowWithTitle:[selected boolValue] ? @"hyper" : @"shyper" count:[selected boolValue] ? 27 : 6
                                            detail:[ConfigurationKeyViews modifierCaps:@[@"ctrl", @"alt", @"cmd"] size:20] detailSpacing:6
                                            insets:NSEdgeInsetsMake(10, 12, 10, 12) boldTitle:YES selected:[selected boolValue] onClick:^{}];
    [[row.widthAnchor constraintEqualToConstant:188] setActive:YES];
    [countRows addObject:row];
  }
  NSStackView *counts = HorizontalStack(countRows, MWMSpacingM);
  NSSwitch *toggle = [[NSSwitch alloc] init];
  [toggle setControlSize:NSControlSizeSmall];
  [toggle setState:NSControlStateValueOn];
  NSView *settingsBlock = [MWMComponents settingsBlockWithSymbol:@"power" title:@"Startup" subtitle:@"Runs quietly in the menu bar" rows:@[[MWMComponents controlRowWithTitle:@"Launch MWM at login" subtitle:nil control:toggle]] titleColumnWidth:200];
  [[settingsBlock.widthAnchor constraintEqualToConstant:520] setActive:YES];
  // The top and bottom of a page opened from another.
  MWMSublevelHeader *header = [MWMSublevelHeader headerWithBackTitle:@"Keyboard" title:@"Editing Shortcut" target:nil action:nil];
  [[header.widthAnchor constraintEqualToConstant:520] setActive:YES];
  MWMSaveBar *saveBar = [MWMSaveBar barWithTarget:nil cancel:nil save:nil];
  [saveBar setDirty:YES canSave:YES];
  [[saveBar.widthAnchor constraintEqualToConstant:520] setActive:YES];
  return VerticalStack(@[chips, buttons, tileRow, keys, misc, rows, counts, settingsBlock, header, saveBar], MWMSpacingL);
}

+ (NSView *)galleryViewWithWidth:(CGFloat)width {
  NSTextField *title = [MWMComponents titleLabel:@"Design system"];
  NSTextField *subtitle = [MWMComponents labelWithText:@"Tokens and components of the configuration window." font:[MWMTheme fontBody] color:[MWMTheme textSecondary]];
  NSStackView *page = VerticalStack(@[title, subtitle, [self section:@"Colors" content:[self colorsSection]], [self section:@"Type" content:[self typeSection]],
                                      [self section:@"Spacing and radii" content:[self spacingSection]], [self section:@"Components" content:[self componentsSection]]], MWMSpacingL);
  [page setCustomSpacing:MWMSpacingXS afterView:title];
  [page setEdgeInsets:NSEdgeInsetsMake(MWMSpacingXL, MWMSpacingXL, MWMSpacingXL, MWMSpacingXL)];
  ConfigurationFlippedView *holder = [[ConfigurationFlippedView alloc] initWithFrame:NSMakeRect(0, 0, width, 100)];
  [holder addSubview:page];
  [NSLayoutConstraint activateConstraints:@[
    [page.topAnchor constraintEqualToAnchor:holder.topAnchor], [page.leadingAnchor constraintEqualToAnchor:holder.leadingAnchor],
    [page.widthAnchor constraintEqualToConstant:width],
  ]];
  for (NSView *view in [page arrangedSubviews]) {
    if ([view isKindOfClass:[NSStackView class]]) [[view.widthAnchor constraintEqualToAnchor:page.widthAnchor constant:-2 * MWMSpacingXL] setActive:YES];
  }
  [holder layoutSubtreeIfNeeded];
  [holder setFrameSize:NSMakeSize(width, [page fittingSize].height)];
  return holder;
}

+ (void)showWindow {
  static NSWindow *window;
  if (window == nil) {
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 760, 720) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    [window setTitle:@"MWM Design System"];
    [window setReleasedWhenClosed:NO];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:[[window contentView] bounds]];
    [scroll setHasVerticalScroller:YES];
    [scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [scroll setDocumentView:[self galleryViewWithWidth:760]];
    [window setContentView:scroll];
    [window center];
  }
  [NSApp activateIgnoringOtherApps:YES];
  [window makeKeyAndOrderFront:nil];
}

@end
