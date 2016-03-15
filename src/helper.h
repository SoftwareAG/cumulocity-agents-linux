#ifndef HELPER_H
#define HELPER_H
#include <sragent.h>
#include <srwatchdogtimer.h>

class Helper: public AbstractTimerFunctor
{
public:
        Helper(SrAgent &a, SrWatchdogTimer &w): timer(10*1000, this), wdt(w) {
                a.addTimer(timer);
                timer.start();
        }
        virtual ~Helper() {}

        void operator()(SrTimer &timer, SrAgent &agent) {
                (void)timer;
                (void)agent;
                wdt.kick();
        }

private:
        SrTimer timer;
        SrWatchdogTimer &wdt;
};

#endif /* HELPER_H */
