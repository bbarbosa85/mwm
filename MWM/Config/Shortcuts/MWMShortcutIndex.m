//
//  MWMShortcutIndex.m
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

#import "MWMShortcutIndex.h"
#import "MWMAction.h"
#import "MWMConfigDocument.h"
#import "MWMShortcut.h"

static NSString *const kCustomGroup = @"Custom";

@implementation MWMShortcutInfo

+ (NSString *)kindTitle:(MWMShortcutKind)kind {
  switch (kind) {
    case MWMShortcutKindMoveToSlot: return @"Move to slot";
    case MWMShortcutKindFocusApp: return @"Focus app";
    case MWMShortcutKindFocusWindow: return @"Focus window";
    case MWMShortcutKindResizeNudge: return @"Resize and nudge";
    case MWMShortcutKindFeature: return @"Features";
    case MWMShortcutKindOther: return @"Other";
  }
}

@end

@implementation MWMModifierGroup
@end

@interface MWMShortcutIndex ()
@property (copy) NSArray<MWMShortcutInfo *> *shortcuts;
@property (copy) NSArray<MWMModifierGroup *> *groups;
@property (assign) NSUInteger conflictCount;
@end

@implementation MWMShortcutIndex

#pragma mark - Reading a document

// "${hyper}" -> ctrl, alt, cmd by the document's own modifier entries; or a written-out "ctrl;alt".
static NSArray<NSString *> *ModifierNamesOf(MWMBindingEntry *binding, MWMConfigDocument *document, NSString **groupName) {
  NSString *text = [binding.modifiers stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] ?: @"";
  NSRegularExpression *alias = [NSRegularExpression regularExpressionWithPattern:@"^\\$\\{([^}]*)\\}$" options:0 error:nil];
  NSTextCheckingResult *match = [alias firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
  if (match != nil) {
    NSString *name = [text substringWithRange:[match rangeAtIndex:1]];
    for (MWMConfigEntry *entry in document.modifiers) {
      if (![entry.name isEqualToString:name]) continue;
      NSArray *names = [MWMShortcut modifierNamesFromString:[entry.value description]];
      if (names != nil) { *groupName = name; return names; }
    }
    return @[];
  }
  NSArray *names = [MWMShortcut modifierNamesFromString:text] ?: @[];
  // A set written out that a group names exactly is that group.
  for (MWMConfigEntry *entry in document.modifiers) {
    NSArray *groupNames = [MWMShortcut modifierNamesFromString:[entry.value description]];
    if ([names count] > 0 && groupNames != nil && [groupNames isEqualToArray:names]) { *groupName = entry.name; break; }
  }
  return names;
}

static MWMShortcutKind KindOfAction(MWMAction *action) {
  switch (action.kind) {
    case MWMActionKindMove: return MWMShortcutKindMoveToSlot;
    case MWMActionKindFocusApp: return MWMShortcutKindFocusApp;
    case MWMActionKindFocusDirection: return MWMShortcutKindFocusWindow;
    case MWMActionKindThrow:
    case MWMActionKindNudge:
    case MWMActionKindResize:
    case MWMActionKindPush: return MWMShortcutKindResizeNudge;
    case MWMActionKindHint:
    case MWMActionKindGrid:
    case MWMActionKindSwitch:
    case MWMActionKindRelaunch:
    case MWMActionKindSnapshot:
    case MWMActionKindRestoreSnapshot: return MWMShortcutKindFeature;
    case MWMActionKindCustom: return MWMShortcutKindOther;
  }
}

static void TitleOfAction(MWMAction *action, NSString **title, NSString **detail) {
  *detail = nil;
  switch (action.kind) {
    case MWMActionKindMove:
      *title = [@"Move to " stringByAppendingString:action.a];
      if ([action.b length] > 0) *detail = [@"on " stringByAppendingString:[[action.b hasPrefix:@"monitor-"] ? [action.b substringFromIndex:8] : action.b capitalizedString]];
      break;
    case MWMActionKindFocusApp: *title = [@"Focus " stringByAppendingString:action.a]; break;
    case MWMActionKindFocusDirection: *title = [@"Focus window " stringByAppendingString:action.a]; break;
    case MWMActionKindThrow: *title = @"Throw to another screen"; *detail = action.a; break;
    case MWMActionKindNudge: *title = @"Nudge"; *detail = [NSString stringWithFormat:@"%@, %@", action.a, action.b]; break;
    case MWMActionKindResize: *title = @"Resize"; *detail = [NSString stringWithFormat:@"%@, %@", action.a, action.b]; break;
    case MWMActionKindPush: *title = [@"Push " stringByAppendingString:action.a]; break;
    case MWMActionKindHint: *title = @"Window hints"; break;
    case MWMActionKindGrid: *title = @"Grid"; break;
    case MWMActionKindSwitch: *title = @"Switch windows"; break;
    case MWMActionKindRelaunch: *title = @"Relaunch MWM"; break;
    case MWMActionKindSnapshot: *title = [@"Save snapshot " stringByAppendingString:action.a]; break;
    case MWMActionKindRestoreSnapshot: *title = [@"Restore snapshot " stringByAppendingString:action.a]; break;
    case MWMActionKindCustom: *title = [action.a length] > 0 ? action.a : @"(empty)"; break;
  }
}

+ (instancetype)indexForDocument:(MWMConfigDocument *)document {
  MWMShortcutIndex *index = [[MWMShortcutIndex alloc] init];
  NSMutableArray *infos = [NSMutableArray array];
  NSMutableDictionary *seen = [NSMutableDictionary dictionary];
  for (NSUInteger i = 0; i < [document.bindings count]; i++) {
    MWMBindingEntry *binding = document.bindings[i];
    MWMShortcutInfo *info = [[MWMShortcutInfo alloc] init];
    info.binding = binding;
    info.index = i;
    info.keyName = binding.key ?: @"";
    NSString *group = nil;
    info.modifierNames = ModifierNamesOf(binding, document, &group);
    info.groupName = group;
    info.identity = [MWMShortcut identityForKey:info.keyName modifiers:[MWMShortcut stringFromModifierNames:info.modifierNames]];
    MWMAction *action = [MWMAction parse:binding.action];
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
    for (MWMShortcutInfo *info in same) info.conflict = YES;
    conflicts++;
  }
  index.shortcuts = infos;
  index.conflictCount = conflicts;

  // The groups the file names, then Custom for the rest.
  NSMutableArray *groups = [NSMutableArray array];
  for (MWMConfigEntry *entry in document.modifiers) {
    NSArray *names = [MWMShortcut modifierNamesFromString:[entry.value description]];
    if (names == nil || [names count] == 0) continue;
    MWMModifierGroup *group = [[MWMModifierGroup alloc] init];
    group.name = entry.name;
    group.modifierNames = names;
    NSUInteger count = 0;
    for (MWMShortcutInfo *info in infos) if ([info.groupName isEqualToString:entry.name]) count++;
    group.count = count;
    [groups addObject:group];
  }
  NSUInteger customCount = 0;
  for (MWMShortcutInfo *info in infos) if (info.groupName == nil && [info.modifierNames count] > 0) customCount++;
  if (customCount > 0) {
    MWMModifierGroup *custom = [[MWMModifierGroup alloc] init];
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

- (NSArray<MWMShortcutInfo *> *)shortcutsInGroup:(NSString *)groupName {
  if (groupName == nil) return self.shortcuts;
  NSMutableArray *result = [NSMutableArray array];
  for (MWMShortcutInfo *info in self.shortcuts) {
    BOOL custom = [groupName isEqualToString:kCustomGroup] && info.groupName == nil && [info.modifierNames count] > 0;
    if (custom || [info.groupName isEqualToString:groupName]) [result addObject:info];
  }
  return result;
}

- (MWMShortcutInfo *)shortcutForKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames {
  NSString *identity = [MWMShortcut identityForKey:keyName modifiers:[MWMShortcut stringFromModifierNames:modifierNames]];
  if (identity == nil) return nil;
  for (MWMShortcutInfo *info in self.shortcuts) if ([info.identity isEqualToString:identity]) return info;
  return nil;
}

- (MWMShortcutInfo *)shortcutAtBindingIndex:(NSUInteger)index {
  return index < [self.shortcuts count] ? self.shortcuts[index] : nil;
}

- (NSUInteger)countOfKind:(MWMShortcutKind)kind {
  NSUInteger count = 0;
  for (MWMShortcutInfo *info in self.shortcuts) if (info.kind == kind) count++;
  return count;
}

@end
