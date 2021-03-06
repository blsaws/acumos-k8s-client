#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T and Tech Mahindra
# under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# This file is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===============LICENSE_END=========================================================
#
#. What this is: Setup script for a private kubernetes (k8s) cluster.
#. 
#. Prerequisites:
#. - One or more Ubuntu Xenial or Centos 7 servers (as target k8s cluster nodes)
#. - This script downloaded to a folder on the server to be the k8s master node
#. - key-based SSH setup between the k8s master node and other nodes
#.
#. Usage:
#. - bash setup_k8s.sh "<nodes>"
#.   nodes: quoted, space-separated list of k8s cluster nodes, with at minimum
#.          the k8s master node (for an all-in-one (AIO) cluster deployment)
#.


