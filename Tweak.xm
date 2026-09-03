#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <CoreMotion/CoreMotion.h>

static IMP orig_startAcc = NULL;
static IMP orig_startDev = NULL;

void hookedStartAccelerometerUpdates(id self, SEL _cmd, NSOperationQueue *queue, CMAccelerometerHandler handler)
{
    CMAccelerometerHandler wrapped = ^(CMAccelerometerData *data, NSError *err) {
        if (!handler) return;
        if (err || !data) {
            handler(data, err);
            return;
        }
        double z = data.acceleration.z;
        if (z < -0.70) {
            return;
        }
        handler(data, err);
    };
    ((void (*)(id,SEL,NSOperationQueue *,CMAccelerometerHandler))orig_startAcc)(self,_cmd,queue,wrapped);
}

void hookedStartDeviceMotionUpdates(id self, SEL _cmd, NSOperationQueue *queue, CMDeviceMotionHandler handler)
{
    CMDeviceMotionHandler wrapped = ^(CMDeviceMotion *motion, NSError *err) {
        if (!handler) return;
        if (err || !motion) {
            handler(motion, err);
            return;
        }
        double z = motion.gravity.z;
        if (z < -0.70) {
            return;
        }
        handler(motion, err);
    };
    ((void (*)(id,SEL,NSOperationQueue *,CMDeviceMotionHandler))orig_startDev)(self,_cmd,queue,wrapped);
}

__attribute__((constructor))
void do_hook(void)
{
    Class motionClass = objc_getClass("CMMotionManager");
    if (!motionClass) return;

    SEL sAcc = @selector(startAccelerometerUpdatesToQueue:withHandler:);
    Method mAcc = class_getInstanceMethod(motionClass, sAcc);
    if(mAcc)
    {
        orig_startAcc = method_getImplementation(mAcc);
        method_setImplementation(mAcc, (IMP)hookedStartAccelerometerUpdates);
    }

    SEL sDev = @selector(startDeviceMotionUpdatesToQueue:withHandler:);
    Method mDev = class_getInstanceMethod(motionClass, sDev);
    if(mDev)
    {
        orig_startDev = method_getImplementation(mDev);
        method_setImplementation(mDev, (IMP)hookedStartDeviceMotionUpdates);
    }
}