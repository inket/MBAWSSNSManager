//
//  AWSSNSManager.m
//
//  Created by Mahdi Bchetnia on 10/30/14.
//  Copyright (c) 2014 Interfirm. All rights reserved.
//

#import "MBAWSSNSManager.h"

#define IOS8 ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)

@interface MBAWSSNSManager()
@property (strong) NSString* applicationPlatformEndpoint;
@property (strong) BFTask* createPlatformEndpointTask;

@end

@implementation MBAWSSNSManager

+ (instancetype)sharedManager {
    static MBAWSSNSManager* manager = nil;
    if (!manager) manager = [[MBAWSSNSManager alloc] init];

    return manager;
}

- (void)registerForNotifications {
    AWSStaticCredentialsProvider *credentialsProvider = [AWSStaticCredentialsProvider credentialsWithAccessKey:self.awsAccessKey
                                                                                                     secretKey:self.awsSecretKey];
    AWSServiceConfiguration *configuration = [AWSServiceConfiguration configurationWithRegion:self.awsRegion
                                                                          credentialsProvider:credentialsProvider];
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;

    if (IOS8)
    {
        UIUserNotificationType types = UIUserNotificationTypeNone;
        if (self.acceptsNotificationTypeAlert) types = types | UIUserNotificationTypeAlert;
        if (self.acceptsNotificationTypeBadge) types = types | UIUserNotificationTypeBadge;
        if (self.acceptsNotificationTypeSound) types = types | UIUserNotificationTypeSound;

        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:self.actionSettings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    else
    {
        UIRemoteNotificationType types = UIRemoteNotificationTypeNone;
        if (self.acceptsNotificationTypeAlert) types = types | UIRemoteNotificationTypeAlert;
        if (self.acceptsNotificationTypeBadge) types = types | UIRemoteNotificationTypeBadge;
        if (self.acceptsNotificationTypeSound) types = types | UIRemoteNotificationTypeSound;
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:types];
    }
}

- (void)setDeviceToken:(NSData *)deviceToken {
    _deviceToken = deviceToken;
    [self createPlatformEndpointWithDeviceToken:deviceToken];
}

- (void)receivedDeviceToken:(NSData*)deviceToken {
    [self createPlatformEndpointWithDeviceToken:deviceToken];
}

- (BFTask*)createPlatformEndpointWithDeviceToken:(NSData *)deviceToken {
    // Get a hex string for the NSData deviceToken
    // http://stackoverflow.com/questions/7520615/how-to-convert-an-nsdata-into-an-nsstring-hex-string
    NSUInteger dataLength = [deviceToken length];
    NSMutableString *deviceTokenString = [NSMutableString stringWithCapacity:dataLength*2];
    const unsigned char *dataBytes = [deviceToken bytes];
    for (NSInteger idx = 0; idx < dataLength; ++idx) {
        [deviceTokenString appendFormat:@"%02x", dataBytes[idx]];
    }

    AWSSNS *sns = [AWSSNS defaultSNS];
    AWSSNSCreatePlatformEndpointInput *request = [AWSSNSCreatePlatformEndpointInput new];
    request.token = deviceTokenString;
    request.platformApplicationArn = self.awsApplicationArn;
    request.customUserData = [UIDevice currentDevice].identifierForVendor.UUIDString;

    self.createPlatformEndpointTask = [sns createPlatformEndpoint:request];
    self.createPlatformEndpointTask = [self.createPlatformEndpointTask continueWithBlock:^id(BFTask *task) {
        if (task.completed && task.result && !task.error)
        {
            AWSSNSCreateEndpointResponse* response = task.result;
            self.applicationPlatformEndpoint = response.endpointArn;
        }
        else if (task.error)
        {
            if (task.error.code == AWSSNSErrorInvalidParameter)
            {
                // Maybe it's a "already exists with the same Token, but different attributes" error
                // We have to check, and Amazon doesn't give any other way to do it.
                NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"Reason: Endpoint (.+) already exists with the same Token" options:NSRegularExpressionCaseInsensitive error:nil];

                NSString* errorMessage = task.error.description;
                __block NSString* matchArn = nil;
                [regex enumerateMatchesInString:errorMessage
                                        options:kNilOptions
                                          range:NSMakeRange(0, errorMessage.length)
                                     usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                         if ([result numberOfRanges] > 0)
                                         {
                                             NSString* maybeAMatch = [errorMessage substringWithRange:[result rangeAtIndex:1]];
                                             if ([maybeAMatch hasPrefix:@"arn:aws:sns:"])
                                             {
                                                 matchArn = maybeAMatch;
                                                 *stop = YES;
                                             }
                                         }
                }];

                if (matchArn)
                {
                    self.applicationPlatformEndpoint = matchArn;

                    // We're going to try replacing the endpoint with a new one.
                    return [[self deletePlatformEndpointWithEndpointArn:self.applicationPlatformEndpoint] continueWithBlock:^id(BFTask *task) {
                        if (!task.error)
                        {
                            // Did succeed in removing, now we create it again
                            return [self createPlatformEndpointWithDeviceToken:self.deviceToken];
                        }
                        else
                        {
                            // Failure while removing the endpoint, we use the already existing one
                            return [BFTask taskWithResult:self.applicationPlatformEndpoint];
                        }
                    }];
                }
            }

            NSLog(@"Error creating platform endpoint: %@", task.error);
        }
        return task;
    }];

    return self.createPlatformEndpointTask;
}

- (BFTask*)deletePlatformEndpointWithEndpointArn:(NSString*)endpointArn {
    AWSSNS *sns = [AWSSNS defaultSNS];
    AWSSNSDeleteEndpointInput* request = [AWSSNSDeleteEndpointInput new];
    request.endpointArn = endpointArn;

    return [sns deleteEndpoint:request];
}

- (void)subscribeToTopics:(NSArray*)topicArns {
    [self.createPlatformEndpointTask continueWithSuccessBlock:^id(BFTask *task) {
        AWSSNS *sns = [AWSSNS defaultSNS];

        for (NSString* topicArn in topicArns) {
            AWSSNSSubscribeInput* subcriptionRequest = [AWSSNSSubscribeInput new];
            subcriptionRequest.endpoint = self.applicationPlatformEndpoint;
            subcriptionRequest.topicArn = topicArn;
            subcriptionRequest.protocol = @"application";
            [[sns subscribe:subcriptionRequest] continueWithBlock:^id(BFTask *task) {
                if (task.completed && task.result && !task.error)
                {
                    NSLog(@"Subscribed!");
                }
                else if (task.error)
                {
                    NSLog(@"Error subscribing to topic: %@", task.error);
                }

                return nil;
            }];
        }

        return nil;
    }];
}

@end
