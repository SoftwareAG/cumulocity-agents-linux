/*
 *++ nmtslave - user-defined CANopen NMT functions 
 *-- nmtslave - anwenderdefinierte CANopen NMT Funktionen 
 *
 * Copyright (c) 1997-2005 port GmbH Halle (Saale)
 *------------------------------------------------------------------
 * $Header: /z2/cvsroot/library/co_lib/examples/s1_x86_socketcan/nmtslave.c,v 1.1 2012/07/27 08:15:31 oe Exp $
 *
 *------------------------------------------------------------------
 *
 * modification history
 * --------------------
 * (not supported with examples)
 *
 *
 *
 *------------------------------------------------------------------
 */


/**
*  \file nmtslave.c
*++ Callback functions concerning the NMT state machine.
*-- Anwenderfunktionen bei Änderung der NMT Zustandsmaschine
*  \author port GmbH Halle (Saale)
*  $Revision: 1.1 $
*  $Date: 2012/07/27 08:15:31 $
*
*++ This file contains function templates for a CANopen device.
*++ The functions have influence to the state machine behaviour of the
*++ CANopen node.
*++ The user is responsible for the contents of the functions.
*++ Before using this template you must make a copy of them.
*-- Diese Datei beinhaltet Funktionen für ein CANopen Gerät.
*-- Die Funktionen haben Einfluß auf das Verhalten der State Machine
*-- des CANopen Knotens.
*-- Der Anwender ist für den Inhalt der Funktionen verantwortlich.
*/

#include <stdio.h>

#define DEF_HW_PART
#include <cal_conf.h>

#include <co_drv.h>
#include <co_usr.h>
#include <co_nmt.h>

#include <examples.h>

/*******************************************************************/
/**
*
*++ \brief resetApplInd - reset the application
*-- \brief resetApplInd - setzt die Applikation zurück
*
*++ This function will reset the device's application.
*++ All application parameters from the Object Dictionary are set
*++ to the default values before this function is called.
*++ The user has to ensure that his application will be reset.
*++ Additionally, it is possible application to load parameters
*++ from a non volatile memory.
*-- Diese Funktion setzt die Geräteapplikation zurück.
*-- Die Applikationsvariablen aus dem Objektverzeichnis werden
*-- vor diesem Funktionsaufruf auf ihre Standardwerte gesetzt.
*-- Der Nutzer ist für das Rücksetzen seiner Applikation verantwortlich.
*-- Zusätzlich können hier Applikationsparameter aus einem nicht flüchtigen
*-- Speicher geladen werden.
*
* \returns
* nothing
*
*/


void resetApplInd(void)
{
#ifdef NO_PRINTF_S
    PUTCHAR('X');
#else
    PRINTF("Application reset\n");
#endif
}

/*******************************************************************/
/**
*
*++ \brief resetCommInd - reset communication parameters
*-- \brief resetCommInd - setzt die Kommunikationsparameter zurück
*
*++ This function is user defined. 
*++ All communication parameters from the Object Dictionary besides the
*++ bit rate and the node ID are set 
*++ to the default values before this function is called.
*++ The default values are taken from the object dictionary's
*++ "default" value, stored as \b defaultVal in the 
*++ object dictionary's \e VALUE_DESC_T struct.
*++ All node-id depending things are reset to
*++ predefined connection set, taking care of the
*++ internal global Variable \e coNodeId,
*++ which is normally set by the library with the call \e initCanopen()
*++ which calls \e getNodeId().
*++ This is only done for the first 4 TPDs and RPDOs, all
*++ others are set to invalid.
*++
*++ In this function the CANopen node can get a new bit rate 
*++ from a DIP-Switch or non volatile memory.
*++ For the CAN controller
*++ bit rate initialisation, the user is responsible.
*++ Further communication parameters can be loaded from a non volatile
*++ memory too. 
*++ In this case the object dictionary values have to be overwritten
*++ using \e putObj() and \e setCommPar() .
*
*-- Diese Funktion wird vom Anwender definiert. Bevor diese Funktion
*-- aufgerufen wird, werden alle Kommunikationsparameter bis auf die
*-- Node ID und die Bitrate auf ihre Standardwerte zurückgesetzt..
*-- Für die von der Node-ID abhängigen Werte , z.B PDO COB-IDs,
*-- wird die aktuelle Knotennummer berücksichtigt.
*-- diese ist in der globalen Variablen \e coNodeId gespeichert,
*-- welche mittels der Funktion \e getNodeId() zuvor ermittelt wurde.
*-- Dem Knoten kann eine neue Bitrate durch Lesen eines
*-- DIP-Switches oder eines nicht-flüchtigen Speichers zugewiesen werden.
*-- Der Anwender ist für das Setzen der Bitrate auf dem CAN-Controller
*-- verantwortlich.
*-- Weiterhin ist es möglich weitere Kommunikationsparameter aus einem
*-- nicht-flüchtigen Speicher zu laden.
*
* \returns
* nothing
*
*/

void resetCommInd(void)
{
    
    /* get bit rate of device (EEPROM,DIP-Switch,...) */
    /* users_function() */
    
    /* sets CAN to new bitrate (manufacturer specific) */
    /*
    Stop_CAN();
    Start_CAN();
    */
    PRINTF("Communication reset\n");
    /* get communication parameter from nonvolatile memory */
    /* users_function() */
    
}

/*******************************************************************/
/**
*
*++ \brief newStateInd -  indicate transition to a new communcation state
*-- \brief newStateInd -  zeigt einen Zustandsübergang in der Kommunikation an
*
*++ This function will be indicated at the slave, if it will be forced 
*++ to an other communication state.
*++ It is called before the transition change.
*++ This user interface ensures a save behaviour of the application,
*++ before the node goes to an other state.
*++ Additionaly a change to change to OPERATIONAL can be prevent.
*-- Diese Funktion wird beim Slave vor einem Zustandsübergang in der 
*-- Kommunikationszustandsmaschine aufgerufen. In dieser Funktion kann
*-- der Anwender in seiner Applikation Sicherheitsvorkehrungen treffen.
*-- Weiterhin kann der Anwnder den Zustandswechsel nach OPERATIONAL
*-- verhindern.
*
* \retval CO_TRUE
*++ State change ok
*-- Zustandswechsel ok
* \retval CO_FALSE
*++ don't change the state to OPERATIONAL
*++ Node soll nicht nach OPERATIONAL gehen
*/


BOOL_T newStateInd(
     NODE_STATE_T  newState  /**< new state */
     )
{
    /* state classification */
    switch (newState) {
        /* Standard CANopen states */
        case PRE_OPERATIONAL:
            PRINTF("was switched to PRE_OPERATIONAL\n");	
	    break;
        case OPERATIONAL:
            PRINTF("was switched to OPERATIONAL\n");	
            break;
        case STOPPED:
            PRINTF("was switched to STOPPED\n");	
            break;
        default:
            PRINTF("was switched to \"unknown state\"\n");	
            break;
    }
    return(CO_TRUE);
    
}
/*______________________________________________________________________EOF_*/
