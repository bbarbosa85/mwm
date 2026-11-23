//
//  PushOperation.m
//  Slate
//
//  Created by Jigish Patel on 1/20/13.
//  Copyright 2011 Jigish Patel. All rights reserved.
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

#import "PushOperation.h"
#import "StringTokenizer.h"
#import "MWMLogger.h"
#import "Constants.h"

@implementation PushOperation

// Where a push puts the window, as expressions: the top left (x, y) and the size (width, height).
// Nil when the direction or the style isn't known.
+ (NSDictionary<NSString *, NSString *> *)geometryForDirection:(NSString *)direction style:(NSString *)style {
  if (style == nil) style = NONE;
  NSString *thickness = nil;
  if ([style hasPrefix:BAR_RESIZE_WITH_VALUE]) {
    thickness = [[style componentsSeparatedByString:COLON] objectAtIndex:1];
    style = BAR_RESIZE_WITH_VALUE;
  }
  BOOL isBarResize = thickness != nil;
  NSString *x = nil, *y = nil, *width = @"windowSizeX", *height = @"windowSizeY";
  if ([direction isEqualToString:TOP] || [direction isEqualToString:UP]) {
    if ([style isEqualToString:CENTER]) { x = @"screenOriginX+(screenSizeX-windowSizeX)/2"; y = @"screenOriginY"; }
    else if ([style isEqualToString:BAR]) { x = @"screenOriginX"; y = @"screenOriginY"; width = @"screenSizeX"; }
    else if (isBarResize) { x = @"screenOriginX"; y = @"screenOriginY"; width = @"screenSizeX"; height = thickness; }
    else if ([style isEqualToString:NONE]) { x = @"windowTopLeftX"; y = @"screenOriginY"; }
  } else if ([direction isEqualToString:BOTTOM] || [direction isEqualToString:DOWN]) {
    if ([style isEqualToString:CENTER]) { x = @"screenOriginX+(screenSizeX-windowSizeX)/2"; y = @"screenOriginY+screenSizeY-windowSizeY"; }
    else if ([style isEqualToString:BAR]) { x = @"screenOriginX"; y = @"screenOriginY+screenSizeY-windowSizeY"; width = @"screenSizeX"; }
    else if (isBarResize) { x = @"screenOriginX"; y = [NSString stringWithFormat:@"screenOriginY+screenSizeY-(%@)", thickness]; width = @"screenSizeX"; height = thickness; }
    else if ([style isEqualToString:NONE]) { x = @"windowTopLeftX"; y = @"screenOriginY+screenSizeY-windowSizeY"; }
  } else if ([direction isEqualToString:LEFT]) {
    if ([style isEqualToString:CENTER]) { x = @"screenOriginX"; y = @"screenOriginY+(screenSizeY-windowSizeY)/2"; }
    else if ([style isEqualToString:BAR]) { x = @"screenOriginX"; y = @"screenOriginY"; height = @"screenSizeY"; }
    else if (isBarResize) { x = @"screenOriginX"; y = @"screenOriginY"; width = thickness; height = @"screenSizeY"; }
    else if ([style isEqualToString:NONE]) { x = @"screenOriginX"; y = @"windowTopLeftY"; }
  } else if ([direction isEqualToString:RIGHT]) {
    if ([style isEqualToString:CENTER]) { x = @"screenOriginX+screenSizeX-windowSizeX"; y = @"screenOriginY+(screenSizeY-windowSizeY)/2"; }
    else if ([style isEqualToString:BAR]) { x = @"screenOriginX+screenSizeX-windowSizeX"; y = @"screenOriginY"; height = @"screenSizeY"; }
    else if (isBarResize) { x = [NSString stringWithFormat:@"screenOriginX+screenSizeX-(%@)", thickness]; y = @"screenOriginY"; width = thickness; height = @"screenSizeY"; }
    else if ([style isEqualToString:NONE]) { x = @"screenOriginX+screenSizeX-windowSizeX"; y = @"windowTopLeftY"; }
  }
  if (x == nil) return nil;
  return @{@"x": x, @"y": y, @"width": width, @"height": height};
}

- (NSArray *)requiredOptions {
  return [NSArray arrayWithObjects:OPT_DIRECTION, nil];
}

// Throws for a direction or style that isn't known, as it always has.
+ (NSDictionary<NSString *, NSString *> *)requiredGeometryForDirection:(NSString *)direction style:(NSString *)style {
  NSDictionary *geometry = [self geometryForDirection:direction style:style];
  if (geometry != nil) return geometry;
  BOOL knownDirection = [@[TOP, UP, BOTTOM, DOWN, LEFT, RIGHT] containsObject:direction];
  NSString *what = knownDirection ? @"Style" : @"Direction";
  NSString *value = knownDirection ? style : direction;
  MWMLogger(@"ERROR: Unrecognized %@ '%@'", [what lowercaseString], value);
  @throw([NSException exceptionWithName:[NSString stringWithFormat:@"Unrecognized %@", what] reason:[NSString stringWithFormat:@"Unrecognized %@ '%@'", [what lowercaseString], value] userInfo:nil]);
}

- (void)afterEvalOptions {
  NSString *direction = [[self options] objectForKey:OPT_DIRECTION];
  NSString *style = [[self options] objectForKey:OPT_STYLE];
  NSString *screen = [[self options] objectForKey:OPT_SCREEN];
  [self setMonitor:screen != nil ? screen : REF_CURRENT_SCREEN];
  NSDictionary *geometry = [PushOperation requiredGeometryForDirection:direction style:style];
  [self setTopLeft:[[ExpressionPoint alloc] initWithX:geometry[@"x"] y:geometry[@"y"]]];
  [self setDimensions:[[ExpressionPoint alloc] initWithX:geometry[@"width"] y:geometry[@"height"]]];
}

+ (id)pushOperation {
  return [[PushOperation alloc] init];
}

+ (id)pushOperationFromString:(NSString *)pushOperation {
  // push <top|bottom|up|down|left|right> <optional:none|center|bar|bar-resize:expression> <optional:monitor (must specify previous option to specify monitor)>
  NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
  [StringTokenizer tokenize:pushOperation into:tokens];

  if ([tokens count] < 2) {
    MWMLogger(@"ERROR: Invalid Parameters '%@'", pushOperation);
    @throw([NSException exceptionWithName:@"Invalid Parameters" reason:[NSString stringWithFormat:@"Invalid Parameters in '%@'. Push operations require the following format: 'push direction [optional:style]'", pushOperation] userInfo:nil]);
  }

  NSString *direction = [tokens objectAtIndex:1];
  NSString *style = [tokens count] >= 3 ? [tokens objectAtIndex:2] : NONE;
  NSDictionary *geometry = [self requiredGeometryForDirection:direction style:style];
  NSString *topLeft = [NSString stringWithFormat:@"%@;%@", geometry[@"x"], geometry[@"y"]];
  NSString *dimensions = [NSString stringWithFormat:@"%@;%@", geometry[@"width"], geometry[@"height"]];
  Operation *op = [[MoveOperation alloc] initWithTopLeft:topLeft dimensions:dimensions monitor:([tokens count] >=4 ? [tokens objectAtIndex:3] : REF_CURRENT_SCREEN)];
  return op;
}

@end
