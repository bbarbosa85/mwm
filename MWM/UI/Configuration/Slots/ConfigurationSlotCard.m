//
//  ConfigurationSlotCard.m
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

#import "ConfigurationSlotCard.h"
#import "MWMTheme.h"
#import "MWMComponents.h"

@interface ConfigurationSlotCard ()
@property (strong) NSView *badgeView;
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
    NSView *gap = [MWMComponents spacer];
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
