//
//  MWMAboutWindow.m
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

#import "MWMAboutWindow.h"
#import "MWMComponents.h"
#import "MWMTheme.h"

static const CGFloat kAboutWidth = 560;

@interface MWMAboutLinks : NSObject
+ (instancetype)shared;
- (void)openLink:(NSButton *)button;
@end

@implementation MWMAboutLinks
+ (instancetype)shared {
  static MWMAboutLinks *links;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ links = [[MWMAboutLinks alloc] init]; });
  return links;
}
- (void)openLink:(NSButton *)button {
  NSURL *url = [NSURL URLWithString:button.identifier];
  if (url != nil) [[NSWorkspace sharedWorkspace] openURL:url];
}
@end

@implementation MWMAboutWindow

+ (NSButton *)linkWithTitle:(NSString *)title url:(NSString *)url {
  NSButton *button = [NSButton buttonWithTitle:title target:[MWMAboutLinks shared] action:@selector(openLink:)];
  [button setBordered:NO];
  [button setContentTintColor:[MWMTheme accent]];
  [button setFont:[MWMTheme fontBody]];
  [button setIdentifier:url];
  [button setToolTip:url];
  return button;
}

+ (NSTextField *)centered:(NSTextField *)label {
  [label setAlignment:NSTextAlignmentCenter];
  [label setLineBreakMode:NSLineBreakByWordWrapping];
  [label setPreferredMaxLayoutWidth:kAboutWidth - 2 * MWMSpacingXL * 2];
  return label;
}

+ (NSView *)contentView {
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *version = [NSString stringWithFormat:@"Version %@ (%@)", [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0",
                       [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1"];
  NSString *copyright = [bundle objectForInfoDictionaryKey:@"NSHumanReadableCopyright"] ?: @"";

  NSImageView *icon = [NSImageView imageViewWithImage:[bundle imageForResource:@"icon"] ?: [NSApp applicationIconImage]];
  [icon setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[[icon.widthAnchor constraintEqualToConstant:112], [icon.heightAnchor constraintEqualToConstant:112]]];

  NSTextField *name = [self centered:[MWMComponents labelWithText:@"MWM" font:[NSFont systemFontOfSize:26 weight:NSFontWeightSemibold] color:[MWMTheme textPrimary]]];
  NSTextField *versionLabel = [self centered:[MWMComponents labelWithText:version font:[MWMTheme fontBody] color:[MWMTheme textSecondary]]];
  NSTextField *tagline = [self centered:[MWMComponents labelWithText:@"Mac Window Manager" font:[MWMTheme fontHeading] color:[MWMTheme textPrimary]]];
  NSTextField *summary = [self centered:[MWMComponents labelWithText:@"Keyboard-driven window management for macOS." font:[MWMTheme fontBody] color:[MWMTheme textSecondary]]];

  NSTextField *based = [self centered:[MWMComponents wrappingLabelWithText:@"MWM is a fork of Slate, the window manager created by Jigish Patel." size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]];
  NSStackView *links = [NSStackView stackViewWithViews:@[[self linkWithTitle:@"Slate on GitHub" url:@"https://github.com/jigish/slate"],
                                                        [self linkWithTitle:@"MWM on GitHub" url:@"https://github.com/bbarbosa85/mwm"],
                                                        [self linkWithTitle:@"Contributors" url:@"https://github.com/bbarbosa85/mwm/graphs/contributors"]]];
  [links setSpacing:MWMSpacingXL];
  NSTextField *license = [self centered:[MWMComponents wrappingLabelWithText:copyright size:11 color:[MWMTheme textTertiary] weight:NSFontWeightRegular]];

  NSView *line = [MWMComponents separator];
  NSStackView *stack = [NSStackView stackViewWithViews:@[icon, name, versionLabel, tagline, summary, line, based, links, license]];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeCenterX];
  [stack setSpacing:MWMSpacingM];
  [stack setCustomSpacing:2 afterView:name];
  [stack setCustomSpacing:MWMSpacingL afterView:versionLabel];
  [stack setCustomSpacing:2 afterView:tagline];
  [stack setCustomSpacing:MWMSpacingL afterView:summary];
  [stack setCustomSpacing:MWMSpacingL afterView:line];
  [stack setCustomSpacing:MWMSpacingXL afterView:links];
  [stack setEdgeInsets:NSEdgeInsetsMake(MWMSpacingXL * 2, MWMSpacingXL * 2, MWMSpacingXL + MWMSpacingL, MWMSpacingXL * 2)];
  [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[line.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-4 * MWMSpacingXL] setActive:YES];

  NSView *holder = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kAboutWidth, 100)];
  [holder addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:holder.topAnchor], [stack.leadingAnchor constraintEqualToAnchor:holder.leadingAnchor],
    [stack.trailingAnchor constraintEqualToAnchor:holder.trailingAnchor], [stack.bottomAnchor constraintEqualToAnchor:holder.bottomAnchor],
    [holder.widthAnchor constraintEqualToConstant:kAboutWidth],
  ]];
  [holder layoutSubtreeIfNeeded];
  [holder setFrameSize:NSMakeSize(kAboutWidth, [stack fittingSize].height)];
  return holder;
}

+ (void)showWindow {
  static NSWindow *window;
  if (window == nil) {
    NSView *content = [self contentView];
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, NSWidth(content.frame), NSHeight(content.frame)) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    [window setTitle:@"About MWM"];
    [window setReleasedWhenClosed:NO];
    [window setTitlebarAppearsTransparent:YES];
    [window setContentView:content];
    [window center];
  }
  [NSApp activateIgnoringOtherApps:YES];
  [window makeKeyAndOrderFront:nil];
}

@end
