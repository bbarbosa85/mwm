//
//  ConfigurationActionView.m
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

#import "ConfigurationActionView.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "MWMAction.h"
#import "MWMSlots.h"
#import "MWMConfigDocument.h"

#pragma mark - Position preview

// A small screen with the window drawn where the position puts it.
@interface ConfigurationPositionPreview : NSView
@property (assign) CGRect fraction;
@end

@implementation ConfigurationPositionPreview
- (NSSize)intrinsicContentSize { return NSMakeSize(32, 20); }
- (void)drawRect:(NSRect)dirtyRect {
  NSRect screen = NSInsetRect([self bounds], 1, 1);
  [[NSColor separatorColor] setStroke];
  NSBezierPath *frame = [NSBezierPath bezierPathWithRoundedRect:screen xRadius:2 yRadius:2];
  [frame setLineWidth:1];
  [frame stroke];
  CGRect f = self.fraction;
  NSRect window = NSMakeRect(screen.origin.x + f.origin.x * screen.size.width,
                             screen.origin.y + (1 - f.origin.y - f.size.height) * screen.size.height,
                             f.size.width * screen.size.width, f.size.height * screen.size.height);
  [[[MWMTheme accent] colorWithAlphaComponent:0.55] setFill];
  [NSBezierPath fillRect:NSIntersectionRect(window, screen)];
}
@end

#pragma mark - Applications

// Names of running and installed applications, for the Focus dropdown.
static NSArray<NSString *> *ApplicationNames(void) {
  NSMutableSet *names = [NSMutableSet set];
  for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
    if (app.activationPolicy == NSApplicationActivationPolicyRegular && app.localizedName != nil) [names addObject:app.localizedName];
  }
  for (NSString *folder in @[@"/Applications", @"/System/Applications", @"/Applications/Utilities", [@"~/Applications" stringByExpandingTildeInPath]]) {
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil]) {
      if ([file hasSuffix:@".app"]) [names addObject:[file stringByDeletingPathExtension]];
    }
  }
  return [[names allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - View

@interface ConfigurationActionView () <NSTextFieldDelegate>
@property (strong) NSStackView *stack;
@property (strong) MWMAction *model;
@property (copy) NSArray<MWMConfigEntry *> *positions;
@property (copy) NSArray<MWMConfigEntry *> *monitors;
@end

@implementation ConfigurationActionView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _stack = [NSStackView stackViewWithViews:@[]];
    [_stack setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
    [_stack setSpacing:6];
    [_stack setAlignment:NSLayoutAttributeCenterY];
    [_stack setDistribution:NSStackViewDistributionFill];
    [_stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:_stack];
    [NSLayoutConstraint activateConstraints:@[
      [_stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2],
      [_stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2],
      [_stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:1],
      [_stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-1],
    ]];
  }
  return self;
}

- (NSString *)action { return [self.model string] ?: @""; }

- (void)setAction:(NSString *)action positions:(NSArray<MWMConfigEntry *> *)positions monitors:(NSArray<MWMConfigEntry *> *)monitors {
  self.positions = positions ?: @[];
  // Screen sizes ("5120x1440") are listed with the monitors but aren't screens.
  NSMutableArray *screens = [NSMutableArray array];
  for (MWMConfigEntry *entry in monitors) {
    if (![[entry.value description] containsString:@"x"]) [screens addObject:entry];
  }
  self.monitors = screens;
  self.model = [MWMAction parse:action];
  [self rebuild];
}

#pragma mark - Controls

- (NSPopUpButton *)popupWithTitles:(NSArray<NSString *> *)titles values:(NSArray<NSString *> *)values selected:(NSString *)selected action:(SEL)action {
  NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  [popup setControlSize:NSControlSizeSmall];
  [popup setFont:[MWMTheme fontSmall]];
  NSUInteger selectedIndex = NSNotFound;
  for (NSUInteger i = 0; i < [titles count]; i++) {
    [popup addItemWithTitle:titles[i]];
    [[popup lastItem] setRepresentedObject:values[i]];
    if ([values[i] isEqualToString:selected]) selectedIndex = i;
  }
  if (selectedIndex == NSNotFound) {  // keep a value the lists don't know, so nothing is lost
    [popup addItemWithTitle:[selected length] > 0 ? selected : @"—"];
    [[popup lastItem] setRepresentedObject:selected ?: @""];
    selectedIndex = [popup numberOfItems] - 1;
  }
  [popup selectItemAtIndex:selectedIndex];
  [popup setTarget:self];
  [popup setAction:action];
  [popup setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
  return popup;
}

- (NSTextField *)fieldWithText:(NSString *)text placeholder:(NSString *)placeholder width:(CGFloat)width monospaced:(BOOL)monospaced action:(SEL)action {
  NSTextField *field = [NSTextField textFieldWithString:text ?: @""];
  [field setControlSize:NSControlSizeSmall];
  [field setFont:monospaced ? [MWMTheme fontMono] : [MWMTheme fontSmall]];
  [field setPlaceholderString:placeholder];
  [field setLineBreakMode:NSLineBreakByTruncatingTail];
  [field setTarget:self];
  [field setAction:action];
  [[field cell] setSendsActionOnEndEditing:YES];
  if (width > 0) [[field.widthAnchor constraintEqualToConstant:width] setActive:YES];
  else [field setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
  return field;
}

- (NSTextField *)labelWithText:(NSString *)text {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[MWMTheme fontSmall]];
  [label setTextColor:[MWMTheme textSecondary]];
  [label setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  return label;
}

- (NSArray<NSString *> *)namesOf:(NSArray<MWMConfigEntry *> *)entries {
  NSMutableArray *names = [NSMutableArray array];
  for (MWMConfigEntry *entry in entries) [names addObject:entry.name];
  return names;
}

- (void)rebuild {
  for (NSView *view in [[self.stack arrangedSubviews] copy]) {
    [self.stack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  MWMAction *m = self.model;
  NSArray<NSNumber *> *kinds = [MWMAction allKinds];
  NSMutableArray *kindTitles = [NSMutableArray array], *kindValues = [NSMutableArray array];
  for (NSNumber *kind in kinds) {
    [kindTitles addObject:[MWMAction titleForKind:(MWMActionKind)[kind integerValue]]];
    [kindValues addObject:[kind stringValue]];
  }
  NSPopUpButton *kindPopup = [self popupWithTitles:kindTitles values:kindValues selected:[@(m.kind) stringValue] action:@selector(kindChanged:)];
  [kindPopup setIdentifier:@"kind"];
  [[kindPopup.widthAnchor constraintEqualToConstant:128] setActive:YES];
  [self.stack addArrangedSubview:kindPopup];

  switch (m.kind) {
    case MWMActionKindMove: {
      NSMutableArray *titles = [NSMutableArray arrayWithArray:[self namesOf:self.positions]];
      NSPopUpButton *position = [self popupWithTitles:titles values:titles selected:m.a action:@selector(firstChanged:)];
      [self.stack addArrangedSubview:position];
      [self.stack addArrangedSubview:[self labelWithText:@"on"]];
      NSMutableArray *monitorTitles = [NSMutableArray arrayWithObject:@"Current screen"], *monitorValues = [NSMutableArray arrayWithObject:@""];
      for (NSString *name in [self namesOf:self.monitors]) { [monitorTitles addObject:name]; [monitorValues addObject:name]; }
      [self.stack addArrangedSubview:[self popupWithTitles:monitorTitles values:monitorValues selected:m.b action:@selector(secondChanged:)]];
      ConfigurationPositionPreview *preview = [[ConfigurationPositionPreview alloc] init];
      CGRect rect;
      NSString *value = nil;
      for (MWMConfigEntry *entry in self.positions) if ([entry.name isEqualToString:m.a]) value = [entry.value description];
      if ([MWMAction previewForPositionText:value rect:&rect] || (value != nil && [MWMSlots getPreviewRect:&rect fromFormula:value])) { preview.fraction = rect; [self.stack addArrangedSubview:preview]; }
      break;
    }
    case MWMActionKindFocusApp: {
      NSComboBox *combo = [[NSComboBox alloc] initWithFrame:NSZeroRect];
      [combo setControlSize:NSControlSizeSmall];
      [combo setFont:[MWMTheme fontSmall]];
      [combo addItemsWithObjectValues:ApplicationNames()];
      [combo setCompletes:YES];
      [combo setStringValue:m.a];
      [combo setPlaceholderString:@"Application"];
      [combo setTarget:self];
      [combo setAction:@selector(firstChanged:)];
      [[combo.widthAnchor constraintGreaterThanOrEqualToConstant:140] setActive:YES];
      [self.stack addArrangedSubview:combo];
      break;
    }
    case MWMActionKindFocusDirection:
      [self.stack addArrangedSubview:[self popupWithTitles:[MWMAction directions] values:[MWMAction directions] selected:m.a action:@selector(firstChanged:)]];
      break;
    case MWMActionKindThrow: {
      NSMutableArray *titles = [NSMutableArray arrayWithObjects:@"next", @"previous", nil];
      NSMutableArray *values = [titles mutableCopy];
      for (NSString *name in [self namesOf:self.monitors]) { [titles addObject:name]; [values addObject:[NSString stringWithFormat:@"${%@}", name]]; }
      [self.stack addArrangedSubview:[self popupWithTitles:titles values:values selected:m.a action:@selector(firstChanged:)]];
      [self.stack addArrangedSubview:[self fieldWithText:m.b placeholder:@"resize" width:0 monospaced:YES action:@selector(secondChanged:)]];
      break;
    }
    case MWMActionKindNudge:
    case MWMActionKindResize:
      [self.stack addArrangedSubview:[self labelWithText:@"x"]];
      [self.stack addArrangedSubview:[self fieldWithText:m.a placeholder:@"+10%" width:64 monospaced:YES action:@selector(firstChanged:)]];
      [self.stack addArrangedSubview:[self labelWithText:@"y"]];
      [self.stack addArrangedSubview:[self fieldWithText:m.b placeholder:@"+0" width:64 monospaced:YES action:@selector(secondChanged:)]];
      break;
    case MWMActionKindPush:
      [self.stack addArrangedSubview:[self popupWithTitles:[MWMAction pushDirections] values:[MWMAction pushDirections] selected:m.a action:@selector(firstChanged:)]];
      [self.stack addArrangedSubview:[self fieldWithText:m.b placeholder:@"bar-resize:screenSizeX/2" width:0 monospaced:YES action:@selector(secondChanged:)]];
      break;
    case MWMActionKindHint:
      [self.stack addArrangedSubview:[self labelWithText:@"letters"]];
      [self.stack addArrangedSubview:[self fieldWithText:m.a placeholder:@"ASDFJKL" width:0 monospaced:YES action:@selector(firstChanged:)]];
      break;
    case MWMActionKindGrid:
      [self.stack addArrangedSubview:[self fieldWithText:m.a placeholder:@"padding:5 0:6,2" width:0 monospaced:YES action:@selector(firstChanged:)]];
      break;
    case MWMActionKindCustom:
      [self.stack addArrangedSubview:[self fieldWithText:m.a placeholder:@"operation" width:0 monospaced:YES action:@selector(firstChanged:)]];
      break;
    case MWMActionKindSnapshot:
    case MWMActionKindRestoreSnapshot:
      [self.stack addArrangedSubview:[self fieldWithText:m.a placeholder:@"snapshot name" width:0 monospaced:YES action:@selector(firstChanged:)]];
      break;
    case MWMActionKindSwitch:
    case MWMActionKindRelaunch:
      break;
  }
  // Kinds without a text box leave the rest of the cell empty instead of stretching a dropdown.
  NSView *last = [[self.stack arrangedSubviews] lastObject];
  if (![last isKindOfClass:[NSTextField class]] && ![last isKindOfClass:[NSComboBox class]]) {
    NSView *spacer = [MWMComponents spacer];
    [self.stack addArrangedSubview:spacer];
  }
}

#pragma mark - Changes

- (void)changed {
  [self.delegate actionView:self didChangeAction:[self.model string]];
}

- (void)selectKindAtIndex:(NSInteger)index {
  NSArray *kinds = [MWMAction allKinds];
  if (index < 0 || index >= (NSInteger)[kinds count]) return;
  MWMActionKind kind = (MWMActionKind)[kinds[index] integerValue];
  if (kind == self.model.kind) return;
  NSString *before = [self.model string];
  MWMAction *next = [MWMAction actionOfKind:kind];
  if (kind == MWMActionKindCustom) next.a = before;  // Advanced… starts from the current text
  if (kind == MWMActionKindMove && [self.positions count] > 0) next.a = ((MWMConfigEntry *)self.positions[0]).name;
  self.model = next;
  [self rebuild];
  [self changed];
}

- (void)kindChanged:(NSPopUpButton *)popup {
  NSInteger index = [popup indexOfSelectedItem];
  dispatch_async(dispatch_get_main_queue(), ^{ [self selectKindAtIndex:index]; });  // not while the menu is closing
}

// Reads the first or second field of the model from whichever control changed.
- (NSString *)valueOf:(id)control {
  if ([control isKindOfClass:[NSPopUpButton class]]) return [[(NSPopUpButton *)control selectedItem] representedObject] ?: @"";
  return [[control stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)firstChanged:(id)control {
  NSString *value = [self valueOf:control];
  if ([value isEqualToString:self.model.a]) return;
  self.model.a = value;
  [self changed];
  if (self.model.kind == MWMActionKindMove) dispatch_async(dispatch_get_main_queue(), ^{ [self rebuild]; });  // the preview follows the position
}

- (void)secondChanged:(id)control {
  NSString *value = [self valueOf:control];
  if ([value isEqualToString:self.model.b]) return;
  self.model.b = value;
  [self changed];
}

@end
