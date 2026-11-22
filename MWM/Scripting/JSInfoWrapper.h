//
//  JSInfoWrapper.h
//  Slate
//
//  Created by Jigish Patel on 1/21/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class ScreenWrapper;
@class AccessibilityWrapper;
@class JSWindowWrapper;
@class JSApplicationWrapper;
@class JSScreenWrapper;

@protocol JSInfoWrapperExport <JSExport>
- (JSWindowWrapper *)window;
- (JSApplicationWrapper *)app;
- (JSScreenWrapper *)screen;
- (void)eachApp:(id)func;
- (void)eapp:(id)func;
- (JSWindowWrapper *)windowUnderPoint:(id)point;
- (JSWindowWrapper *)wup:(id)point;
- (BOOL)isRectOffScreen:(id)rect;
- (BOOL)rectoff:(id)rect;
- (BOOL)isPointOffScreen:(id)point;
- (BOOL)pntoff:(id)point;
- (JSScreenWrapper *)screenForRef:(id)ref;
- (JSScreenWrapper *)screenr:(id)ref;
- (NSInteger)screenCount;
- (NSInteger)screenc;
- (JSScreenWrapper *)screenUnderPoint:(id)point;
- (JSScreenWrapper *)sup:(id)point;
- (void)eachScreen:(id)func;
- (void)escreen:(id)func;
- (id)jsMethods;
@end

@interface JSInfoWrapper : NSObject <JSInfoWrapperExport> {
  ScreenWrapper *sw;
  AccessibilityWrapper *aw;
}

@property (strong) ScreenWrapper *sw;
@property (strong) AccessibilityWrapper *aw;

- (id)initWithAccessibilityWrapper:(AccessibilityWrapper *)_aw screenWrapper:(ScreenWrapper *)_sw;

+ (JSInfoWrapper *)getInstance;

@end
