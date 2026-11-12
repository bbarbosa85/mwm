//
//  SlateShortcut.m
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

#import "SlateShortcut.h"
#import "Binding.h"
#import "SlateConfigDocument.h"

static NSArray<NSString *> *ModifierOrder(void) {
  return @[@"ctrl", @"alt", @"shift", @"cmd", @"fn"];
}

@implementation SlateShortcut

#pragma mark - Keys

// The key dictionary maps names to key codes, one to one, so it can be turned around.
+ (nullable NSString *)keyNameForKeyCode:(UInt16)keyCode {
  static NSDictionary *source;
  static NSDictionary<NSNumber *, NSString *> *inverse;
  NSDictionary *dictionary = [Binding asciiToCodeDict];
  if (dictionary != source) {
    NSMutableDictionary *flipped = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];
    for (NSString *name in dictionary) flipped[dictionary[name]] = name;
    inverse = flipped;
    source = dictionary;
  }
  return inverse[@(keyCode)];
}

+ (NSString *)displayForKeyName:(NSString *)keyName {
  static NSDictionary *symbols;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    symbols = @{
      @"left": @"←", @"right": @"→", @"up": @"↑", @"down": @"↓",
      @"return": @"↩", @"tab": @"⇥", @"delete": @"⌫", @"esc": @"⎋", @"space": @"Space", @"caps": @"⇪",
      @"home": @"Home", @"end": @"End", @"pageUp": @"Page Up", @"pageDown": @"Page Down",
      @"help": @"Help", @"mute": @"Mute", @"backslash": @"\\",
      @"padEnter": @"Num ↩", @"padClear": @"Num Clear",
    };
  });
  if (symbols[keyName] != nil) return symbols[keyName];
  if ([keyName hasPrefix:@"pad"] && [keyName length] > 3) return [@"Num " stringByAppendingString:[keyName substringFromIndex:3]];
  return [keyName uppercaseString];
}

#pragma mark - Modifiers

+ (NSArray<NSString *> *)modifierNamesFromFlags:(NSEventModifierFlags)flags {
  NSMutableArray *names = [NSMutableArray array];
  if (flags & NSEventModifierFlagControl) [names addObject:@"ctrl"];
  if (flags & NSEventModifierFlagOption) [names addObject:@"alt"];
  if (flags & NSEventModifierFlagShift) [names addObject:@"shift"];
  if (flags & NSEventModifierFlagCommand) [names addObject:@"cmd"];
  return names;
}

+ (NSArray<NSString *> *)modifierNamesFromString:(NSString *)modifiers {
  NSMutableSet *found = [NSMutableSet set];
  NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@",;"];
  for (NSString *part in [modifiers componentsSeparatedByCharactersInSet:separators]) {
    NSString *name = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([name length] == 0) continue;
    if (![ModifierOrder() containsObject:name]) return nil;
    [found addObject:name];
  }
  NSMutableArray *ordered = [NSMutableArray array];
  for (NSString *name in ModifierOrder()) {
    if ([found containsObject:name]) [ordered addObject:name];
  }
  return ordered;
}

+ (NSString *)stringFromModifierNames:(NSArray<NSString *> *)names {
  return [names componentsJoinedByString:@";"];
}

+ (NSString *)aliasForModifierNames:(NSArray<NSString *> *)names inEntries:(NSArray<SlateConfigEntry *> *)entries {
  if ([names count] == 0) return nil;
  for (SlateConfigEntry *entry in entries) {
    NSArray *entryNames = [self modifierNamesFromString:[entry.value description]];
    if (entryNames != nil && [entryNames isEqualToArray:names]) return [NSString stringWithFormat:@"${%@}", entry.name];
  }
  return nil;
}

+ (NSString *)symbolForModifierName:(NSString *)name {
  if ([name isEqualToString:@"ctrl"]) return @"⌃";
  if ([name isEqualToString:@"alt"]) return @"⌥";
  if ([name isEqualToString:@"shift"]) return @"⇧";
  if ([name isEqualToString:@"cmd"]) return @"⌘";
  return name;
}

#pragma mark - Identity

+ (NSString *)identityForKey:(NSString *)key modifiers:(NSString *)modifiers {
  NSString *keystroke = [modifiers length] > 0 ? [NSString stringWithFormat:@"%@:%@", key, modifiers] : key;
  @try {
    NSArray *parsed = [Binding getKeystrokeFromString:keystroke];
    return [NSString stringWithFormat:@"%@:%@:%@", parsed[0], parsed[1], parsed.count > 2 && parsed[2] != [NSNull null] ? parsed[2] : @""];
  } @catch (NSException *exception) {
    return nil;
  }
}

@end
