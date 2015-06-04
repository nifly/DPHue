//
//  DPJSONConnection.m
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue


#import "DPJSONConnection.h"

static NSMutableArray *sharedConnectionList = nil;


@interface DPJSONConnection () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, strong) NSURLSessionDataTask *internalTask;

@end


@implementation DPJSONConnection

- (id)initWithRequest:(NSURLRequest *)request
{
  if (self = [super init])
  {
    _request = request;
  }
  
  return self;
}

- (void)start
{
  if (!sharedConnectionList)
    sharedConnectionList = [NSMutableArray new];
  [sharedConnectionList addObject:self];
  
  __weak typeof(self)wkSelf = self;
  void (^innerCompletionBlock)(id, NSError *) = ^(id obj, NSError *err) {
    if ( wkSelf.completionBlock )
    {
      __strong typeof(wkSelf)strongSelf = wkSelf;
      dispatch_async(dispatch_get_main_queue(), ^{
        strongSelf.completionBlock( obj, err );
      });
    }
    [sharedConnectionList removeObject:wkSelf];
  };
  
  NSURLSession *session = [NSURLSession sharedSession];
  self.internalTask = [session dataTaskWithRequest:self.request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if ( error )
    {
      innerCompletionBlock( nil, error );
      return;
    }
    
    if (!wkSelf.jsonRootObject)
    {
      innerCompletionBlock( data, nil );
      return;
    }
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if ( error )
    {
      innerCompletionBlock( nil, error );
      return;
    }
    
    [wkSelf.jsonRootObject readFromJSONDictionary:json];
    innerCompletionBlock( wkSelf.jsonRootObject, nil );
  }];
  
  [self.internalTask resume];
}

@end
