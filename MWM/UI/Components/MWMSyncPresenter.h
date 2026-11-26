//
//  MWMSyncPresenter.h
//
//  Runs a sync and tells the person what happened, with the MWM logo and the sync icons: what was sent and
//  received, and, when profiles were deleted on one side, a question to clear them or keep them.
//  The Backup page and the menu bar both use it.
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
#import "MWMSync.h"

NS_ASSUME_NONNULL_BEGIN

@interface MWMSyncPresenter : NSObject

// Syncs, shows the result and any question, and calls `done` after all of it (so a page can refresh).
+ (void)runWithCompletion:(nullable void (^)(MWMSyncReport *report))done;

// The sentences of the result alert, for tests: the summary line, and the question about deleted profiles.
+ (NSString *)messageForReport:(MWMSyncReport *)report;
+ (nullable NSString *)questionForFlagged:(NSArray<MWMSyncItem *> *)flagged;

@end

NS_ASSUME_NONNULL_END
