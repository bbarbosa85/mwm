//
//  JSWindowWrapper.h
//  Slate
//
//  Created by Jigish Patel on 1/21/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class AccessibilityWrapper;
@class ScreenWrapper;
@class JSScreenWrapper;
@class JSApplicationWrapper;

@protocol JSWindowWrapperExport <JSExport>
- (NSString *)title;
- (id)rect;
- (id)topLeft;
- (id)tl;
- (id)size;
- (pid_t)pid;
- (BOOL)focus;
- (BOOL)hidden;
- (BOOL)isMinimizedOrHidden;
- (BOOL)movable;
- (BOOL)isMovable;
- (BOOL)resizable;
- (BOOL)isResizable;
- (BOOL)main;
- (BOOL)isMain;
- (BOOL)move:(id)point;
- (BOOL)resize:(id)size;
- (JSScreenWrapper *)screen;
- (JSApplicationWrapper *)app;
JSExportAs(doOperation,
- (BOOL)doOperation:(id)op options:(id)opts
);
JSExportAs(doop,
- (BOOL)doop:(id)op options:(id)opts
);
@end

@interface JSWindowWrapper : NSObject <JSWindowWrapperExport> {
  ScreenWrapper *sw;
  AccessibilityWrapper *aw;
}

@property (strong) ScreenWrapper *sw;
@property (strong) AccessibilityWrapper *aw;

- (id)initWithAccessibilityWrapper:(AccessibilityWrapper *)_aw screenWrapper:(ScreenWrapper *)_sw;

@end
