/*
 * usr_301 - modul for user interfaces
 *
 * Copyright (c) 1997-2005 port GmbH Halle (Saale)
 *------------------------------------------------------------------
 * $Header: /z2/cvsroot/library/co_lib/examples/s1_x86_socketcan/usr_301.c,v 1.1 2012/07/27 08:15:31 oe Exp $
 *
 *------------------------------------------------------------------
 *
 *
 * modification history
 * --------------------
 * (not supported with examples)
 *
 *
 *
 *
 *------------------------------------------------------------------
 */


/**
*  \file usr_301.c
*  \author port GmbH Halle (Saale)
*  $Revision: 1.1 $
*  $Date: 2012/07/27 08:15:31 $
*
*++ This modul contains functions for the error handling
*++ (CAN controller errors, node-guarding errors, abort domain transfer)
*++ by the application.
*++ Furthermore interface routines for receiving SDOs and PDOs are defined here.
*++ The functions are called by the CANopen communication services.
*++ The user is responsible for the content of all these functions.
*-- Dieses Modul enthält Funktionen zur Fehlerbehandlung
*-- (CAN Controller Fehler, Node Guarding Fehler, Abort Domain Transfer)
*-- durch die Applikation.
*-- Weiterhin enthält es Schnittstellenfunktionen für den Empfang von
*-- SDOs und PDOs.
*
*/


#include <stdio.h>

#define DEF_HW_PART
#include <cal_conf.h>

#include <co_usr.h>
#include <co_acces.h>
#include <co_pdo.h>
#include <co_sdo.h>
#include <co_stru.h>
#include <co_flag.h>
#include <co_drv.h>

#include <objects.h>

#include <examples.h>

/* constant definitions
---------------------------------------------------------------------------*/

/* external variables
---------------------------------------------------------------------------*/
extern UNSIGNED8 lNodeId; /* local Node-ID for our examples */

/* list of external used functions, if not in headers
---------------------------------------------------------------------------*/
void set_outputs(int port);

/* list of global defined functions
---------------------------------------------------------------------------*/

/* list of local defined functions
---------------------------------------------------------------------------*/

/*******************************************************************/
/**
*
*++ \brief getNodeId - get the node ID of the device
*-- \brief getNodeId - ermitteln der Knotennummer des Gerätes
*
*++ This function has to be filled by the user.
*++ It returns the node ID of the device from e.g. a DIP switch
*++ or nonvolatile memory to the CANopen layer.
*-- Der Inhalt dieser Funktion ist durch den Anwender zu definieren.
*-- Sie ermittelt die Netzwerkknotennummer von z.B. einem Schalter
*-- oder nichtflüchtigen Speicher.
*
*++ It is called from the CANopen layer
*++ to initialize node ID dependent COB-IDs.
*-- Die Funktion wird von der CANopen Schicht aufgerufen,
*-- um die von der Knotennummer abhängigen Werte bestimmter COB-IDs
*-- zu bestimmen.
*
* \returns node-id
*++ node ID in the range of 1..127
*-- Netzwerkknotennummer im Bereich von 1..127
*/

UNSIGNED8 getNodeId(void)
{
    return(lNodeId);
}



#ifdef CONFIG_PDO_CONSUMER
/*******************************************************************/
/**
*
*++ \brief pdoInd - indicate the occurence of a PDO
*-- \brief pdoInd - zeigt den Empfang einer PDO an
*
*++ In this function the user has to define his application specific
*++ handling for PDOs.
*-- In diese Funktion ist das Verhalten der Applikation bei Empfang
*-- bestimmter Nachrichten (PDOs) zu implementieren.
*
* \returns
*++ nothing
*-- nichts
*
*/

void pdoInd(
     UNSIGNED16 pdoNr    /**< nr of PDO */
     )
{
   /* Indicate the PDO indication */

# ifndef CONFIG_TIME_TEST
#  ifdef NO_PRINTF_S
    PUTCHAR('*');
#  else /* NO_PRINTF_S */
    PRINTF("PDO received %u \n",(int)pdoNr);
#  endif /* NO_PRINTF_S */
# endif /* CONFIG_TIME_TEST */

    switch(pdoNr) {
	case 1:
	    /* we have a fixed PDO mapping.
	     * Therefore we know that the two sub indicies of 0x6200
	     * are mapped. The content now in the object directory
	     * has to be transferred to the two hardware ports 1 and 2.
	     */
	    set_outputs(1);
	    set_outputs(2);
	    break;

    }
}

#endif /* CONFIG_PDO_CONSUMER */



#ifdef CONFIG_SDO_SERVER
/********************************************************************/
/**
*
*++ \brief sdoWrInd - indicate the occurence of a SDO write access
*-- \brief sdoWrInd - zeigt einen Schreibzugriff über eine SDO an
*
*++ This function is called if an SDO write request reaches the CANopen
*++ SDO server.
*++ Parameters of the function are the Index and Sub Index
*++ of the entry in the local object dictionary where the data
*++ should be written to.
*
*-- Diese Funktion wird beim Eintreffen eines Schreib-Requestes auf einem
*-- CANopen SDO Server gerufen.
*-- Parameter sind der Index und Subindex eines Eintrages im lokalen
*-- Objektverzeichnis, in den der Schreibzugriff erfolgen soll.
*
*++ If numerical data with size up to 4 byte should be written,
*++ the library stores the prevoius value in in temporary buffer.
*++ The new value is put into the local object dictionary.
*-- Bei numerischen Werten (Objektgröße bis zu 4 Byte)
*-- speichert die CANopen Library den alten Wert
*-- in einem Zwischenpuffer und legt den im Schreibrequest enthaltenen Wert
*-- im Objektverzeichnis ab.
*
*++ If the application does not accept this new value,
*++ i.e. the function returns with a value > 0,
*++ the old value is restored from the temporary buffer to the
*++ object dictionary and the SDO write request will be answered
*++ with a "\b Abort \b Domain \b Transfer"
*++ by the library.
*-- Verwirft die Applikation diesen Wert, d.h. Funktionsrückgabewert > 0,
*-- so wird der alte Wert aus dem Zwischenpuffer
*-- nach dem Verlassen dieser Funktion wieder hergestellt und ein
*-- "\b Abort \b Domain \b Transfer"
*-- wird gestartet.
*-- Den Abbruchkode kann man durch Angabe des
*-- \b return -Wertes
*-- festlegen.
*++ The abort code can be specified by the \b return -value.
*
* \returns
*++ The return value, which has to be specified by the application,
*++ selects the possible protocol answer of the write request
*++ to the SDO server.
*-- Der Rückgabewert, welcher applikationsspezifisch ausgefüllt werden muß,
*-- legt die Antwort des SDO-Servers auf die Schreibanforderung fest.
*-- Mögliche Werte sind:
* \retval CO_OK
*++ success
*-- Erfolg
* \retval RET_T
*-- Einer der gültigen, SDO bezogenen Werte kann übergeben werden.
*-- Dieser Wert wird im Fehlerfall an \em abortSdoTransf_Req() übergeben
*++ One of the valid, SDO related, values can be returned.
*++ This value is transferred  to  \em abortSdoTransf_Req() .
*-- Möglich sind:
*++ Possible are:
* \li \c CO_E_NONEXIST_OBJECT
* \li \c CO_E_NONEXIST_SUBINDEX
* \li \c CO_E_NO_READ_PERM
* \li \c CO_E_NO_WRITE_PERM
* \li \c CO_E_MAP
* \li \c CO_E_DATA_LENGTH
* \li \c CO_E_TRANS_TYPE
* \li \c CO_E_VALUE_TO_HIGH
* \li \c CO_E_VALUE_TO_LOW:
* \li \c CO_E_WRONG_SIZE
* \li \c CO_E_PARA_INCOMP
* \li \c CO_E_HARDWARE_FAULT
* \li \c CO_E_SRD_NO_RESSOURCE
* \li \c CO_E_SDO_CMD_SPEC_INVALID
* \li \c CO_E_MEM
* \li \c CO_E_SDO_INVALID_BLKSIZE
* \li \c CO_E_SDO_INVALID_BLKCRC
* \li \c CO_E_SDO_TIMEOUT
* \li \c CO_E_INVALID_TRANSMODE
* \li \c CO_E_SDO_OTHER
* \li \c CO_E_DEVICE_STATE
*
*++ all other return values are defaulting to E_SDO_OTHER.
*-- alle anderen Werte führen zu einem Default Wert E_SDO_OTHER.
*
*/

RET_T sdoWrInd(
	  UNSIGNED16 index,	/**< index to object */
	  UNSIGNED8  subIndex   /**< subindex to object */
	  )
{

        printf("sdoWrInd: %d:%d\n", index, subIndex);
    if (index == 0x6200) {
	/* write request to the digital output 8-bit ports */
	set_outputs(subIndex);
    }

    return CO_OK;
}


/********************************************************************/
/**
*++ \brief sdoRdInd - indicate the occurence of a SDO read access
*-- \brief sdoRdInd - zeigt einen Lesezugriff über eine SDO an
*
*++ This function determines a reaction to the device for
*++ an index - subindex read access via SDO.
*++ With this function the object dictionary has to made up to date
*++ e.g. by reading of digital inputs.
*++ If an error occurs an \b abort \b domain \b transfer will be started.
*++ This function is called
*++ only for objects with an index greater 0x1FFF.
*-- Diese Funktion definiert eine Reaktion der Applikation auf einen
*-- Lesezugriff zum Objektverzeichnis.
*-- Durch diese Funktion ist der angegebene Wert im Objektverzeichnis
*-- zu aktualisieren z.B Einlesen von digitalen Eingängen.
*-- Tritt ein Fehler auf, wird ein \b Abort \b Domain \b Transfer gestartet.
*-- Diese Funktion wird nur für Objekte mit einem Index größer 0x1FFF gerufen.
*
* \retval CO_OK
*++ success
*-- Erfolg
* \retval RET_T
*-- Einer der gültigen, SDO bezogenen Werte kann übergeben werden.
*-- Dieser Wert wird im Fehlerfall an \em abortSdoTransf_Req() übergeben
*++ One of the valid, SDO related, values can be returned.
*++ This value is transferred  to  \em abortSdoTransf_Req() .
*-- Möglich sind:
*++ Possible are:
* \li \c CO_E_NONEXIST_OBJECT
* \li \c CO_E_NONEXIST_SUBINDEX
* \li \c CO_E_NO_READ_PERM
* \li \c CO_E_NO_WRITE_PERM
* \li \c CO_E_MAP
* \li \c CO_E_DATA_LENGTH
* \li \c CO_E_TRANS_TYPE
* \li \c CO_E_VALUE_TO_HIGH
* \li \c CO_E_VALUE_TO_LOW:
* \li \c CO_E_WRONG_SIZE
* \li \c CO_E_PARA_INCOMP
* \li \c CO_E_HARDWARE_FAULT
* \li \c CO_E_SRD_NO_RESSOURCE
* \li \c CO_E_SDO_CMD_SPEC_INVALID
* \li \c CO_E_MEM
* \li \c CO_E_SDO_INVALID_BLKSIZE
* \li \c CO_E_SDO_INVALID_BLKCRC
* \li \c CO_E_SDO_TIMEOUT
* \li \c CO_E_INVALID_TRANSMODE
* \li \c CO_E_SDO_OTHER
* \li \c CO_E_DEVICE_STATE
*
*++ all other return values are defaulting to E_SDO_OTHER.
*-- alle anderen Werte führen zu einem Default Wert E_SDO_OTHER.
*
*/

RET_T sdoRdInd(
	  UNSIGNED16 index,	/**< index to object */
	  UNSIGNED8  subIndex   /**< subindex to object */
	  )
{
    switch (index) {
	case 0x1000:
	    if (subIndex > 0) {
		subIndex = 0;
	    }
	    break;
    }
    return CO_OK;
}


#endif /* CONFIG_SDO_SERVER */


#ifdef CONFIG_CAN_ERROR_HANDLING
/********************************************************************/
/**
*++ \brief canErrorInd - indicate the occurence of errors on the CAN driver
*-- \brief canErrorInd - zeigt das Aufreten von CAN Treiberfehlern an
*
*++ This function indicates the following errors:
*-- Diese Funktion zeigt das Auftreten der folgenden Fehler an:
*
* - \c CANFLAG_ACTIVE -
*   CAN Error Active
*
* - \c CANFLAG_BUSOFF -
*++ CAN-controller error CAN Busoff
*-- Fehler vom CAN Controller - CAN Busoff
*
* - \c CANFLAG_PASSIVE -
*++ CAN-controller error
*-- Fehler vom CAN Controller
*
* - \c CANFLAG_OVERFLOW -
*++ CAN-controller overrun error
*-- Overrun Fehler vom CAN Controller
*
* - \c CANFLAG_TXBUFFER_OVERFLOW -
*++ transmit buffer overflow
*-- Sendepuffer übergelaufen
*
* - \c CANFLAG_RXBUFFER_OVERFLOW -
*++ receive buffer overflow
*-- Empfangspuffer übergelaufen
*
*
*++ All occured status changes since the last canErrorInd() call are indicated.
*++ The current state can be read with getCanDriverState().
*-- Es werden alle aufgetretenen Statusänderungen
*-- seit dem letzten canErrorInd() angezeigt.
*-- Der aktuelle Zustand kann mit getCanDriverState() ausgelesen werden.
*
* \retval
* CO_TRUE
*++ CAN controller has to stay in the current state
*-- CAN Controller soll im aktuellen Zustand bleiben
* \retval
* CO_FALSE
*++ CAN controller has to go to BUS ON again
*-- CAN Controller soll wieder nach BUS ON gehen
*
*/

BOOL_T canErrorInd(
	UNSIGNED8 errorFlags	/**< CAN error flags */
	CO_COMMA_LINE_PARA_DECL
    )
{
UNSIGNED8	state;
BOOL_T		ret = CO_TRUE;

#undef PRINTF
#define PRINTF	printf
    PRINTF("canErrorInd status changes: ");
    if ((errorFlags & CANFLAG_PASSIVE) != 0)  {
	PRINTF("ERROR_PASSIVE\n");
    }
    if ((errorFlags & CANFLAG_BUSOFF) != 0)  {
	PRINTF("BUS_OFF\n");
	ret = CO_FALSE; /* Auto Bus-On */
    }
    if ((errorFlags & CANFLAG_OVERFLOW) != 0)  {
	PRINTF("OVERRUN\n");
    }
    if ((errorFlags & CANFLAG_RXBUFFER_OVERFLOW) != 0)  {
	PRINTF("ERROR_RXBUFFER_OVERFLOW\n");
    }
    if ((errorFlags & CANFLAG_TXBUFFER_OVERFLOW) != 0)  {
	PRINTF("ERROR_TXBUFFER_OVERFLOW\n");
    }

    state = getCanDriverState();
    PRINTF("The actual state is: (%x): ", state);

    if ((state & CANFLAG_INIT) != 0)  {
	PRINTF("INIT\n");
    }
    if ((state & CANFLAG_ACTIVE) != 0)  {
	PRINTF("Active\n");
    }
    if ((state & CANFLAG_BUSOFF) != 0)  {
	PRINTF("BUS_OFF\n");
    }
    if ((state & CANFLAG_PASSIVE) != 0)  {
	PRINTF("ERROR_PASSIVE\n");
    }

    return(ret);
}
#endif /* CONFIG_CAN_ERROR_HANDLING */

/*______________________________________________________________________EOF_*/
