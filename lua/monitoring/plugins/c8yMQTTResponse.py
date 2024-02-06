#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Estimates average response time of Cumulocity MQTT

Usage:
    c8yMQTTResponse.py [-h] [--tls] [--qos] [--simulation] host tenant username password

Returns:
    string containing response time in milliseconds

Exit code:
    0 if all is correct
    2 if there was an error

Requires:
    paho-mqtt

"""
from __future__ import print_function

import argparse
import sys
import time
import ssl
import random

try:
    import paho.mqtt.client as mqtt
except ImportError as e:
    print("Import error: {}".format(str(e)), file=sys.stderr)
    exit(2)

TLS_PORT = 8883

CLIENT_ID = "test_mqtt_response_client"
DEVICE_NAME = "Test MQTT Response Device"

TOTAL_TEST_RUNS = 10
TIMEOUT_SECONDS = 10
SLEEP_INTERVAL_SECONDS = 0.001
COUNTER_MAX = int(TIMEOUT_SECONDS / SLEEP_INTERVAL_SECONDS)

TEST_PUBLISH_SUBSCRIBE_QOS = ((1, 0), (1, 1), (2, 2))

MEASUREMENT_TYPE = 'c8y_TestMeasurement'
TEMPLATES_XID = 'Testing_MQTT_Response_Collection'
TEMPLATES = "10,999,POST,MEASUREMENT,true,{0},,{0}.M.value,NUMBER\n" \
            "11,888,,{0},type,id,{0}.M.value".format(MEASUREMENT_TYPE)

MEAN_SIMULATED_VALUE = 50


def parse_args():
    parser = argparse.ArgumentParser(description='Testing Cumulocity MQTT response.')
    parser.add_argument('host')
    parser.add_argument('tenant')
    parser.add_argument('username')
    parser.add_argument('password')
    parser.add_argument('--tls', action='store_true', help='use secure MQTT')
    parser.add_argument('--qos', action='store_true', help='output QoS')
    parser.add_argument('--simulation', action='store_true', help='simulation mode')
    args = parser.parse_args()

    return args.host, args.tenant, args.username, args.password, args.tls, args.qos, args.simulation


def on_message(_, __, msg):
    topic = to_unicode(msg.topic)
    payload = to_unicode(msg.payload)
    received[topic] = payload


def client_tls_connect():
    client.tls_set(cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLSv1_2)
    client.tls_insecure_set(False)
    try:
        client.connect(host, TLS_PORT)
    except Exception as ee:
        print("Connection error: {}".format(str(ee)), file=sys.stderr)
        exit(2)


def to_unicode(input_string):
    try:
        return input_string.decode('utf-8')
    except AttributeError:
        return input_string


def manage_templates():
    if not templates_exist():
        client.publish('s/ut/' + TEMPLATES_XID, TEMPLATES, 2)
    counter = 0
    while not templates_exist():
        time.sleep(SLEEP_INTERVAL_SECONDS)
        counter += 1
        if counter == COUNTER_MAX:
            raise RuntimeError("Templates creation timeout expired.")


def templates_exist():
    dt = 's/dt'
    ut = 's/ut/' + TEMPLATES_XID

    client.subscribe(dt, 2)

    if dt in received:
        del received[dt]

    client.publish(ut, None, 2)

    poll(dt)

    client.unsubscribe(dt)

    payload = received[dt]
    if payload.startswith('20,' + TEMPLATES_XID):
        return True
    elif payload.startswith('41,' + TEMPLATES_XID):
        return False
    else:
        raise RuntimeError("SmartREST template's response mismatch.")


def poll(topic):
    counter = 0
    while topic not in received:
        time.sleep(SLEEP_INTERVAL_SECONDS)
        counter += 1
        if counter == COUNTER_MAX:
            raise RuntimeError("Receive timeout expired.")


def run_test(value, publish_qos):
    uc = 's/uc/' + TEMPLATES_XID
    dc = 's/dc/' + TEMPLATES_XID

    if dc in received:
        del received[dc]

    client.publish(uc, '999,,' + value, publish_qos)

    poll(dc)

    payload_list = received[dc].split(',')
    if payload_list[-1] != value:
        raise RuntimeError("Measurement's value mismatch in the response.")
    elif payload_list[-2] is None:
        raise RuntimeError("Measurement's id is missing in the response.")
    elif payload_list[-3] != MEASUREMENT_TYPE:
        raise RuntimeError("Measurement's type mismatch in the response.")


if __name__ == '__main__':
    host, tenant, username, password, use_tls, output_qos, simulation_mode = parse_args()

    if simulation_mode:
        simulated_avg_response = abs(random.gauss(MEAN_SIMULATED_VALUE, MEAN_SIMULATED_VALUE * 0.1))
        print("Average response time: {0:1.3f} ms".format(simulated_avg_response))
        exit(0)

    received = {}

    client = mqtt.Client(CLIENT_ID)
    client.username_pw_set(tenant + '/' + username, password)
    client.on_message = on_message

    if use_tls:
        client_tls_connect()
    else:
        try:
            client.connect(host)
        except Exception:
            client_tls_connect()

    client.loop_start()

    client.publish("s/us", "100," + DEVICE_NAME + ",c8y_MQTTDevice", 2)

    try:
        manage_templates()
    except RuntimeError as e:
        print("Templates error: {}".format(str(e)), file=sys.stderr)
        client.loop_stop()
        exit(2)

    t0 = t1 = None
    qos_p = qos_s = None
    values = [str(x) for x in range(1, TOTAL_TEST_RUNS + 1)]
    for i, qos in enumerate(TEST_PUBLISH_SUBSCRIBE_QOS):
        qos_p = qos[0]
        qos_s = qos[1]
        dc_topic = 's/dc/' + TEMPLATES_XID
        client.subscribe(dc_topic, qos_s)
        try:
            t0 = time.time()
            for v in values:
                run_test(v, qos_p)
            t1 = time.time()
        except RuntimeError as e:
            if i == len(TEST_PUBLISH_SUBSCRIBE_QOS) - 1:
                print("Tests error: {}".format(str(e)), file=sys.stderr)
                client.loop_stop()
                exit(2)
            else:
                client.unsubscribe(dc_topic)
                continue
        break

    client.loop_stop()

    avg_response = (t1 - t0) * 1000 / TOTAL_TEST_RUNS

    if output_qos:
        print("Average response time: {0:1.3f} ms, publish QoS: {1:d}, subscribe QoS: {2:d}."
              .format(avg_response, qos_p, qos_s))
    else:
        print("Average response time: {0:1.3f} ms".format(avg_response))
