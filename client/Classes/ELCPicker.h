#ifndef __ELC_PICKER_H__
#define __ELC_PICKER_H__

#include <vector>

class ElcListener {
public:
    struct JpgData {
        const void *data;
        unsigned int length;
    };
    virtual void onElcLoad(std::vector<JpgData>& jpgs) {};
    virtual void onElcCancel() {};
};

void showElcPickerView(ElcListener* listener);
ElcListener* getElcListener();

#endif // __ELC_PICKER_H__