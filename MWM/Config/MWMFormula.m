//
//  MWMFormula.m
//  MWM
//
//  
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

#import "MWMFormula.h"
#import "ExpressionPoint.h"
#import "Constants.h"

@implementation MWMFormula

+ (NSArray<NSString *> *)variableNames {
  return @[SCREEN_ORIGIN_X, SCREEN_ORIGIN_Y, SCREEN_SIZE_X, SCREEN_SIZE_Y, WINDOW_TOP_LEFT_X, WINDOW_TOP_LEFT_Y,
           WINDOW_SIZE_X, WINDOW_SIZE_Y, NEW_WINDOW_SIZE_X, NEW_WINDOW_SIZE_Y];
}

+ (CGRect)sampleWindowForScreenSize:(CGSize)screen {
  return CGRectMake(screen.width / 4, screen.height / 4, screen.width / 2, screen.height / 2);
}

+ (NSDictionary *)valuesForScreenSize:(CGSize)screen window:(CGRect)window {
  return @{SCREEN_ORIGIN_X: @0, SCREEN_ORIGIN_Y: @0, SCREEN_SIZE_X: @(screen.width), SCREEN_SIZE_Y: @(screen.height),
           WINDOW_TOP_LEFT_X: @(window.origin.x), WINDOW_TOP_LEFT_Y: @(window.origin.y),
           WINDOW_SIZE_X: @(window.size.width), WINDOW_SIZE_Y: @(window.size.height),
           NEW_WINDOW_SIZE_X: @(window.size.width), NEW_WINDOW_SIZE_Y: @(window.size.height)};
}

// The checks that need no evaluation: what is written, not what it gives.
+ (NSString *)writtenErrorForExpression:(NSString *)expression {
  NSString *text = [expression stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([text length] == 0) return @"Enter a number or a formula.";
  if ([text rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
    return @"Leave out the spaces: write screenSizeX/3, not screenSizeX / 3.";
  }
  NSRange alias = [text rangeOfString:@"${"];
  if (alias.location != NSNotFound) {
    NSRange end = [text rangeOfString:@"}" options:0 range:NSMakeRange(alias.location, [text length] - alias.location)];
    NSString *name = end.location != NSNotFound ? [text substringWithRange:NSMakeRange(alias.location, end.location + 1 - alias.location)] : @"${";
    return [NSString stringWithFormat:@"%@ isn't defined.", name];
  }
  NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
  [allowed addCharactersInString:@"_.+-*/()"];
  if ([text rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) {
    return @"Only numbers, MWM's names, + - * / and parentheses can be used.";
  }
  NSInteger depth = 0;
  for (NSUInteger i = 0; i < [text length]; i++) {
    unichar c = [text characterAtIndex:i];
    if (c == '(') depth++;
    if (c == ')' && --depth < 0) break;
  }
  if (depth != 0) return @"The parentheses don't match.";
  NSRegularExpression *names = [NSRegularExpression regularExpressionWithPattern:@"[A-Za-z_][A-Za-z0-9_]*" options:0 error:nil];
  for (NSTextCheckingResult *match in [names matchesInString:text options:0 range:NSMakeRange(0, [text length])]) {
    NSString *name = [text substringWithRange:match.range];
    if (![[self variableNames] containsObject:name]) {
      return [NSString stringWithFormat:@"\"%@\" isn't a name MWM knows. Try %@.", name, [[self variableNames] componentsJoinedByString:@", "]];
    }
  }
  return nil;
}

+ (NSString *)errorForExpression:(NSString *)expression {
  NSString *written = [self writtenErrorForExpression:expression];
  if (written != nil) return written;
  CGSize screen = CGSizeMake(1600, 1000);
  @try {
    float value = [ExpressionPoint expToFloat:expression withDict:[self valuesForScreenSize:screen window:[self sampleWindowForScreenSize:screen]]];
    if (isnan(value) || isinf(value)) return @"This divides by zero.";
  } @catch (NSException *exception) {
    return @"This isn't a formula MWM can work out. Check the operators and parentheses.";
  }
  return nil;
}

// The pieces of "move x;y w;h [screen]": nil and a message when it doesn't have that shape.
+ (NSArray<NSString *> *)partsOfMoveText:(NSString *)text error:(NSString **)error {
  NSMutableArray *words = [NSMutableArray array];
  for (NSString *word in [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) if ([word length] > 0) [words addObject:word];
  if ([words count] < 3 || ![words[0] isEqualToString:@"move"]) {
    if (error) *error = @"Write it as: move x;y width;height";
    return nil;
  }
  ExpressionPoint *origin = [ExpressionPoint pointFromString:words[1]], *size = [ExpressionPoint pointFromString:words[2]];
  if (origin == nil || size == nil) {
    if (error) *error = @"Write it as: move x;y width;height, with a semicolon between each pair and no spaces inside.";
    return nil;
  }
  return @[origin.x, origin.y, size.x, size.y];
}

+ (BOOL)getRect:(CGRect *)rect fromMoveText:(NSString *)text screenSize:(CGSize)screen window:(CGRect)window error:(NSString **)error {
  NSArray *parts = [self partsOfMoveText:text error:error];
  if (parts == nil) return NO;
  NSArray *labels = @[@"x", @"y", @"Width", @"Height"];
  float numbers[4];
  NSDictionary *values = [self valuesForScreenSize:screen window:window];
  for (NSUInteger i = 0; i < 4; i++) {
    NSString *problem = [self writtenErrorForExpression:parts[i]];
    if (problem != nil) { if (error) *error = [NSString stringWithFormat:@"%@: %@", labels[i], problem]; return NO; }
    @try {
      numbers[i] = [ExpressionPoint expToFloat:parts[i] withDict:values];
    } @catch (NSException *exception) {
      if (error) *error = [NSString stringWithFormat:@"%@: this isn't a formula MWM can work out. Check the operators and parentheses.", labels[i]];
      return NO;
    }
    if (isnan(numbers[i]) || isinf(numbers[i])) {
      if (error) *error = [NSString stringWithFormat:@"%@: this divides by zero.", labels[i]];
      return NO;
    }
  }
  if (rect) *rect = CGRectMake(numbers[0], numbers[1], numbers[2], numbers[3]);
  return YES;
}

+ (BOOL)moveTextUsesUnsupportedSyntax:(NSString *)text {
  NSArray *parts = [self partsOfMoveText:text error:nil];
  if (parts == nil) return NO;
  NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
  [allowed addCharactersInString:@"_.+-*/()"];
  for (NSString *part in parts) if ([part rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return YES;
  return NO;
}

+ (NSString *)errorForMoveText:(NSString *)text {
  NSString *error = nil;
  CGSize screen = CGSizeMake(1600, 1000);
  return [self getRect:NULL fromMoveText:text screenSize:screen window:[self sampleWindowForScreenSize:screen] error:&error] ? nil : error;
}

@end
