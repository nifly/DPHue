//
//  DPJSONConnection.h
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

// DPJSONConnection wraps NSURLSession and optionally
// decodes JSON into a supplied object if it conforms to
// the DPJSONSerializable protocol

#import <Foundation/Foundation.h>
#import "DPJSONSerializable.h"

@interface DPJSONConnection : NSObject

@property (nonatomic, readonly, copy) NSURLRequest *request;
@property (nonatomic, strong) id <DPJSONSerializable> jsonRootObject;

/**
 Completion handler.
 
 @note Calls back on main queue
 @param obj If no @p jsonRootObject is provided, this is the raw NSData. Otherwise
            it is the @p jsonRootObject after calling @p readFromJSONDictionary.
 */
@property (nonatomic, copy) void (^completionBlock)(id obj, NSError *err);


- (id)initWithRequest:(NSURLRequest *)request;
- (void)start;

@end
