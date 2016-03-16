#ifndef INTEGRATE_H
#define INTEGRATE_H
#include <sragent.h>
#include <srwatchdogtimer.h>


class Integrate: public SrIntegrate
{
public:
        Integrate(SrWatchdogTimer &w): SrIntegrate(), wdt(w) {}
        virtual ~Integrate() {}
        virtual int integrate(const SrAgent &agent, const string &srv,
                              const string &srt);

private:
        SrWatchdogTimer &wdt;
};

#endif /* INTEGRATE_H */
