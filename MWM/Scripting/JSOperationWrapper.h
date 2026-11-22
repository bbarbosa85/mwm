//
//  JSOperationWrapper.h
//  Slate
//
//  Created by Jigish Patel on 1/25/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class AccessibilityWrapper;
@class ScreenWrapper;
@class Operation;
@class JSOperationWrapper;

@protocol JSOperationWrapperExport <JSExport>
- (BOOL)run;
- (JSOperationWrapper *)dup:(id)opts;
- (BOOL)doOperation;
@end

@interface JSOperationWrapper : NSObject <JSOperationWrapperExport> {
  Operation *op;
}

@property (strong) Operation *op;

- (BOOL)run;
- (JSOperationWrapper *)dup:(id)opts;
- (BOOL)doOperation;
- (BOOL)doOperationWithAccessibilityWrapper:(AccessibilityWrapper *)aw screenWrapper:(ScreenWrapper *)sw;

+ (JSOperationWrapper *)operation:(NSString*)name options:(id)opts;
+ (JSOperationWrapper *)operationFromString:(NSString *)opString;

@end
