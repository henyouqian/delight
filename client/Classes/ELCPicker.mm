#include "ELCPicker.h"
#import "RootViewController.h"

void showElcPickerView() {
    RootViewController *rootViewController = (RootViewController*)[[[UIApplication sharedApplication] keyWindow] rootViewController];
    [rootViewController showElcPickerView];
    
}