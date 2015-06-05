//
//  DPJSONConnection.m
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import "DPJSONConnection.h"
#import "WSLog.h"


static NSMutableArray *sharedConnectionList = nil;


@interface DPJSONConnection () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, strong) NSURLSessionDataTask *internalTask;

@end


@implementation DPJSONConnection

- (id)initWithRequest:(NSURLRequest *)request sender:(id)sender;
{
  if (self = [super init])
  {
    _request = request;
    _sender = sender;
  }
  
  return self;
}

- (void)start
{
  if (!sharedConnectionList)
    sharedConnectionList = [NSMutableArray new];
  [sharedConnectionList addObject:self];
  
  // Avoid if-checks within the `internalTask` completion block
  __weak typeof(self)wkSelf = self;
  void (^innerCompletionBlock)(id, NSError *) = ^(id json, NSError *err) {
    __strong typeof(wkSelf)strongSelf = wkSelf;
    if ( strongSelf.completionBlock )
    {
      dispatch_async(dispatch_get_main_queue(), ^{
        strongSelf.completionBlock( strongSelf.sender, json, err );
      });
    }
    [sharedConnectionList removeObject:strongSelf];
  };
  
  NSURLSession *session = [NSURLSession sharedSession];
  self.internalTask = [session dataTaskWithRequest:self.request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if ( error )
    {
      innerCompletionBlock( nil, error );
      return;
    }
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if ( error )
    {
      innerCompletionBlock( nil, error );
      return;
    }
    
    innerCompletionBlock( json, nil );
  }];
  
  [[self class] logPendingRequest:self.request];
  [self.internalTask resume];
}


#pragma mark - Helpers

+ (void)logPendingRequest:(NSURLRequest *)request
{
#if REQUEST_LOGGING_ENABLED
  NSString *pretty = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
  NSMutableString *msg = [NSMutableString new];
  [msg appendFormat:@"Writing to: %@\n", request.URL];
  [msg appendFormat:@"Writing values: %@\n", pretty];
  WSLog(@"%@", msg);
#endif
}

@end
