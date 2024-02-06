#!/usr/bin/python3
# -*- coding: utf-8 -*-
import base64
import datetime
import json
import sys
from subprocess import Popen
import time
import urllib.request
import unittest

try:
    from subprocess import DEVNULL
except ImportError:
    import os
    DEVNULL = open(os.devnull, 'w')


host = None
parentID = None
deviceID = None
nodeID = None
user = None
pw = None
canPort = None
pid_agent = None
pid_service = None
pid_simulator = None


def makeRequest(endpoint, method, payload=b''):
    url = host + endpoint
    req = urllib.request.Request(url=url, data=payload, method=method)
    req.add_header('Content-Type', 'application/json')
    req.add_header('Accept', 'application/json')
    cred = base64.b64encode('{}:{}'.format(user, pw).encode('utf-8'))
    req.add_header('Authorization', 'Basic %s' % cred.decode('utf-8'))
    with urllib.request.urlopen(req) as f:
        data = f.read()
        return json.loads(data)


def getMO():
    url = '/inventory/managedObjects/' + deviceID
    data = makeRequest(url, 'GET')
    return data


def putMO(payload):
    url = '/inventory/managedObjects/' + deviceID
    data = makeRequest(url, 'PUT', payload)
    return data


def getMeasurement(Type, since, until):
    query = {'source': deviceID, 'type': Type,
             'dateFrom': since, 'dateTo': until}
    url = '/measurement/measurements/?' + urllib.parse.urlencode(query)
    data = makeRequest(url, 'GET')
    return data


def getActiveAlarm():
    fmt = '/alarm/alarms?source={}&status=ACTIVE'
    url = fmt.format(deviceID)
    data = makeRequest(url, 'GET')
    return data


def getEvent(Type, since, until):
    query = {'source': deviceID, 'type': Type,
             'dateFrom': since, 'dateTo': until}
    url = '/event/events/?' + urllib.parse.urlencode(query)
    data = makeRequest(url, 'GET')
    return data


def getOperation(opID):
    url = '/devicecontrol/operations/' + opID
    data = makeRequest(url, 'GET')
    return data


def postOperation(payload):
    url = '/devicecontrol/operations/'
    data = makeRequest(url, 'POST', payload)
    return data


def setRegister(index, subIndex, dataType, value):
    fmt = 'Set CANopen register {}sub{} to {}'
    desc = fmt.format(index, subIndex, value)
    data = {
        'c8y_SetRegister': {
            'dataType': dataType,
            'index': index,
            'subIndex': subIndex,
            'nodeId': nodeID,
            'value': value
        },
        'deviceId': deviceID,
        'description': desc
    }
    payload = json.dumps(data).encode('utf-8')
    resp = postOperation(payload)
    return resp


def shellCommand(command):
    desc = 'shell command: ' + command
    data = {
        'c8y_Command': {
            'text': command
        },
        'deviceId': deviceID,
        'description': desc
    }
    payload = json.dumps(data).encode('utf-8')
    return postOperation(payload)


def setCANopenConf(baud, transmit, polling):
    fmt = 'set CANopen configuration: baud {}, transmit {}, polling {}'
    desc = fmt.format(baud, transmit, polling)
    data = {
        'c8y_CANopenConfiguration': {
            'baudRate': baud,
            'transmitRate': transmit,
            'pollingRate': polling
        },
        'deviceId': parentID,
        'description': desc
    }
    payload = json.dumps(data).encode('utf-8')
    return postOperation(payload)


def isoformat(time):
    time = time.replace(tzinfo=datetime.timezone.utc)
    return time.isoformat(timespec='seconds')


def getTimeRange():
    delta = datetime.timedelta(seconds=90)
    now = datetime.datetime.utcnow()
    since = isoformat(now - delta)
    until = isoformat(now)
    return since, until


class MyTestSuite(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        global pid_agent, pid_service, pid_simulator
        executable = './canopen_simulator/c8y_canopen_simulator'
        pid_simulator = startProcess([executable, str(nodeID), canPort])
        pid_service = startProcess(['../bin/c8y_canopend'])
        pid_agent = startProcess(['cumulocity-agent'])

    @classmethod
    def tearDownClass(cls):
        pid_agent.terminate()
        pid_service.terminate()
        pid_simulator.terminate()
        pid_agent.wait()
        pid_service.wait()
        pid_simulator.wait()

    def testCANopenConf(self):
        global deviceID
        did = deviceID
        deviceID = parentID
        mo = getMO()
        baud = int(mo['c8y_CANopenConfiguration']['baudRate'])
        opID = setCANopenConf(baud, 5, 3)['id']
        time.sleep(10)
        operation = getOperation(opID)
        mo = getMO()
        deviceID = did
        self.assertEqual(operation['status'], 'SUCCESSFUL')
        self.assertEqual(mo['c8y_CANopenConfiguration']['pollingRate'], 3)
        self.assertEqual(mo['c8y_CANopenConfiguration']['transmitRate'], 5)

    def testActiveAlarm(self):
        resp = getActiveAlarm()
        alarms = [x['type'] == 'Temp' for x in resp['alarms']]
        self.assertTrue(any(alarms))

    def testEvent(self):
        since, until = getTimeRange()
        events = getEvent('Temp', since, until)['events']
        self.assertTrue(len(events) > 0)

    def testMeasurement(self):
        since, until = getTimeRange()
        measurements = getMeasurement('Temp', since, until)['measurements']
        measurements = [x for x in measurements if x['type'] == 'Temp' and
                        x['Temp']['T']['value'] == 23.455999]
        self.assertTrue(len(measurements) > 0)

    def testWriteInteger(self):
        opID = setRegister(0x2002, 0, 'unsigned8', 255)['id']
        time.sleep(10)
        operation = getOperation(opID)
        mo = getMO()
        self.assertEqual(operation['status'], 'SUCCESSFUL')
        self.assertEqual(mo['c8y_RegisterStatus']['p2002_0'], 255)

    def testWriteNegative(self):
        opID = setRegister(0x6000, 2, 'signed16', -1)['id']
        time.sleep(10)
        operation = getOperation(opID)
        mo = getMO()
        self.assertEqual(operation['status'], 'SUCCESSFUL')
        self.assertEqual(mo['c8y_RegisterStatus']['p6000_2'], -1)

    def testWriteFloat(self):
        opID = setRegister(0x2001, 0, 'real32', 32.5)['id']
        time.sleep(10)
        operation = getOperation(opID)
        mo = getMO()
        self.assertEqual(operation['status'], 'SUCCESSFUL')
        self.assertEqual(mo['c8y_RegisterStatus']['p2001_0'], 32.5)

    def testClearAlarm(self):
        setRegister(0x2002, 0, 'unsigned8', 0)
        time.sleep(10)
        alarms = getActiveAlarm()['alarms']
        alarms = [x for x in alarms if x['type'] == 'Temp']
        self.assertEqual(len(alarms), 0)

    def testShellWrite64bit(self):
        opID = shellCommand('w 0x6001 0 u64 4294967296')['id']
        time.sleep(10)
        operation = getOperation(opID)
        mo = getMO()
        self.assertEqual(operation['status'], 'SUCCESSFUL')
        self.assertEqual(mo['c8y_RegisterStatus']['p6001_0'], 4294967296)

    def testShellRead64bit(self):
        opID = shellCommand('r 0x6001 0 u64')['id']
        time.sleep(10)
        operation = getOperation(opID)
        mo = getMO()
        self.assertEqual(operation['status'], 'SUCCESSFUL')
        self.assertEqual(mo['c8y_RegisterStatus']['p6001_0'], 4294967296)

    def testShellInfoId(self):
        opID = shellCommand('info id')['id']
        time.sleep(10)
        operation = getOperation(opID)
        self.assertEqual(operation['status'], 'SUCCESSFUL')
        self.assertEqual(operation['c8y_Command']['result'], str(nodeID))

    def testShellInfoBitrate(self):
        opID = shellCommand('info bitrate')['id']
        time.sleep(10)
        operation = getOperation(opID)
        self.assertEqual(operation['status'], 'SUCCESSFUL')

    def testShellInfoSdoTimeout(self):
        opID = shellCommand('info sdo_timeout')['id']
        time.sleep(10)
        operation = getOperation(opID)
        self.assertEqual(operation['status'], 'SUCCESSFUL')

    def testUnavailabilityAlarm(self):
        global pid_simulator
        pid_simulator.terminate()
        pid_simulator.wait()
        time.sleep(10)
        Type = 'c8y_CANopenAvailabilityAlarm'
        resp = getActiveAlarm()['alarms']
        alarms = [x for x in resp if x['type'] == Type]
        self.assertGreater(len(alarms), 0)
        executable = './canopen_simulator/c8y_canopen_simulator'
        pid_simulator = startProcess([executable, str(nodeID), canPort])
        time.sleep(15)
        resp = getActiveAlarm()['alarms']
        alarms = [x for x in resp if x['type'] == Type]
        self.assertEqual(len(alarms), 0)


def startProcess(args):
    pid = Popen(args, stdout=DEVNULL, stderr=DEVNULL)
    print('{}: {}'.format(pid.pid, ' '.join(args)))
    return pid


if __name__ == '__main__':
    host, user, pw = sys.argv[1], sys.argv[2], sys.argv[3]
    parentID, deviceID, nodeID = sys.argv[4], sys.argv[5], int(sys.argv[6])
    canPort = sys.argv[7]
    del sys.argv[1:]
    unittest.main(verbosity=2)
