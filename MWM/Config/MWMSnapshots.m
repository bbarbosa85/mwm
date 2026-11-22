//
//  MWMSnapshots.m
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

#import "MWMSnapshots.h"
#import "ActivateSnapshotOperation.h"
#import "Snapshot.h"
#import "SnapshotList.h"
#import "SnapshotOperation.h"
#import "MWMConfig.h"
#import "MWMDisplays.h"
#import "WindowSnapshot.h"

@implementation MWMSnapshotWindow
@end

@implementation MWMSnapshotScreen
@end

@implementation MWMSnapshotInfo

- (NSArray<NSString *> *)appNames {
  NSCountedSet *counts = [NSCountedSet set];
  for (MWMSnapshotWindow *window in self.windows) [counts addObject:window.app];
  return [[counts allObjects] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
    NSUInteger ca = [counts countForObject:a], cb = [counts countForObject:b];
    if (ca != cb) return ca > cb ? NSOrderedAscending : NSOrderedDescending;
    return [a localizedCaseInsensitiveCompare:b];
  }];
}

- (NSUInteger)windowCount { return [self.windows count]; }

- (NSString *)screensText {
  NSMutableArray *names = [NSMutableArray array];
  for (MWMSnapshotScreen *screen in self.screens) [names addObject:screen.builtIn ? @"Built-in" : ([screen.name length] > 0 ? screen.name : @"Screen")];
  return [names componentsJoinedByString:@" + "];
}

- (BOOL)isLaptop {
  return self.screensKnown && [self.screens count] == 1 && [self.screens[0] builtIn];
}

- (BOOL)allScreensConnected {
  for (MWMSnapshotScreen *screen in self.screens) if (!screen.connected) return NO;
  return YES;
}

- (NSString *)summary {
  NSUInteger count = [self windowCount];
  NSString *windows = [NSString stringWithFormat:@"%lu window%@", (unsigned long)count, count == 1 ? @"" : @"s"];
  NSString *screens = [self screensText];
  return [screens length] > 0 ? [NSString stringWithFormat:@"%@ · %@", windows, screens] : windows;
}

@end

NSString *const MWMSnapshotsDidChangeNotification = @"MWMSnapshotsDidChangeNotification";

static NSMutableDictionary<NSString *, SnapshotList *> *gOverride;

@implementation MWMSnapshots

+ (void)setListsOverride:(NSMutableDictionary<NSString *, SnapshotList *> *)lists { gOverride = lists; }

+ (NSMutableDictionary<NSString *, SnapshotList *> *)lists {
  return gOverride ?: (NSMutableDictionary *)[[MWMConfig getInstance] snapshots];
}

+ (void)persist {
  if (gOverride == nil) [[MWMConfig getInstance] saveSnapshots];
  [self announceChange];
}

+ (void)announceChange {
  dispatch_async(dispatch_get_main_queue(), ^{ [[NSNotificationCenter defaultCenter] postNotificationName:MWMSnapshotsDidChangeNotification object:nil]; });
}

#pragma mark - Reading

static BOOL SameDisplay(MWMDisplay *display, NSDictionary *saved) {
  if (display.width != [saved[@"width"] integerValue] || display.height != [saved[@"height"] integerValue]) return NO;
  // The built-in screen is the built-in screen, whatever macOS calls it.
  return display.builtIn ? [saved[@"builtIn"] boolValue] : (![saved[@"builtIn"] boolValue] && [display.name isEqualToString:saved[@"name"] ?: @""]);
}

+ (MWMSnapshotInfo *)infoForList:(SnapshotList *)list connected:(NSArray<MWMDisplay *> *)connected {
  return [self infoForSnapshot:[list popSnapshot:NO] name:list.name keep:list.saveToDisk connected:connected];
}

+ (MWMSnapshotInfo *)infoForSnapshot:(Snapshot *)snapshot name:(NSString *)name keep:(BOOL)keep connected:(NSArray<MWMDisplay *> *)connected {
  MWMSnapshotInfo *info = [[MWMSnapshotInfo alloc] init];
  info.name = name ?: @"";
  info.keepAfterRestart = keep;
  NSMutableArray *windows = [NSMutableArray array];
  for (NSString *app in [[snapshot.apps allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
    for (WindowSnapshot *saved in snapshot.apps[app]) {
      MWMSnapshotWindow *window = [[MWMSnapshotWindow alloc] init];
      window.app = app;
      window.title = saved.title ?: @"";
      window.rect = CGRectMake(saved.topLeft.x, saved.topLeft.y, saved.size.width, saved.size.height);
      [windows addObject:window];
    }
  }
  info.windows = windows;

  NSMutableArray *screens = [NSMutableArray array];
  if ([snapshot.screens count] > 0) {
    info.screensKnown = YES;
    for (NSDictionary *saved in snapshot.screens) {
      MWMSnapshotScreen *screen = [[MWMSnapshotScreen alloc] init];
      screen.name = saved[@"name"] ?: @"";
      screen.builtIn = [saved[@"builtIn"] boolValue];
      screen.rect = CGRectMake([saved[@"x"] doubleValue], [saved[@"y"] doubleValue], [saved[@"width"] doubleValue], [saved[@"height"] doubleValue]);
      for (MWMDisplay *display in connected) if (SameDisplay(display, saved)) screen.connected = YES;
      [screens addObject:screen];
    }
  } else {
    // Taken before screens were kept: the screens that hold its windows today.
    for (MWMDisplay *display in connected) {
      CGRect rect = CGRectMake(display.originX, display.originY, display.width, display.height);
      BOOL used = [windows count] == 0;
      for (MWMSnapshotWindow *window in windows) if (CGRectIntersectsRect(rect, window.rect)) { used = YES; break; }
      if (!used) continue;
      MWMSnapshotScreen *screen = [[MWMSnapshotScreen alloc] init];
      screen.name = display.name;
      screen.builtIn = display.builtIn;
      screen.rect = rect;
      screen.connected = YES;
      [screens addObject:screen];
    }
  }
  info.screens = screens;
  return info;
}

+ (NSArray<MWMSnapshotInfo *> *)infosForLists:(NSDictionary<NSString *, SnapshotList *> *)lists connected:(NSArray<MWMDisplay *> *)connected {
  NSMutableArray *infos = [NSMutableArray array];
  for (NSString *name in [[lists allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
    if ([name hasPrefix:@"_internal_"]) continue;   // the engine's own undo history isn't a snapshot of yours
    [infos addObject:[self infoForList:lists[name] connected:connected]];
  }
  return infos;
}

static MWMSnapshotInfo *gCurrentOverride;
+ (void)setCurrentWindowsOverride:(MWMSnapshotInfo *)info { gCurrentOverride = info; }

+ (MWMSnapshotInfo *)currentWindows {
  if (gCurrentOverride != nil) return gCurrentOverride;
  if (gOverride != nil) return nil;   // tests don't read the real windows
  return [self infoForSnapshot:[SnapshotOperation captureSnapshot] name:@"" keep:NO connected:[MWMDisplays connected]];
}

+ (NSArray<MWMSnapshotInfo *> *)snapshots {
  return [self infosForLists:[self lists] connected:[MWMDisplays connected]];
}

#pragma mark - Changing

+ (NSString *)problemWithName:(NSString *)name except:(NSString *)except {
  NSString *trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([trimmed length] == 0) return @"Give the snapshot a name.";
  if ([trimmed rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) return @"Use a name without spaces, so a shortcut can refer to it.";
  if (![trimmed isEqualToString:except ?: @""] && [self lists][trimmed] != nil) return [NSString stringWithFormat:@"There is already a snapshot called \"%@\".", trimmed];
  return nil;
}

+ (BOOL)saveCurrentWindowsAs:(NSString *)name keepAfterRestart:(BOOL)keep {
  if ([self problemWithName:name except:name] != nil) return NO;
  if (gOverride != nil) return NO;   // tests don't read the real windows
  SnapshotOperation *operation = [[SnapshotOperation alloc] initWithName:name options:keep ? @"save-to-disk" : nil];
  BOOL saved = [operation doOperation];
  if (saved) [self announceChange];
  return saved;
}

+ (BOOL)updateName:(NSString *)name {
  SnapshotList *list = [self lists][name];
  if (list == nil || gOverride != nil) return NO;   // tests don't read the real windows
  SnapshotOperation *operation = [[SnapshotOperation alloc] initWithName:name options:list.saveToDisk ? @"save-to-disk" : nil];
  BOOL saved = [operation doOperation];
  if (saved) [self announceChange];
  return saved;
}

+ (void)restoreName:(NSString *)name {
  if (gOverride != nil) return;
  [ActivateSnapshotOperation activateSnapshot:name remove:NO];
}

+ (BOOL)renameFrom:(NSString *)name to:(NSString *)newName {
  NSString *trimmed = [newName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  SnapshotList *list = [self lists][name];
  if (list == nil || [self problemWithName:trimmed except:name] != nil) return NO;
  if ([trimmed isEqualToString:name]) return YES;
  [[self lists] removeObjectForKey:name];
  list.name = trimmed;
  [self lists][trimmed] = list;
  [self persist];
  return YES;
}

+ (void)deleteName:(NSString *)name {
  if ([self lists][name] == nil) return;
  [[self lists] removeObjectForKey:name];
  [self persist];
}

+ (void)setKeepAfterRestart:(BOOL)keep forName:(NSString *)name {
  SnapshotList *list = [self lists][name];
  if (list == nil) return;
  list.saveToDisk = keep;
  [self persist];
}

@end
