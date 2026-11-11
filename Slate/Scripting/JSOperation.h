//
//  JSOperation.h
//  Slate
//
//  Created by Jigish Patel on 1/22/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Operation.h"

@interface JSOperation : Operation {
  JSValue *function;
}

@property (strong) JSValue *function;

- (id)initWithFunction:(JSValue *)_function;
+ (id)jsOperationWithFunction:(JSValue *)function;

@end
