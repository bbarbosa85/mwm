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

@implementation MWMComponents

+ (NSTextField *)labelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
  NSTextField *label = [NSTextField labelWithString:text ?: @""];
  [label setFont:font];
  [label setTextColor:color];
  [label setLineBreakMode:NSLineBreakByTruncatingTail];
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

+ (NSButton *)primaryButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
  NSButton *button = [self secondaryButtonWithTitle:title target:target action:action];
  [button setKeyEquivalent:@"\r"];
  return button;
}

+ (NSView *)spacer {
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  return spacer;
}

@end
