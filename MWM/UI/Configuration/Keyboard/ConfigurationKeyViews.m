//
//  ConfigurationKeyViews.m
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

#import "ConfigurationKeyViews.h"
#import "MWMTheme.h"
#import "MWMShortcut.h"

// A key cap: a rounded outline whose colors follow light and dark mode.
@interface ConfigurationCapView : NSView
@property (strong, nullable) NSColor *tint;
@end

@implementation ConfigurationCapView
- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self layer] setBorderColor:[(self.tint ?: [MWMTheme textTertiary]) CGColor]];
    [[self layer] setBackgroundColor:[[(self.tint ?: [MWMTheme textPrimary]) colorWithAlphaComponent:0.08] CGColor]];
  }];
}
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self viewDidChangeEffectiveAppearance]; }
@end

// A rounded tint behind a group's name.
@interface ConfigurationPillView : NSView
@property (strong, nullable) NSColor *tint;
@end

@implementation ConfigurationPillView
- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self layer] setBackgroundColor:[[(self.tint ?: [MWMTheme accent]) colorWithAlphaComponent:0.16] CGColor]];
  }];
}
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self viewDidChangeEffectiveAppearance]; }
@end

@implementation ConfigurationKeyViews

+ (NSView *)capWithText:(NSString *)text size:(CGFloat)size tint:(NSColor *)tint {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[NSFont systemFontOfSize:size * 0.5 weight:NSFontWeightMedium]];
  if (tint != nil) [label setTextColor:tint];
  [label setAlignment:NSTextAlignmentCenter];
  [label setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationCapView *cap = [[ConfigurationCapView alloc] init];
  cap.tint = tint;
  [cap setWantsLayer:YES];
  [[cap layer] setCornerRadius:size * 0.25];
  [[cap layer] setBorderWidth:0.5];
  [cap setTranslatesAutoresizingMaskIntoConstraints:NO];
  [cap addSubview:label];
  [NSLayoutConstraint activateConstraints:@[
    [label.centerYAnchor constraintEqualToAnchor:cap.centerYAnchor],
    [label.leadingAnchor constraintEqualToAnchor:cap.leadingAnchor constant:size * 0.22], [label.trailingAnchor constraintEqualToAnchor:cap.trailingAnchor constant:-size * 0.22],
    [cap.heightAnchor constraintEqualToConstant:size], [cap.widthAnchor constraintGreaterThanOrEqualToConstant:size],
  ]];
  return cap;
}

+ (NSView *)capWithText:(NSString *)text size:(CGFloat)size {
  return [self capWithText:text size:size tint:nil];
}

+ (NSView *)modifierCaps:(NSArray<NSString *> *)modifierNames size:(CGFloat)size {
  NSMutableArray *caps = [NSMutableArray array];
  for (NSString *name in modifierNames) [caps addObject:[self capWithText:[MWMShortcut symbolForModifierName:name] size:size]];
  NSStackView *stack = [NSStackView stackViewWithViews:caps];
  [stack setSpacing:3];
  return stack;
}

+ (NSView *)keyCapsForModifiers:(NSArray<NSString *> *)modifierNames keyName:(NSString *)keyName size:(CGFloat)size {
  return [self keyCapsForModifiers:modifierNames keyName:keyName size:size tint:nil];
}

+ (NSView *)keyCapsForModifiers:(NSArray<NSString *> *)modifierNames keyName:(NSString *)keyName size:(CGFloat)size tint:(NSColor *)tint {
  NSMutableArray *caps = [NSMutableArray array];
  for (NSString *name in modifierNames) [caps addObject:[self capWithText:[MWMShortcut symbolForModifierName:name] size:size tint:tint]];
  [caps addObject:[self capWithText:[MWMShortcut displayForKeyName:keyName] size:size tint:tint]];
  NSStackView *stack = [NSStackView stackViewWithViews:caps];
  [stack setSpacing:3];
  return stack;
}

+ (NSView *)pillWithText:(NSString *)text {
  return [self pillWithText:text tint:nil];
}

+ (NSView *)pillWithText:(NSString *)text tint:(NSColor *)tint {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[MWMTheme fontCaptionStrong]];
  [label setTextColor:tint ?: [MWMTheme accent]];
  [label setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationPillView *pill = [[ConfigurationPillView alloc] init];
  pill.tint = tint;
  [pill setWantsLayer:YES];
  [[pill layer] setCornerRadius:9];
  [pill setTranslatesAutoresizingMaskIntoConstraints:NO];
  [pill addSubview:label];
  [NSLayoutConstraint activateConstraints:@[
    [label.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:8], [label.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-8],
    [label.topAnchor constraintEqualToAnchor:pill.topAnchor constant:2], [label.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-2],
  ]];
  return pill;
}

+ (NSView *)shortcutViewForInfo:(MWMShortcutInfo *)info size:(CGFloat)size {
  NSMutableArray *views = [NSMutableArray array];
  if (info.groupName != nil) [views addObject:[self pillWithText:info.groupName]];
  [views addObject:[self keyCapsForModifiers:info.groupName != nil ? @[] : info.modifierNames keyName:info.keyName size:size]];
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  [stack setSpacing:6];
  [stack setAlignment:NSLayoutAttributeCenterY];
  return stack;
}

+ (NSColor *)colorForKind:(MWMShortcutKind)kind {
  switch (kind) {
    case MWMShortcutKindMoveToSlot: return [MWMTheme accent];
    case MWMShortcutKindFocusApp:
    case MWMShortcutKindFocusWindow:
    case MWMShortcutKindResizeNudge: return [MWMTheme success];
    case MWMShortcutKindFeature:
    case MWMShortcutKindOther: return [MWMTheme feature];
  }
}

+ (NSString *)symbolForKind:(MWMShortcutKind)kind {
  switch (kind) {
    case MWMShortcutKindMoveToSlot: return @"rectangle.split.3x1";
    case MWMShortcutKindFocusApp: return @"app.badge";
    case MWMShortcutKindFocusWindow: return @"eye";
    case MWMShortcutKindResizeNudge: return @"arrow.up.left.and.arrow.down.right";
    case MWMShortcutKindFeature: return @"sparkles";
    case MWMShortcutKindOther: return @"chevron.left.forwardslash.chevron.right";
  }
}

@end
