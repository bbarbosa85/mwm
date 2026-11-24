//
//  MWMBackup.h
//
//  One backed-up "environment": a name, the date, the displays it was saved with, the configuration
//  text, and the snapshots. It is stored as one JSON file in a private gist (see MWMGist).
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

@class MWMDisplay;

NS_ASSUME_NONNULL_BEGIN

@interface MWMBackupEnvironment : NSObject
@property (copy) NSString *name;
@property (strong) NSDate *savedAt;
@property (copy) NSArray<MWMDisplay *> *displays;
@property (copy) NSString *configText;
@property (copy) NSDictionary *snapshots;       // as MWMSnapshots exportAll
@property (readonly) NSUInteger shortcutCount;
@property (readonly) NSUInteger modifierCount;
@property (readonly) NSUInteger snapshotCount;

// Reads the counts out of the configuration text.
+ (instancetype)environmentNamed:(NSString *)name configText:(NSString *)text snapshots:(NSDictionary *)snapshots displays:(NSArray<MWMDisplay *> *)displays date:(NSDate *)date;
// The same displays (model, size, built-in or not) as these, in any order.
- (BOOL)matchesDisplays:(NSArray<MWMDisplay *> *)connected;
// "Samsung Odyssey G9 (5120 × 1440)" for each display.
+ (NSString *)descriptionOfDisplay:(MWMDisplay *)display;

- (NSData *)fileData;
+ (nullable instancetype)environmentFromFileData:(nullable NSData *)data;

// The gist file an environment of this name is kept in; the same name always gives the same file.
+ (NSString *)fileNameForName:(NSString *)name;
+ (BOOL)isEnvironmentFileName:(NSString *)fileName;
// Why a name can't be used, or nil.
+ (nullable NSString *)problemWithName:(NSString *)name;
+ (NSString *)trimmedName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
