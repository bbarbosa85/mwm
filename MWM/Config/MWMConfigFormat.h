//
//  MWMConfigFormat.h
//  Slate
//
//  The version 2 file format of ~/.mwm.yml: one object per monitor, slot and action,
//  plain names for references, real lists. It translates between that file and the
//  document model the rest of MWM uses (named entries and action strings), so the
//  engine and the window don't change. See docs/configuration-format-v2.md.
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

@class MWMConfigDocument, MWMYAMLMapping;

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger MWMConfigFormatCurrentVersion;

@interface MWMConfigFormat : NSObject

// Turns a version 2 file's tree into the shape the version 1 reader takes
// (positions as formulas, monitors as name/value entries, mods and actions as text).
// Errors name the line in the file.
+ (nullable MWMYAMLMapping *)versionOneTreeFromVersionTwo:(MWMYAMLMapping *)config error:(NSError **)error;

// The text of a document in version 2.
+ (NSString *)textForDocument:(MWMConfigDocument *)document header:(NSString *)header;

// Rewrites a version 1 file as version 2. The old file is kept next to it as
// <path>.v1-<timestamp> and the new text is checked by reading it back before anything is
// replaced. Returns YES when it migrated; NO with no error when there was nothing to do (no
// file, empty, or already version 2), and NO with an error when the file couldn't be read or
// the conversion wasn't exact (the file is left as it was).
+ (BOOL)migrateFileAtPath:(NSString *)path backupPath:(NSString * _Nullable * _Nullable)backupPath error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
