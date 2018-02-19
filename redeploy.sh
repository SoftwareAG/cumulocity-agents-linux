#!/bin/bash

sudo systemctl kill cumulocity-agent
sleep 1
sudo make uninstall
sleep 1
sudo make install
sleep 1
sudo systemctl enable cumulocity-agent
sleep 1
sudo systemctl start cumulocity-agent

