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
@property (copy) void (^onManageDisplays)(void);
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

+ (NSString *)manageDisplaysMarker { return @"@manage-displays"; }

+ (instancetype)rowsForOptions:(MWMPushOptions *)options direction:(NSString *)direction screenTitles:(NSArray<NSString *> *)titles screenValues:(NSArray<NSString *> *)values
                       onChange:(void (^)(MWMPushOptions *))onChange onManageDisplays:(void (^)(void))onManageDisplays {
  ConfigurationPushRows *builder = [[ConfigurationPushRows alloc] init];
  builder.options = [options copy];
  builder.direction = direction;
  builder.onChange = onChange;
  builder.onManageDisplays = onManageDisplays;
  builder.rows = [builder buildRowsWithScreenTitles:titles values:values];
  return builder;
}

- (NSArray<NSDictionary *> *)buildRowsWithScreenTitles:(NSArray<NSString *> *)screenTitles values:(NSArray<NSString *> *)screenValues {
  NSMutableArray *rows = [NSMutableArray array];
  MWMPushOptions *options = self.options;
  // The style as cards: what the window keeps or becomes, with an icon for each.
  NSArray<NSNumber *> *styles = @[@(MWMPushStyleKeepSize), @(MWMPushStyleCenter), @(MWMPushStyleBar), @(MWMPushStyleThickness)];
  __weak ConfigurationPushRows *weakSelf = self;
  MWMOptionCards *styleCards = [MWMOptionCards cardsWithTitles:@[@"Keep its size", @"Centered", @"Full bar", @"Set thickness"]
                                                       symbols:@[@"rectangle", @"rectangle.center.inset.filled", @"rectangle.lefthalf.filled", @"rectangle.leftthird.inset.filled"]
                                                 selectedIndex:(NSInteger)[styles indexOfObject:@(options.style)]
                                                      onChange:^(NSInteger index) { [weakSelf chooseStyle:(MWMPushStyle)[styles[index] integerValue]]; }];
  [styleCards setIdentifier:@"push-style"];
  [rows addObject:@{@"label": @"Style", @"identifier": @"row-style", @"views": @[styleCards]}];
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
    // The note goes under the number and its unit, not beside them.
    NSStackView *inputs = [NSStackView stackViewWithViews:@[value, unit]];
    [inputs setSpacing:10];
    [inputs setAlignment:NSLayoutAttributeCenterY];
    NSStackView *column = [NSStackView stackViewWithViews:@[inputs, note]];
    [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [column setAlignment:NSLayoutAttributeTrailing];
    [column setSpacing:6];
    [rows addObject:@{@"label": @"Thickness", @"identifier": @"row-thickness", @"views": @[column]}];
  }
  NSMutableArray *titles = [NSMutableArray arrayWithObject:@"Current screen"], *values = [NSMutableArray arrayWithObject:@""];
  [titles addObjectsFromArray:screenTitles];
  [values addObjectsFromArray:screenValues];
  NSPopUpButton *screenPopup = [self popupWithTitles:titles values:values selected:options.screen action:@selector(screenChanged:) identifier:@"push-screen"];
  [[screenPopup menu] addItem:[NSMenuItem separatorItem]];
  [screenPopup addItemWithTitle:@"Manage displays…"];
  [[screenPopup lastItem] setRepresentedObject:[ConfigurationPushRows manageDisplaysMarker]];
  [rows addObject:@{@"label": @"On screen", @"identifier": @"row-screen", @"views": @[screenPopup]}];
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
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];   // what it writes goes under the picture
  [stack setSpacing:6];
  [stack setAlignment:NSLayoutAttributeTrailing];
  return stack;
}

#pragma mark - Changes

- (void)changed { self.onChange(self.options); }

- (void)chooseStyle:(MWMPushStyle)style {
  if (style == MWMPushStyleThickness && self.options.style != MWMPushStyleThickness) {
    self.options.unit = MWMPushUnitParts;   // half to begin with
    self.options.thickness = 2;
  }
  self.options.style = style;
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
  NSString *value = [[popup selectedItem] representedObject] ?: @"";
  if ([value isEqualToString:[ConfigurationPushRows manageDisplaysMarker]]) {
    if (self.onManageDisplays) self.onManageDisplays();
    [self changed];   // back to the screen it was
    return;
  }
  self.options.screen = value;
  [self changed];
}

@end
