#ifndef INTEGRATE_H
#define INTEGRATE_H
#include <sragent.h>


class Integrate: public SrIntegrate
{
public:
        Integrate(): SrIntegrate() {}
        virtual ~Integrate() {}
        virtual int integrate(const SrAgent &agent, const string &srv,
                              const string &srt);
};

#endif /* INTEGRATE_H */
