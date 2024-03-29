/*
 * co_init.c - Initialization functions for the CANopen Library
 *
 * Copyright (C) 1998-2018  by port GmbH  Halle(Saale)/Germany
 *
 *------------------------------------------------------------
 * This file was generated by the CANopen Design Tool V2.3.20.0
 * from project /home/tiens/Workspace/Port-CANOpen/canopen_simulator/cdt.can
 * on 2018/09/18 at 12:30:53.
 */

/**
 * \file co_init.c
 * \author port GmbH
 *
 * This module contains the initialization and deinitialization
 * of the CANopen Library for the CANopen device.
 */


/* header of standard C libraries */ 
#include <stdio.h>
#include <stdlib.h>

/* header of the CANopen Library */
#include <cal_conf.h>
#include <co_init.h>
#include <co_type.h>
#include <co_acces.h>
#include <co_nmt.h>
#include <co_lme.h>
#include <co_drv.h>
#include <co_sdo.h>
#include <co_util.h>
/* Redefine the following expressions with your specific
 output functions.*/
#ifndef PRINTF
# define PRINTF(s, e)  
#endif
#ifndef PUTCHAR
# define PUTCHAR(e)  
#endif


#ifndef CO_GLOBVARS_PARA_DECL
# define CO_GLOBVARS_PARA_DECL	void
#endif


/* Redefine INIT_USER_SETTINGS with your specific function. */
#ifndef INIT_USER_SETTINGS
# define INIT_USER_SETTINGS()  
#endif


/* Macro to return at errors. */ 
#ifndef CO_INIT_PRINTRET
# ifdef NO_PRINTF_S
#  define CO_INIT_PRINTRET(s) do {						\
		    if ( commonRet == CO_OK ) { PUTCHAR('0'); }		\
		    else { PUTCHAR('1'); return(commonRet); }		\
		  } while(0)
# else 
#  define CO_INIT_PRINTRET(s) do {						\
		    PRINTF( s": %d\n", (int) commonRet);         	\
		    if( commonRet != CO_OK ) return(commonRet);		\
		  } while(0)
# endif
#endif

#ifdef CONFIG_RCS_IDENT
static CO_CONST char _rcsid[] = "$Id: generateInitc.tcl,v 1.73 2016/05/27 10:48:22 se Exp $";
#endif /* CONFIG_RCS_IDENT*/

 
/* Definition of init_Library */ 
/********************************************************************/
/**
*\brief init_Library - initialization routine for the CANopen Library
*
* This function initializes the CANopen Library
* and defines the CANopen services.
*
*\retval
* CO_OK in case of success
* or specific library error code of the failed function.
*/
RET_T init_Library(CO_GLOBVARS_PARA_DECL) { 
RET_T commonRet;          /* return value for CANopen functions */

   /*--- inititializing of CANopen -----------------------------------*/ 
   /* defines also the Network control Object -- NMT 
    * reset communication and goes to the 
    * state preoperational + Initialization of CANopen */ 
    commonRet = initCANopen( CO_LINE_PARA );
    CO_INIT_PRINTRET("CANopen initialization");

   /* Call user defined function */

    INIT_USER_SETTINGS();

    /* Definition of CANopen Objects */
    /* ============================= */

    /* definition of SDOs Line 0 
     * 1st parameter: SDO number 
     * 2nd parameter: SDO type: CLIENT  SERVER
     */
    commonRet = defineSdo(1, SERVER  CO_COMMA_LINE_PARA);
    CO_INIT_PRINTRET("Line 0: Define 1st Server-SDO");

    /* definition of the local node */
                     /* Node Guarding, Heartbeat, Master */
    commonRet = createNodeReq(CO_FALSE,CO_TRUE CO_COMMA_LINE_PARA);
    CO_INIT_PRINTRET("NMT Node created");
    return(commonRet);
}

/* Definition of deinit_Library */ 
/********************************************************************/
/**
*\brief deinit_Library - deinitialization routine for the CANopen Library
*
* This function deinitializes the CANopen Library.
*
*\retval
* CO_OK
*
*/
RET_T deinit_Library(CO_GLOBVARS_PARA_DECL) { 

RET_T commonRet;      /* return value for CANopen functions */ 

    /* delete node object */
    commonRet = deleteNodeReq(CO_LINE_PARA);
    CO_INIT_PRINTRET("NMT Node removed");

    /* leaves CANopen    */
    leaveCANopen(CO_LINE_PARA);
    return(CO_OK);
}
