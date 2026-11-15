//
//  SlateDisplays.m
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

#import "SlateDisplays.h"

static NSString *const kRolePrefix = @"display:";
// A screen reference that matches no screen, so MWM falls back to the current one.
static NSString *const kMissingReference = @"ordered:99";

@implementation SlateDisplay

+ (SlateDisplay *)displayNamed:(NSString *)name width:(NSInteger)width height:(NSInteger)height builtIn:(BOOL)builtIn x:(CGFloat)x y:(CGFloat)y {
  SlateDisplay *display = [[SlateDisplay alloc] init];
  display.name = name;
  display.width = width;
  display.height = height;
  display.builtIn = builtIn;
  display.originX = x;
  display.originY = y;
  return display;
}

- (NSString *)sizeText {
  return [NSString stringWithFormat:@"%ldx%ld", (long)self.width, (long)self.height];
}

@end

static NSArray<SlateDisplay *> *gOverride = nil;

@implementation SlateDisplays

#pragma mark - Connected displays

+ (void)setConnectedOverride:(NSArray<SlateDisplay *> *)displays {
  gOverride = [displays copy];
}

+ (NSArray<SlateDisplay *> *)connected {
  if (gOverride != nil) return [self sortedLeftToRight:gOverride];
  NSArray<NSScreen *> *screens = [NSScreen screens];
  if ([screens count] == 0) return @[];
  NSRect main = [[screens firstObject] frame];
  NSMutableArray *displays = [NSMutableArray array];
  for (NSScreen *screen in screens) {
    NSRect frame = [screen frame];
    NSNumber *number = [screen deviceDescription][@"NSScreenNumber"];
    BOOL builtIn = number != nil && CGDisplayIsBuiltin((CGDirectDisplayID)[number unsignedIntValue]);
    NSString *name = [screen localizedName] ?: @"Display";
    // y grows downward from the top of the main display.
    CGFloat y = (NSMaxY(main) - NSMaxY(frame));
    [displays addObject:[SlateDisplay displayNamed:name width:(NSInteger)frame.size.width height:(NSInteger)frame.size.height
                                           builtIn:builtIn x:frame.origin.x - main.origin.x y:y]];
  }
  return [self sortedLeftToRight:displays];
}

+ (NSArray<SlateDisplay *> *)sortedLeftToRight:(NSArray<SlateDisplay *> *)displays {
  return [displays sortedArrayUsingComparator:^NSComparisonResult(SlateDisplay *a, SlateDisplay *b) {
    if (a.originX != b.originX) return a.originX < b.originX ? NSOrderedAscending : NSOrderedDescending;
    if (a.originY != b.originY) return a.originY < b.originY ? NSOrderedAscending : NSOrderedDescending;
    return NSOrderedSame;
  }];
}

#pragma mark - Roles

// "display: Samsung Odyssey 2560x1440 #2" -> model, optional size and number.
+ (BOOL)parseRole:(NSString *)role model:(NSString **)model width:(NSInteger *)width height:(NSInteger *)height number:(NSInteger *)number builtIn:(BOOL *)builtIn {
  if (![self isRole:role]) return NO;
  NSString *text = [[role substringFromIndex:[kRolePrefix length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if ([text caseInsensitiveCompare:@"built-in"] == NSOrderedSame) {
    *builtIn = YES;
    *model = @"";
    *width = *height = *number = 0;
    return YES;
  }
  *builtIn = NO;
  *width = *height = 0;
  *number = 1;
  NSRegularExpression *numberPart = [NSRegularExpression regularExpressionWithPattern:@"\\s+#([0-9]+)$" options:0 error:nil];
  NSTextCheckingResult *n = [numberPart firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
  if (n) {
    *number = [[text substringWithRange:[n rangeAtIndex:1]] integerValue];
    text = [text substringToIndex:[n range].location];
  }
  NSRegularExpression *sizePart = [NSRegularExpression regularExpressionWithPattern:@"\\s+([0-9]+)x([0-9]+)$" options:0 error:nil];
  NSTextCheckingResult *s = [sizePart firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
  if (s) {
    *width = [[text substringWithRange:[s rangeAtIndex:1]] integerValue];
    *height = [[text substringWithRange:[s rangeAtIndex:2]] integerValue];
    text = [text substringToIndex:[s range].location];
  }
  *model = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  return YES;
}

+ (BOOL)isRole:(NSString *)value {
  return [value isKindOfClass:[NSString class]] && [[value lowercaseString] hasPrefix:kRolePrefix];
}

+ (NSUInteger)identicalCountForDisplay:(SlateDisplay *)display in:(NSArray<SlateDisplay *> *)displays {
  NSUInteger count = 0;
  for (SlateDisplay *other in displays) {
    if (!other.builtIn && !display.builtIn && other.width == display.width && other.height == display.height &&
        [other.name caseInsensitiveCompare:display.name] == NSOrderedSame) count++;
  }
  return count;
}

+ (SlateDisplay *)displayForRole:(NSString *)role in:(NSArray<SlateDisplay *> *)displays {
  NSString *model;
  NSInteger width, height, number;
  BOOL builtIn;
  if (![self parseRole:role model:&model width:&width height:&height number:&number builtIn:&builtIn]) return nil;
  NSArray *ordered = [self sortedLeftToRight:displays];
  NSInteger seen = 0;
  for (SlateDisplay *display in ordered) {
    if (builtIn) {
      if (display.builtIn) return display;
      continue;
    }
    if (display.builtIn) continue;
    if ([display.name caseInsensitiveCompare:model] != NSOrderedSame) continue;
    if (width > 0 && (display.width != width || display.height != height)) continue;
    if (++seen == number) return display;
  }
  return nil;
}

+ (BOOL)display:(SlateDisplay *)a looksLike:(SlateDisplay *)b {
  return !a.builtIn && !b.builtIn && a.width == b.width && a.height == b.height && [a.name caseInsensitiveCompare:b.name] == NSOrderedSame;
}

// Which of its identical twins this display is, counting from the left.
+ (NSInteger)rankOfDisplay:(SlateDisplay *)display in:(NSArray<SlateDisplay *> *)displays {
  NSInteger rank = 0;
  for (SlateDisplay *other in [self sortedLeftToRight:displays]) {
    if ([self display:other looksLike:display]) rank++;
    if (other == display) break;
  }
  return rank;
}

+ (NSString *)roleForDisplay:(SlateDisplay *)display in:(NSArray<SlateDisplay *> *)displays {
  if (display.builtIn) return @"display: built-in";
  NSString *role = [NSString stringWithFormat:@"display: %@ %@", display.name, [display sizeText]];
  if ([self identicalCountForDisplay:display in:displays] > 1) {
    role = [role stringByAppendingFormat:@" #%ld", (long)[self rankOfDisplay:display in:displays]];
  }
  return role;
}

+ (NSString *)referenceForValue:(NSString *)value {
  return [self referenceForValue:value displays:[self connected]];
}

+ (NSString *)referenceForValue:(NSString *)value displays:(NSArray<SlateDisplay *> *)displays {
  if (![self isRole:value]) return value;
  SlateDisplay *display = [self displayForRole:value in:displays];
  if (display == nil) return kMissingReference;
  NSUInteger index = [[self sortedLeftToRight:displays] indexOfObjectIdenticalTo:display];
  return [NSString stringWithFormat:@"ordered:%lu", (unsigned long)index];
}

#pragma mark - Names and old references

+ (NSString *)suggestedNameForDisplay:(SlateDisplay *)display in:(NSArray<SlateDisplay *> *)displays {
  if (display.builtIn) return @"monitor-built-in";
  NSMutableString *slug = [NSMutableString string];
  for (NSUInteger i = 0; i < [display.name length]; i++) {
    unichar c = [[display.name lowercaseString] characterAtIndex:i];
    if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:c]) [slug appendFormat:@"%C", c];
    else if ([slug length] > 0 && ![slug hasSuffix:@"-"]) [slug appendString:@"-"];
  }
  NSString *base = [@"monitor-" stringByAppendingString:[slug stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-"]]];
  if ([self identicalCountForDisplay:display in:displays] <= 1) return base;
  return [NSString stringWithFormat:@"%@-%ld", base, (long)[self rankOfDisplay:display in:displays]];
}

+ (SlateDisplay *)displayForNumber:(NSInteger)number leftToRight:(BOOL)leftToRight in:(NSArray<SlateDisplay *> *)displays {
  NSArray *list = leftToRight ? [self sortedLeftToRight:displays] : displays;
  return number >= 0 && number < (NSInteger)[list count] ? list[number] : nil;
}

@end
