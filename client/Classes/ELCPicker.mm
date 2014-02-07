#include "ELCPicker.h"
#import "RootViewController.h"

static ElcListener* _listener = nullptr;

void showElcPickerView(ElcListener* listener) {
    _listener = listener;
    RootViewController *rootViewController = (RootViewController*)[[[UIApplication sharedApplication] keyWindow] rootViewController];
    [rootViewController showElcPickerView];
}

ElcListener* getElcListener() {
    return _listener;
}
