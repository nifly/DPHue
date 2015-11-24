//
//  DPHueNUPNP.m
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import "DPHueNUPNP.h"


@implementation DPHueNUPNP


- (NSString *)description
{
  return [NSString stringWithFormat:@"ID: %@\nIP: %@\nMAC: %@\n",
          self.hueID, self.hueIP, self.hueMACAddress];
}


#pragma mark - HueAPIRequestGeneration

- (NSURLRequest *)requestForDiscovery
{
  NSURL *url = [NSURL URLWithString:@"https://www.meethue.com/api/nupnp"];
  return [NSURLRequest requestWithURL:url];
}


#pragma mark - HueAPIJsonParsing

- (instancetype)parseDiscovery:(id)json
{
  if ( [json respondsToSelector:@selector(objectAtIndex:)] && [json count] > 0 )
  {
    NSDictionary *configuration = json[0];
    _hueID = configuration[@"id"];
    _hueIP = configuration[@"internalipaddress"];
    _hueMACAddress = configuration[@"macaddress"];
  }
  
  return self;
}

@end
