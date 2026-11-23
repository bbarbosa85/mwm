//
//  MWMPushOptions.m
//  MWM
//
//  Formulas like screenOriginX+screenSizeX/3, checked and worked out for a screen of a given size, using the same
//  evaluator MWM uses when a shortcut runs. Nothing outside numbers, MWM's variable names, + - * / and
//  parentheses is accepted, so what the window shows is what the shortcut will do.
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

#import "MWMPushOptions.h"
#import "PushOperation.h"
#import "MWMFormula.h"

static NSString *Number(double value) { return [NSString stringWithFormat:@"%g", value]; }

@implementation MWMPushOptions

+ (instancetype)defaultOptions {
  MWMPushOptions *options = [[MWMPushOptions alloc] init];
  options.style = MWMPushStyleThickness;
  options.thickness = 2;
  options.unit = MWMPushUnitParts;
  return options;
}

- (instancetype)init {
  self = [super init];
  if (self) { _screen = @""; _thickness = 50; _unit = MWMPushUnitPercent; }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  MWMPushOptions *copy = [[MWMPushOptions alloc] init];
  copy.style = self.style; copy.thickness = self.thickness; copy.unit = self.unit; copy.screen = self.screen; copy.writesKeepSize = self.writesKeepSize;
  return copy;
}

// The screen's width for a push to the left or right, its height for up or down.
static NSString *AxisName(NSString *direction) {
  return [direction isEqualToString:@"left"] || [direction isEqualToString:@"right"] ? @"screenSizeX" : @"screenSizeY";
}

- (NSString *)thicknessExpressionForDirection:(NSString *)direction {
  switch (self.unit) {
    case MWMPushUnitPixels: return Number(self.thickness);
    case MWMPushUnitParts: return [NSString stringWithFormat:@"%@/%@", AxisName(direction), Number(self.thickness)];
    case MWMPushUnitPercent: return [NSString stringWithFormat:@"%@*%@/100", AxisName(direction), Number(self.thickness)];
  }
}

- (NSString *)textForDirection:(NSString *)direction {
  NSString *style;
  switch (self.style) {
    case MWMPushStyleKeepSize: style = self.writesKeepSize || [self.screen length] > 0 ? @"none" : @""; break;
    case MWMPushStyleCenter: style = @"center"; break;
    case MWMPushStyleBar: style = @"bar"; break;
    case MWMPushStyleThickness: style = [@"bar-resize:" stringByAppendingString:[self thicknessExpressionForDirection:direction]]; break;
  }
  if ([self.screen length] > 0) return [NSString stringWithFormat:@"%@ %@", style, self.screen];
  return style;
}

+ (nullable instancetype)optionsFromText:(NSString *)text direction:(NSString *)direction {
  NSArray *tokens = [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  tokens = [tokens filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
  if ([tokens count] > 2) return nil;
  NSString *style = [tokens count] > 0 ? tokens[0] : @"";
  MWMPushOptions *options = [[MWMPushOptions alloc] init];
  options.screen = [tokens count] > 1 ? tokens[1] : @"";
  if ([style length] == 0 || [style isEqualToString:@"none"]) {
    options.style = MWMPushStyleKeepSize;
    options.writesKeepSize = [style isEqualToString:@"none"];
  } else if ([style isEqualToString:@"center"]) {
    options.style = MWMPushStyleCenter;
  } else if ([style isEqualToString:@"bar"]) {
    options.style = MWMPushStyleBar;
  } else if ([style hasPrefix:@"bar-resize:"]) {
    options.style = MWMPushStyleThickness;
    NSString *expression = [style substringFromIndex:[@"bar-resize:" length]];
    NSString *axis = AxisName(direction);
    NSArray *(^groups)(NSString *) = ^NSArray *(NSString *pattern) {
      NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
      NSTextCheckingResult *match = [regex firstMatchInString:expression options:0 range:NSMakeRange(0, [expression length])];
      return match == nil ? nil : @[[expression substringWithRange:[match rangeAtIndex:1]]];
    };
    NSString *number = @"([0-9]+(?:\\.[0-9]+)?)";
    NSArray *found;
    if ((found = groups([NSString stringWithFormat:@"^%@/%@$", axis, number]))) { options.unit = MWMPushUnitParts; options.thickness = [found[0] doubleValue]; }
    else if ((found = groups([NSString stringWithFormat:@"^%@\\*%@/100$", axis, number]))) { options.unit = MWMPushUnitPercent; options.thickness = [found[0] doubleValue]; }
    else if ((found = groups(@"^([0-9]+)$"))) { options.unit = MWMPushUnitPixels; options.thickness = [found[0] doubleValue]; }
    else return nil;
  } else {
    return nil;
  }
  // Only what it would have written itself.
  NSString *normalized = [tokens componentsJoinedByString:@" "];
  return [[options textForDirection:direction] isEqualToString:normalized] ? options : nil;
}

- (NSString *)problem {
  if (self.style != MWMPushStyleThickness) return nil;
  if (self.thickness <= 0) return @"The thickness needs to be more than zero.";
  if (self.unit == MWMPushUnitPercent && self.thickness > 100) return @"A percent of the screen can't be more than 100.";
  if (self.unit == MWMPushUnitParts && self.thickness < 1) return @"One part in N needs N to be 1 or more.";
  return nil;
}

- (CGRect)previewRectForDirection:(NSString *)direction {
  NSString *style = [[self textForDirection:direction] componentsSeparatedByString:@" "][0];
  NSDictionary *geometry = [PushOperation geometryForDirection:direction style:[style length] > 0 ? style : @"none"];
  if (geometry == nil || [self problem] != nil) return CGRectNull;
  NSString *text = [NSString stringWithFormat:@"move %@;%@ %@;%@", geometry[@"x"], geometry[@"y"], geometry[@"width"], geometry[@"height"]];
  CGSize screen = CGSizeMake(1600, 1000);
  CGRect rect;
  if (![MWMFormula getRect:&rect fromMoveText:text screenSize:screen window:[MWMFormula sampleWindowForScreenSize:screen] error:nil]) return CGRectNull;
  return CGRectMake(rect.origin.x / screen.width, rect.origin.y / screen.height, rect.size.width / screen.width, rect.size.height / screen.height);
}

@end
