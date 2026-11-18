//
//  ConfigurationSnapshotsView.h
//  Slate
//
//  The Snapshots page: a grid of cards, ending with a "New snapshot" card (a live picture of the windows
//  as they are now, a name and Save).
//  A card has the name and its actions on top (Restore, the pin that keeps it after a restart, and a
//  menu with rename, update and delete), a centered picture of the windows on the screens (each with
//  its app's icon), and one line: how many windows, kept, and whether a screen is missing.
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

@class ConfigurationSnapshotsView;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationSnapshotsViewDelegate <NSObject>
// Snapshots were added, removed or renamed (the sidebar count follows).
- (void)snapshotsViewDidChange:(ConfigurationSnapshotsView *)view;
@end

@interface ConfigurationSnapshotsView : NSView

@property (weak, nullable) id<ConfigurationSnapshotsViewDelegate> delegate;
// Tests turn this off so deleting doesn't ask.
@property (assign) BOOL confirmsDeleting;
@property (readonly) NSTextField *nameField;

- (void)reload;
// As pressing "Save current windows" with this name.
- (void)saveCurrentWindowsAs:(NSString *)name;
- (void)restoreNamed:(NSString *)name;
- (void)deleteNamed:(NSString *)name;
// Records the windows as they are now, over the snapshot of this name.
- (void)updateNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
