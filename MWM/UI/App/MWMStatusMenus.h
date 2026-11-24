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
// "Restore Configuration": the backups in the gist (newest first), or a message when there are none.
- (NSMenu *)restoreMenu;
// Fills the restore menu from these backups (the menu asks GitHub when it opens; tests call this).
- (void)showBackups:(NSArray *)environments inMenu:(NSMenu *)menu;

// Asks for a name and saves the open windows (tests call this without the dialog).
- (void)saveSnapshotNamed:(NSString *)name keep:(BOOL)keep;
// Turns "Restore", "Update" ... for one snapshot into menu items (also for tests).
- (NSMenu *)menuForSnapshotNamed:(NSString *)name keep:(BOOL)keep;

@end

NS_ASSUME_NONNULL_END
