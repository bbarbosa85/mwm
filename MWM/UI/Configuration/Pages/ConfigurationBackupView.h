//
//  ConfigurationBackupView.h
//
//  The Backup page. Backup is a sync of the profiles in ~/.mwm (and the snapshots) with one private
//  GitHub gist. Sync now sends what changed here and receives what changed there; under it, a list shows where
//  each profile stands. Without a token the page walks through making one.
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
#import "MWMSync.h"

@class ConfigurationBackupView;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationBackupViewDelegate <NSObject>
// A sync received files (a profile, or snapshots): the open one may have changed on disk.
- (void)backupViewDidChangeFiles:(ConfigurationBackupView *)view;
@end

@interface ConfigurationBackupView : NSView

@property (weak, nullable) id<ConfigurationBackupViewDelegate> delegate;
// Tests turn this off so nothing announces a result or asks a question.
@property (assign) BOOL interactive;
@property (readonly) NSTextField *tokenField;
// Where each profile stands, from the last look at the gist.
@property (readonly, copy) NSArray<MWMSyncItem *> *items;
@property (readonly, copy, nullable) NSString *problem;
@property (readonly, strong, nullable) MWMSyncReport *lastReport;

// Looks at the gist and shows where everything stands.
- (void)refresh:(nullable void (^)(void))done;
- (void)connectWithToken:(NSString *)token completion:(nullable void (^)(void))done;
// Sends and receives, then refreshes the list.
- (void)syncWithCompletion:(nullable void (^)(void))done;

@end

NS_ASSUME_NONNULL_END
