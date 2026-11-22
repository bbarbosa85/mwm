//
//  JSScreenWrapper.h
//  Slate
//
//  Created by Jigish Patel on 1/21/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class ScreenWrapper;

@protocol JSScreenWrapperExport <JSExport>
- (NSInteger)id;
- (id)rect;
- (id)visibleRect;
- (id)vrect;
- (BOOL)isMain;
- (BOOL)main;
- (NSString *)toString;
@end

@interface JSScreenWrapper : NSObject <JSScreenWrapperExport> {
  NSInteger screenId;
  ScreenWrapper *sw;
}

@property (assign) NSInteger screenId;
@property (strong) ScreenWrapper *sw;

- (id)initWithScreenId:(NSInteger)_id screenWrapper:(ScreenWrapper *)_sw;
- (NSInteger)id;
- (NSString *)toString;

@end
