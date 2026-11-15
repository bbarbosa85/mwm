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
#import "SlateConfigDocument.h"
#import "SlateConfig.h"

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

// A scroll view puts a short document at the bottom unless the document is flipped.
@interface ConfigurationFlippedView : NSView
@end

@implementation ConfigurationFlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface ConfigurationBlockView : NSView
@end

// A rounded, softly tinted row.
@implementation ConfigurationBlockView
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setWantsLayer:YES];
    [[self layer] setCornerRadius:12];
  }
  return self;
}
- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self layer] setBackgroundColor:[[[NSColor labelColor] colorWithAlphaComponent:0.05] CGColor]];
  }];
}
- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  [self viewDidChangeEffectiveAppearance];
}
@end

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

    NSView *flipped = [[ConfigurationFlippedView alloc] init];
    [flipped setTranslatesAutoresizingMaskIntoConstraints:NO];
    [flipped addSubview:_stack];
    _scroll = [[NSScrollView alloc] init];
    [_scroll setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_scroll setHasVerticalScroller:YES];
    [_scroll setAutohidesScrollers:YES];
    [_scroll setDrawsBackground:NO];
    NSClipView *clip = [[NSClipView alloc] init];
    [clip setDrawsBackground:NO];
    [_scroll setContentView:clip];
    [_scroll setDocumentView:flipped];
    [self addSubview:_scroll];
    [NSLayoutConstraint activateConstraints:@[
      [_scroll.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [_scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [flipped.topAnchor constraintEqualToAnchor:clip.topAnchor],
      [flipped.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
      [flipped.trailingAnchor constraintEqualToAnchor:clip.trailingAnchor],
      [_stack.topAnchor constraintEqualToAnchor:flipped.topAnchor],
      [_stack.bottomAnchor constraintEqualToAnchor:flipped.bottomAnchor],
      [_stack.leadingAnchor constraintEqualToAnchor:flipped.leadingAnchor],
      [_stack.trailingAnchor constraintEqualToAnchor:flipped.trailingAnchor],
    ]];
  }
  return self;
}

- (void)setDocument:(SlateConfigDocument *)document {
  _document = document;
  [self reload];
}

#pragma mark - Settings

- (SlateConfigEntry *)entryNamed:(NSString *)name {
  for (SlateConfigEntry *entry in self.document.settings) {
    if ([entry.name isEqualToString:name]) return entry;
  }
  return nil;
}

// The setting's value, or MWM's default when the file doesn't set it.
- (NSString *)valueOfSetting:(NSString *)name {
  SlateConfigEntry *entry = [self entryNamed:name];
  if (entry != nil) {
    if ([entry.value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)entry.value) == CFBooleanGetTypeID()) {
      return [entry.value boolValue] ? @"true" : @"false";
    }
    return [entry.value description] ?: @"";
  }
  return [[SlateConfig getInstance] getConfigDefault:name] ?: @"";
}

- (void)setSetting:(NSString *)name value:(id)value {
  SlateConfigEntry *entry = [self entryNamed:name];
  if (entry != nil) entry.value = value;
  else [self.document.settings addObject:[SlateConfigEntry entryWithName:name value:value]];
  [self.delegate settingsViewDidChangeDocument:self];
}

- (void)setPage:(ConfigurationSettingsPage)page {
  _page = page;
  [self reload];
}

#pragma mark - Controls

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  NSTextField *label = [NSTextField wrappingLabelWithString:text];
  [label setFont:[NSFont systemFontOfSize:size weight:weight]];
  [label setTextColor:color];
  [label setSelectable:NO];
  return label;
}

// A label with an optional smaller line under it.
- (NSView *)textWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
  NSMutableArray *lines = [NSMutableArray arrayWithObject:[self labelWithText:title size:13 color:[NSColor labelColor] weight:NSFontWeightRegular]];
  if ([subtitle length] > 0) [lines addObject:[self labelWithText:subtitle size:11 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular]];
  NSStackView *stack = [NSStackView stackViewWithViews:lines];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:1];
  return stack;
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
  NSView *text = [self textWithTitle:title subtitle:subtitle];
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *row = [NSStackView stackViewWithViews:@[text, spacer, control]];
  [row setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
  [row setAlignment:NSLayoutAttributeCenterY];
  [row setSpacing:12];
  [control setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  return row;
}

- (NSView *)toggleRowTitle:(NSString *)title subtitle:(NSString *)subtitle setting:(NSString *)name {
  BOOL on = [[self valueOfSetting:name] isEqualToString:@"true"];
  return [self rowWithTitle:title subtitle:subtitle control:[self switchNamed:name on:on]];
}

// A block: icon, title and description on the left, the rows on the right.
- (NSView *)blockWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle rows:(NSArray<NSView *> *)rows {
  ConfigurationBlockView *block = [[ConfigurationBlockView alloc] init];
  [block setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
  [icon setContentTintColor:[NSColor secondaryLabelColor]];
  [icon setSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightRegular]];
  [icon setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSView *heading = [self textWithTitle:title subtitle:subtitle];
  [(NSTextField *)[[(NSStackView *)heading arrangedSubviews] firstObject] setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
  NSStackView *left = [NSStackView stackViewWithViews:@[icon, heading]];
  [left setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
  [left setAlignment:NSLayoutAttributeTop];
  [left setSpacing:10];
  [left setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSStackView *right = [NSStackView stackViewWithViews:rows];
  [right setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [right setAlignment:NSLayoutAttributeLeading];
  [right setSpacing:10];
  [right setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *row in rows) {
    [[row.widthAnchor constraintEqualToAnchor:right.widthAnchor] setActive:YES];
  }

  [block addSubview:left];
  [block addSubview:right];
  [NSLayoutConstraint activateConstraints:@[
    [left.leadingAnchor constraintEqualToAnchor:block.leadingAnchor constant:14],
    [left.topAnchor constraintEqualToAnchor:block.topAnchor constant:14],
    [left.widthAnchor constraintEqualToConstant:kTitleColumnWidth],
    [right.leadingAnchor constraintEqualToAnchor:left.trailingAnchor constant:16],
    [right.trailingAnchor constraintEqualToAnchor:block.trailingAnchor constant:-14],
    [right.topAnchor constraintEqualToAnchor:block.topAnchor constant:14],
    [right.bottomAnchor constraintEqualToAnchor:block.bottomAnchor constant:-14],
    [block.bottomAnchor constraintGreaterThanOrEqualToAnchor:left.bottomAnchor constant:14],
  ]];
  return block;
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
  NSTextField *value = [self labelWithText:[NSString stringWithFormat:@"%.2f s", [slider doubleValue]] size:12 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular];
  [value setIdentifier:[name stringByAppendingString:@".value"]];
  [[value.widthAnchor constraintEqualToConstant:48] setActive:YES];
  [value setAlignment:NSTextAlignmentRight];
  NSStackView *controls = [NSStackView stackViewWithViews:@[slider, value]];
  [controls setSpacing:10];
  return [self rowWithTitle:title subtitle:nil control:controls];
}

// Settings the other pages have no controls for: edited as name and value.
- (NSArray<SlateConfigEntry *> *)otherSettings {
  NSMutableArray *others = [NSMutableArray array];
  for (SlateConfigEntry *entry in self.document.settings) {
    if ([EverydaySettings() containsObject:entry.name] || [ControlledAdvancedSettings() containsObject:entry.name]) continue;
    [others addObject:entry];
  }
  return others;
}

- (NSView *)otherSettingRow:(SlateConfigEntry *)entry {
  NSString *fallback = [[SlateConfig getInstance] getConfigDefault:entry.name];
  NSTextField *name = [self labelWithText:entry.name size:12 color:fallback == nil ? [NSColor systemOrangeColor] : [NSColor labelColor] weight:NSFontWeightRegular];
  [name setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
  [[name.widthAnchor constraintEqualToConstant:210] setActive:YES];
  [name setToolTip:fallback == nil ? @"MWM doesn't know this setting" : [NSString stringWithFormat:@"Default: %@", [fallback length] > 0 ? fallback : @"(empty)"]];
  NSString *shown = [self valueOfSetting:entry.name];
  NSTextField *value = [NSTextField textFieldWithString:shown];
  [value setIdentifier:entry.name];
  [value setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
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
  for (SlateConfigEntry *entry in [self otherSettings]) [rows addObject:[self otherSettingRow:entry]];
  NSButton *add = [NSButton buttonWithTitle:@"Add setting…" target:self action:@selector(showAddMenu:)];
  [add setBezelStyle:NSBezelStyleRounded];
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
  SlateConfigEntry *entry = [self entryNamed:[field identifier]];
  if (entry == nil || [text isEqualToString:[self valueOfSetting:entry.name]]) return;
  [self setSetting:entry.name value:TypedValue(text)];
}

- (void)removeOtherSetting:(NSButton *)button {
  SlateConfigEntry *entry = [self entryNamed:[button identifier]];
  if (entry == nil) return;
  [self.document.settings removeObjectIdenticalTo:entry];
  [self.delegate settingsViewDidChangeDocument:self];
  [self reload];
}

- (void)showAddMenu:(NSButton *)button {
  NSDictionary *defaults = [[SlateConfig getInstance] configDefaults];
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
  NSString *fallback = [[SlateConfig getInstance] getConfigDefault:name] ?: @"";
  [self.document.settings addObject:[SlateConfigEntry entryWithName:name value:TypedValue(fallback)]];
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
