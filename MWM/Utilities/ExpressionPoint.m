//
//  ExpressionPoint.m
//  Slate
//
//  Created by Jigish Patel on 5/18/11.
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

#import "ExpressionPoint.h"
#import "Constants.h"


@implementation ExpressionPoint

@synthesize x;
@synthesize y;

- (id)init {
  self = [super init];
  if (self) {
    [self setX:@"0"];
    [self setY:@"0"];
  }

  return self;
}

- (id)initWithX:(NSString *)xVal y:(NSString *)yVal {
  self = [super init];
  if (self) {
    [self setX:xVal];
    [self setY:yVal];
  }

  return self;
}


- (NSPoint)getPointWithDict:(NSDictionary *)values {
  return NSMakePoint([ExpressionPoint expToFloat:x withDict:values],[ExpressionPoint expToFloat:y withDict:values]);
}

- (NSSize)getSizeWithDict:(NSDictionary *)values {
  return NSMakeSize([ExpressionPoint expToFloat:x withDict:values],[ExpressionPoint expToFloat:y withDict:values]);
}

+ (ExpressionPoint *)pointFromString:(NSString *)str {
  if (str == nil) return nil;
  NSArray *tokens = [str componentsSeparatedByString:SEMICOLON];
  if ([tokens count] == 2) {
    return [[ExpressionPoint alloc] initWithX:[tokens objectAtIndex:0] y:[tokens objectAtIndex:1]];
  }
  tokens = [str componentsSeparatedByString:COMMA];
  if ([tokens count] == 2) {
    return [[ExpressionPoint alloc] initWithX:[tokens objectAtIndex:0] y:[tokens objectAtIndex:1]];
  }
  return nil;
}

+ (float)expToFloat:(NSString *)exp withDict:(NSDictionary *)values {
  if (exp != nil) {
    // then do the normal predicate stuff
    NSComparisonPredicate *pred = (NSComparisonPredicate *)[NSPredicate predicateWithFormat:[exp stringByAppendingString:@" == 42"]];
    NSExpression *lexp = [pred leftExpression];
    NSNumber *result = [lexp expressionValueWithObject:values context:nil];
    if (result == nil)
      @throw([NSException exceptionWithName:@"Unable to compute result" reason:exp userInfo:nil]);
    return [result floatValue];
  }
  @throw([NSException exceptionWithName:@"Expression is nil" reason:exp userInfo:nil]);
}

@end
