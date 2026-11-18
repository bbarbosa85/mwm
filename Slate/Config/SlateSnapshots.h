//
//  SlateSnapshots.h
//  Slate
//
//  What the Snapshots page needs from the engine's saved window arrangements: a list of what
//  each one holds (windows, apps, screens), and saving, restoring, renaming, deleting and
//  keeping them across restarts. The engine itself is unchanged; this reads its snapshot lists.
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

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class SlateDisplay, SnapshotList;

NS_ASSUME_NONNULL_BEGIN

// Posted (on the main thread) when snapshots are added, renamed, deleted or kept differently, here or by a shortcut.
extern NSString *const SlateSnapshotsDidChangeNotification;

@interface SlateSnapshotWindow : NSObject
@property (copy) NSString *app;
@property (copy) NSString *title;
@property (assign) CGRect rect;      // global coordinates, y growing downward
@end

@interface SlateSnapshotScreen : NSObject
@property (copy) NSString *name;
@property (assign) CGRect rect;      // global coordinates, y growing downward
@property (assign) BOOL builtIn;
@property (assign) BOOL connected;   // plugged in now
@end

@interface SlateSnapshotInfo : NSObject
@property (copy) NSString *name;
@property (copy) NSArray<SlateSnapshotWindow *> *windows;
@property (copy) NSArray<SlateSnapshotScreen *> *screens;
@property (assign) BOOL keepAfterRestart;
@property (assign) BOOL screensKnown;           // false: worked out from today's screens, not saved with it
- (NSArray<NSString *> *)appNames;               // each once, most windows first
- (NSUInteger)windowCount;
- (NSString *)screensText;                       // "Built-in + Samsung Odyssey"
- (BOOL)isLaptop;                                // taken with only the built-in screen
- (BOOL)allScreensConnected;
- (NSString *)summary;                           // "6 windows · Built-in + Desk"
@end

@interface SlateSnapshots : NSObject

// Newest first by name.
+ (NSArray<SlateSnapshotInfo *> *)snapshots;
// Where every window is right now, for the "new snapshot" card (nil when it can't be read).
+ (nullable SlateSnapshotInfo *)currentWindows;
+ (void)setCurrentWindowsOverride:(nullable SlateSnapshotInfo *)info;
+ (NSArray<SlateSnapshotInfo *> *)infosForLists:(NSDictionary<NSString *, SnapshotList *> *)lists connected:(NSArray<SlateDisplay *> *)connected;

// Why a name can't be used (empty, or taken), or nil. `except` is the name being renamed.
+ (nullable NSString *)problemWithName:(NSString *)name except:(nullable NSString *)except;

// Records where every open window is now.
+ (BOOL)saveCurrentWindowsAs:(NSString *)name keepAfterRestart:(BOOL)keep;
+ (void)restoreName:(NSString *)name;
// Records the open windows over an existing snapshot, keeping its name and whether it is kept.
+ (BOOL)updateName:(NSString *)name;
+ (BOOL)renameFrom:(NSString *)name to:(NSString *)newName;
+ (void)deleteName:(NSString *)name;
+ (void)setKeepAfterRestart:(BOOL)keep forName:(NSString *)name;

// Tests work on their own lists, and nothing is written to disk or moved on screen.
+ (void)setListsOverride:(nullable NSMutableDictionary<NSString *, SnapshotList *> *)lists;

@end

NS_ASSUME_NONNULL_END
