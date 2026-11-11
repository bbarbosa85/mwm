//
//  ConfigurationStatusBar.m
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

#import "ConfigurationStatusBar.h"

static const CGFloat kBarHeight = 44;

@interface ConfigurationStatusBar ()
@property (strong) NSImageView *savedIcon;
@property (strong) NSTextField *savedLabel;
@property (strong, readwrite) NSButton *statusButton;
@end

@implementation ConfigurationStatusBar

+ (NSImage *)symbol:(NSString *)name color:(NSColor *)color {
  NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
  return [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithHierarchicalColor:color]];
}

- (NSTextField *)label {
  NSTextField *label = [NSTextField labelWithString:@""];
  [label setTranslatesAutoresizingMaskIntoConstraints:NO];
  [label setLineBreakMode:NSLineBreakByTruncatingMiddle];
  return label;
}

- (instancetype)initWithTarget:(id)target path:(NSString *)path {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

    NSBox *separator = [[NSBox alloc] init];
    [separator setBoxType:NSBoxSeparator];
    [separator setTranslatesAutoresizingMaskIntoConstraints:NO];

    self.savedIcon = [[NSImageView alloc] init];
    [self.savedIcon setTranslatesAutoresizingMaskIntoConstraints:NO];
    self.savedLabel = [self label];
    NSTextField *pathLabel = [self label];
    [pathLabel setStringValue:[path stringByAbbreviatingWithTildeInPath]];
    [pathLabel setTextColor:[NSColor secondaryLabelColor]];

    self.statusButton = [NSButton buttonWithTitle:@"" target:target action:@selector(showIssues:)];
    [self.statusButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.statusButton setBordered:NO];
    [self.statusButton setImagePosition:NSImageLeading];
    [self.statusButton setImageHugsTitle:YES];
    [[self.statusButton cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.statusButton setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSButton *apply = [NSButton buttonWithTitle:@"Apply" target:target action:@selector(apply:)];
    [apply setTranslatesAutoresizingMaskIntoConstraints:NO];
    [apply setBezelColor:[NSColor controlAccentColor]];
    [apply setToolTip:@"Close and restart MWM to apply ~/.mwm.yml"];
    NSButton *close = [NSButton buttonWithTitle:@"Close" target:target action:@selector(closeWindow:)];
    [close setTranslatesAutoresizingMaskIntoConstraints:NO];
    [close setKeyEquivalent:@"w"];
    [close setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [close setToolTip:@"Close this window (⌘W)"];

    for (NSView *view in @[separator, self.savedIcon, self.savedLabel, pathLabel, self.statusButton, apply, close]) {
      [self addSubview:view];
    }

    NSLayoutConstraint *centered = [self.statusButton.centerXAnchor constraintEqualToAnchor:self.centerXAnchor];
    [centered setPriority:NSLayoutPriorityDefaultHigh];
    [NSLayoutConstraint activateConstraints:@[
      [self.heightAnchor constraintEqualToConstant:kBarHeight],
      [separator.topAnchor constraintEqualToAnchor:self.topAnchor],
      [separator.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [separator.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

      [self.savedIcon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
      [self.savedIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [self.savedLabel.leadingAnchor constraintEqualToAnchor:self.savedIcon.trailingAnchor constant:5],
      [self.savedLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [pathLabel.leadingAnchor constraintEqualToAnchor:self.savedLabel.trailingAnchor constant:10],
      [pathLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

      centered,
      [self.statusButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [self.statusButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:pathLabel.trailingAnchor constant:16],
      [self.statusButton.trailingAnchor constraintLessThanOrEqualToAnchor:apply.leadingAnchor constant:-16],

      [close.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
      [close.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [apply.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-8],
      [apply.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];
  }
  return self;
}

- (void)setSavedText:(NSString *)text symbol:(NSString *)symbol color:(NSColor *)color {
  [self.savedIcon setImage:[ConfigurationStatusBar symbol:symbol color:color]];
  [self.savedLabel setStringValue:text];
}

- (void)setStatusText:(NSString *)text symbol:(NSString *)symbol color:(NSColor *)color tip:(NSString *)tip {
  [self.statusButton setImage:[ConfigurationStatusBar symbol:symbol color:color]];
  [self.statusButton setTitle:text];
  [self.statusButton setToolTip:tip];
}

@end
