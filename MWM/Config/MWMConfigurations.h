//
//  MWMConfigurations.h
//
//  The configurations MWM keeps on this computer: one file for each, named <name>.mwm.yaml, in the
//  ~/.mwm folder. Exactly one is active; MWM loads that one. The name of the active one is kept in
//  ~/.mwm/active. Snapshots are shared by every configuration.
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

@interface MWMConfigurations : NSObject

// Tests use another home folder, so they never touch the real one. nil goes back to the real one (or to the
// folder in the MWM_HOME environment variable, which development builds use to try things safely).
+ (void)setHomeDirectory:(nullable NSString *)home;
+ (NSString *)homeDirectory;

// ~/.mwm, and whether it exists yet.
+ (NSString *)folder;
+ (BOOL)folderExists;
// Makes the folder if it isn't there.
+ (BOOL)createFolder:(NSError **)error;

// Every configuration, sorted by name. Files ending in .mwm.yaml or .mwm.yml count.
+ (NSArray<NSString *> *)names;
// The file for a name: the existing one, or where a new one would go (<name>.mwm.yaml).
+ (NSString *)pathForName:(NSString *)name;
+ (BOOL)existsNamed:(NSString *)name;
+ (nullable NSDate *)modificationDateForName:(NSString *)name;

// The one MWM loads. Falls back to "default", then to the first one; "default" when there are none yet.
+ (NSString *)activeName;
+ (NSString *)activePath;
+ (BOOL)setActiveName:(NSString *)name;

// Why a name can't be used, or nil. `except` is the name being renamed (it may keep its own name).
+ (nullable NSString *)problemWithName:(NSString *)name except:(nullable NSString *)except;
+ (NSString *)trimmedName:(NSString *)name;
// A name that is free: this one, or this one followed by 2, 3 ...
+ (NSString *)freeNameFrom:(NSString *)name;
// A backup's name made safe to use as a file name.
+ (NSString *)fileSafeName:(NSString *)name;

// Each answers NO with an error that reads as a sentence.
+ (BOOL)createNamed:(NSString *)name text:(NSString *)text error:(NSError **)error;
+ (BOOL)duplicateNamed:(NSString *)name as:(NSString *)copyName error:(NSError **)error;
+ (BOOL)renameNamed:(NSString *)name to:(NSString *)newName error:(NSError **)error;
// Moves it to the Trash. The active one, and the last one, can't be deleted.
+ (BOOL)deleteNamed:(NSString *)name error:(NSError **)error;
// Copies a configuration file in under a free name, which it answers.
+ (nullable NSString *)importFileAtPath:(NSString *)path error:(NSError **)error;
// Puts text in the configuration of this name (replacing it, keeping the old one as <file>.bak).
+ (BOOL)writeText:(NSString *)text named:(NSString *)name error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
