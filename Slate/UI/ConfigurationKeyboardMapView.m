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
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "SlateAction.h"
#import "SlateConfigDocument.h"
#import "SlateReservedShortcuts.h"
#import "SlateShortcut.h"
#import "SlateShortcutIndex.h"
#import "SlateSlots.h"

static const CGFloat kGroupsWidth = 188;
static const CGFloat kUnitsWide = 19.5;
static const CGFloat kUnitsTall = 5.8;

typedef NS_ENUM(NSInteger, MapKeyState) {
  MapKeyStateFree,
  MapKeyStateTaken,      // has a shortcut in this group (colored by what it does)
  MapKeyStateConflict,
  MapKeyStateReserved,   // macOS uses it with this group's modifiers
};

#pragma mark - A key

@interface ConfigurationMapKey : NSView
@property (copy) NSString *keyName;
@property (copy) NSString *label;
@property (assign) MapKeyState state;
@property (strong, nullable) NSColor *tint;
@property (assign) BOOL selected;
@property (assign) BOOL modifier;   // drawn dashed; can't hold a shortcut
@property (assign) NSRect units;    // x, y, width, height in key units
@property (copy) void (^onClick)(void);
@end

@implementation ConfigurationMapKey
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event { if (!self.modifier && self.onClick) self.onClick(); }
- (void)drawRect:(NSRect)dirtyRect {
  CGFloat radius = MIN(7, NSHeight([self bounds]) * 0.22);
  NSRect rect = NSInsetRect([self bounds], 1, 1);
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
  NSColor *fill, *stroke, *text;
  switch (self.state) {
    case MapKeyStateTaken:
      fill = [self.tint colorWithAlphaComponent:0.20]; stroke = [self.tint colorWithAlphaComponent:0.55]; text = self.tint; break;
    case MapKeyStateConflict:
      fill = [[MWMTheme warning] colorWithAlphaComponent:0.25]; stroke = [MWMTheme warning]; text = [MWMTheme warning]; break;
    case MapKeyStateReserved:
      fill = [[MWMTheme reserved] colorWithAlphaComponent:0.12]; stroke = [[MWMTheme reserved] colorWithAlphaComponent:0.5]; text = [MWMTheme reserved]; break;
    default:
      fill = [[MWMTheme textPrimary] colorWithAlphaComponent:self.modifier ? 0.02 : 0.05]; stroke = [NSColor quaternaryLabelColor]; text = [MWMTheme textTertiary]; break;
  }
  [fill setFill];
  [path fill];
  [stroke setStroke];
  [path setLineWidth:0.8];
  if (self.modifier) { CGFloat dash[] = {3, 2}; [path setLineDash:dash count:2 phase:0]; }
  [path stroke];
  if (self.selected) {
    NSBezierPath *ring = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, -1, -1) xRadius:radius + 1 yRadius:radius + 1];
    [[MWMTheme accent] setStroke];
    [ring setLineWidth:2.2];
    [ring stroke];
  }
  CGFloat unit = NSHeight([self bounds]) / MAX(0.5, self.units.size.height);
  CGFloat size = MAX(7, unit * ([self.label length] > 2 ? 0.27 : 0.4));
  NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:size weight:NSFontWeightMedium], NSForegroundColorAttributeName: text};
  NSSize textSize = [self.label sizeWithAttributes:attributes];
  [self.label drawAtPoint:NSMakePoint(NSMidX([self bounds]) - textSize.width / 2, NSMidY([self bounds]) - textSize.height / 2) withAttributes:attributes];
}
@end

#pragma mark - The keyboard

// A Mac keyboard drawn in key units; the keys follow the width they're given.
@interface ConfigurationMacKeyboard : NSView
@property (copy) NSArray<ConfigurationMapKey *> *keys;
@end

@implementation ConfigurationMacKeyboard
- (BOOL)isFlipped { return YES; }
- (void)layout {
  [super layout];
  CGFloat unit = NSWidth([self bounds]) / kUnitsWide;
  CGFloat gap = unit * 0.12;
  for (ConfigurationMapKey *key in self.keys) {
    NSRect u = key.units;
    [key setFrame:NSMakeRect(u.origin.x * unit + gap / 2, u.origin.y * unit + gap / 2, u.size.width * unit - gap, u.size.height * unit - gap)];
  }
}
@end

#pragma mark - Page

@interface ConfigurationKeyboardMapView ()
@property (strong) SlateShortcutIndex *index;
@property (strong) NSStackView *groupsStack;
@property (strong) ConfigurationMacKeyboard *keyboard;
@property (strong) NSStackView *selectionStack;
@property (strong) NSStackView *legendStack;
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
    [self.keyboard.widthAnchor constraintLessThanOrEqualToConstant:kUnitsWide * 40],
    [self.keyboard.widthAnchor constraintGreaterThanOrEqualToConstant:kUnitsWide * 20],
    [self.keyboard.heightAnchor constraintEqualToAnchor:self.keyboard.widthAnchor multiplier:kUnitsTall / kUnitsWide],
    [self.keyboard.topAnchor constraintEqualToAnchor:keyboardCard.topAnchor constant:16],
    [self.keyboard.bottomAnchor constraintEqualToAnchor:keyboardCard.bottomAnchor constant:-16],
    [self.keyboard.centerXAnchor constraintEqualToAnchor:keyboardCard.centerXAnchor],
  ]];

  self.legendStack = [NSStackView stackViewWithViews:@[]];
  [self.legendStack setSpacing:16];

  self.selectionStack = [NSStackView stackViewWithViews:@[]];
  [self.selectionStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.selectionStack setAlignment:NSLayoutAttributeLeading];
  [self.selectionStack setSpacing:10];
  [self.selectionStack setEdgeInsets:NSEdgeInsetsMake(16, 16, 14, 16)];
  ConfigurationBlockView *selectionCard = [[ConfigurationBlockView alloc] init];
  [selectionCard setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.selectionStack setTranslatesAutoresizingMaskIntoConstraints:NO];
  [selectionCard addSubview:self.selectionStack];
  [NSLayoutConstraint activateConstraints:@[
    [selectionCard.heightAnchor constraintEqualToConstant:222],
    [self.selectionStack.topAnchor constraintEqualToAnchor:selectionCard.topAnchor],
    [self.selectionStack.leadingAnchor constraintEqualToAnchor:selectionCard.leadingAnchor], [self.selectionStack.trailingAnchor constraintEqualToAnchor:selectionCard.trailingAnchor],
  ]];

  NSTextField *note = [self labelWithText:@"Dashed keys are modifiers. They make the groups, so they can't hold a shortcut." size:11 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
  NSStackView *main = [NSStackView stackViewWithViews:@[keyboardCard, self.legendStack, note, selectionCard, spacer]];
  [main setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [main setAlignment:NSLayoutAttributeLeading];
  [main setSpacing:12];
  [main setEdgeInsets:NSEdgeInsetsMake(8, 0, 16, 20)];
  [main setTranslatesAutoresizingMaskIntoConstraints:NO];
  [main setCustomSpacing:6 afterView:keyboardCard];
  [main setCustomSpacing:4 afterView:self.legendStack];
  [main setCustomSpacing:16 afterView:note];
  for (NSView *view in @[keyboardCard, selectionCard]) [[view.widthAnchor constraintEqualToAnchor:main.widthAnchor constant:-20] setActive:YES];

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

- (void)setDocument:(SlateConfigDocument *)document {
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
  self.index = [SlateShortcutIndex indexForDocument:self.document];
  NSArray *names = [self.index.groups valueForKey:@"name"];
  if (_groupName == nil || ![names containsObject:_groupName]) _groupName = [names firstObject];
  [self rebuildGroups];
  [self rebuildKeyboard];
  [self rebuildSelection];
}

- (SlateModifierGroup *)currentGroup {
  for (SlateModifierGroup *group in self.index.groups) if ([group.name isEqualToString:self.groupName ?: @""]) return group;
  return nil;
}

// The modifiers that go with the group being shown (none for Custom, which is every other set).
- (NSArray<NSString *> *)groupModifiers {
  SlateModifierGroup *group = [self currentGroup];
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
  NSView *gap = [[NSView alloc] init];
  [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
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
  for (SlateModifierGroup *group in self.index.groups) {
    BOOL selected = [group.name isEqualToString:self.groupName ?: @""];
    NSView *row = [[NSView alloc] init];
    [row setTranslatesAutoresizingMaskIntoConstraints:NO];
    ConfigurationClickView *click = [[ConfigurationClickView alloc] init];
    click.cornerRadius = 10;
    click.selected = selected;
    NSString *name = group.name;
    click.onClick = ^{ weakSelf.groupName = name; };
    NSTextField *title = [self labelWithText:group.name size:13 color:selected ? [MWMTheme accent] : [MWMTheme textPrimary] weight:NSFontWeightMedium];
    NSTextField *count = [self labelWithText:[NSString stringWithFormat:@"%lu", (unsigned long)group.count] size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    NSView *space = [[NSView alloc] init];
    [space setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *line = [NSStackView stackViewWithViews:@[title, space, count]];
    [line setAlignment:NSLayoutAttributeFirstBaseline];
    NSView *caps = group.custom ? [self labelWithText:@"other combinations" size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]
                                : [ConfigurationKeyViews modifierCaps:group.modifierNames size:20];
    NSStackView *stack = [NSStackView stackViewWithViews:@[line, caps]];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setAlignment:NSLayoutAttributeLeading];
    [stack setSpacing:6];
    [stack setEdgeInsets:NSEdgeInsetsMake(10, 12, 10, 12)];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[line.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-24] setActive:YES];
    [row addSubview:stack];
    [row addSubview:click positioned:NSWindowAbove relativeTo:nil];
    for (NSView *view in @[stack, click]) {
      [view setTranslatesAutoresizingMaskIntoConstraints:NO];
      [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:row.topAnchor], [view.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [view.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [view.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
      ]];
    }
    [row setIdentifier:[@"group-" stringByAppendingString:group.name]];
    [self.groupsStack addArrangedSubview:row];
    [[row.widthAnchor constraintEqualToConstant:kGroupsWidth] setActive:YES];
  }
}

- (void)groupsPressed:(id)sender {
  [self.delegate keyboardMapViewWantsGroups:self];
}

#pragma mark - Keyboard

// The Mac layout: name, label, width in units. A name starting with "-" is a modifier (not bindable).
+ (NSArray<ConfigurationMapKey *> *)buildKeys {
  NSMutableArray *keys = [NSMutableArray array];
  void (^add)(NSString *, NSString *, CGFloat, CGFloat, CGFloat, CGFloat, BOOL) = ^(NSString *name, NSString *label, CGFloat x, CGFloat y, CGFloat w, CGFloat h, BOOL modifier) {
    ConfigurationMapKey *key = [[ConfigurationMapKey alloc] init];
    key.keyName = name;
    key.label = label ?: [SlateShortcut displayForKeyName:name];
    key.units = NSMakeRect(x, y, w, h);
    key.modifier = modifier;
    [key setIdentifier:[(modifier ? @"modifier-" : @"key-") stringByAppendingString:name]];
    [keys addObject:key];
  };
  void (^row)(CGFloat, CGFloat, NSArray *) = ^(CGFloat x, CGFloat y, NSArray *items) {
    for (NSArray *item in items) {
      CGFloat w = [item[2] doubleValue];
      add(item[0], [item[1] length] > 0 ? item[1] : nil, x, y, w, 1, [item count] > 3);
      x += w;
    }
  };
  // Function row.
  CGFloat x = 0;
  add(@"esc", @"esc", x, 0, 1.5, 0.65, NO); x += 1.5;
  for (int i = 1; i <= 12; i++) { add([NSString stringWithFormat:@"f%d", i], [NSString stringWithFormat:@"F%d", i], x, 0, 1, 0.65, NO); x += 1; }
  add(@"power", @"⏻", x, 0, 1.5, 0.65, YES);
  NSArray *(^letters)(NSString *) = ^NSArray *(NSString *chars) {
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < [chars length]; i++) { NSString *c = [chars substringWithRange:NSMakeRange(i, 1)]; [items addObject:@[c, @"", @1]]; }
    return items;
  };
  row(0, 0.8, [[letters(@"`1234567890-=") ?: @[] arrayByAddingObject:@[@"delete", @"delete", @2]] copy]);
  row(0, 1.8, [[@[@[@"tab", @"tab", @1.5]] arrayByAddingObjectsFromArray:letters(@"qwertyuiop[]")] arrayByAddingObject:@[@"backslash", @"\\", @1.5]]);
  row(0, 2.8, [[@[@[@"caps", @"caps", @1.75]] arrayByAddingObjectsFromArray:letters(@"asdfghjkl;'")] arrayByAddingObject:@[@"return", @"return", @2.25]]);
  row(0, 3.8, [[@[@[@"shiftL", @"shift", @2.25, @1]] arrayByAddingObjectsFromArray:letters(@"zxcvbnm,./")] arrayByAddingObject:@[@"shiftR", @"shift", @2.75, @1]]);
  row(0, 4.8, @[@[@"fn", @"fn", @1, @1], @[@"ctrlL", @"ctrl", @1, @1], @[@"optL", @"opt", @1, @1], @[@"cmdL", @"⌘", @1.25, @1], @[@"space", @"", @5.5],
                @[@"cmdR", @"⌘", @1.25, @1], @[@"optR", @"opt", @1, @1], @[@"left", @"←", @1]]);
  add(@"up", @"↑", 13, 4.8, 1, 0.5, NO);
  add(@"down", @"↓", 13, 5.3, 1, 0.5, NO);
  add(@"right", @"→", 14, 4.8, 1, 1, NO);
  // Number pad.
  row(15.5, 0.8, @[@[@"padClear", @"clr", @1], @[@"pad=", @"=", @1], @[@"pad/", @"/", @1], @[@"pad*", @"*", @1]]);
  row(15.5, 1.8, @[@[@"pad7", @"7", @1], @[@"pad8", @"8", @1], @[@"pad9", @"9", @1], @[@"pad-", @"−", @1]]);
  row(15.5, 2.8, @[@[@"pad4", @"4", @1], @[@"pad5", @"5", @1], @[@"pad6", @"6", @1], @[@"pad+", @"+", @1]]);
  row(15.5, 3.8, @[@[@"pad1", @"1", @1], @[@"pad2", @"2", @1], @[@"pad3", @"3", @1]]);
  add(@"padEnter", @"↩", 18.5, 3.8, 1, 2, NO);
  row(15.5, 4.8, @[@[@"pad0", @"0", @2], @[@"pad.", @".", @1]]);
  return keys;
}

- (void)rebuildKeyboard {
  for (NSView *view in [[self.keyboard subviews] copy]) [view removeFromSuperview];
  NSArray *keys = [[self class] buildKeys];
  NSArray *modifiers = [self effectiveModifiers];
  __weak ConfigurationKeyboardMapView *weakSelf = self;
  for (ConfigurationMapKey *key in keys) {
    [self.keyboard addSubview:key];
    if (key.modifier) continue;
    NSString *name = key.keyName;
    [self styleKey:key modifiers:modifiers];
    key.selected = [name isEqualToString:self.selectedKeyName ?: @""];
    key.onClick = ^{ [weakSelf selectKeyNamed:name]; };
  }
  self.keyboard.keys = keys;
  self.keys = keys;
  [self.keyboard setNeedsLayout:YES];
  [self rebuildLegend];
}

// A key's color in the current group: what its shortcut does, or conflict / reserved / free.
- (void)styleKey:(ConfigurationMapKey *)key modifiers:(NSArray<NSString *> *)modifiers {
  SlateShortcutInfo *info = [self infoForKeyName:key.keyName];
  key.tint = nil;
  if (info != nil) {
    key.state = info.conflict ? MapKeyStateConflict : MapKeyStateTaken;
    key.tint = [ConfigurationKeyViews colorForKind:info.kind];
  } else if (([[self currentGroup] custom] == NO || self.pickerMode) && [SlateReservedShortcuts reasonForKeyName:key.keyName modifierNames:modifiers] != nil && [modifiers count] > 0) {
    key.state = MapKeyStateReserved;
  } else {
    key.state = MapKeyStateFree;
  }
  [key setNeedsDisplay:YES];
}

// The shortcut on this key in the group being shown, if any.
- (SlateShortcutInfo *)infoForKeyName:(NSString *)keyName {
  SlateModifierGroup *group = [self currentGroup];
  for (SlateShortcutInfo *info in self.index.shortcuts) {
    if (![info.keyName isEqualToString:keyName]) continue;
    if (self.ignoredBinding != nil && info.binding == self.ignoredBinding) continue;
    if (self.pickerMode && group.custom) {
      if ([[SlateShortcut stringFromModifierNames:info.modifierNames] isEqualToString:[SlateShortcut stringFromModifierNames:self.customModifiers ?: @[]]]) return info;
      continue;
    }
    BOOL inGroup = group.custom ? (info.groupName == nil && [info.modifierNames count] > 0) : [info.groupName isEqualToString:group.name];
    if (inGroup) return info;
  }
  return nil;
}

- (void)rebuildLegend {
  for (NSView *view in [[self.legendStack arrangedSubviews] copy]) {
    [self.legendStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  NSArray *entries = @[@[@"Move to slot", [MWMTheme accent]], @[@"Windows and apps", [MWMTheme success]], @[@"Features", [MWMTheme feature]],
                       @[@"Conflict", [MWMTheme warning]], @[@"Reserved by macOS", [MWMTheme reserved]]];
  for (NSArray *entry in entries) {
    NSView *dot = [[NSView alloc] init];
    [dot setWantsLayer:YES];
    [[dot layer] setCornerRadius:3];
    [[dot layer] setBackgroundColor:[[(NSColor *)entry[1] colorWithAlphaComponent:0.6] CGColor]];
    [dot setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[[dot.widthAnchor constraintEqualToConstant:9], [dot.heightAnchor constraintEqualToConstant:9]]];
    NSTextField *label = [self labelWithText:entry[0] size:11 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
    NSStackView *item = [NSStackView stackViewWithViews:@[dot, label]];
    [item setSpacing:5];
    [item setAlignment:NSLayoutAttributeCenterY];
    [self.legendStack addArrangedSubview:item];
  }
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
  for (SlateConfigEntry *entry in self.document.positions) {
    if ([entry.name isEqualToString:name]) return [SlateSlots getRect:rect fromFormula:[entry.value description]];
  }
  SlateSlot *preset = [SlateSlots presetNamed:name];
  if (preset == nil) return NO;
  *rect = preset.rect;
  return YES;
}

// "To" followed by a colored icon tile, the title and detail, and a slot preview.
- (NSArray<NSView *> *)resultViewsForInfo:(SlateShortcutInfo *)info {
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
  SlateAction *action = [SlateAction parse:info.binding.action];
  CGRect rect;
  if (info.kind == SlateShortcutKindMoveToSlot && [self getRect:&rect forSlotNamed:action.a]) {
    NSView *gap = [[NSView alloc] init];
    [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
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
    return;
  }
  SlateModifierGroup *group = [self currentGroup];
  SlateShortcutInfo *info = [self infoForKeyName:keyName];
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
    reason = group.custom ? nil : [SlateReservedShortcuts reasonForKeyName:keyName modifierNames:modifiers];
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
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [buttonRow addObject:spacer];
  if (info != nil) {
    if (info.conflict) {
      NSString *otherTitle = nil;
      for (SlateShortcutInfo *other in self.index.shortcuts) {
        if (other != info && [other.identity isEqualToString:info.identity] && other.binding.enabled) { otherTitle = other.title; break; }
      }
      NSString *chipText = [NSString stringWithFormat:@"⚠ Same keys as \"%@\". Only one can work.", otherTitle ?: @"another shortcut"];
      MWMChipView *chip = [MWMChipView chipWithText:chipText color:[MWMTheme warning]];
      [chip setIdentifier:@"conflict-chip"];
      [buttonRow addObject:chip];
    }
    NSButton *remove = [NSButton buttonWithTitle:@"Remove" target:self action:@selector(removePressed:)];
    NSButton *edit = [NSButton buttonWithTitle:@"Edit" target:self action:@selector(editPressed:)];
    [edit setKeyEquivalent:@"\r"];
    for (NSButton *button in @[remove, edit]) [button setBezelStyle:NSBezelStyleRounded];
    [buttonRow addObject:remove];
    [buttonRow addObject:edit];
  } else if (reason == nil && !group.custom) {
    NSButton *add = [NSButton buttonWithTitle:@"Add Shortcut" target:self action:@selector(addPressed:)];
    [add setBezelStyle:NSBezelStyleRounded];
    [add setKeyEquivalent:@"\r"];
    [buttonRow addObject:add];
  }
  if ([buttonRow count] > 1) {
    NSStackView *buttons = [NSStackView stackViewWithViews:buttonRow];
    [buttons setSpacing:8];
    [buttons setAlignment:NSLayoutAttributeCenterY];
    [self.selectionStack addArrangedSubview:buttons];
    [[buttons.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor constant:-32] setActive:YES];
  }
}

#pragma mark - Picker

- (void)setPickerMode:(BOOL)pickerMode {
  _pickerMode = pickerMode;
  [self reload];
}

- (void)toggleModifier:(NSButton *)button {
  NSMutableSet *chosen = [NSMutableSet setWithArray:self.customModifiers ?: @[]];
  NSString *name = button.identifier;
  if ([button state] == NSControlStateValueOn) [chosen addObject:name]; else [chosen removeObject:name];
  NSMutableArray *ordered = [NSMutableArray array];
  for (NSString *each in @[@"ctrl", @"alt", @"shift", @"cmd"]) if ([chosen containsObject:each]) [ordered addObject:each];
  self.customModifiers = ordered;
  [self reload];
}

- (void)rebuildPickerSelection {
  SlateModifierGroup *group = [self currentGroup];
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
    NSMutableArray *toggles = [NSMutableArray array];
    for (NSString *name in @[@"ctrl", @"alt", @"shift", @"cmd"]) {
      NSButton *check = [NSButton checkboxWithTitle:[NSString stringWithFormat:@"%@ %@", [SlateShortcut symbolForModifierName:name], name] target:self action:@selector(toggleModifier:)];
      [check setIdentifier:name];
      [check setState:[modifiers containsObject:name] ? NSControlStateValueOn : NSControlStateValueOff];
      [toggles addObject:check];
    }
    NSStackView *row = [NSStackView stackViewWithViews:toggles];
    [row setSpacing:16];
    [self.selectionStack addArrangedSubview:row];
  }

  // What stands in the way of these keys.
  NSString *warning = nil;
  BOOL blocked = keyName == nil || [modifiers count] == 0;
  if (keyName != nil) {
    NSString *reason = [SlateReservedShortcuts reasonForKeyName:keyName modifierNames:modifiers];
    SlateShortcutInfo *taken = [self infoForKeyName:keyName];
    if (reason != nil) { warning = reason; blocked = YES; }
    else if (taken != nil) warning = [NSString stringWithFormat:@"Already used by \"%@\". Both would fire on the same keys.", taken.title];
  }
  NSTextField *note = [self labelWithText:warning ?: @" " size:12 color:[MWMTheme warning] weight:NSFontWeightRegular];
  [note setIdentifier:@"pick-warning"];
  [self.selectionStack addArrangedSubview:note];

  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelPickPressed:)];
  NSButton *use = [NSButton buttonWithTitle:@"Use these keys" target:self action:@selector(usePickPressed:)];
  [use setKeyEquivalent:@"\r"];
  [use setEnabled:!blocked];
  [use setIdentifier:@"pick-use"];
  for (NSButton *button in @[cancel, use]) [button setBezelStyle:NSBezelStyleRounded];
  NSStackView *buttons = [NSStackView stackViewWithViews:@[spacer, cancel, use]];
  [buttons setSpacing:8];
  [self.selectionStack addArrangedSubview:buttons];
  [[buttons.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor constant:-32] setActive:YES];
}

- (void)cancelPickPressed:(id)sender {
  if ([self.delegate respondsToSelector:@selector(keyboardMapViewDidCancelPicking:)]) [self.delegate keyboardMapViewDidCancelPicking:self];
}

- (void)usePickPressed:(id)sender {
  SlateModifierGroup *group = [self currentGroup];
  if (self.selectedKeyName == nil || ![self.delegate respondsToSelector:@selector(keyboardMapView:didPickKey:modifierNames:groupName:)]) return;
  [self.delegate keyboardMapView:self didPickKey:self.selectedKeyName modifierNames:[self effectiveModifiers] groupName:group.custom ? nil : group.name];
}

#pragma mark - Actions

- (void)editPressed:(id)sender {
  SlateShortcutInfo *info = [self infoForKeyName:self.selectedKeyName ?: @""];
  if (info != nil) [self.delegate keyboardMapView:self wantsToEditBindingAtIndex:info.index];
}

- (void)addPressed:(id)sender {
  SlateModifierGroup *group = [self currentGroup];
  if (self.selectedKeyName != nil) [self.delegate keyboardMapView:self wantsNewShortcutInGroup:group.custom ? nil : group.name keyName:self.selectedKeyName];
}

- (void)removePressed:(id)sender {
  if (self.confirmsRemoval) {
    SlateShortcutInfo *info = [self infoForKeyName:self.selectedKeyName ?: @""];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:[NSString stringWithFormat:@"Remove \"%@\"?", info.title]];
    [alert setInformativeText:@"The shortcut is taken out of your configuration."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Remove"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  [self removeSelected];
}

- (void)removeSelected {
  SlateShortcutInfo *info = [self infoForKeyName:self.selectedKeyName ?: @""];
  if (info == nil) return;
  [self.document.bindings removeObjectIdenticalTo:info.binding];
  _selectedKeyName = nil;
  [self.delegate keyboardMapViewDidChangeDocument:self];
  [self reload];
}

@end
