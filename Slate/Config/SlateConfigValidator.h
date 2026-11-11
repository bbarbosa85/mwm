//
//  SlateConfigValidator.h
//  Slate
//
//  Checks ~/.slate.js text without applying it: runs it against the real
//  slate API with a stand-in controller that records settings and bindings
//  instead of registering them, then checks those with Slate's own parsers.
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

@interface SlateConfigIssue : NSObject
@property (assign) BOOL isError;  // NO for warnings
@property (copy) NSString *message;
@property (assign) NSUInteger line;  // 1-based; 0 when unknown
@end

@interface SlateConfigValidationResult : NSObject
@property (strong) NSArray<SlateConfigIssue *> *issues;  // errors first, then by line
@property (assign) NSUInteger settingCount;
@property (assign) NSUInteger bindingCount;
@property (readonly) NSUInteger errorCount;
@property (readonly) NSUInteger warningCount;
@end

@interface SlateConfigValidator : NSObject

+ (SlateConfigValidationResult *)validateSource:(NSString *)source;

@end

NS_ASSUME_NONNULL_END
