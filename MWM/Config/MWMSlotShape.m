//
//  MWMSlotShape.m
//  MWM
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

#import "MWMSlotShape.h"
#import "MWMSlots.h"

static const CGFloat kEpsilon = 0.0005;

@implementation MWMSlotAxis

- (instancetype)init {
  self = [super init];
  if (self) { _position = 0; _sizeFraction = 1; }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  MWMSlotAxis *copy = [[MWMSlotAxis alloc] init];
  copy.position = self.position; copy.centered = self.centered; copy.sizeInPixels = self.sizeInPixels;
  copy.sizeFraction = self.sizeFraction; copy.sizePixels = self.sizePixels;
  copy.marginStart = self.marginStart; copy.marginEnd = self.marginEnd;
  return copy;
}

- (BOOL)isPlain {
  return !self.sizeInPixels && self.marginStart == 0 && self.marginEnd == 0;
}

// The start and size in points on a screen of this size along this axis.
- (void)getStart:(CGFloat *)start size:(CGFloat *)size forScreen:(CGFloat)screen {
  CGFloat base = self.sizeInPixels ? self.sizePixels : self.sizeFraction * screen;
  CGFloat from = self.centered ? (screen - base) / 2 : self.position * screen;
  *start = from + self.marginStart;
  *size = base - self.marginStart - self.marginEnd;
}

// The two expressions for this axis: where it starts, and how big it is.
- (void)getStartExpression:(NSString **)start sizeExpression:(NSString **)size origin:(NSString *)origin variable:(NSString *)variable {
  NSString *base = self.sizeInPixels ? [NSString stringWithFormat:@"%ld", (long)self.sizePixels] : [MWMSlots scaledVariable:variable fraction:self.sizeFraction];
  NSInteger margins = self.marginStart + self.marginEnd;
  *size = margins > 0 ? [NSString stringWithFormat:@"%@-%ld", base, (long)margins] : base;
  NSString *position;
  if (self.centered && self.sizeInPixels) position = [NSString stringWithFormat:@"%@+(%@-%ld)/2", origin, variable, (long)self.sizePixels];
  else if (self.centered) position = [MWMSlots positionWithOrigin:origin size:variable fraction:(1 - self.sizeFraction) / 2];
  else position = [MWMSlots positionWithOrigin:origin size:variable fraction:self.position];
  if (self.marginStart > 0) {
    position = [position isEqualToString:origin] ? [NSString stringWithFormat:@"%@+%ld", origin, (long)self.marginStart]
                                                 : [NSString stringWithFormat:@"(%@)+%ld", position, (long)self.marginStart];
  }
  *start = position;
}

// "screenSizeX", "screenSizeX/4" or "(3*screenSizeX/4)" as a fraction; NO when it is anything else.
+ (BOOL)getFraction:(CGFloat *)fraction fromScaled:(NSString *)text variable:(NSString *)variable {
  if ([text isEqualToString:variable]) { *fraction = 1; return YES; }
  NSString *escaped = [NSRegularExpression escapedPatternForString:variable];
  NSArray *patterns = @[[NSString stringWithFormat:@"^%@/(\\d+)$", escaped], [NSString stringWithFormat:@"^\\((\\d+)\\*%@/(\\d+)\\)$", escaped]];
  for (NSUInteger i = 0; i < 2; i++) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:patterns[i] options:0 error:nil];
    NSTextCheckingResult *match = [re firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
    if (match == nil) continue;
    double p = i == 0 ? 1 : [[text substringWithRange:[match rangeAtIndex:1]] doubleValue];
    double q = [[text substringWithRange:[match rangeAtIndex:i == 0 ? 1 : 2]] doubleValue];
    if (q == 0) return NO;
    *fraction = p / q;
    return YES;
  }
  return NO;
}

+ (NSString *)group:(NSInteger)n of:(NSString *)text match:(NSTextCheckingResult *)match { return [text substringWithRange:[match rangeAtIndex:n]]; }

// Reads the two expressions back; nil when they aren't what getStartExpression: writes.
+ (MWMSlotAxis *)axisFromStart:(NSString *)start size:(NSString *)size origin:(NSString *)origin variable:(NSString *)variable {
  MWMSlotAxis *axis = [[MWMSlotAxis alloc] init];
  NSString *o = [NSRegularExpression escapedPatternForString:origin], *v = [NSRegularExpression escapedPatternForString:variable];
  // How big, and the margins taken off it.
  NSRegularExpression *sizeRe = [NSRegularExpression regularExpressionWithPattern:@"^([^-]+)(?:-(\\d+))?$" options:0 error:nil];
  NSTextCheckingResult *sm = [sizeRe firstMatchInString:size options:0 range:NSMakeRange(0, [size length])];
  if (sm == nil) return nil;
  NSString *base = [size substringWithRange:[sm rangeAtIndex:1]];
  NSInteger margins = [sm rangeAtIndex:2].location != NSNotFound ? [[size substringWithRange:[sm rangeAtIndex:2]] integerValue] : 0;
  CGFloat fraction = 0;
  NSRegularExpression *digits = [NSRegularExpression regularExpressionWithPattern:@"^\\d+$" options:0 error:nil];
  if ([digits firstMatchInString:base options:0 range:NSMakeRange(0, [base length])] != nil) { axis.sizeInPixels = YES; axis.sizePixels = [base integerValue]; }
  else if ([self getFraction:&fraction fromScaled:base variable:variable]) axis.sizeFraction = fraction;
  else return nil;
  // Where it starts, and the margin at that side.
  NSInteger startMargin = 0;
  NSString *core = start;
  NSRegularExpression *withMargin = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^\\((.+)\\)\\+(\\d+)$"] options:0 error:nil];
  NSRegularExpression *originMargin = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@\\+(\\d+)$", o] options:0 error:nil];
  NSTextCheckingResult *wm = [withMargin firstMatchInString:start options:0 range:NSMakeRange(0, [start length])];
  NSTextCheckingResult *om = [originMargin firstMatchInString:start options:0 range:NSMakeRange(0, [start length])];
  if (wm != nil) { core = [start substringWithRange:[wm rangeAtIndex:1]]; startMargin = [[start substringWithRange:[wm rangeAtIndex:2]] integerValue]; }
  else if (om != nil) { core = origin; startMargin = [[start substringWithRange:[om rangeAtIndex:1]] integerValue]; }
  if ([core isEqualToString:origin]) axis.position = 0;
  else {
    NSRegularExpression *centeredRe = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@\\+\\(%@-(\\d+)\\)/2$", o, v] options:0 error:nil];
    NSRegularExpression *offsetRe = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@\\+(.+)$", o] options:0 error:nil];
    NSTextCheckingResult *cm = [centeredRe firstMatchInString:core options:0 range:NSMakeRange(0, [core length])];
    NSTextCheckingResult *fm = [offsetRe firstMatchInString:core options:0 range:NSMakeRange(0, [core length])];
    if (cm != nil) {
      if (!axis.sizeInPixels || [[core substringWithRange:[cm rangeAtIndex:1]] integerValue] != axis.sizePixels) return nil;
      axis.centered = YES;
    } else if (fm != nil && [self getFraction:&fraction fromScaled:[core substringWithRange:[fm rangeAtIndex:1]] variable:variable]) {
      axis.position = fraction;
    } else return nil;
  }
  if (margins < startMargin) return nil;
  axis.marginStart = startMargin;
  axis.marginEnd = margins - startMargin;
  return axis;
}

@end

@implementation MWMSlotShape

- (instancetype)init {
  self = [super init];
  if (self) { _horizontal = [[MWMSlotAxis alloc] init]; _vertical = [[MWMSlotAxis alloc] init]; }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  MWMSlotShape *copy = [[MWMSlotShape alloc] init];
  copy.horizontal = [self.horizontal copy];
  copy.vertical = [self.vertical copy];
  return copy;
}

+ (instancetype)shapeFromRect:(CGRect)r {
  MWMSlotShape *shape = [[MWMSlotShape alloc] init];
  shape.horizontal.position = r.origin.x; shape.horizontal.sizeFraction = r.size.width;
  shape.vertical.position = r.origin.y; shape.vertical.sizeFraction = r.size.height;
  return shape;
}

- (BOOL)isPlainPercent {
  return [self.horizontal isPlain] && [self.vertical isPlain] && !self.horizontal.centered && !self.vertical.centered;
}

- (CGRect)plainRect {
  return CGRectMake(self.horizontal.position, self.vertical.position, self.horizontal.sizeFraction, self.vertical.sizeFraction);
}

- (NSString *)formula {
  if ([self isPlainPercent]) return [MWMSlots formulaForRect:[self plainRect]];
  NSString *x, *w, *y, *h;
  [self.horizontal getStartExpression:&x sizeExpression:&w origin:@"screenOriginX" variable:@"screenSizeX"];
  [self.vertical getStartExpression:&y sizeExpression:&h origin:@"screenOriginY" variable:@"screenSizeY"];
  return [NSString stringWithFormat:@"move %@;%@ %@;%@", x, y, w, h];
}

+ (MWMSlotShape *)shapeFromFormula:(NSString *)formula {
  NSMutableArray *words = [NSMutableArray array];
  for (NSString *word in [formula componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) if ([word length] > 0) [words addObject:word];
  if ([words count] != 3 || ![words[0] isEqualToString:@"move"]) return nil;
  NSArray *origin = [words[1] componentsSeparatedByString:@";"], *size = [words[2] componentsSeparatedByString:@";"];
  if ([origin count] != 2 || [size count] != 2) return nil;
  MWMSlotAxis *horizontal = [MWMSlotAxis axisFromStart:origin[0] size:size[0] origin:@"screenOriginX" variable:@"screenSizeX"];
  MWMSlotAxis *vertical = [MWMSlotAxis axisFromStart:origin[1] size:size[1] origin:@"screenOriginY" variable:@"screenSizeY"];
  if (horizontal == nil || vertical == nil) return nil;
  MWMSlotShape *shape = [[MWMSlotShape alloc] init];
  shape.horizontal = horizontal;
  shape.vertical = vertical;
  // Only what this shape would have written itself counts: anything else keeps its text as a custom formula.
  NSString *normalized = [words componentsJoinedByString:@" "];
  return [[shape formula] isEqualToString:normalized] ? shape : nil;
}

- (CGRect)rectForScreenSize:(CGSize)screen {
  CGFloat x, w, y, h;
  [self.horizontal getStart:&x size:&w forScreen:screen.width];
  [self.vertical getStart:&y size:&h forScreen:screen.height];
  return CGRectMake(x, y, w, h);
}

- (CGRect)fractionRectForScreenSize:(CGSize)screen {
  CGRect r = [self rectForScreenSize:screen];
  return CGRectMake(r.origin.x / screen.width, r.origin.y / screen.height, r.size.width / screen.width, r.size.height / screen.height);
}

- (NSString *)problem {
  CGRect r = [self rectForScreenSize:CGSizeMake(1000, 1000)];
  if (r.size.width < 1 || r.size.height < 1) return @"The margins and sizes leave nothing of the slot.";
  return nil;
}

- (BOOL)isEqualToShape:(MWMSlotShape *)other {
  return [[self formula] isEqualToString:[other formula]];
}

@end
