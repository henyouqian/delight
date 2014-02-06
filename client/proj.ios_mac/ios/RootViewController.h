#import <UIKit/UIKit.h>
#import "ELCImagePicker/ELCImagePickerController.h"

@interface RootViewController : UIViewController <ELCImagePickerControllerDelegate> {

}
- (BOOL) prefersStatusBarHidden;
- (void) showElcPickerView;

@end
