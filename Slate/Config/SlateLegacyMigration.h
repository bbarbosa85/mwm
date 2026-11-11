//
//  SlateLegacyMigration.h
//  Slate
//
//  Converts a legacy ~/.slate file into the managed ~/.slate.js format and
//  moves users over to it on startup.
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

@class SlateConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@interface SlateLegacyMigration : NSObject

// Converts legacy .slate text. config/alias/bind lines become settings, aliases
// and bindings; commented-out bind lines become disabled bindings; section
// headers become binding groups and comments directly above a binding become
// its note. Anything else is kept as comments in the custom code, and active
// lines that couldn't be converted are described in `warnings`.
+ (SlateConfigDocument *)documentFromLegacySource:(NSString *)source warnings:(NSMutableArray<NSString *> *)warnings;

// Combines a converted legacy document with existing ~/.slate.js contents,
// matching today's load order (~/.slate first, then ~/.slate.js). A managed
// file is merged entry by entry, with ~/.slate.js winning on conflicts. Any
// other JavaScript is kept unchanged as the custom code.
+ (SlateConfigDocument *)documentByMergingLegacy:(SlateConfigDocument *)legacy
                                   intoJavaScript:(NSString *)javaScript
                                         warnings:(NSMutableArray<NSString *> *)warnings;

// Converts legacyPath, merging into jsPath when it exists, writes jsPath, then
// renames legacyPath to <legacyPath>.migrated-<timestamp> so it stops loading.
// Returns the backup path, or nil (with nothing changed on disk) on failure.
+ (nullable NSString *)migrateLegacyFile:(NSString *)legacyPath
                                  toFile:(NSString *)jsPath
                                warnings:(NSMutableArray<NSString *> *)warnings
                                   error:(NSError **)error;

// Startup entry point: migrates ~/.slate when present, asking first if
// ~/.slate.js also exists. Shows alerts; does nothing when there's no ~/.slate.
+ (void)runStartupMigration;

@end

NS_ASSUME_NONNULL_END
