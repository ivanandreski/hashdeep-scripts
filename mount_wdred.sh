#!/usr/bin/env bash

sudo mkdir /mnt/ivan-server.wdred
sudo mount -t cifs //192.168.1.143/wdred-movies /mnt/ivan-server.wdred -o username=ivan
