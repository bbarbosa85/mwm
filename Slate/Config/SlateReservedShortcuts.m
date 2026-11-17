//
//  SlateReservedShortcuts.m
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

#import "SlateReservedShortcuts.h"
#import "SlateShortcut.h"


@implementation SlateReservedShortcuts

+ (NSArray<NSDictionary *> *)all {
  static NSArray *entries;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSMutableArray *list = [NSMutableArray array];
    void (^add)(NSArray *, NSString *, NSString *) = ^(NSArray *mods, NSString *key, NSString *reason) {
      [list addObject:@{@"modifiers": mods, @"key": key, @"reason": reason}];
    };
    NSArray *cmd = @[@"cmd"];
    add(cmd, @"s", @"saves in almost every app");
    add(cmd, @"c", @"copies");
    add(cmd, @"v", @"pastes");
    add(cmd, @"x", @"cuts");
    add(cmd, @"z", @"undoes");
    add(cmd, @"a", @"selects everything");
    add(cmd, @"q", @"quits the app");
    add(cmd, @"w", @"closes the window");
    add(cmd, @"n", @"opens a new window or document");
    add(cmd, @"t", @"opens a new tab");
    add(cmd, @"f", @"searches");
    add(cmd, @"p", @"prints");
    add(cmd, @"o", @"opens a file");
    add(cmd, @"tab", @"switches apps");
    add(cmd, @"space", @"opens Spotlight");
    add(cmd, @"h", @"hides the app");
    add(cmd, @"m", @"minimizes the window");
    for (NSString *key in @[@"3", @"4", @"5"]) add((@[@"shift", @"cmd"]), key, @"takes screenshots");
    add((@[@"ctrl", @"cmd"]), @"q", @"locks the screen");
    add((@[@"alt", @"cmd"]), @"esc", @"opens Force Quit");
    for (NSString *key in @[@"left", @"right", @"up", @"down"]) add((@[@"ctrl"]), key, @"switches Spaces and Mission Control");
    entries = list;
  });
  return entries;
}

+ (NSString *)reasonForKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames {
  NSArray *given = [SlateShortcut modifierNamesFromString:[modifierNames componentsJoinedByString:@";"]] ?: modifierNames;
  if ([given count] == 0) return @"A key with no modifier would stop working when you type. Add a modifier.";
  for (NSDictionary *entry in [self all]) {
    if ([entry[@"key"] isEqualToString:keyName] && [entry[@"modifiers"] isEqualToArray:given]) {
      NSMutableString *combo = [NSMutableString string];
      for (NSString *name in entry[@"modifiers"]) [combo appendString:[SlateShortcut symbolForModifierName:name]];
      [combo appendString:[SlateShortcut displayForKeyName:keyName]];
      return [NSString stringWithFormat:@"%@ %@. Pick another combo.", combo, entry[@"reason"]];
    }
  }
  return nil;
}

@end
