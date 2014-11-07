## MBAWSSNSManager

Is a small class that makes it easy to do the basic AWS SNS-related tasks:

- Register for notifications:
	1. Request device token from Apple
	- Create platform endpoint with SNS
	- Subscribe to SNS Topic
- Delete platform endpoint

This allows you to receive broadcast Push notifications from Amazon Web Services' Simple Notification Service (AWS SNS).


## Usage

Add `pod AWSiOSSDKv2` to your Podfile then run `pod install`

	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
		[self registerForNotifications];
	}
	
	- (void)registerForNotifications {
	    MBAWSSNSManager* manager = [MBAWSSNSManager sharedManager];
	    manager.acceptsNotificationTypeAlert = YES;
	    manager.acceptsNotificationTypeBadge = YES;
	    manager.acceptsNotificationTypeSound = YES;
	    manager.awsAccessKey = @"<your_key>";
	    manager.awsSecretKey = @"<your_other_key>";
	    manager.awsRegion = <your_region (e.g. AWSRegionUSWest1)>;
	    manager.awsApplicationArn = @"<your_app_arn>";
	    [manager registerForNotifications];
	}
	
	- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
	    MBAWSSNSManager* manager = [MBAWSSNSManager sharedManager];
	    manager.deviceToken = deviceToken;
	    [manager subscribeToTopics:@[
	                                 @"<your_topic_arn>"
	                                 ]];
	}

	- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error{
	    NSLog(@"Failed to register with error : %@", error);
	}


For more details see the blog post @ [Interfirm's blog](http://blog.interfirm.co.jp/entry/2014/11/07/184629)