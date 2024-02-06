#!/usr/bin/python3

import argparse, requests, unittest, sys, json
from requests.auth import HTTPBasicAuth

parser = argparse.ArgumentParser(description='Testing Cumulocity API.')

parser.add_argument('host')
parser.add_argument('tenant')
parser.add_argument('username')
parser.add_argument('password')

args = parser.parse_args()

class TestCumulocityAPI(unittest.TestCase):

   def test_getInventory(self):
      getInvResp = requests.get('https://'+args.host+'/inventory/managedObjects',
         auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))
      self.assertEqual(getInvResp.status_code, 200)

   def test_getMeasurements(self):
      getMeasurementsResp = requests.get('https://'+args.host+'/measurement/measurements',
         auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))
      self.assertEqual(getMeasurementsResp.status_code, 200)

   def test_postMeasurement(self):
      headers = {'accept': 'application/json'}

      managedObject = {
         'name': 'testMeasurementDevice',
         'c8y_IsDevice': {}
      }

      postManagedObjResp = requests.post('https://'+args.host+'/inventory/managedObjects',
         auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), data=json.dumps(managedObject), headers=headers)
      self.assertEqual(postManagedObjResp.status_code/100, 2)
      testDeviceId = postManagedObjResp.json()['id']

      getManagedObjResp = requests.get('https://'+args.host+'/inventory/managedObjects/'+testDeviceId,
         auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), headers=headers)
      self.assertEqual(getManagedObjResp.status_code/100, 2)
      self.assertEqual(getManagedObjResp.json()['name'], managedObject['name'])

      measurement = {
         'c8y_TemperatureMeasurement': {
            'T': {
             'value': 21,
             'unit': 'C'
            }
         },
         'time':'2016-09-07T11:50:14.000+02:00',
         'source': {
            'id': testDeviceId
         },
         'type': 'c8y_TemperatureMeasurement'
      }

      postMeasurementResp = requests.post('https://'+args.host+'/measurement/measurements',
         auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), data=json.dumps(measurement), headers=headers)
      self.assertEqual(postMeasurementResp.status_code/100, 2)
      testMeasurementId = postMeasurementResp.json()['id']

      getMeasurementResp = requests.get('https://'+args.host+'/measurement/measurements/'+testMeasurementId,
         auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), headers=headers)
      self.assertEqual(getMeasurementResp.status_code/100, 2)
      self.assertEqual(getMeasurementResp.json()['c8y_TemperatureMeasurement']['T']['value'],
         measurement['c8y_TemperatureMeasurement']['T']['value'])

      if testMeasurementId and testMeasurementId.strip():
         deleteMeasurementResp = requests.delete('https://'+args.host+'/measurement/measurements/'+testMeasurementId,
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))
         self.assertEqual(getMeasurementResp.status_code/100, 2)

         getMeasurementResp2 = requests.get('https://'+args.host+'/measurement/measurements/'+testMeasurementId,
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password), headers=headers)
         self.assertEqual(getMeasurementResp2.status_code, 404)

      if testDeviceId and testDeviceId.strip():
         deleteManagedObjResp = requests.delete('https://'+args.host+'/inventory/managedObjects/'+testDeviceId,
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))
         self.assertEqual(deleteManagedObjResp.status_code/100, 2)

         getManagedObjResp2 = requests.get('https://'+args.host+'/inventory/managedObjects/'+testDeviceId,
            auth=HTTPBasicAuth(args.tenant+'/'+args.username,args.password))
         self.assertEqual(getManagedObjResp2.status_code, 404)


if __name__ == '__main__':
   del sys.argv[1:]
   unittest.main()
