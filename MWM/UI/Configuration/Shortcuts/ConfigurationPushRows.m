//
//  ConfigurationPushRows.m
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


#import "ConfigurationPushRows.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"

@interface ConfigurationPushRows ()
@property (strong) MWMPushOptions *options;
@property (copy) NSString *direction;
@property (copy) void (^onChange)(MWMPushOptions *options);
@property (strong) NSArray<NSDictionary *> *rows;
@end

@implementation ConfigurationPushRows

static NSArray<NSString *> *StyleTitles(void) { return @[@"Keep its size", @"Centered", @"Full bar", @"Bar with a set thickness"]; }
static NSArray<NSString *> *UnitTitles(void) { return @[@"%", @"px", @"1 of N"]; }

- (NSPopUpButton *)popupWithTitles:(NSArray<NSString *> *)titles values:(NSArray *)values selected:(id)selected action:(SEL)action identifier:(NSString *)identifier {
  NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  [popup setFont:[MWMTheme fontBody]];
  for (NSUInteger i = 0; i < [titles count]; i++) {
    [popup addItemWithTitle:titles[i]];
    [[popup lastItem] setRepresentedObject:values[i]];
    if ([values[i] isEqual:selected]) [popup selectItem:[popup lastItem]];
  }
  [popup setIdentifier:identifier];
  [popup setTarget:self];
  [popup setAction:action];
  [[popup.widthAnchor constraintGreaterThanOrEqualToConstant:200] setActive:YES];
  return popup;
}

+ (instancetype)rowsForOptions:(MWMPushOptions *)options direction:(NSString *)direction screens:(NSArray<NSString *> *)screens onChange:(void (^)(MWMPushOptions *))onChange {
  ConfigurationPushRows *builder = [[ConfigurationPushRows alloc] init];
  builder.options = [options copy];
  builder.direction = direction;
  builder.onChange = onChange;
  builder.rows = [builder buildRowsWithScreens:screens];
  return builder;
}

- (NSArray<NSDictionary *> *)buildRowsWithScreens:(NSArray<NSString *> *)screens {
  NSMutableArray *rows = [NSMutableArray array];
  MWMPushOptions *options = self.options;
  [rows addObject:@{@"label": @"Style", @"identifier": @"row-style",
                    @"views": @[[self popupWithTitles:StyleTitles() values:@[@(MWMPushStyleKeepSize), @(MWMPushStyleCenter), @(MWMPushStyleBar), @(MWMPushStyleThickness)] selected:@(options.style) action:@selector(styleChanged:) identifier:@"push-style"]]}];
  if (options.style == MWMPushStyleThickness) {
    NSTextField *value = [NSTextField textFieldWithString:[NSString stringWithFormat:@"%g", options.thickness]];
    [value setFont:[MWMTheme fontMono]];
    [value setIdentifier:@"push-thickness"];
    [value setTarget:self];
    [value setAction:@selector(thicknessChanged:)];
    [[value cell] setSendsActionOnEndEditing:YES];
    [[value.widthAnchor constraintEqualToConstant:72] setActive:YES];
    NSSegmentedControl *unit = [NSSegmentedControl segmentedControlWithLabels:UnitTitles() trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(unitChanged:)];
    [unit setIdentifier:@"push-unit"];
    [unit setSelectedSegment:options.unit == MWMPushUnitPercent ? 0 : options.unit == MWMPushUnitPixels ? 1 : 2];
    BOOL across = [self.direction isEqualToString:@"left"] || [self.direction isEqualToString:@"right"];
    NSString *of = options.unit == MWMPushUnitPixels ? @"" : (across ? @"of the screen width" : @"of the screen height");
    if (options.unit == MWMPushUnitParts) of = across ? @"parts of the screen width (3 is a third)" : @"parts of the screen height (3 is a third)";
    NSTextField *note = [MWMComponents labelWithText:of font:[MWMTheme fontCaption] color:[MWMTheme textSecondary]];
    [rows addObject:@{@"label": @"Thickness", @"identifier": @"row-thickness", @"views": @[value, unit, note]}];
  }
  NSMutableArray *titles = [NSMutableArray arrayWithObject:@"Current screen"], *values = [NSMutableArray arrayWithObject:@""];
  for (NSString *name in screens) { [titles addObject:name]; [values addObject:[NSString stringWithFormat:@"${%@}", name]]; }
  [rows addObject:@{@"label": @"On screen", @"identifier": @"row-screen", @"views": @[[self popupWithTitles:titles values:values selected:options.screen action:@selector(screenChanged:) identifier:@"push-screen"]]}];
  [rows addObject:@{@"label": @"Result", @"identifier": @"row-result", @"views": @[[self resultView]]}];
  return rows;
}

// A small screen with the window where the push puts it, then what it writes or what is wrong.
- (NSView *)resultView {
  ConfigurationSlotThumbnail *thumbnail = [[ConfigurationSlotThumbnail alloc] init];
  [thumbnail setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSString *problem = [self.options problem];
  CGRect rect = [self.options previewRectForDirection:self.direction];
  thumbnail.rect = CGRectIsNull(rect) ? CGRectZero : rect;
  thumbnail.valid = problem == nil;
  [NSLayoutConstraint activateConstraints:@[[thumbnail.widthAnchor constraintEqualToConstant:80], [thumbnail.heightAnchor constraintEqualToConstant:50]]];
  NSString *text = problem ?: [NSString stringWithFormat:@"Writes: push %@ %@", self.direction, [self.options textForDirection:self.direction]];
  NSTextField *label = [MWMComponents labelWithText:text font:problem != nil ? [MWMTheme fontCaption] : [MWMTheme fontMono] color:problem != nil ? [MWMTheme warning] : [MWMTheme textSecondary]];
  [label setIdentifier:@"push-result"];
  NSStackView *stack = [NSStackView stackViewWithViews:@[thumbnail, label]];
  [stack setSpacing:10];
  [stack setAlignment:NSLayoutAttributeCenterY];
  return stack;
}

#pragma mark - Changes

- (void)changed { self.onChange(self.options); }

- (void)styleChanged:(NSPopUpButton *)popup {
  self.options.style = (MWMPushStyle)[[[popup selectedItem] representedObject] integerValue];
  [self changed];
}

- (void)thicknessChanged:(NSTextField *)field {
  NSString *text = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSScanner *scanner = [NSScanner scannerWithString:text];
  double value = 0;
  BOOL valid = [scanner scanDouble:&value] && [scanner isAtEnd];
  self.options.thickness = valid ? value : 0;   // not a number: the options say what is wrong
  [self changed];
}

- (void)unitChanged:(NSSegmentedControl *)control {
  NSInteger index = [control selectedSegment];
  MWMPushUnit unit = index == 0 ? MWMPushUnitPercent : index == 1 ? MWMPushUnitPixels : MWMPushUnitParts;
  // A percent and one part in N are the same size written two ways, so it stays the same size; pixels start over.
  double fraction = 0, value = self.options.thickness;
  if (value > 0 && self.options.unit == MWMPushUnitPercent) fraction = value / 100;
  if (value > 0 && self.options.unit == MWMPushUnitParts) fraction = 1 / value;
  double (^rounded)(double) = ^double(double number) { return round(number * 100) / 100; };
  if (unit == MWMPushUnitPixels) self.options.thickness = 400;
  else if (unit == MWMPushUnitPercent) self.options.thickness = fraction > 0 ? rounded(fraction * 100) : 50;
  else self.options.thickness = fraction > 0 ? rounded(1 / fraction) : 2;
  self.options.unit = unit;
  [self changed];
}

- (void)screenChanged:(NSPopUpButton *)popup {
  self.options.screen = [[popup selectedItem] representedObject] ?: @"";
  [self changed];
}

@end
