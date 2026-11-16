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
#import "ConfigurationBlockView.h"
#import "ConfigurationKeyViews.h"
#import "SlateAction.h"
#import "SlateConfigDocument.h"
#import "SlateReservedShortcuts.h"
#import "SlateShortcut.h"
#import "SlateShortcutIndex.h"
#import "SlateSlots.h"

static const CGFloat kGroupsWidth = 188;
static const CGFloat kKeySize = 38;

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
@property (copy) void (^onClick)(void);
@end

@implementation ConfigurationMapKey
- (NSSize)intrinsicContentSize { return NSMakeSize(kKeySize, kKeySize); }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event { if (self.onClick) self.onClick(); }
- (void)drawRect:(NSRect)dirtyRect {
  NSRect rect = NSInsetRect([self bounds], 1, 1);
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8 yRadius:8];
  NSColor *fill, *stroke, *text;
  switch (self.state) {
    case MapKeyStateTaken:
      fill = [self.tint colorWithAlphaComponent:0.20]; stroke = [self.tint colorWithAlphaComponent:0.55]; text = self.tint; break;
    case MapKeyStateConflict:
      fill = [[NSColor systemOrangeColor] colorWithAlphaComponent:0.25]; stroke = [NSColor systemOrangeColor]; text = [NSColor systemOrangeColor]; break;
    case MapKeyStateReserved:
      fill = [[NSColor systemYellowColor] colorWithAlphaComponent:0.12]; stroke = [[NSColor systemYellowColor] colorWithAlphaComponent:0.5]; text = [NSColor systemYellowColor]; break;
    default:
      fill = [[NSColor labelColor] colorWithAlphaComponent:0.05]; stroke = [NSColor quaternaryLabelColor]; text = [NSColor tertiaryLabelColor]; break;
  }
  [fill setFill];
  [path fill];
  [stroke setStroke];
  [path setLineWidth:0.8];
  [path stroke];
  if (self.selected) {
    NSBezierPath *ring = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, -1, -1) xRadius:9 yRadius:9];
    [[NSColor controlAccentColor] setStroke];
    [ring setLineWidth:2.2];
    [ring stroke];
  }
  NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:[self.label length] > 2 ? 10 : 13 weight:NSFontWeightMedium], NSForegroundColorAttributeName: text};
  NSSize size = [self.label sizeWithAttributes:attributes];
  [self.label drawAtPoint:NSMakePoint(NSMidX([self bounds]) - size.width / 2, NSMidY([self bounds]) - size.height / 2) withAttributes:attributes];
}
@end

#pragma mark - Page

@interface ConfigurationKeyboardMapView ()
@property (strong) SlateShortcutIndex *index;
@property (strong) NSStackView *groupsStack;
@property (strong) NSStackView *keyboardStack;
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
  [self.groupsStack setSpacing:6];
  [self.groupsStack setEdgeInsets:NSEdgeInsetsMake(8, 20, 16, 0)];
  [self.groupsStack setTranslatesAutoresizingMaskIntoConstraints:NO];

  self.keyboardStack = [NSStackView stackViewWithViews:@[]];
  [self.keyboardStack setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
  [self.keyboardStack setAlignment:NSLayoutAttributeTop];
  [self.keyboardStack setSpacing:26];
  [self.keyboardStack setEdgeInsets:NSEdgeInsetsMake(14, 14, 14, 14)];
  [self.keyboardStack setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationBlockView *keyboardCard = [[ConfigurationBlockView alloc] init];
  [keyboardCard setTranslatesAutoresizingMaskIntoConstraints:NO];
  [keyboardCard addSubview:self.keyboardStack];
  [NSLayoutConstraint activateConstraints:@[
    [self.keyboardStack.topAnchor constraintEqualToAnchor:keyboardCard.topAnchor], [self.keyboardStack.bottomAnchor constraintEqualToAnchor:keyboardCard.bottomAnchor],
    [self.keyboardStack.centerXAnchor constraintEqualToAnchor:keyboardCard.centerXAnchor],
  ]];

  self.legendStack = [NSStackView stackViewWithViews:@[]];
  [self.legendStack setSpacing:16];

  self.selectionStack = [NSStackView stackViewWithViews:@[]];
  [self.selectionStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.selectionStack setAlignment:NSLayoutAttributeLeading];
  [self.selectionStack setSpacing:0];
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
  NSStackView *main = [NSStackView stackViewWithViews:@[keyboardCard, selectionCard, self.legendStack, spacer]];
  [main setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [main setAlignment:NSLayoutAttributeLeading];
  [main setSpacing:12];
  [main setEdgeInsets:NSEdgeInsetsMake(8, 0, 16, 20)];
  [main setTranslatesAutoresizingMaskIntoConstraints:NO];
  for (NSView *view in @[keyboardCard, selectionCard]) [[view.widthAnchor constraintEqualToAnchor:main.widthAnchor constant:-20] setActive:YES];

  [self addSubview:self.groupsStack];
  [self addSubview:main];
  [NSLayoutConstraint activateConstraints:@[
    [self.groupsStack.topAnchor constraintEqualToAnchor:self.topAnchor], [self.groupsStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [self.groupsStack.widthAnchor constraintEqualToConstant:kGroupsWidth + 20],
    [main.topAnchor constraintEqualToAnchor:self.topAnchor], [main.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [main.leadingAnchor constraintEqualToAnchor:self.groupsStack.trailingAnchor constant:12], [main.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
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

#pragma mark - Groups

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  NSTextField *label = [NSTextField labelWithString:text];
  [label setFont:[NSFont systemFontOfSize:size weight:weight]];
  [label setTextColor:color];
  [label setLineBreakMode:NSLineBreakByTruncatingTail];
  return label;
}

- (void)rebuildGroups {
  for (NSView *view in [[self.groupsStack arrangedSubviews] copy]) {
    [self.groupsStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  __weak ConfigurationKeyboardMapView *weakSelf = self;
  for (SlateModifierGroup *group in self.index.groups) {
    BOOL selected = [group.name isEqualToString:self.groupName ?: @""];
    ConfigurationBlockView *card = [[ConfigurationBlockView alloc] init];
    [card setTranslatesAutoresizingMaskIntoConstraints:NO];
    ConfigurationClickView *click = [[ConfigurationClickView alloc] init];
    click.cornerRadius = 12;
    click.selected = selected;
    [click setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSString *name = group.name;
    click.onClick = ^{ weakSelf.groupName = name; };
    NSTextField *title = [self labelWithText:group.name size:13 color:selected ? [NSColor controlAccentColor] : [NSColor labelColor] weight:NSFontWeightMedium];
    NSTextField *count = [self labelWithText:[NSString stringWithFormat:@"%lu", (unsigned long)group.count] size:11 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular];
    NSView *gap = [[NSView alloc] init];
    [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *top = [NSStackView stackViewWithViews:@[title, gap, count]];
    [top setAlignment:NSLayoutAttributeFirstBaseline];
    NSView *caps = group.custom ? [self labelWithText:@"other combinations" size:11 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular]
                                : [ConfigurationKeyViews modifierCaps:group.modifierNames size:20];
    NSStackView *stack = [NSStackView stackViewWithViews:@[top, caps]];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setAlignment:NSLayoutAttributeLeading];
    [stack setSpacing:5];
    [stack setEdgeInsets:NSEdgeInsetsMake(8, 10, 8, 10)];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[top.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-20] setActive:YES];
    [card addSubview:stack];
    [card addSubview:click positioned:NSWindowAbove relativeTo:nil];
    for (NSView *view in @[stack, click]) {
      [view setTranslatesAutoresizingMaskIntoConstraints:NO];
      [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:card.topAnchor], [view.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [view.leadingAnchor constraintEqualToAnchor:card.leadingAnchor], [view.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
      ]];
    }
    [card setIdentifier:[@"group-" stringByAppendingString:group.name]];
    [self.groupsStack addArrangedSubview:card];
    [[card.widthAnchor constraintEqualToConstant:kGroupsWidth] setActive:YES];
  }
  NSButton *manage = [NSButton buttonWithTitle:@"Manage groups…" target:self action:@selector(groupsPressed:)];
  [manage setBezelStyle:NSBezelStyleRounded];
  [manage setImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:nil]];
  [manage setImagePosition:NSImageLeft];
  [self.groupsStack addArrangedSubview:manage];
  [[manage.widthAnchor constraintEqualToConstant:kGroupsWidth] setActive:YES];
}

- (void)groupsPressed:(id)sender {
  [self.delegate keyboardMapViewWantsGroups:self];
}

#pragma mark - Keyboard

// The key rows, as names in the key table and what to write on the cap.
+ (NSArray<NSArray<NSArray<NSString *> *> *> *)layout {
  static NSArray *rows;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSArray *(^cap)(NSString *) = ^NSArray *(NSString *name) { return @[name, [SlateShortcut displayForKeyName:name]]; };
    NSArray *(^row)(NSArray *) = ^NSArray *(NSArray *names) { NSMutableArray *r = [NSMutableArray array]; for (NSString *n in names) [r addObject:cap(n)]; return r; };
    rows = @[
      @[row(@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"]),
        row(@[@"q", @"w", @"e", @"r", @"t", @"y", @"u", @"i", @"o", @"p"]),
        row(@[@"a", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l"]),
        row(@[@"z", @"x", @"c", @"v", @"b", @"n", @"m"]),
        row(@[@"esc", @"tab", @"space", @"return", @"delete"]),
        row(@[@"left", @"up", @"down", @"right"])],
      @[row(@[@"pad7", @"pad8", @"pad9"]), row(@[@"pad4", @"pad5", @"pad6"]), row(@[@"pad1", @"pad2", @"pad3"]), row(@[@"pad0", @"pad."])],
    ];
  });
  return rows;
}

- (void)rebuildKeyboard {
  for (NSView *view in [[self.keyboardStack arrangedSubviews] copy]) {
    [self.keyboardStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  NSMutableArray *allKeys = [NSMutableArray array];
  NSArray *modifiers = [self groupModifiers];
  __weak ConfigurationKeyboardMapView *weakSelf = self;
  for (NSArray *block in [[self class] layout]) {
    NSMutableArray *rowViews = [NSMutableArray array];
    for (NSArray *row in block) {
      NSMutableArray *capViews = [NSMutableArray array];
      for (NSArray *capInfo in row) {
        NSString *name = capInfo[0];
        ConfigurationMapKey *key = [[ConfigurationMapKey alloc] init];
        key.keyName = name;
        key.label = capInfo[1];
        [key setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self styleKey:key modifiers:modifiers];
        key.selected = [name isEqualToString:self.selectedKeyName ?: @""];
        key.onClick = ^{ [weakSelf selectKeyNamed:name]; };
        [key setIdentifier:[@"key-" stringByAppendingString:name]];
        [capViews addObject:key];
        [allKeys addObject:key];
      }
      NSStackView *rowStack = [NSStackView stackViewWithViews:capViews];
      [rowStack setSpacing:5];
      [rowViews addObject:rowStack];
    }
    NSStackView *blockStack = [NSStackView stackViewWithViews:rowViews];
    [blockStack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [blockStack setAlignment:NSLayoutAttributeLeading];
    [blockStack setSpacing:5];
    [self.keyboardStack addArrangedSubview:blockStack];
  }
  self.keys = allKeys;
  [self rebuildLegend];
}

// A key's color in the current group: what its shortcut does, or conflict / reserved / free.
- (void)styleKey:(ConfigurationMapKey *)key modifiers:(NSArray<NSString *> *)modifiers {
  SlateShortcutInfo *info = [self infoForKeyName:key.keyName];
  key.tint = nil;
  if (info != nil) {
    key.state = info.conflict ? MapKeyStateConflict : MapKeyStateTaken;
    key.tint = [ConfigurationKeyViews colorForKind:info.kind];
  } else if ([[self currentGroup] custom] == NO && [SlateReservedShortcuts reasonForKeyName:key.keyName modifierNames:modifiers] != nil && [modifiers count] > 0) {
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
  NSArray *entries = @[@[@"Move to slot", [NSColor controlAccentColor]], @[@"Windows and apps", [NSColor systemGreenColor]], @[@"Features", [NSColor systemPurpleColor]],
                       @[@"Conflict", [NSColor systemOrangeColor]], @[@"Reserved by macOS", [NSColor systemYellowColor]]];
  for (NSArray *entry in entries) {
    NSView *dot = [[NSView alloc] init];
    [dot setWantsLayer:YES];
    [[dot layer] setCornerRadius:3];
    [[dot layer] setBackgroundColor:[[(NSColor *)entry[1] colorWithAlphaComponent:0.6] CGColor]];
    [dot setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[[dot.widthAnchor constraintEqualToConstant:9], [dot.heightAnchor constraintEqualToConstant:9]]];
    NSTextField *label = [self labelWithText:entry[0] size:11 color:[NSColor tertiaryLabelColor] weight:NSFontWeightRegular];
    NSStackView *item = [NSStackView stackViewWithViews:@[dot, label]];
    [item setSpacing:5];
    [item setAlignment:NSLayoutAttributeCenterY];
    [self.legendStack addArrangedSubview:item];
  }
}

- (void)selectKeyNamed:(NSString *)keyName {
  _selectedKeyName = [keyName copy];
  for (ConfigurationMapKey *key in self.keys) key.selected = [key.keyName isEqualToString:keyName];
  [self.keys makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:@YES];
  [self rebuildSelection];
}

#pragma mark - Selected key

- (NSStackView *)selectionRowWithLabel:(NSString *)label content:(NSView *)content {
  NSTextField *name = [self labelWithText:label size:11 color:[NSColor tertiaryLabelColor] weight:NSFontWeightRegular];
  [[name.widthAnchor constraintEqualToConstant:78] setActive:YES];
  NSStackView *row = [NSStackView stackViewWithViews:@[name, content]];
  [row setSpacing:12];
  [row setAlignment:NSLayoutAttributeCenterY];
  [row setEdgeInsets:NSEdgeInsetsMake(10, 14, 10, 14)];
  return row;
}

- (void)addSelectionRow:(NSView *)row {
  if ([[self.selectionStack arrangedSubviews] count] > 0) {
    NSBox *line = [[NSBox alloc] init];
    [line setBoxType:NSBoxSeparator];
    [line setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.selectionStack addArrangedSubview:line];
    [[line.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor] setActive:YES];
  }
  [self.selectionStack addArrangedSubview:row];
  [[row.widthAnchor constraintEqualToAnchor:self.selectionStack.widthAnchor] setActive:YES];
}

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

- (NSView *)doesThisViewForInfo:(SlateShortcutInfo *)info {
  NSColor *color = [ConfigurationKeyViews colorForKind:info.kind];
  NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:[ConfigurationKeyViews symbolForKind:info.kind] accessibilityDescription:nil]];
  [icon setContentTintColor:color];
  [icon setSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightRegular]];
  [icon setTranslatesAutoresizingMaskIntoConstraints:NO];
  ConfigurationBlockView *tile = [[ConfigurationBlockView alloc] init];
  [tile setTranslatesAutoresizingMaskIntoConstraints:NO];
  [tile addSubview:icon];
  [NSLayoutConstraint activateConstraints:@[
    [tile.widthAnchor constraintEqualToConstant:36], [tile.heightAnchor constraintEqualToConstant:36],
    [icon.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor], [icon.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
  ]];
  NSTextField *title = [self labelWithText:info.title size:14 color:color weight:NSFontWeightMedium];
  NSMutableArray *texts = [NSMutableArray arrayWithObject:title];
  if ([info.detail length] > 0) [texts addObject:[self labelWithText:info.detail size:12 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular]];
  NSStackView *text = [NSStackView stackViewWithViews:texts];
  [text setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [text setAlignment:NSLayoutAttributeLeading];
  [text setSpacing:1];
  NSMutableArray *views = [NSMutableArray arrayWithObjects:tile, text, nil];
  // For moving to a slot: a small screen with the slot drawn on it.
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
  NSStackView *row = [NSStackView stackViewWithViews:views];
  [row setSpacing:12];
  [row setAlignment:NSLayoutAttributeCenterY];
  return row;
}

- (void)rebuildSelection {
  for (NSView *view in [[self.selectionStack arrangedSubviews] copy]) {
    [self.selectionStack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  NSString *keyName = self.selectedKeyName;
  if (keyName == nil) {
    NSTextField *hint = [self labelWithText:@"Click a key to see what it does, or to give it a shortcut." size:13 color:[NSColor tertiaryLabelColor] weight:NSFontWeightRegular];
    NSStackView *row = [NSStackView stackViewWithViews:@[hint]];
    [row setEdgeInsets:NSEdgeInsetsMake(18, 14, 18, 14)];
    [self addSelectionRow:row];
    return;
  }
  SlateModifierGroup *group = [self currentGroup];
  SlateShortcutInfo *info = [self infoForKeyName:keyName];
  NSArray *modifiers = info != nil ? info.modifierNames : [self groupModifiers];

  // Keys
  NSMutableArray *keyViews = [NSMutableArray array];
  if (!group.custom || info != nil) {
    if (info != nil ? info.groupName != nil : !group.custom) [keyViews addObject:[ConfigurationKeyViews pillWithText:info != nil ? info.groupName : group.name]];
  }
  [keyViews addObject:[ConfigurationKeyViews keyCapsForModifiers:modifiers keyName:keyName size:26]];
  NSStackView *keys = [NSStackView stackViewWithViews:keyViews];
  [keys setSpacing:8];
  [keys setAlignment:NSLayoutAttributeCenterY];
  [self addSelectionRow:[self selectionRowWithLabel:@"Keys" content:keys]];

  if (info != nil) {
    [self addSelectionRow:[self selectionRowWithLabel:@"Does this" content:[self doesThisViewForInfo:info]]];
    // The same key in other groups.
    NSMutableArray *elsewhere = [NSMutableArray array];
    for (SlateShortcutInfo *other in self.index.shortcuts) {
      if (other == info || ![other.keyName isEqualToString:keyName]) continue;
      [elsewhere addObject:[NSString stringWithFormat:@"%@ · %@", other.groupName ?: @"Custom", other.title]];
    }
    NSString *text = [elsewhere count] > 0 ? [elsewhere componentsJoinedByString:@"   ·   "] : @"Nothing else uses this key.";
    [self addSelectionRow:[self selectionRowWithLabel:@"Same key" content:[self labelWithText:text size:12 color:[NSColor secondaryLabelColor] weight:NSFontWeightRegular]]];
    NSButton *remove = [NSButton buttonWithTitle:@"Remove" target:self action:@selector(removePressed:)];
    NSButton *edit = [NSButton buttonWithTitle:@"Edit" target:self action:@selector(editPressed:)];
    [edit setKeyEquivalent:@"\r"];
    for (NSButton *button in @[remove, edit]) [button setBezelStyle:NSBezelStyleRounded];
    [self addSelectionRow:[self buttonRow:@[remove, edit]]];
  } else {
    NSString *reason = [[self currentGroup] custom] ? nil : [SlateReservedShortcuts reasonForKeyName:keyName modifierNames:modifiers];
    NSString *free = reason != nil ? reason : @"Nothing yet. This key is free in this group.";
    [self addSelectionRow:[self selectionRowWithLabel:@"Does this" content:[self labelWithText:free size:13 color:reason != nil ? [NSColor systemOrangeColor] : [NSColor secondaryLabelColor] weight:NSFontWeightRegular]]];
    if (reason == nil && !group.custom) {
      NSButton *add = [NSButton buttonWithTitle:@"Add Shortcut" target:self action:@selector(addPressed:)];
      [add setBezelStyle:NSBezelStyleRounded];
      [add setKeyEquivalent:@"\r"];
      [self addSelectionRow:[self buttonRow:@[add]]];
    }
  }
}

- (NSView *)buttonRow:(NSArray<NSButton *> *)buttons {
  NSView *spacer = [[NSView alloc] init];
  [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *row = [NSStackView stackViewWithViews:[@[spacer] arrayByAddingObjectsFromArray:buttons]];
  [row setSpacing:8];
  [row setEdgeInsets:NSEdgeInsetsMake(10, 14, 10, 14)];
  return row;
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
