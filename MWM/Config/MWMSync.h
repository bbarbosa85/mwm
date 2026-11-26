//
//  MWMSync.h
//
//  Backup is a sync of the profile files in ~/.mwm (and the snapshots) with one private GitHub gist. Sync
//  sends what changed here, receives what changed there, and never deletes anything by itself: a file gone from one
//  side is flagged, and the person decides to clear it or keep it. See MWMSyncPlan for the rules.
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
#import "MWMSyncPlan.h"

NS_ASSUME_NONNULL_BEGIN

@interface MWMSyncReport : NSObject
@property (copy) NSArray<MWMSyncItem *> *items;
@property (assign) NSUInteger sent;
@property (assign) NSUInteger received;
@property (assign) NSUInteger upToDate;
@property (copy) NSArray<MWMSyncItem *> *flagged;      // deleted on one side: ask what to do
@property (copy, nullable) NSString *problem;          // in words; nil when it worked
@property (strong, nullable) NSDate *date;
// "Sent 1, received 2, 3 up to date"
@property (readonly) NSString *summary;
@end

@interface MWMSync : NSObject

// What a sync would do now (nothing is changed). Answers on the main thread.
+ (void)preview:(void (^)(NSArray<MWMSyncItem *> *items, NSString *_Nullable problem))done;
// Sends and receives. Flagged files are left alone until `resolveFlagged:keep:completion:`.
+ (void)syncWithCompletion:(void (^)(MWMSyncReport *report))done;
// Clear (remove the file from the side that still has it) or keep (bring it back to the side that lost it).
// `notes` says what was kept or cleared, and why anything couldn't be.
+ (void)resolveFlagged:(NSArray<MWMSyncItem *> *)flagged keep:(BOOL)keep completion:(void (^)(NSString *notes, NSString *_Nullable problem))done;

// When and how the last sync ended on this computer.
+ (nullable NSDate *)lastSyncDate;
+ (nullable NSString *)lastSummary;

// Tests say when the snapshots last changed instead of reading the file.
+ (void)setSnapshotsModifiedOverride:(nullable NSDate *)date;

@end

NS_ASSUME_NONNULL_END
