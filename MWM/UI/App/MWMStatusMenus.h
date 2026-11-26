//
//  MWMStatusMenus.h
//  Slate
//
//  The submenus of the menu bar menu: Snapshots (save, and a submenu per snapshot to restore, update,
//  keep or delete it; refilled each time it opens), Keyboard Shortcuts, and Open Page (a line for each
//  page of the configuration window).
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MWMStatusMenus : NSObject <NSMenuDelegate, NSMenuItemValidation>

+ (instancetype)shared;

- (NSMenu *)snapshotsMenu;
- (NSMenu *)keyboardMenu;
- (NSMenu *)pagesMenu;
// "Backup": Sync Now, when it last ran, and Backup Settings…. Sync Now opens the Backup page while there's no token.
- (NSMenu *)backupMenu;
// Fills the backup menu (it does this when it opens; tests call it with a last-sync line).
- (void)showBackupInMenu:(NSMenu *)menu lastSync:(nullable NSString *)lastSync;
// "Profiles": one item for each profile, a check on the active one, and Manage Profiles….
- (NSMenu *)profilesMenu;
// Fills the menu from these names (the menu does this when it opens; tests call it).
- (void)showProfiles:(NSArray<NSString *> *)names active:(NSString *)active inMenu:(NSMenu *)menu;

// Asks for a name and saves the open windows (tests call this without the dialog).
- (void)saveSnapshotNamed:(NSString *)name keep:(BOOL)keep;
// Turns "Restore", "Update" ... for one snapshot into menu items (also for tests).
- (NSMenu *)menuForSnapshotNamed:(NSString *)name keep:(BOOL)keep;

@end

NS_ASSUME_NONNULL_END
