#!/bin/bash

sudo systemctl stop cumulocity-agent
sleep 1
sudo make uninstall
sudo make install
sudo systemctl enable cumulocity-agent
sudo systemctl start cumulocity-agent