//
//  ConfigurationBackupView.h
//
//  The Backup page. Backups go to a private GitHub gist, as named "environments" (the configuration,
//  the snapshots, and the displays they were saved with). A card for this computer has a name and
//  Back up (a name that exists replaces that backup); each saved environment is a card with its date,
//  Restore and a trash icon.
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

#import <Cocoa/Cocoa.h>
#import "MWMBackup.h"

@class ConfigurationBackupView, MWMConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationBackupViewDelegate <NSObject>
// Put this text in the configuration file and show it. Answers whether that worked.
- (BOOL)backupView:(ConfigurationBackupView *)view restoreConfigText:(NSString *)text;
// Snapshots were replaced by a restore (the sidebar count follows).
- (void)backupViewDidRestoreSnapshots:(ConfigurationBackupView *)view;
@end

@interface ConfigurationBackupView : NSView

@property (weak, nullable) id<ConfigurationBackupViewDelegate> delegate;
// The configuration the form is showing, which is what Back up saves.
@property (strong, nullable, nonatomic) MWMConfigDocument *document;
// Tests turn this off so nothing asks first or announces a result.
@property (assign) BOOL interactive;
@property (readonly) NSTextField *nameField;
@property (readonly) NSTextField *tokenField;
@property (readonly, copy) NSArray<MWMBackupEnvironment *> *environments;
@property (readonly, copy, nullable) NSString *problem;

// Asks GitHub for the saved environments and shows them.
- (void)refresh:(nullable void (^)(void))done;
- (void)connectWithToken:(NSString *)token completion:(nullable void (^)(void))done;
- (void)backUpAs:(NSString *)name completion:(nullable void (^)(void))done;
- (void)restoreNamed:(NSString *)name;
- (void)deleteNamed:(NSString *)name completion:(nullable void (^)(void))done;

@end

NS_ASSUME_NONNULL_END
