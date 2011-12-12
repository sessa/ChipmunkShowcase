#import <UIKit/UIKit.h>

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(strong, nonatomic) UIWindow *window;
@property(strong, nonatomic) ViewController *viewController;

@property(nonatomic, retain) NSString *currentDemo;

-(void)nextDemo;

@end