//
//  ConfigurationFormulaHelp.m
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

#import "ConfigurationFormulaHelp.h"
#import "MWMTheme.h"
#import "MWMComponents.h"

static const CGFloat kTextWidth = 300;

@implementation ConfigurationFormulaHelp

+ (NSTextField *)wrappingText:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
  NSTextField *label = [NSTextField wrappingLabelWithString:text];
  [label setFont:font];
  [label setTextColor:color];
  [label setPreferredMaxLayoutWidth:kTextWidth];
  return label;
}

+ (NSPopover *)popover {
  NSArray *names = @[
    @[@"screenSizeX, screenSizeY", @"Width and height of the screen"],
    @[@"screenOriginX, screenOriginY", @"Where the screen starts"],
    @[@"windowSizeX, windowSizeY", @"Size of the window now"],
    @[@"windowTopLeftX, windowTopLeftY", @"Where the window is now"],
    @[@"newWindowSizeX, newWindowSizeY", @"Size the window has after the move"],
  ];
  NSMutableArray *rows = [NSMutableArray array];
  [rows addObject:[MWMComponents labelWithText:@"Names you can use" size:13 color:[MWMTheme textPrimary] weight:NSFontWeightMedium]];
  for (NSArray *pair in names) {
    NSTextField *name = [MWMComponents labelWithText:pair[0] font:[MWMTheme fontMono] color:[MWMTheme textPrimary]];
    NSTextField *what = [MWMComponents labelWithText:pair[1] font:[MWMTheme fontCaption] color:[MWMTheme textSecondary]];
    [rows addObject:[MWMComponents columnWithViews:@[name, what] spacing:1 insets:NSEdgeInsetsZero]];
  }
  [rows addObject:[self wrappingText:@"A slot is move x;y width;height. Add, subtract, multiply and divide with + - * / and parentheses. Put no spaces inside a number: screenSizeX/3, not screenSizeX / 3." font:[MWMTheme fontCaption] color:[MWMTheme textSecondary]]];
  [rows addObject:[self wrappingText:@"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY" font:[NSFont monospacedSystemFontOfSize:10.5 weight:NSFontWeightRegular] color:[MWMTheme textPrimary]]];
  NSStackView *stack = [MWMComponents columnWithViews:rows spacing:8 insets:NSEdgeInsetsMake(14, 14, 14, 14)];
  [[stack.widthAnchor constraintEqualToConstant:kTextWidth + 28] setActive:YES];   // the text wraps inside the padding
  NSViewController *controller = [[NSViewController alloc] init];
  [controller setView:stack];
  NSPopover *popover = [[NSPopover alloc] init];
  [popover setBehavior:NSPopoverBehaviorTransient];
  [popover setContentViewController:controller];
  return popover;
}

@end
