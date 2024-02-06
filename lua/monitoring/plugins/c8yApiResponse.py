#!/usr/bin/python3

import argparse, requests, unittest, sys, json
from requests.auth import HTTPBasicAuth
import time

parser = argparse.ArgumentParser(description='Testing Cumulocity API.')

parser.add_argument('host')
parser.add_argument('tenant')
parser.add_argument('username')
parser.add_argument('password')

args = parser.parse_args()


class TestCumulocityAPI():
   def __init__(self):
      self.testDeviceId = ''
      self.testMeasurementId = ''
      self.headers = {'accept': 'application/json'}
      self.managedObject = {
            'name': 'testMeasurementDevice',
            'c8y_IsDevice': {}
      }
      self.testCount = 0

   def tests(self): 

      def test_getAllManagedObjects(self):
         self.testCount += 1
         getInvResp = requests.get('https://'+args.host+'/inventory/managedObjects',
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))


      def test_getAllMeasurements(self):
         self.testCount += 1
         getMeasurementsResp = requests.get('https://'+args.host+'/measurement/measurements',
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))

      def test_postManagedObject(self):
         self.testCount += 1     
         postManagedObjResp = requests.post('https://'+args.host+'/inventory/managedObjects',
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), data=json.dumps(self.managedObject), headers=self.headers)
         self.testDeviceId = postManagedObjResp.json()['id']

      def test_getManagedObject(self):
         self.testCount += 1 
         getManagedObjResp = requests.get('https://'+args.host+'/inventory/managedObjects/'+self.testDeviceId,
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), headers=self.headers)
            
      def test_deleteManagedObject(self):
         if self.testDeviceId and self.testDeviceId.strip():
            self.testCount += 1
            deleteManagedObjResp = requests.delete('https://'+args.host+'/inventory/managedObjects/'+self.testDeviceId,
               auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))

      def test_postMeasurement(self):
         self.testCount += 1
         self.measurement = {
            'c8y_TemperatureMeasurement': {
               'T': {
                'value': 21,
                'unit': 'C'
               }
            },
            'time':'2016-09-07T11:50:14.000+02:00',
            'source': {
               'id': self.testDeviceId
            },
            'type': 'c8y_TemperatureMeasurement'
         }
         postMeasurementResp = requests.post('https://'+args.host+'/measurement/measurements',
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), data=json.dumps(self.measurement), headers=self.headers)
         self.testMeasurementId = postMeasurementResp.json()['id']

      def test_getMeasurement(self):
         self.testCount += 1
         getMeasurementResp = requests.get('https://'+args.host+'/measurement/measurements/'+self.testMeasurementId,
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), headers=self.headers)

      def test_deleteMeasurement(self):
         if self.testMeasurementId and self.testMeasurementId.strip():
            self.testCount += 1
            deleteMeasurementResp = requests.delete('https://'+args.host+'/measurement/measurements/'+self.testMeasurementId,
               auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))
      
      t0 = time.time()
      try :
         test_getAllManagedObjects(self)
         test_getAllMeasurements(self)
         test_postManagedObject(self)
         test_postMeasurement(self)
         test_getMeasurement(self)
         test_deleteMeasurement(self)
         test_getMeasurement(self) # of deleted object
         test_getManagedObject(self)
         test_deleteManagedObject(self)
         test_getManagedObject(self) # of deleted object
      finally:
         t1 = time.time()
         return self.testCount, t1 - t0 



if __name__ == '__main__':
   del sys.argv[1:]
   testCumulocityAPI = TestCumulocityAPI()
   testCount, time = testCumulocityAPI.tests()
   print('\nRan {0} tests in {1:1.3f}s'.format(testCount, time))
   print('Average response time: {0:1.3f}ms'.format(time*1000/testCount))
