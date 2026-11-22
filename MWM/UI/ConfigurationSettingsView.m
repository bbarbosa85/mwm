//
//  ConfigurationSettingsView.m
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

#import "ConfigurationSettingsView.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "MWMConfigDocument.h"
#import "MWMConfig.h"

static NSString *const kLaunchAtLogin = @"launchAtLogin";
static const CGFloat kTitleColumnWidth = 230;

// Settings the Advanced page has its own controls for.
static NSArray<NSString *> *ControlledAdvancedSettings(void) {
  return @[@"nudgePercentOf", @"resizePercentOf", @"secondsBeforeRepeat", @"secondsBetweenRepeat"];
}

// The everyday settings, shown on the General page.
static NSArray<NSString *> *EverydaySettings(void) {
  return @[@"defaultToCurrentScreen", @"keyboardLayout", @"windowHintsShowIcons", @"windowHintsSpread", @"windowHintsIgnoreHiddenWindows"];
}

// "true" -> YES, "0.4" -> 0.4, anything else stays text.
static id TypedValue(NSString *text) {
  if ([text isEqualToString:@"true"]) return @YES;
  if ([text isEqualToString:@"false"]) return @NO;
  NSRegularExpression *number = [NSRegularExpression regularExpressionWithPattern:@"^-?[0-9]+(\\.[0-9]+)?$" options:0 error:nil];
  if ([number numberOfMatchesInString:text options:0 range:NSMakeRange(0, [text length])] == 1) return @([text doubleValue]);
  return text;
}

@interface ConfigurationSettingsView ()
@property (strong) NSScrollView *scroll;
@property (strong) NSStackView *stack;
@end

@implementation ConfigurationSettingsView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _stack = [NSStackView stackViewWithViews:@[]];
    [_stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [_stack setAlignment:NSLayoutAttributeLeading];
    [_stack setSpacing:10];
    [_stack setEdgeInsets:NSEdgeInsetsMake(8, 20, 20, 20)];
    [_stack setTranslatesAutoresizingMaskIntoConstraints:NO];

    _scroll = [MWMComponents scrollViewWithContent:_stack];
    [self addSubview:_scroll];
    [MWMComponents pinView:_scroll toEdgesOf:self insets:NSEdgeInsetsMake(0, 0, 0, 0)];
  }
  return self;
}

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
  [self reload];
}

#pragma mark - Settings

- (MWMConfigEntry *)entryNamed:(NSString *)name {
  for (MWMConfigEntry *entry in self.document.settings) {
    if ([entry.name isEqualToString:name]) return entry;
  }
  return nil;
}

// The setting's value, or MWM's default when the file doesn't set it.
- (NSString *)valueOfSetting:(NSString *)name {
  MWMConfigEntry *entry = [self entryNamed:name];
  if (entry != nil) {
    if ([entry.value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)entry.value) == CFBooleanGetTypeID()) {
      return [entry.value boolValue] ? @"true" : @"false";
    }
    return [entry.value description] ?: @"";
  }
  return [[MWMConfig getInstance] getConfigDefault:name] ?: @"";
}

- (void)setSetting:(NSString *)name value:(id)value {
  MWMConfigEntry *entry = [self entryNamed:name];
  if (entry != nil) entry.value = value;
  else [self.document.settings addObject:[MWMConfigEntry entryWithName:name value:value]];
  [self.delegate settingsViewDidChangeDocument:self];
}

- (void)setPage:(ConfigurationSettingsPage)page {
  _page = page;
  [self reload];
}

#pragma mark - Controls

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  return [MWMComponents wrappingLabelWithText:text size:size color:color weight:weight];
}

- (NSView *)textWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
  return [MWMComponents titleWithSubtitle:title subtitle:subtitle];
}

- (NSSwitch *)switchNamed:(NSString *)name on:(BOOL)on {
  NSSwitch *toggle = [[NSSwitch alloc] init];
  [toggle setState:on ? NSControlStateValueOn : NSControlStateValueOff];
  [toggle setIdentifier:name];
  [toggle setTarget:self];
  [toggle setAction:@selector(switchToggled:)];
  [toggle setControlSize:NSControlSizeSmall];
  return toggle;
}

// Text on the left, a control on the right.
- (NSView *)rowWithTitle:(NSString *)title subtitle:(NSString *)subtitle control:(NSView *)control {
  return [MWMComponents controlRowWithTitle:title subtitle:subtitle control:control];
}

- (NSView *)toggleRowTitle:(NSString *)title subtitle:(NSString *)subtitle setting:(NSString *)name {
  BOOL on = [[self valueOfSetting:name] isEqualToString:@"true"];
  return [self rowWithTitle:title subtitle:subtitle control:[self switchNamed:name on:on]];
}

// A block: icon, title and description on the left, the rows on the right.
- (NSView *)blockWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle rows:(NSArray<NSView *> *)rows {
  return [MWMComponents settingsBlockWithSymbol:symbol title:title subtitle:subtitle rows:rows titleColumnWidth:kTitleColumnWidth];
}

- (void)addBlock:(NSView *)block {
  [self.stack addArrangedSubview:block];
  [[block.widthAnchor constraintEqualToAnchor:self.stack.widthAnchor constant:-40] setActive:YES];
}

#pragma mark - Building

- (void)reload {
  for (NSView *view in [[self.stack arrangedSubviews] copy]) {
    [self.stack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  if (self.document == nil) return;
  if (self.page == ConfigurationSettingsPageAdvanced) {
    [self reloadAdvanced];
    return;
  }

  BOOL login = [self.delegate respondsToSelector:@selector(settingsViewLaunchesAtLogin:)] && [self.delegate settingsViewLaunchesAtLogin:self];
  [self addBlock:[self blockWithSymbol:@"power" title:@"Startup" subtitle:@"Runs quietly in the menu bar" rows:@[
    [self rowWithTitle:@"Launch MWM at login" subtitle:nil control:[self switchNamed:kLaunchAtLogin on:login]],
  ]]];

  [self addBlock:[self blockWithSymbol:@"macwindow" title:@"Windows" subtitle:@"Where shortcuts act by default" rows:@[
    [self toggleRowTitle:@"Use the screen you're working on" subtitle:@"When a shortcut names no screen" setting:@"defaultToCurrentScreen"],
  ]]];

  [self addBlock:[self blockWithSymbol:@"sparkles" title:@"Window hints" subtitle:@"Letters shown on windows" rows:@[
    [self toggleRowTitle:@"Show app icons" subtitle:nil setting:@"windowHintsShowIcons"],
    [self toggleRowTitle:@"Spread letters apart" subtitle:nil setting:@"windowHintsSpread"],
    [self toggleRowTitle:@"Ignore hidden windows" subtitle:nil setting:@"windowHintsIgnoreHiddenWindows"],
  ]]];

  NSPopUpButton *layout = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  NSString *current = [[self valueOfSetting:@"keyboardLayout"] lowercaseString];
  NSArray *layouts = @[@"qwerty", @"dvorak", @"colemak", @"azerty"];
  for (NSString *name in layouts) [layout addItemWithTitle:[name uppercaseString]];
  if (![layouts containsObject:current] && [current length] > 0) [layout addItemWithTitle:current];
  [layout selectItemWithTitle:[layouts containsObject:current] ? [current uppercaseString] : current];
  [layout setTarget:self];
  [layout setAction:@selector(layoutChanged:)];
  [self addBlock:[self blockWithSymbol:@"keyboard" title:@"Keyboard layout" subtitle:@"Used to name recorded keys" rows:@[
    [self rowWithTitle:@"Layout" subtitle:nil control:layout],
  ]]];

  NSButton *finder = [NSButton buttonWithTitle:@"Show in Finder" target:self action:@selector(showInFinder:)];
  NSButton *editor = [NSButton buttonWithTitle:@"Open in Text Editor" target:self action:@selector(openInTextEditor:)];
  NSStackView *buttons = [NSStackView stackViewWithViews:@[finder, editor]];
  [buttons setSpacing:8];
  [self addBlock:[self blockWithSymbol:@"doc.text" title:@"Config file" subtitle:@"~/.mwm.yml" rows:@[
    [self rowWithTitle:@"Edit it by hand if you like" subtitle:nil control:buttons],
  ]]];
}

#pragma mark - Advanced

- (NSSegmentedControl *)screenOrWindowControl:(NSString *)name {
  NSSegmentedControl *control = [NSSegmentedControl segmentedControlWithLabels:@[@"Screen", @"Window"]
                                                                  trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                        target:self action:@selector(percentOfChanged:)];
  [control setIdentifier:name];
  [control setSelectedSegment:[[self valueOfSetting:name] isEqualToString:@"windowSize"] ? 1 : 0];
  return control;
}

- (NSView *)sliderRowTitle:(NSString *)title setting:(NSString *)name min:(double)min max:(double)max {
  NSSlider *slider = [NSSlider sliderWithValue:[[self valueOfSetting:name] doubleValue] minValue:min maxValue:max target:self action:@selector(sliderMoved:)];
  [slider setIdentifier:name];
  [slider setContinuous:YES];
  [[slider.widthAnchor constraintGreaterThanOrEqualToConstant:160] setActive:YES];
  NSTextField *value = [self labelWithText:[NSString stringWithFormat:@"%.2f s", [slider doubleValue]] size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  [value setIdentifier:[name stringByAppendingString:@".value"]];
  [[value.widthAnchor constraintEqualToConstant:48] setActive:YES];
  [value setAlignment:NSTextAlignmentRight];
  NSStackView *controls = [NSStackView stackViewWithViews:@[slider, value]];
  [controls setSpacing:10];
  return [self rowWithTitle:title subtitle:nil control:controls];
}

// Settings the other pages have no controls for: edited as name and value.
- (NSArray<MWMConfigEntry *> *)otherSettings {
  NSMutableArray *others = [NSMutableArray array];
  for (MWMConfigEntry *entry in self.document.settings) {
    if ([EverydaySettings() containsObject:entry.name] || [ControlledAdvancedSettings() containsObject:entry.name]) continue;
    [others addObject:entry];
  }
  return others;
}

- (NSView *)otherSettingRow:(MWMConfigEntry *)entry {
  NSString *fallback = [[MWMConfig getInstance] getConfigDefault:entry.name];
  NSTextField *name = [self labelWithText:entry.name size:12 color:fallback == nil ? [MWMTheme warning] : [MWMTheme textPrimary] weight:NSFontWeightRegular];
  [name setFont:[MWMTheme fontMono]];
  [[name.widthAnchor constraintEqualToConstant:210] setActive:YES];
  [name setToolTip:fallback == nil ? @"MWM doesn't know this setting" : [NSString stringWithFormat:@"Default: %@", [fallback length] > 0 ? fallback : @"(empty)"]];
  NSString *shown = [self valueOfSetting:entry.name];
  NSTextField *value = [NSTextField textFieldWithString:shown];
  [value setIdentifier:entry.name];
  [value setFont:[MWMTheme fontMono]];
  [value setTarget:self];
  [value setAction:@selector(otherSettingEdited:)];
  [[value cell] setSendsActionOnEndEditing:YES];
  [value setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSButton *remove = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"minus.circle" accessibilityDescription:@"Remove"] target:self action:@selector(removeOtherSetting:)];
  [remove setBordered:NO];
  [remove setIdentifier:entry.name];
  [remove setToolTip:@"Remove this setting (MWM goes back to its default)"];
  NSStackView *row = [NSStackView stackViewWithViews:@[name, value, remove]];
  [row setSpacing:10];
  [row setAlignment:NSLayoutAttributeCenterY];
  return row;
}

- (void)reloadAdvanced {
  [self addBlock:[self blockWithSymbol:@"ruler" title:@"Nudge and resize" subtitle:@"How percentages are measured" rows:@[
    [self rowWithTitle:@"Nudge by percent of" subtitle:nil control:[self screenOrWindowControl:@"nudgePercentOf"]],
    [self rowWithTitle:@"Resize by percent of" subtitle:nil control:[self screenOrWindowControl:@"resizePercentOf"]],
  ]]];
  [self addBlock:[self blockWithSymbol:@"repeat" title:@"Held keys" subtitle:@"How fast a held shortcut repeats" rows:@[
    [self sliderRowTitle:@"Before repeating" setting:@"secondsBeforeRepeat" min:0.1 max:1.0],
    [self sliderRowTitle:@"Between repeats" setting:@"secondsBetweenRepeat" min:0.02 max:0.5],
  ]]];

  NSMutableArray *rows = [NSMutableArray array];
  for (MWMConfigEntry *entry in [self otherSettings]) [rows addObject:[self otherSettingRow:entry]];
  NSButton *add = [MWMComponents secondaryButtonWithTitle:@"Add setting…" target:self action:@selector(showAddMenu:)];
  [rows addObject:add];
  [self addBlock:[self blockWithSymbol:@"slider.horizontal.3" title:@"Other settings" subtitle:@"Anything else MWM can be told" rows:rows]];
}

- (void)percentOfChanged:(NSSegmentedControl *)control {
  [self setSetting:[control identifier] value:[control selectedSegment] == 1 ? @"windowSize" : @"screenSize"];
}

- (void)sliderMoved:(NSSlider *)slider {
  NSString *name = [slider identifier];
  double value = round([slider doubleValue] * 100) / 100;
  for (NSView *view in [self allSubviewsOf:self]) {
    if ([view isKindOfClass:[NSTextField class]] && [[view identifier] isEqualToString:[name stringByAppendingString:@".value"]]) {
      [(NSTextField *)view setStringValue:[NSString stringWithFormat:@"%.2f s", value]];
    }
  }
  // Save once the slider is let go, not on every step of the drag.
  NSEventType type = [[NSApp currentEvent] type];
  if (type == NSEventTypeLeftMouseDragged || type == NSEventTypeLeftMouseDown) return;
  [self setSetting:name value:@(value)];
}

- (NSArray<NSView *> *)allSubviewsOf:(NSView *)view {
  NSMutableArray *all = [NSMutableArray array];
  for (NSView *child in [view subviews]) {
    [all addObject:child];
    [all addObjectsFromArray:[self allSubviewsOf:child]];
  }
  return all;
}

- (void)otherSettingEdited:(NSTextField *)field {
  NSString *text = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  MWMConfigEntry *entry = [self entryNamed:[field identifier]];
  if (entry == nil || [text isEqualToString:[self valueOfSetting:entry.name]]) return;
  [self setSetting:entry.name value:TypedValue(text)];
}

- (void)removeOtherSetting:(NSButton *)button {
  MWMConfigEntry *entry = [self entryNamed:[button identifier]];
  if (entry == nil) return;
  [self.document.settings removeObjectIdenticalTo:entry];
  [self.delegate settingsViewDidChangeDocument:self];
  [self reload];
}

- (void)showAddMenu:(NSButton *)button {
  NSDictionary *defaults = [[MWMConfig getInstance] configDefaults];
  NSSet *present = [NSSet setWithArray:[self.document.settings valueForKey:@"name"]];
  NSMenu *menu = [[NSMenu alloc] init];
  for (NSString *name in [[defaults allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
    if ([present containsObject:name] || [EverydaySettings() containsObject:name] || [ControlledAdvancedSettings() containsObject:name]) continue;
    NSMenuItem *item = [menu addItemWithTitle:name action:@selector(addSettingChosen:) keyEquivalent:@""];
    [item setTarget:self];
    [item setRepresentedObject:name];
  }
  if ([menu numberOfItems] == 0) [menu addItemWithTitle:@"Every setting is already listed" action:nil keyEquivalent:@""];
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight([button bounds]) + 4) inView:button];
}

- (void)addSettingChosen:(NSMenuItem *)item {
  NSString *name = [item representedObject];
  NSString *fallback = [[MWMConfig getInstance] getConfigDefault:name] ?: @"";
  [self.document.settings addObject:[MWMConfigEntry entryWithName:name value:TypedValue(fallback)]];
  [self.delegate settingsViewDidChangeDocument:self];
  [self reload];
}

#pragma mark - Actions

- (void)switchToggled:(NSSwitch *)toggle {
  BOOL on = [toggle state] == NSControlStateValueOn;
  if ([[toggle identifier] isEqualToString:kLaunchAtLogin]) {
    [self.delegate settingsView:self setLaunchesAtLogin:on];
    return;
  }
  [self setSetting:[toggle identifier] value:on ? @YES : @NO];
}

- (void)layoutChanged:(NSPopUpButton *)popup {
  [self setSetting:@"keyboardLayout" value:[[popup titleOfSelectedItem] lowercaseString]];
}

- (void)showInFinder:(id)sender { [self.delegate settingsViewWantsFinder:self]; }
- (void)openInTextEditor:(id)sender { [self.delegate settingsViewWantsTextEditor:self]; }

@end
