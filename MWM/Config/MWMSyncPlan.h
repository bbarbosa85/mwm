//
//  MWMSyncPlan.h
//
//  What a sync would do. Given the profile files on this computer, the ones in the gist, and what both
//  looked like at the last sync (the "base"), it decides for each file whether it is up to date, goes to the
//  gist, comes from the gist, or was deleted on one side. It touches no files and no network.
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

NS_ASSUME_NONNULL_BEGIN

// One file as one side sees it.
@interface MWMSyncFile : NSObject
@property (copy) NSString *name;
@property (copy) NSString *contentHash;   // of its text
@property (copy, nullable) NSString *text; // the text itself, when it is at hand
@property (strong, nullable) NSDate *modified;
+ (instancetype)fileNamed:(NSString *)name text:(NSString *)text modified:(nullable NSDate *)modified;
+ (instancetype)fileNamed:(NSString *)name contentHash:(NSString *)contentHash modified:(nullable NSDate *)modified;
// SHA-256 of the UTF-8 text, as lowercase hex.
+ (NSString *)hashOfText:(NSString *)text;
@end

typedef NS_ENUM(NSInteger, MWMSyncStatus) {
  MWMSyncStatusSynced,          // the same on both sides
  MWMSyncStatusChangedHere,     // this computer's is newer: it will be sent
  MWMSyncStatusNewerInGist,     // the gist's is newer: it will be received
  MWMSyncStatusOnlyHere,        // not in the gist yet: it will be sent
  MWMSyncStatusOnlyInGist,      // not here yet: it will be received
  MWMSyncStatusDeletedHere,     // it was here at the last sync and is gone; still in the gist (flagged)
  MWMSyncStatusDeletedInGist,   // it was in the gist at the last sync and is gone; still here (flagged)
};

@interface MWMSyncItem : NSObject
@property (copy) NSString *name;
@property (assign) BOOL isSnapshots;
@property (assign) MWMSyncStatus status;
@property (assign) BOOL conflict;                      // changed on both sides; the newer one was chosen
@property (strong, nullable) MWMSyncFile *local;
@property (strong, nullable) MWMSyncFile *remote;
// The same profile can be spelled differently in the gist (Desk, desk): names are matched ignoring case.
@property (readonly) NSString *remoteName;
@property (readonly) BOOL willSend;
@property (readonly) BOOL willReceive;
@property (readonly) BOOL flagged;                     // deleted on one side: ask what to do after the sync
@end

@interface MWMSyncPlan : NSObject

// The name the snapshots go under, next to the profiles.
+ (NSString *)snapshotsName;

// `base` maps a name (any case) to the hash both sides had at the last sync (empty before the first sync). A file
// changed on one side wins over a deletion on the other. When both changed, the newer one wins; on a tie, this computer.
// The snapshots (pass them with the name above; nil when there are none) are never flagged as deleted.
+ (NSArray<MWMSyncItem *> *)planForLocal:(NSArray<MWMSyncFile *> *)local
                                  remote:(NSArray<MWMSyncFile *> *)remote
                                    base:(NSDictionary<NSString *, NSString *> *)base;

@end

NS_ASSUME_NONNULL_END
