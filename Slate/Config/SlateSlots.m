//
//  SlateSlots.m
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

#import "SlateSlots.h"
#import "SlateAction.h"

static const CGFloat kEpsilon = 0.0005;  // a twentieth of a percent

// v as p/q with a small q when it is one (1/3, 3/4), else hundredths of a percent.
static void Rationalize(CGFloat v, NSInteger *p, NSInteger *q) {
  for (NSInteger d = 1; d <= 12; d++) {
    if (fabs(v * d - round(v * d)) < 1e-6) { *p = (NSInteger)round(v * d); *q = d; return; }
  }
  *p = (NSInteger)round(v * 10000);
  *q = 10000;
  NSInteger a = *p, b = *q;
  while (b != 0) { NSInteger t = a % b; a = b; b = t; }
  if (a > 1) { *p /= a; *q /= a; }
}

// "screenSizeX/4", "(3*screenSizeX/4)", or the variable itself for all of it.
static NSString *Scaled(NSString *variable, CGFloat fraction) {
  NSInteger p, q;
  Rationalize(fraction, &p, &q);
  if (p == q) return variable;
  if (p == 1) return [NSString stringWithFormat:@"%@/%ld", variable, (long)q];
  return [NSString stringWithFormat:@"(%ld*%@/%ld)", (long)p, variable, (long)q];
}

static NSString *Position(NSString *origin, NSString *size, CGFloat fraction) {
  return fraction < 1e-9 ? origin : [NSString stringWithFormat:@"%@+%@", origin, Scaled(size, fraction)];
}

@implementation SlateSlot

+ (SlateSlot *)slotNamed:(NSString *)name rect:(CGRect)rect preset:(BOOL)preset {
  SlateSlot *slot = [[SlateSlot alloc] init];
  slot.name = name;
  slot.rect = rect;
  slot.preset = preset;
  return slot;
}

- (NSString *)formula {
  return [SlateSlots formulaForRect:self.rect];
}

- (NSString *)summary {
  CGRect r = self.rect;
  NSString *(^percent)(CGFloat) = ^NSString *(CGFloat v) {
    double rounded = round(v * 10000) / 100;
    return rounded == floor(rounded) ? [NSString stringWithFormat:@"%.0f%%", rounded] : [NSString stringWithFormat:@"%.1f%%", rounded];
  };
  NSString *width = r.size.width > 1 - kEpsilon ? @"full width" : [percent(r.size.width) stringByAppendingString:@" wide"];
  NSString *height = r.size.height > 1 - kEpsilon ? @"full height" : [percent(r.size.height) stringByAppendingString:@" tall"];
  return [NSString stringWithFormat:@"%@, %@", width, height];
}

@end

@implementation SlateSlots

#pragma mark - Presets

+ (NSArray<SlateSlot *> *)presets {
  static NSArray *presets;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSMutableArray *list = [NSMutableArray array];
    void (^add)(NSString *, CGFloat, CGFloat, CGFloat, CGFloat) = ^(NSString *name, CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
      [list addObject:[SlateSlot slotNamed:name rect:CGRectMake(x, y, w, h) preset:YES]];
    };
    add(@"full", 0, 0, 1, 1);
    add(@"lefthalf", 0, 0, 0.5, 1);
    add(@"righthalf", 0.5, 0, 0.5, 1);
    add(@"tophalf", 0, 0, 1, 0.5);
    add(@"bottomhalf", 0, 0.5, 1, 0.5);
    for (NSInteger i = 0; i < 3; i++) add([NSString stringWithFormat:@"third%ld", (long)i + 1], i / 3.0, 0, 1 / 3.0, 1);
    for (NSInteger i = 0; i < 3; i++) add([NSString stringWithFormat:@"thirdrow%ld", (long)i + 1], 0, i / 3.0, 1, 1 / 3.0);
    for (NSInteger i = 0; i < 4; i++) add([NSString stringWithFormat:@"quarter%ld", (long)i + 1], i / 4.0, 0, 0.25, 1);
    for (NSInteger i = 0; i < 4; i++) add([NSString stringWithFormat:@"quarterrow%ld", (long)i + 1], 0, i / 4.0, 1, 0.25);
    presets = list;
  });
  return presets;
}

+ (SlateSlot *)presetNamed:(NSString *)name {
  for (SlateSlot *preset in [self presets]) if ([preset.name isEqualToString:name]) return preset;
  return nil;
}

+ (SlateSlot *)presetWithRect:(CGRect)rect {
  for (SlateSlot *preset in [self presets]) if ([self rect:preset.rect isSameAreaAs:rect]) return preset;
  return nil;
}

#pragma mark - Formulas

+ (NSString *)formulaForRect:(CGRect)r {
  return [NSString stringWithFormat:@"move %@;%@ %@;%@",
          Position(@"screenOriginX", @"screenSizeX", r.origin.x), Position(@"screenOriginY", @"screenSizeY", r.origin.y),
          Scaled(@"screenSizeX", r.size.width), Scaled(@"screenSizeY", r.size.height)];
}

+ (BOOL)getRect:(CGRect *)rect fromFormula:(NSString *)formula {
  // "move x;y w;h" and nothing after it: a formula that names a screen isn't a slot.
  NSArray *tokens = [[formula stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  NSMutableArray *words = [NSMutableArray array];
  for (NSString *token in tokens) if ([token length] > 0) [words addObject:token];
  if ([words count] != 3) return NO;
  return [SlateAction previewForPositionText:formula rect:rect];
}

+ (BOOL)rect:(CGRect)a isSameAreaAs:(CGRect)b {
  return fabs(a.origin.x - b.origin.x) < kEpsilon && fabs(a.origin.y - b.origin.y) < kEpsilon &&
         fabs(a.size.width - b.size.width) < kEpsilon && fabs(a.size.height - b.size.height) < kEpsilon;
}

#pragma mark - Rules

+ (NSString *)problemWithName:(NSString *)name rect:(CGRect)rect otherSlots:(NSArray<SlateSlot *> *)others takenNames:(NSSet<NSString *> *)taken {
  NSString *trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([trimmed length] == 0) return @"Give the slot a name.";
  if ([self presetNamed:trimmed] != nil) return [NSString stringWithFormat:@"\"%@\" is a built-in preset name.", trimmed];
  if ([taken containsObject:trimmed]) return [NSString stringWithFormat:@"The name \"%@\" is already used.", trimmed];
  if (rect.size.width < kEpsilon || rect.size.height < kEpsilon) return @"The slot needs some width and height.";
  if (rect.origin.x < -kEpsilon || rect.origin.y < -kEpsilon || CGRectGetMaxX(rect) > 1 + kEpsilon || CGRectGetMaxY(rect) > 1 + kEpsilon) {
    return @"The slot has to stay inside the screen.";
  }
  SlateSlot *preset = [self presetWithRect:rect];
  if (preset != nil) return [NSString stringWithFormat:@"Same area as the preset \"%@\".", preset.name];
  for (SlateSlot *other in others) {
    if ([self rect:other.rect isSameAreaAs:rect]) return [NSString stringWithFormat:@"Same area as \"%@\".", other.name];
  }
  return nil;
}

#pragma mark - Snapping

+ (CGFloat)snapped:(CGFloat)value tolerance:(CGFloat)tolerance divisions:(NSInteger)divisions {
  if (divisions >= 2) {
    CGFloat line = round(value * divisions) / divisions;
    if (fabs(value - line) <= tolerance) return line;
  }
  return round(value * 100) / 100;
}

@end
