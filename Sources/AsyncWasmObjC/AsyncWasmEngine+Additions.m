//
//  AsyncWasmEngine+Additions.m
//  WasmHost
//
//  Created by L7Studio on 12/2/25.
//

#import "AsyncWasmEngine+Additions.h"
@import Protobuf;
@implementation AsyncWasmEngine (Protobuf)
-(void)performSelector:(SEL)selector
                  args:(NSArray*)args
                 clazz:(Class)clazz
     completionHandler:(void(^)(id _Nullable, NSError *_Nullable))completionHandler {
    __weak AsyncWasmEngine *weakSelf = self;
    __block void (^dataCallbackBlock)(NSData *_Nullable, NSError * _Nullable);
    dataCallbackBlock = ^(NSData *_Nullable data, NSError *_Nullable error){
        [weakSelf cast:data error:error clazz:clazz completionHandler:completionHandler];
    };
    NSMethodSignature *msig = [self methodSignatureForSelector:selector];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:msig];
    [inv setSelector:selector];
    [inv setTarget:self];
    [args enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [inv setArgument:&obj atIndex:idx + 2];// because 2 hidden arguments (self, _cmd)
    }];
    [inv setArgument:&dataCallbackBlock atIndex:args.count + 2];
    [inv invoke];
}


-(void)cast:(NSData*)data
      error:(NSError* _Nullable)error
      clazz:(Class)clazz
completionHandler:(void(^)(id _Nullable, NSError * _Nullable))completionHandler {
    if (error != nil ) {
        completionHandler(nil, error);
        return;
    }
    if (![clazz isSubclassOfClass: GPBMessage.class]) {
        completionHandler(nil, [NSError errorWithDomain:[AsyncifyWasmConstants errorDomain] code:-1 userInfo:@{NSLocalizedFailureReasonErrorKey: @"required subsclass of GPBMessage"}]);
        return;
    }
    id ret = [[clazz alloc] initWithData:data error:&error];
    if (error != nil ) {
        completionHandler(nil, error);
        return;
    }
    completionHandler(ret, nil);
}


@end
