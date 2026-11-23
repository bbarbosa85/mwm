//
//  PushOperation.h
//  Slate
//
//  Created by Jigish Patel on 1/20/13.
//  Copyright 2011 Jigish Patel. All rights reserved.
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

#import "MoveOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface PushOperation : MoveOperation

+ (id)pushOperation;
+ (id)pushOperationFromString:(NSString *)pushOperation;
// Where a push puts the window, as expressions: x, y, width and height. Nil when the direction or style isn't known.
+ (nullable NSDictionary<NSString *, NSString *> *)geometryForDirection:(NSString *)direction style:(nullable NSString *)style;

@end

NS_ASSUME_NONNULL_END
