#import <UIKit/UIKit.h>
#import "ELCImagePickerController.h"

@interface RootViewController : UIViewController <ELCImagePickerControllerDelegate> {
    ELCImagePickerController *elcPicker;
}
- (BOOL) prefersStatusBarHidden;

- (void) showElcPickerView;

@end
