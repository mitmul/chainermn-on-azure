#!/bin/bash

# Create jumpbox VM
python deploy.py \
-k ~/.ssh/id_rsa.pub \
-g chainermn \
-s chainermnscripts \
--jumpbox-only

