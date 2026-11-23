//
//  ConfigurationMacKeyboard.m
//  MWM
//
//  A Mac keyboard drawn in key units, shared by the Keyboard map (keys colored by what their shortcut does)
//  and the modifier group editor (its modifier keys are clickable, to build a combination).
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

#import "ConfigurationMacKeyboard.h"
#import "MWMTheme.h"
#import "MWMShortcut.h"

const CGFloat kMacKeyboardUnitsWide = 19.5;
const CGFloat kMacKeyboardUnitsTall = 5.8;
const CGFloat kMacKeyboardCompactUnitsWide = 15.0;

@implementation ConfigurationMapKey
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event { if ((!self.modifier || self.clickable) && self.onClick) self.onClick(); }
- (void)drawRect:(NSRect)dirtyRect {
  if (self.dimmed) CGContextSetAlpha([[NSGraphicsContext currentContext] CGContext], 0.35);
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
    case MapKeyStateOn:
      fill = [[MWMTheme accent] colorWithAlphaComponent:0.9]; stroke = [MWMTheme accent]; text = [NSColor whiteColor]; break;
    default:
      fill = [[MWMTheme textPrimary] colorWithAlphaComponent:self.modifier ? (self.clickable ? 0.10 : 0.02) : 0.05];
      stroke = self.clickable ? [MWMTheme textSecondary] : [NSColor quaternaryLabelColor];
      text = self.clickable ? [MWMTheme textPrimary] : [MWMTheme textTertiary]; break;
  }
  [fill setFill];
  [path fill];
  [stroke setStroke];
  [path setLineWidth:0.8];
  if (self.modifier && !self.clickable) { CGFloat dash[] = {3, 2}; [path setLineDash:dash count:2 phase:0]; }
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

@implementation ConfigurationMacKeyboard
- (BOOL)isFlipped { return YES; }
- (CGFloat)unitsWide { return _unitsWide > 0 ? _unitsWide : kMacKeyboardUnitsWide; }
- (void)layout {
  [super layout];
  CGFloat unit = NSWidth([self bounds]) / self.unitsWide;
  CGFloat gap = unit * 0.12;
  for (ConfigurationMapKey *key in self.keys) {
    NSRect u = key.units;
    [key setFrame:NSMakeRect(u.origin.x * unit + gap / 2, u.origin.y * unit + gap / 2, u.size.width * unit - gap, u.size.height * unit - gap)];
  }
}

@synthesize unitsWide = _unitsWide;

+ (NSArray<ConfigurationMapKey *> *)buildCompactKeys {
  NSMutableArray *keys = [NSMutableArray array];
  for (ConfigurationMapKey *key in [self buildKeys]) if (key.units.origin.x < 15.4) [keys addObject:key];
  return keys;
}

+ (NSArray<ConfigurationMapKey *> *)buildKeys {
NSMutableArray *keys = [NSMutableArray array];
  void (^add)(NSString *, NSString *, CGFloat, CGFloat, CGFloat, CGFloat, BOOL) = ^(NSString *name, NSString *label, CGFloat x, CGFloat y, CGFloat w, CGFloat h, BOOL modifier) {
    ConfigurationMapKey *key = [[ConfigurationMapKey alloc] init];
    key.keyName = name;
    key.label = label ?: [MWMShortcut displayForKeyName:name];
    key.units = NSMakeRect(x, y, w, h);
    key.modifier = modifier;
    NSDictionary *names = @{@"ctrlL": @"ctrl", @"optL": @"alt", @"shiftL": @"shift", @"cmdL": @"cmd"};
    key.modifierName = names[name];
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


- (void)setSelectedModifiers:(NSArray<NSString *> *)names {
  for (ConfigurationMapKey *key in self.keys) {
    if (key.modifierName == nil) continue;
    key.state = [names containsObject:key.modifierName] ? MapKeyStateOn : MapKeyStateFree;
    [key setNeedsDisplay:YES];
  }
}

- (void)showModifierPickerWithSelected:(NSArray<NSString *> *)names dimOthers:(BOOL)dim toggle:(void (^)(NSString *name))toggle {
  for (ConfigurationMapKey *key in self.keys) {
    if (key.modifierName != nil) {
      NSString *name = key.modifierName;
      key.clickable = YES;
      key.onClick = ^{ toggle(name); };
      [key setToolTip:[NSString stringWithFormat:@"Click to add or remove %@", name]];
      key.state = MapKeyStateFree;
    } else if (dim) {
      key.dimmed = YES;
      key.onClick = nil;
      key.state = MapKeyStateFree;
    }
  }
  [self setSelectedModifiers:names];
}
@end

