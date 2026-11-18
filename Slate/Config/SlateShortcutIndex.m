//
//  SlateShortcutIndex.m
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

#import "SlateShortcutIndex.h"
#import "SlateAction.h"
#import "SlateConfigDocument.h"
#import "SlateShortcut.h"

static NSString *const kCustomGroup = @"Custom";

@implementation SlateShortcutInfo

+ (NSString *)kindTitle:(SlateShortcutKind)kind {
  switch (kind) {
    case SlateShortcutKindMoveToSlot: return @"Move to slot";
    case SlateShortcutKindFocusApp: return @"Focus app";
    case SlateShortcutKindFocusWindow: return @"Focus window";
    case SlateShortcutKindResizeNudge: return @"Resize and nudge";
    case SlateShortcutKindFeature: return @"Features";
    case SlateShortcutKindOther: return @"Other";
  }
}

@end

@implementation SlateModifierGroup
@end

@interface SlateShortcutIndex ()
@property (copy) NSArray<SlateShortcutInfo *> *shortcuts;
@property (copy) NSArray<SlateModifierGroup *> *groups;
@property (assign) NSUInteger conflictCount;
@end

@implementation SlateShortcutIndex

#pragma mark - Reading a document

// "${hyper}" -> ctrl, alt, cmd by the document's own modifier entries; or a written-out "ctrl;alt".
static NSArray<NSString *> *ModifierNamesOf(SlateBindingEntry *binding, SlateConfigDocument *document, NSString **groupName) {
  NSString *text = [binding.modifiers stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] ?: @"";
  NSRegularExpression *alias = [NSRegularExpression regularExpressionWithPattern:@"^\\$\\{([^}]*)\\}$" options:0 error:nil];
  NSTextCheckingResult *match = [alias firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
  if (match != nil) {
    NSString *name = [text substringWithRange:[match rangeAtIndex:1]];
    for (SlateConfigEntry *entry in document.modifiers) {
      if (![entry.name isEqualToString:name]) continue;
      NSArray *names = [SlateShortcut modifierNamesFromString:[entry.value description]];
      if (names != nil) { *groupName = name; return names; }
    }
    return @[];
  }
  NSArray *names = [SlateShortcut modifierNamesFromString:text] ?: @[];
  // A set written out that a group names exactly is that group.
  for (SlateConfigEntry *entry in document.modifiers) {
    NSArray *groupNames = [SlateShortcut modifierNamesFromString:[entry.value description]];
    if ([names count] > 0 && groupNames != nil && [groupNames isEqualToArray:names]) { *groupName = entry.name; break; }
  }
  return names;
}

static SlateShortcutKind KindOfAction(SlateAction *action) {
  switch (action.kind) {
    case SlateActionKindMove: return SlateShortcutKindMoveToSlot;
    case SlateActionKindFocusApp: return SlateShortcutKindFocusApp;
    case SlateActionKindFocusDirection: return SlateShortcutKindFocusWindow;
    case SlateActionKindThrow:
    case SlateActionKindNudge:
    case SlateActionKindResize:
    case SlateActionKindPush: return SlateShortcutKindResizeNudge;
    case SlateActionKindHint:
    case SlateActionKindGrid:
    case SlateActionKindSwitch:
    case SlateActionKindRelaunch:
    case SlateActionKindSnapshot:
    case SlateActionKindRestoreSnapshot: return SlateShortcutKindFeature;
    case SlateActionKindCustom: return SlateShortcutKindOther;
  }
}

static void TitleOfAction(SlateAction *action, NSString **title, NSString **detail) {
  *detail = nil;
  switch (action.kind) {
    case SlateActionKindMove:
      *title = [@"Move to " stringByAppendingString:action.a];
      if ([action.b length] > 0) *detail = [@"on " stringByAppendingString:[[action.b hasPrefix:@"monitor-"] ? [action.b substringFromIndex:8] : action.b capitalizedString]];
      break;
    case SlateActionKindFocusApp: *title = [@"Focus " stringByAppendingString:action.a]; break;
    case SlateActionKindFocusDirection: *title = [@"Focus window " stringByAppendingString:action.a]; break;
    case SlateActionKindThrow: *title = @"Throw to another screen"; *detail = action.a; break;
    case SlateActionKindNudge: *title = @"Nudge"; *detail = [NSString stringWithFormat:@"%@, %@", action.a, action.b]; break;
    case SlateActionKindResize: *title = @"Resize"; *detail = [NSString stringWithFormat:@"%@, %@", action.a, action.b]; break;
    case SlateActionKindPush: *title = [@"Push " stringByAppendingString:action.a]; break;
    case SlateActionKindHint: *title = @"Window hints"; break;
    case SlateActionKindGrid: *title = @"Grid"; break;
    case SlateActionKindSwitch: *title = @"Switch windows"; break;
    case SlateActionKindRelaunch: *title = @"Relaunch MWM"; break;
    case SlateActionKindSnapshot: *title = [@"Save snapshot " stringByAppendingString:action.a]; break;
    case SlateActionKindRestoreSnapshot: *title = [@"Restore snapshot " stringByAppendingString:action.a]; break;
    case SlateActionKindCustom: *title = [action.a length] > 0 ? action.a : @"(empty)"; break;
  }
}

+ (instancetype)indexForDocument:(SlateConfigDocument *)document {
  SlateShortcutIndex *index = [[SlateShortcutIndex alloc] init];
  NSMutableArray *infos = [NSMutableArray array];
  NSMutableDictionary *seen = [NSMutableDictionary dictionary];
  for (NSUInteger i = 0; i < [document.bindings count]; i++) {
    SlateBindingEntry *binding = document.bindings[i];
    SlateShortcutInfo *info = [[SlateShortcutInfo alloc] init];
    info.binding = binding;
    info.index = i;
    info.keyName = binding.key ?: @"";
    NSString *group = nil;
    info.modifierNames = ModifierNamesOf(binding, document, &group);
    info.groupName = group;
    info.identity = [SlateShortcut identityForKey:info.keyName modifiers:[SlateShortcut stringFromModifierNames:info.modifierNames]];
    SlateAction *action = [SlateAction parse:binding.action];
    info.kind = KindOfAction(action);
    NSString *title, *detail;
    TitleOfAction(action, &title, &detail);
    info.title = title;
    info.detail = detail;
    [infos addObject:info];
    if (binding.enabled && info.identity != nil) {
      NSMutableArray *same = seen[info.identity];
      if (same == nil) seen[info.identity] = same = [NSMutableArray array];
      [same addObject:info];
    }
  }
  NSUInteger conflicts = 0;
  for (NSArray *same in [seen allValues]) {
    if ([same count] < 2) continue;
    for (SlateShortcutInfo *info in same) info.conflict = YES;
    conflicts++;
  }
  index.shortcuts = infos;
  index.conflictCount = conflicts;

  // The groups the file names, then Custom for the rest.
  NSMutableArray *groups = [NSMutableArray array];
  for (SlateConfigEntry *entry in document.modifiers) {
    NSArray *names = [SlateShortcut modifierNamesFromString:[entry.value description]];
    if (names == nil || [names count] == 0) continue;
    SlateModifierGroup *group = [[SlateModifierGroup alloc] init];
    group.name = entry.name;
    group.modifierNames = names;
    NSUInteger count = 0;
    for (SlateShortcutInfo *info in infos) if ([info.groupName isEqualToString:entry.name]) count++;
    group.count = count;
    [groups addObject:group];
  }
  NSUInteger customCount = 0;
  for (SlateShortcutInfo *info in infos) if (info.groupName == nil && [info.modifierNames count] > 0) customCount++;
  if (customCount > 0) {
    SlateModifierGroup *custom = [[SlateModifierGroup alloc] init];
    custom.name = kCustomGroup;
    custom.modifierNames = @[];
    custom.custom = YES;
    custom.count = customCount;
    [groups addObject:custom];
  }
  index.groups = groups;
  return index;
}

#pragma mark - Looking things up

- (NSArray<SlateShortcutInfo *> *)shortcutsInGroup:(NSString *)groupName {
  if (groupName == nil) return self.shortcuts;
  NSMutableArray *result = [NSMutableArray array];
  for (SlateShortcutInfo *info in self.shortcuts) {
    BOOL custom = [groupName isEqualToString:kCustomGroup] && info.groupName == nil && [info.modifierNames count] > 0;
    if (custom || [info.groupName isEqualToString:groupName]) [result addObject:info];
  }
  return result;
}

- (SlateShortcutInfo *)shortcutForKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames {
  NSString *identity = [SlateShortcut identityForKey:keyName modifiers:[SlateShortcut stringFromModifierNames:modifierNames]];
  if (identity == nil) return nil;
  for (SlateShortcutInfo *info in self.shortcuts) if ([info.identity isEqualToString:identity]) return info;
  return nil;
}

- (SlateShortcutInfo *)shortcutAtBindingIndex:(NSUInteger)index {
  return index < [self.shortcuts count] ? self.shortcuts[index] : nil;
}

- (NSUInteger)countOfKind:(SlateShortcutKind)kind {
  NSUInteger count = 0;
  for (SlateShortcutInfo *info in self.shortcuts) if (info.kind == kind) count++;
  return count;
}

@end
