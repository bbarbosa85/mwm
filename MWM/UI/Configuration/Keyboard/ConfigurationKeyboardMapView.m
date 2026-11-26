//
//  ConfigurationKeyboardMapView.m
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

#import "ConfigurationKeyboardMapView.h"
#import "MWMAlert.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "ConfigurationMacKeyboard.h"
#import "MWMAction.h"
#import "MWMConfigDocument.h"
#import "MWMReservedShortcuts.h"
#import "MWMShortcut.h"
#import "MWMShortcutIndex.h"
#import "MWMSlots.h"

static const CGFloat kGroupsWidth = 188;

#pragma mark - Page

@interface ConfigurationKeyboardMapView ()
@property (strong) MWMShortcutIndex *index;
@property (strong) NSStackView *groupsStack;
@property (strong) ConfigurationMacKeyboard *keyboard;
@property (strong) NSStackView *selectionStack;
@property (strong) NSPopover *legendPopover;
@property (copy) NSArray<ConfigurationMapKey *> *keys;
@end

@implementation ConfigurationKeyboardMapView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _confirmsRemoval = YES;
    _keys = @[];
    [self buildInterface];
  }
  return self;
}

- (void)buildInterface {
  self.groupsStack = [NSStackView stackViewWithViews:@[]];
  [self.groupsStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.groupsStack setAlignment:NSLayoutAttributeLeading];
  [self.groupsStack setSpacing:4];
  [self.groupsStack setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 0)];
  [self.groupsStack setTranslatesAutoresizingMaskIntoConstraints:NO];

  self.keyboard = [[ConfigurationMacKeyboard alloc] init];
  [self.keyboard setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationBlockView *keyboardCard = [[ConfigurationBlockView alloc] init];
  [keyboardCard setTranslatesAutoresizingMaskIntoConstraints:NO];
  [keyboardCard addSubview:self.keyboard];
  NSLayoutConstraint *fill = [self.keyboard.widthAnchor constraintEqualToAnchor:keyboardCard.widthAnchor constant:-32];
  fill.priority = 750;
  [NSLayoutConstraint activateConstraints:@[
    fill,
    [self.keyboard.widthAnchor constraintLessThanOrEqualToConstant:kMacKeyboardUnitsWide * 40],
    [self.keyboard.widthAnchor constraintGreaterThanOrEqualToConstant:kMacKeyboardUnitsWide * 20],
    [self.keyboard.heightAnchor constraintEqualToAnchor:self.keyboard.widthAnchor multiplier:kMacKeyboardUnitsTall / kMacKeyboardUnitsWide],
    [self.keyboard.topAnchor constraintEqualToAnchor:keyboardCard.topAnchor constant:16],
    [self.keyboard.bottomAnchor constraintEqualToAnchor:keyboardCard.bottomAnchor constant:-16],
    [self.keyboard.centerXAnchor constraintEqualToAnchor:keyboardCard.centerXAnchor],
  ]];

  self.selectionStack = [NSStackView stackViewWithViews:@[]];
  [self.selectionStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.selectionStack setAlignment:NSLayoutAttributeLeading];
  [self.selectionStack setSpacing:10];
  [self.selectionStack setEdgeInsets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  ConfigurationBlockView *selectionCard = [[ConfigurationBlockView alloc] init];
  [selectionCard setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.selectionStack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [selectionCard addSubview:self.selectionStack];
  [NSLayoutConstraint activateConstraints:@[
    [self.selectionStack.topAnchor constraintEqualToAnchor:selectionCard.topAnchor], [self.selectionStack.bottomAnchor constraintEqualToAnchor:selectionCard.bottomAnchor],
    [self.selectionStack.leadingAnchor constraintEqualToAnchor:selectionCard.leadingAnchor], [self.selectionStack.trailingAnchor constraintEqualToAnchor:selectionCard.trailingAnchor],
  ]];

  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  // The colors are explained in a popover from a button right under the keyboard.
  NSButton *legend = [NSButton buttonWithTitle:@"Key colors" target:self action:@selector(legendPressed:)];
  [legend setImage:[NSImage imageWithSystemSymbolName:@"paintpalette" accessibilityDescription:nil]];
  [legend setImagePosition:NSImageLeft];
  [legend setBezelStyle:NSBezelStyleRounded];
  [legend setControlSize:NSControlSizeSmall];
  [legend setIdentifier:@"keyboard-legend"];
  [legend setToolTip:@"What the colors on the keyboard mean"];
  NSStackView *legendRow = [NSStackView stackViewWithViews:@[[MWMComponents spacer], legend]];   // at the right of the keyboard
  NSStackView *main = [NSStackView stackViewWithViews:@[keyboardCard, legendRow, selectionCard, spacer]];
  [main setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [main setAlignment:NSLayoutAttributeLeading];
  [main setSpacing:12];
  [main setEdgeInsets:NSEdgeInsetsMake(8, 0, 16, 20)];
  [main setTranslatesAutoresizingMaskIntoConstraints:NO];
  [main setCustomSpacing:6 afterView:keyboardCard];
  [main setCustomSpacing:16 afterView:legendRow];
  for (NSView *view in @[keyboardCard, legendRow, selectionCard]) [[view.widthAnchor constraintEqualToAnchor:main.widthAnchor constant:-20] setActive:YES];

  [self addSubview:self.groupsStack];
  [self addSubview:main];
  [NSLayoutConstraint activateConstraints:@[
    [self.groupsStack.topAnchor constraintEqualToAnchor:self.topAnchor], [self.groupsStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [self.groupsStack.widthAnchor constraintEqualToConstant:kGroupsWidth + 20],
    [main.topAnchor constraintEqualToAnchor:self.topAnchor], [main.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [main.leadingAnchor constraintEqualToAnchor:self.groupsStack.trailingAnchor constant:16], [main.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
  ]];
}

#pragma mark - Model

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
  _selectedKeyName = nil;
  [self reload];
}

- (void)setGroupName:(NSString *)groupName {
  _groupName = [groupName copy];
  _selectedKeyName = nil;
  [self reload];
}

- (void)reload {
  if (self.document == nil) return;
  self.index = [MWMShortcutIndex indexForDocument:self.document];
  NSArray *names = [self.index.groups valueForKey:@"name"];
  if (_groupName == nil || ![names containsObject:_groupName]) _groupName = [names firstObject];
  [self rebuildGroups];
  [self rebuildKeyboard];
  [self rebuildSelection];
}

- (MWMModifierGroup *)currentGroup {
  for (MWMModifierGroup *group in self.index.groups) if ([group.name isEqualToString:self.groupName ?: @""]) return group;
  return nil;
}

// The modifiers that go with the group being shown (none for Custom, which is every other set).
- (NSArray<NSString *> *)groupModifiers {
  MWMModifierGroup *group = [self currentGroup];
  return group.custom ? @[] : group.modifierNames ?: @[];
}

// The modifiers whose keys are shown: the group's, or while picking in Custom the ones toggled on.
- (NSArray<NSString *> *)effectiveModifiers {
  if (self.pickerMode && [[self currentGroup] custom]) return self.customModifiers ?: @[];
  return [self groupModifiers];
}

#pragma mark - Groups

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  return [MWMComponents labelWithText:text font:[NSFont systemFontOfSize:size weight:weight] color:color];
}

- (void)rebuildGroups {
  for (NSView *view in [[self.groupsStack arrangedSubviews] copy]) {
    [self.groupsStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  // Heading with the Manage button at its right.
  NSTextField *heading = [self labelWithText:@"GROUPS" size:11 color:[MWMTheme textTertiary] weight:NSFontWeightSemibold];
  NSView *gap = [MWMComponents spacer];
  NSButton *manage = [NSButton buttonWithTitle:@"Manage" target:self action:@selector(groupsPressed:)];
  [manage setBezelStyle:NSBezelStyleRounded];
  [manage setControlSize:NSControlSizeSmall];
  [manage setFont:[MWMTheme fontCaption]];
  [manage setIdentifier:@"manage-groups"];
  NSStackView *top = [NSStackView stackViewWithViews:@[heading, gap, manage]];
  [top setAlignment:NSLayoutAttributeCenterY];
  [self.groupsStack addArrangedSubview:top];
  [[top.widthAnchor constraintEqualToConstant:kGroupsWidth] setActive:YES];
  [self.groupsStack setCustomSpacing:8 afterView:top];

  __weak ConfigurationKeyboardMapView *weakSelf = self;
  for (MWMModifierGroup *group in self.index.groups) {
    BOOL selected = [group.name isEqualToString:self.groupName ?: @""];
    NSString *name = group.name;
    NSView *detail = group.custom ? [self labelWithText:@"other combinations" size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]
                                  : [ConfigurationKeyViews modifierCaps:group.modifierNames size:20];
    NSView *row = [MWMComponents countRowWithTitle:group.name count:group.count detail:detail detailSpacing:6 insets:NSEdgeInsetsMake(10, 12, 10, 12)
                                         boldTitle:YES selected:selected selectedColor:[MWMTheme groupColor] onClick:^{ weakSelf.groupName = name; }];
    [row setIdentifier:[@"group-" stringByAppendingString:group.name]];
    [self.groupsStack addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToConstant:kGroupsWidth] setActive:YES];
  }
}

- (void)groupsPressed:(id)sender {
  [self.delegate keyboardMapViewWantsGroups:self];
}

#pragma mark - Keyboard

// The Mac layout (see ConfigurationMacKeyboard).
+ (NSArray<ConfigurationMapKey *> *)buildKeys {
  return [ConfigurationMacKeyboard buildKeys];
}

- (void)rebuildKeyboard {
  for (NSView *view in [[self.keyboard subviews] copy]) [view removeFromSuperview];
  NSArray *keys = [[self class] buildKeys];
  NSArray *modifiers = [self effectiveModifiers];
  __weak ConfigurationKeyboardMapView *weakSelf = self;
  for (ConfigurationMapKey *key in keys) {
    [self.keyboard addSubview:key];
    if (key.modifier) {
      // The selected group's modifier keys (the left ones, which are the ones that build a group), in the group's color, still dashed.
      BOOL inGroup = key.modifierName != nil && [modifiers containsObject:key.modifierName] && !(self.pickerMode && [[self currentGroup] custom]);
      key.state = inGroup ? MapKeyStateGroup : MapKeyStateFree;
      [key setNeedsDisplay:YES];
      continue;
    }
    NSString *name = key.keyName;
    [self styleKey:key modifiers:modifiers];
    key.selected = [name isEqualToString:self.selectedKeyName ?: @""];
    key.onClick = ^{ [weakSelf selectKeyNamed:name]; };
  }
  self.keyboard.keys = keys;
  self.keys = keys;
  // Choosing keys for a shortcut that isn't in a group: its modifiers are built on this same keyboard.
  if (self.pickerMode && [[self currentGroup] custom]) {
    [self.keyboard showModifierPickerWithSelected:modifiers dimOthers:NO toggle:^(NSString *name) { [weakSelf toggleModifierNamed:name]; }];
  }
  [self.keyboard setNeedsLayout:YES];
}

// A key's color in the current group: what its shortcut does, or conflict / reserved / free.
- (void)styleKey:(ConfigurationMapKey *)key modifiers:(NSArray<NSString *> *)modifiers {
  MWMShortcutInfo *info = [self infoForKeyName:key.keyName];
  key.tint = nil;
  if (info != nil) {
    key.state = info.conflict ? MapKeyStateConflict : MapKeyStateTaken;
    key.tint = [ConfigurationKeyViews colorForKind:info.kind];
  } else if (([[self currentGroup] custom] == NO || self.pickerMode) && [MWMReservedShortcuts reasonForKeyName:key.keyName modifierNames:modifiers] != nil && [modifiers count] > 0) {
    key.state = MapKeyStateReserved;
  } else {
    key.state = MapKeyStateFree;
  }
  [key setNeedsDisplay:YES];
}

// The shortcut on this key in the group being shown, if any.
- (MWMShortcutInfo *)infoForKeyName:(NSString *)keyName {
  MWMModifierGroup *group = [self currentGroup];
  for (MWMShortcutInfo *info in self.index.shortcuts) {
    if (![info.keyName isEqualToString:keyName]) continue;
    if (self.ignoredBinding != nil && info.binding == self.ignoredBinding) continue;
    if (self.pickerMode && group.custom) {
      if ([[MWMShortcut stringFromModifierNames:info.modifierNames] isEqualToString:[MWMShortcut stringFromModifierNames:self.customModifiers ?: @[]]]) return info;
      continue;
    }
    BOOL inGroup = group.custom ? (info.groupName == nil && [info.modifierNames count] > 0) : [info.groupName isEqualToString:group.name];
    if (inGroup) return info;
  }
  return nil;
}

- (void)legendPressed:(NSButton *)sender {
  if (self.legendPopover.shown) { [self.legendPopover close]; return; }
  NSViewController *controller = [[NSViewController alloc] init];
  controller.view = [self legendView];
  self.legendPopover = [[NSPopover alloc] init];
  [self.legendPopover setBehavior:NSPopoverBehaviorTransient];
  [self.legendPopover setContentViewController:controller];
  [self.legendPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}

// What the colors on the keyboard mean, for the Legend popover.
- (NSView *)legendView {
  NSArray *entries = @[@[@"Move to slot", [MWMTheme accent]], @[@"Windows and apps", [MWMTheme success]], @[@"Features", [MWMTheme feature]],
                       @[@"Conflict", [MWMTheme warning]], @[@"Reserved by macOS", [MWMTheme reserved]], @[@"Selected group", [MWMTheme groupColor]]];
  NSMutableArray *rows = [NSMutableArray array];
  [rows addObject:[self labelWithText:@"Key colors" size:13 color:[MWMTheme textPrimary] weight:NSFontWeightMedium]];
  for (NSArray *entry in entries) {
    NSView *dot = [[NSView alloc] init];
    [dot setWantsLayer:YES];
    [[dot layer] setCornerRadius:3];
    [[dot layer] setBackgroundColor:[[(NSColor *)entry[1] colorWithAlphaComponent:0.6] CGColor]];
    [dot setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[[dot.widthAnchor constraintEqualToConstant:10], [dot.heightAnchor constraintEqualToConstant:10]]];
    NSTextField *label = [self labelWithText:entry[0] size:12 color:[MWMTheme textPrimary] weight:NSFontWeightRegular];
    NSStackView *item = [NSStackView stackViewWithViews:@[dot, label]];
    [item setSpacing:MWMSpacingS];
    [item setAlignment:NSLayoutAttributeCenterY];
    [rows addObject:item];
  }
  // The note wraps inside the popover, whose padding is the design system's.
  NSTextField *note = [MWMComponents wrappingLabelWithText:@"Dashed keys are modifiers. They make the groups, so they can't hold a shortcut." size:11 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
  [note setPreferredMaxLayoutWidth:228];
  [rows addObject:note];
  NSStackView *stack = [NSStackView stackViewWithViews:rows];
  [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [stack setAlignment:NSLayoutAttributeLeading];
  [stack setSpacing:MWMSpacingS];
  [stack setEdgeInsets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  [[stack.widthAnchor constraintEqualToConstant:228 + 2 * MWMSpacingL] setActive:YES];
  [[note.widthAnchor constraintEqualToConstant:228] setActive:YES];
  return stack;
}

- (void)selectKeyNamed:(NSString *)keyName {
  _selectedKeyName = [keyName copy];
  for (ConfigurationMapKey *key in self.keys) key.selected = [key.keyName isEqualToString:keyName] && !key.modifier;
  [self.keys makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:@YES];
  [self rebuildSelection];
}

#pragma mark - Selected key

// The area of a slot by name, from the file or the presets.
- (BOOL)getRect:(CGRect *)rect forSlotNamed:(NSString *)name {
  for (MWMConfigEntry *entry in self.document.positions) {
    if ([entry.name isEqualToString:name]) return [MWMSlots getRect:rect fromFormula:[entry.value description]];
  }
  MWMSlot *preset = [MWMSlots presetNamed:name];
  if (preset == nil) return NO;
  *rect = preset.rect;
  return YES;
}

// "To" followed by a colored icon tile, the title and detail, and a slot preview.
- (NSArray<NSView *> *)resultViewsForInfo:(MWMShortcutInfo *)info {
  NSColor *color = [ConfigurationKeyViews colorForKind:info.kind];
  NSView *tile = [MWMComponents iconTileWithSymbol:[ConfigurationKeyViews symbolForKind:info.kind] color:color size:34];
  NSTextField *title = [self labelWithText:info.title size:14 color:[MWMTheme textPrimary] weight:NSFontWeightMedium];
  NSMutableArray *texts = [NSMutableArray arrayWithObject:title];
  if ([info.detail length] > 0) [texts addObject:[self labelWithText:info.detail size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]];
  NSStackView *text = [NSStackView stackViewWithViews:texts];
  [text setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [text setAlignment:NSLayoutAttributeLeading];
  [text setSpacing:1];
  NSMutableArray *views = [NSMutableArray arrayWithObjects:tile, text, nil];
  MWMAction *action = [MWMAction parse:info.binding.action];
  CGRect rect;
  if (info.kind == MWMShortcutKindMoveToSlot && [self getRect:&rect forSlotNamed:action.a]) {
    NSView *gap = [MWMComponents spacer];
    ConfigurationSlotThumbnail *preview = [[ConfigurationSlotThumbnail alloc] init];
    preview.rect = rect;
    preview.valid = YES;
    [preview setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[[preview.widthAnchor constraintEqualToConstant:84], [preview.heightAnchor constraintEqualToConstant:50]]];
    [views addObject:gap];
    [views addObject:preview];
  }
  return views;
}

- (NSTextField *)smallWord:(NSString *)text {
  return [self labelWithText:text size:12 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
}

- (NSView *)boxWithLabel:(NSString *)label views:(NSArray<NSView *> *)views height:(CGFloat)height identifier:(NSString *)identifier {
  ConfigurationBlockView *box = [[ConfigurationBlockView alloc] init];
  [box setTranslatesAutoresizingMaskIntoConstraints:NO];
  [box setIdentifier:identifier];
  NSTextField *name = [self smallWord:label];
  [name setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSStackView *content = [NSStackView stackViewWithViews:views];
  [content setSpacing:12];
  [content setAlignment:NSLayoutAttributeCenterY];
  [content setTranslatesAutoresizingMaskIntoConstraints:NO];
  [box addSubview:name];
  [box addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [box.heightAnchor constraintEqualToConstant:height],
    [name.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16], [name.widthAnchor constraintEqualToConstant:52], [name.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
    [content.leadingAnchor constraintEqualToAnchor:name.trailingAnchor constant:8], [content.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16],
    [content.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
  ]];
  return box;
}

- (void)rebuildSelection {
  for (NSView *view in [[self.selectionStack arrangedSubviews] copy]) {
    [self.selectionStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  if (self.pickerMode) { [self rebuildPickerSelection]; return; }
  NSString *keyName = self.selectedKeyName;
  if (keyName == nil) {
    [self.selectionStack addArrangedSubview:[self labelWithText:@"Click a key to see what it does, or to give it a shortcut." size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular]];
    NSButton *newShortcut = [MWMComponents secondaryButtonWithTitle:@"New Shortcut" symbol:@"plus" target:self action:@selector(newPressed:)];
    [newShortcut setIdentifier:@"new-shortcut"];
    [self.selectionStack addArrangedSubview:newShortcut];
    return;
  }
  MWMModifierGroup *group = [self currentGroup];
  MWMShortcutInfo *info = [self infoForKeyName:keyName];
  NSArray *modifiers = info != nil ? info.modifierNames : [self groupModifiers];
  NSColor *amber = (info != nil && info.conflict) ? [MWMTheme warning] : nil;

  // Press [group + keys] → To [what it does]
  NSMutableArray *keyViews = [NSMutableArray array];
  if (info != nil ? info.groupName != nil : !group.custom) [keyViews addObject:[ConfigurationKeyViews pillWithText:info != nil ? info.groupName : group.name tint:amber]];
  [keyViews addObject:[ConfigurationKeyViews keyCapsForModifiers:modifiers keyName:keyName size:26 tint:amber]];
  NSStackView *keys = [NSStackView stackViewWithViews:keyViews];
  [keys setSpacing:8];
  [keys setAlignment:NSLayoutAttributeCenterY];

  NSMutableArray *line = [NSMutableArray array];
  NSString *reason = nil;
  if (info != nil) {
    [line addObjectsFromArray:[self resultViewsForInfo:info]];
  } else {
    reason = group.custom ? nil : [MWMReservedShortcuts reasonForKeyName:keyName modifierNames:modifiers];
    NSString *free = reason != nil ? reason : @"Nothing yet. This key is free in this group.";
    [line addObject:[self labelWithText:free size:13 color:reason != nil ? [MWMTheme warning] : [MWMTheme textSecondary] weight:NSFontWeightRegular]];
  }
  // "Press" and "To" each get their own full-width box, with fixed heights so the page doesn't shift.
  for (NSView *box in @[[self boxWithLabel:@"Press" views:@[keys] height:58 identifier:@"press-box"], [self boxWithLabel:@"To" views:line height:68 identifier:@"to-box"]]) {
    [self.selectionStack addArrangedSubview:box];
    [[box.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor constant:-32] setActive:YES];
  }

  // Buttons on their own row, right-aligned; a conflict chip sits to their left.
  NSMutableArray *buttonRow = [NSMutableArray array];
  NSButton *newShortcut = [MWMComponents secondaryButtonWithTitle:@"New Shortcut" symbol:@"plus" target:self action:@selector(newPressed:)];   // always there
  [newShortcut setIdentifier:@"new-shortcut"];
  [buttonRow addObject:newShortcut];
  NSView *spacer = [MWMComponents spacer];
  [buttonRow addObject:spacer];
  if (info != nil) {
    if (info.conflict) {
      NSString *otherTitle = nil;
      for (MWMShortcutInfo *other in self.index.shortcuts) {
        if (other != info && [other.identity isEqualToString:info.identity] && other.binding.enabled) { otherTitle = other.title; break; }
      }
      NSString *chipText = [NSString stringWithFormat:@"⚠ Same keys as \"%@\". Only one can work.", otherTitle ?: @"another shortcut"];
      MWMChipView *chip = [MWMChipView chipWithText:chipText color:[MWMTheme warning]];
      [chip setIdentifier:@"conflict-chip"];
      [buttonRow addObject:chip];
    }
    NSButton *remove = [MWMComponents secondaryButtonWithTitle:@"Remove" target:self action:@selector(removePressed:)];
    NSButton *edit = [MWMComponents primaryButtonWithTitle:@"Edit" target:self action:@selector(editPressed:)];
    [buttonRow addObject:remove];
    [buttonRow addObject:edit];
  } else if (reason == nil && !group.custom) {
    NSButton *add = [MWMComponents primaryButtonWithTitle:@"Add Shortcut" target:self action:@selector(addPressed:)];
    [buttonRow addObject:add];
  }
  NSStackView *buttons = [NSStackView stackViewWithViews:buttonRow];
  [buttons setSpacing:8];
  [buttons setAlignment:NSLayoutAttributeCenterY];
  [self.selectionStack addArrangedSubview:buttons];
  [[buttons.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor constant:-32] setActive:YES];
}

#pragma mark - Picker

- (void)setPickerMode:(BOOL)pickerMode {
  _pickerMode = pickerMode;
  [self reload];
}

// A click on ctrl, opt, shift or ⌘ on the keyboard while choosing keys for an ungrouped shortcut.
- (void)toggleModifierNamed:(NSString *)name {
  NSMutableSet *chosen = [NSMutableSet setWithArray:self.customModifiers ?: @[]];
  if ([chosen containsObject:name]) [chosen removeObject:name]; else [chosen addObject:name];
  NSMutableArray *ordered = [NSMutableArray array];
  for (NSString *each in @[@"ctrl", @"alt", @"shift", @"cmd"]) if ([chosen containsObject:each]) [ordered addObject:each];
  self.customModifiers = ordered;
  [self reload];
}

- (void)rebuildPickerSelection {
  MWMModifierGroup *group = [self currentGroup];
  NSString *keyName = self.selectedKeyName;
  NSArray *modifiers = [self effectiveModifiers];
  NSMutableArray *keyViews = [NSMutableArray array];
  if (keyName == nil) {
    [keyViews addObject:[self labelWithText:@"Click a key on the keyboard." size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular]];
  } else {
    if (!group.custom) [keyViews addObject:[ConfigurationKeyViews pillWithText:group.name]];
    [keyViews addObject:[ConfigurationKeyViews keyCapsForModifiers:modifiers keyName:keyName size:26]];
  }
  [self.selectionStack addArrangedSubview:[self boxWithLabel:@"Keys" views:keyViews height:58 identifier:@"pick-keys"]];
  [[[self.selectionStack arrangedSubviews].lastObject.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor constant:-32] setActive:YES];

  if (group.custom) {
    [self.selectionStack addArrangedSubview:[self labelWithText:@"Click ctrl, opt, shift or ⌘ on the left of the keyboard to change the modifiers." size:12 color:[MWMTheme textTertiary] weight:NSFontWeightRegular]];
  }

  // What stands in the way of these keys.
  NSString *warning = nil;
  BOOL blocked = keyName == nil || [modifiers count] == 0;
  if (keyName != nil) {
    NSString *reason = [MWMReservedShortcuts reasonForKeyName:keyName modifierNames:modifiers];
    MWMShortcutInfo *taken = [self infoForKeyName:keyName];
    if (reason != nil) { warning = reason; blocked = YES; }
    else if (taken != nil) warning = [NSString stringWithFormat:@"Already used by \"%@\". Both would fire on the same keys.", taken.title];
  }
  NSTextField *note = [self labelWithText:warning ?: @" " size:12 color:[MWMTheme warning] weight:NSFontWeightRegular];
  [note setIdentifier:@"pick-warning"];
  [self.selectionStack addArrangedSubview:note];

  NSView *spacer = [MWMComponents spacer];
  NSButton *cancel = [MWMComponents secondaryButtonWithTitle:@"Cancel" target:self action:@selector(cancelPickPressed:)];
  NSButton *use = [MWMComponents primaryButtonWithTitle:@"Use these keys" target:self action:@selector(usePickPressed:)];
  [use setEnabled:!blocked];
  [use setIdentifier:@"pick-use"];
  NSStackView *buttons = [NSStackView stackViewWithViews:@[spacer, use, cancel]];
  [buttons setSpacing:8];
  [self.selectionStack addArrangedSubview:buttons];
  [[buttons.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor constant:-32] setActive:YES];
}

- (void)cancelPickPressed:(id)sender {
  if ([self.delegate respondsToSelector:@selector(keyboardMapViewDidCancelPicking:)]) [self.delegate keyboardMapViewDidCancelPicking:self];
}

- (void)usePickPressed:(id)sender {
  MWMModifierGroup *group = [self currentGroup];
  if (self.selectedKeyName == nil || ![self.delegate respondsToSelector:@selector(keyboardMapView:didPickKey:modifierNames:groupName:)]) return;
  [self.delegate keyboardMapView:self didPickKey:self.selectedKeyName modifierNames:[self effectiveModifiers] groupName:group.custom ? nil : group.name];
}

#pragma mark - Actions

- (void)editPressed:(id)sender {
  MWMShortcutInfo *info = [self infoForKeyName:self.selectedKeyName ?: @""];
  if (info != nil) [self.delegate keyboardMapView:self wantsToEditBindingAtIndex:info.index];
}

- (void)newPressed:(id)sender {
  [self.delegate keyboardMapView:self wantsNewShortcutInGroup:nil keyName:nil];
}

- (void)addPressed:(id)sender {
  MWMModifierGroup *group = [self currentGroup];
  if (self.selectedKeyName != nil) [self.delegate keyboardMapView:self wantsNewShortcutInGroup:group.custom ? nil : group.name keyName:self.selectedKeyName];
}

- (void)removePressed:(id)sender {
  if (self.confirmsRemoval) {
    MWMShortcutInfo *info = [self infoForKeyName:self.selectedKeyName ?: @""];
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindDanger];
    [alert setMessageText:[NSString stringWithFormat:@"Remove \"%@\"?", info.title]];
    [alert setInformativeText:@"The shortcut is taken out of your configuration."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addDestructiveButtonWithTitle:@"Remove"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  [self removeSelected];
}

- (void)removeSelected {
  MWMShortcutInfo *info = [self infoForKeyName:self.selectedKeyName ?: @""];
  if (info == nil) return;
  [self.document.bindings removeObjectIdenticalTo:info.binding];
  _selectedKeyName = nil;
  [self.delegate keyboardMapViewDidChangeDocument:self];
  [self reload];
}

@end
