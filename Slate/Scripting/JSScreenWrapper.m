//
//  JSScreenWrapper.m
//  Slate
//
//  Created by Jigish Patel on 1/21/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import "JSScreenWrapper.h"
#import "ScreenWrapper.h"
#import "JSController.h"

@implementation JSScreenWrapper

@synthesize screenId;
@synthesize sw;

- (id)init {
  self = [super init];
  if (self) {
    [self setScreenId:0];
    [self setSw:[[ScreenWrapper alloc] init]];
  }
  return self;
}

- (id)initWithScreenId:(NSInteger)_id screenWrapper:(ScreenWrapper *)_sw {
  self = [super init];
  if (self) {
    [self setScreenId:_id];
    [self setSw:_sw];
  }
  return self;
}

- (NSInteger)id {
  return [self screenId];
}

- (id)rect {
  NSRect rect = [sw getScreenRectForRef:[self screenId]];
  return [[JSController getInstance] marshall:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:rect.size.width],
                                                                                         @"width",
                                                                                         [NSNumber numberWithInteger:rect.size.height],
                                                                                         @"height",
                                                                                         [NSNumber numberWithInteger:rect.origin.x],
                                                                                         @"x",
                                                                                         [NSNumber numberWithInteger:rect.origin.y],
                                                                                         @"y", nil]];
}

- (id)vrect { return [self visibleRect]; }

- (id)visibleRect {
  NSRect rect = [sw getScreenVisibleRectForRef:[self screenId]];
  return [[JSController getInstance] marshall:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:rect.size.width],
                                                                                         @"width",
                                                                                         [NSNumber numberWithInteger:rect.size.height],
                                                                                         @"height",
                                                                                         [NSNumber numberWithInteger:rect.origin.x],
                                                                                         @"x",
                                                                                         [NSNumber numberWithInteger:rect.origin.y],
                                                                                         @"y", nil]];
}

- (NSString *)toString {
  return [NSString stringWithFormat:@"%ld", (long)[self screenId]];
}

- (BOOL)main { return [self isMain]; }

- (BOOL)isMain {
  return [sw isMainScreenRef:[self screenId]];
}

@end
