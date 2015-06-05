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


#define REQUEST_LOGGING_ENABLED 0


@interface DPJSONConnection : NSObject


@property (nonatomic, readonly, copy) NSURLRequest *request;
@property (nonatomic, readonly, strong) id sender;


/**
 Completion handler.
 
 @param sender
          The sender passed in during initialization of the connection. This is a
          strong reference that will be released upon completion of @p completionBlock.
 @param json
          The result from calling @p [NSJSONSerialization JSONObjectWithData]
          with the result of the request, or nil if unsuccessful.
 @param err
          Error encountered during request/parsing, or nil if successful.
 
 @note Calls back on main queue
 */
@property (nonatomic, copy) void (^completionBlock)(id sender, id json, NSError *err);


/**
 Create a connection that is ready to go when you call @p start on it.
 
 @param request
          The request to initiate upon calling @p start
 @param sender
          A convenient capturing on the sender to allow referencing @p self
          within @p completionBlock
 */
- (id)initWithRequest:(NSURLRequest *)request sender:(id)sender;

/// Initiate the request
- (void)start;

@end
