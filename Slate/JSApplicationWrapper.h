//
//  JSApplicationWrapper.h
//  Slate
//
//  Created by Jigish Patel on 1/21/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class AccessibilityWrapper;
@class ScreenWrapper;

@protocol JSApplicationWrapperExport <JSExport>
- (pid_t)pid;
- (NSString *)name;
- (id)mainWindow;
- (id)mwindow;
- (void)eachWindow:(id)funcOrOp;
- (void)ewindow:(id)obj;
- (NSString *)toString;
@end

@interface JSApplicationWrapper : NSObject <JSApplicationWrapperExport> {
  AccessibilityWrapper *aw;
  ScreenWrapper *sw;
  NSRunningApplication *app;
}

@property (strong) AccessibilityWrapper *aw;
@property (strong) ScreenWrapper *sw;
@property (strong) NSRunningApplication *app;

- (id)initWithAccessibilityWrapper:(AccessibilityWrapper *)_aw screenWrapper:(ScreenWrapper *)_sw;
- (id)initWithRunningApplication:(NSRunningApplication *)_app screenWrapper:(ScreenWrapper *)_sw;
- (NSString *)toString;

@end
