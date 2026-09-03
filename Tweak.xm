#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <CoreMotion/CoreMotion.h>

static void (*orig_start)(CMMotionManager *, SEL, NSOperationQueue *, CMAccelerometerHandler);

static void hookedStartAccelerometerUpdates(
    CMMotionManager *self, SEL _cmd,
    NSOperationQueue *queue,
    CMAccelerometerHandler originalHandler
)
{
    CMAccelerometerHandler wrapped = ^(CMAccelerometerData *data, NSError *err) {
        if(err || !data) {
            if(originalHandler) originalHandler(data, err);
            return;
        }
        double z = data.acceleration.z;
        if(z < -0.70) {
            return;
        }
        if(originalHandler) originalHandler(data, err);
    };
    orig_start(self, _cmd, queue, wrapped);
}

__attribute__((constructor))
void init_hook(void) {
    Class cmClass = objc_getClass("CMMotionManager");
    if (!cmClass) return;

    MSHookMessage(
        cmClass,
        @selector(startAccelerometerUpdatesToQueue:withHandler:),
        (IMP)hookedStartAccelerometerUpdates,
        (IMP *)&orig_start
    );
}