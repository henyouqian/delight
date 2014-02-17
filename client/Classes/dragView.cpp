#include "dragView.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

bool DragView::init() {
    if ( !Node::init() ) {
        return false;
    }
    _trackTouch = false;
    _dragging = false;
    _rollSpeed = 0.f;
    _bouncing = false;
    _contentHeight = 1000.f;
    
    scheduleUpdate();
    return true;
}

void DragView::setWindowRect(const Rect &rect) {
    _windowRect = rect;
    setPositionY(rect.size.height);
}

const Rect& DragView::getWindowRect() {
    return _windowRect;
}

void DragView::setContentHeight(float height) {
    _contentHeight = height;
}

bool DragView::isDragging() {
    return _dragging;
}

void DragView::onTouchesBegan(const Touch* touch) {
    if (_windowRect.containsPoint(touch->getLocation()) && !_bouncing) {
        _trackTouch = true;
        _dragPointInfos.clear();
        _rollSpeed = 0.f;
    }
}

void DragView::onTouchesMoved(const Touch* touch) {
    if (!_trackTouch) {
        return;
    }
    if (!_dragging) {
        auto p0 = touch->getStartLocation();
        auto p1 = touch->getLocation();
        if (fabs(p0.y-p1.y) > 10) {
            _dragging = true;
        }
    }
    if (_dragging) {
        auto pos = this->getPosition();
        
        float top = _windowRect.origin.y+_windowRect.size.height;
        if (pos.y < top) {
            float dt = top - pos.y;
            float maxDist = 300.f;
            if (dt < maxDist) {
                pos.y += touch->getDelta().y * (cos((dt/maxDist)*M_PI_2+M_PI_2)+1.f);
            }
        } else {
            pos.y += touch->getDelta().y;
            
            //roll speed
            DragPointInfo dpi;
            dpi.y = touch->getLocation().y;
            dpi.t = std::chrono::steady_clock::now();
            _dragPointInfos.push_back(dpi);
            if (_dragPointInfos.size() > 5) {
                _dragPointInfos.pop_front();
            }
            
        }
        this->setPosition(pos);
    }
}

void DragView::onTouchesEnded(const Touch* touch) {
    _trackTouch = false;
    _dragging = false;
    
    if (beyondTop()) {
        float top = _windowRect.origin.y+_windowRect.size.height;
        auto moveTo = MoveTo::create(.2f, Point(0.f, top));
        auto ease = EaseSineOut::create(moveTo);
        auto callback = CallFunc::create(CC_CALLBACK_0(DragView::bounceEnd, this));
        auto seq = Sequence::create(ease, callback, nullptr);
        this->runAction(seq);
        _bouncing = true;
    } else {
        //roll
        _rollSpeed = 0.f;
        auto now = std::chrono::steady_clock::now();
        float minDt = 0.1f;
        for (auto it = _dragPointInfos.begin(); it != _dragPointInfos.end(); ++it) {
            auto dt = std::chrono::duration_cast<std::chrono::duration<float>>(now - it->t).count();
            if (dt < minDt) {
                _rollSpeed = (touch->getLocation().y - it->y) / dt / 60.f;
                _rollSpeed = MIN(100.f, MAX(-100.f, _rollSpeed));
                break;
            }
        }
    }
}

void DragView::update(float delta) {
    if (_rollSpeed) {
        if (beyondTop() && !_bouncing) {
            bool neg = _rollSpeed < 0;
            float v = fabs(_rollSpeed);
            float brk = 8.f;
            v = MIN(v, 40.f);
            v -= brk;
            if (v < 0.01f) {
                v = 0;
                float top = _windowRect.origin.y+_windowRect.size.height;
                auto moveTo = MoveTo::create(.2f, Point(0.f, top));
                auto ease = EaseSineOut::create(moveTo);
                auto callback = CallFunc::create(CC_CALLBACK_0(DragView::bounceEnd, this));
                auto seq = Sequence::create(ease, callback, nullptr);
                this->runAction(seq);
                _bouncing = true;
            }
            _rollSpeed = v;
            if (neg) {
                _rollSpeed = -_rollSpeed;
            }
            
            auto pos = this->getPosition();
            pos.y += _rollSpeed;
            this->setPositionY(floor(pos.y));
            
//            float top = _windowRect.origin.y+_windowRect.size.height;
//            float t = fabs(_rollSpeed*0.003f);
//            lwinfo("%f", t);
//            float s = 1800.f*t*t;
//            auto moveTo1 = MoveTo::create(t, Point(0.f, top-s));
//            auto ease1 = EaseOut::create(moveTo1, 1.f);
//            auto moveTo2 = MoveTo::create(t, Point(0.f, top));
//            auto ease2 = EaseIn::create(moveTo2, 1.f);
//            auto callback = CallFunc::create(CC_CALLBACK_0(DragView::bounceEnd, this));
//            auto seq = Sequence::create(ease1, ease2, callback, nullptr);
//            this->runAction(seq);
//            _rollSpeed = 0;
            return;
        }
        
        auto pos = this->getPosition();
        pos.y += _rollSpeed;
        this->setPositionY(floor(pos.y));
        
        bool neg = _rollSpeed < 0;
        float v = fabs(_rollSpeed);
        //v -= 2;
        float brk = v * .08f;
        brk = MAX(brk, 0.1f);
        v -= brk;
        if (v < 0.01f) {
            v = 0;
        }
        _rollSpeed = v;
        if (neg) {
            _rollSpeed = -_rollSpeed;
        }
        
//        float top = _windowRect.origin.y+_windowRect.size.height;
//        if (pos.y < top) {
//            if (_rollSpeed != 0) {
//                bool neg = _rollSpeed < 0;
//                float brk = v*.2f;
//                float v = fabs(_rollSpeed);
//                v -= brk;
//                if (v < 0.01f) {
//                    v = 0;
//                }
//                _rollSpeed = v;
//                if (neg) {
//                    _rollSpeed = -_rollSpeed;
//                }
//            }
//            if (_rollSpeed == 0) {
//                auto moveTo = MoveTo::create(.2f, Point(0.f, top));
//                auto ease = EaseSineOut::create(moveTo);
//                this->runAction(ease);
//            }
//        }
    }
}

void DragView::bounceEnd() {
    _bouncing = false;
}

bool DragView::beyondTop() {
    float limit = _windowRect.origin.y+_windowRect.size.height;
    if (getPosition().y < limit) {
        return true;
    }
    return false;
}
bool DragView::beyondBottom() {
    float bottom = getPosition().y + _contentHeight;
    if (bottom > _windowRect.origin.y) {
        return true;
    }
    return false;
}
