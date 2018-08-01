.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
.. http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================


========================================================
Acumos Solution Deployment in Private Kubernetes Cluster
========================================================

This document describes the design for the Acumos platform support of deploying
Acumos machine-learning models into private kubernetes (k8s) clusters, as simple
(single model) or composite (multi-model) solutions. This document is published
as part of the Acumos kubernetes-client repository. The private kubernetes
deployment capabilities and design are collectively referred to in this document
as the "private-k8s-deployment" feature.

-----
Scope
-----

"Private" as used here means a k8s cluster deployed in an environment (e.g.
VM(s) or bare metal machine(s)) for which the model user has ability to use the
kubectl CLI tool on the k8s cluster master ("k8s master") to manage apps in the
cluster. This is typically only available to users when they have deployed the
cluster for their own purposes, e.g. to develop/test k8s apps.

Other designs under the Acumos kubernetes-client repo will address deployment in
other k8s environments, e.g. public clouds, or using other more generic methods
that do not depend upon direct access to the k8s master node. There is expected
to be much in common across these designs, so this design is intended to provide
an initial baseline for direct reuse in other environments where possible.

Initially however, this design makes some simplifying assumptions/choices, which
over time can be relaxed or modified, to support other types of k8s environments
(e.g. other types of private and public k8s clusters, other host machines):

* deployment process split into two steps:

  * installation of a k8s cluster, as needed: a downloadable script is provided
    for this purpose, which the user must run prior to deploying the solution
  * user manual invocation of the deployment process on the k8s master, using a
    downloadable solution package including:

    * a deployment script which the user can run to start the deployment
    * a k8s template for the solution
    * a model blueprint file as created today by the Acumos Design Studio

* the k8s cluster is deployed (or will be) on a linux variant host OS. Ubuntu
  and Centos 7 will be specifically tested/supported.

............................
Previously Released Features
............................

This is the first release of the private-k8s-client.

........................
Current Release Features
........................

The private-k8s-deployment features planned for delivery in the current release
("Athena") are:

* a utility script (k8s-cluster.sh) enabling the user to prepare a k8s cluster
  that includes the prerequisites of the solution deployment process
* a templated deployment shell script (deploy.sh) that executes the deployment
  when invoked by the user on the k8s master
* a new Acumos platform component, the "k8s-client", that collects solution
  artifacts, creates a k8s template for the solution, and prepares a
  downloadable solution package as "solution.zip"

private-k8s-deployment depends upon these related features to be delivered in
the Athena release:

* Acumos portal-marketplace support for a new "deploy to private kubernetes"
  option for a solution
* A new Acumos component, the "docker-proxy", which provides a user's kubernetes
  cluster to pull docker images from an Acumos platform Nexus repository

------------
Architecture
------------

The following diagram illustrates the functional components, interfaces, and
interaction of the components for a typical private-k8s-deployment process:

.. image:: images/private-k8s-client-arch.png

A summary of the process steps:

#. At the Acumos platform, the user selects "deploy to private k8s cloud", and
   follows this optional procedure to setup a private k8s cluster

   * A: the user selects a link to "download a k8s cluster setup script"
   * B: the user saves the script on a host where the k8s cluster will be installed
   * C: the user executes the setup script and a k8s cluster is installed

#. The solution package is prepared and staged for deployment on the k8s master

   * A: the user selects a link to "download the solution and deployment script"
   * B: the portal-marketplace calls the /getSolutionZip API of the k8s-client
     service
   * C: the k8s-client calls the Solution Controller APIs of the
     common-data-service to obtain the URIs of the artifacts to be included
   * D: the k8s-client calls the Maven artifact API of nexus to retrieve the
     artifacts, prepares the solution package, and returns it to the
     portal-marketplace, which downloads it to the user's machine
   * E: the user uploads the downloaded solution package to the k8s master host
   * F: the user unpacks the package, which includes 

      * deploy.sh: deployment script
      * solution.yaml: k8s template for deploying the set of model microservices
        included in the solution, plus the Data Broker, Model Connector, and
        Probe services
      * databroker.json: Data Broker model data source to target mapping info
      * blueprint.json: solution blueprint as created by the Design Studio
      * a "microservice" subfolder, containing a subfolder named for each
        model microservice container in the solution, within which is the
        "model.proto" artifact for the microservice

#. The user kicks off the deployment, which runs automatically from this point

   * A: the user invokes deploy.sh, including parameters

     * the data source (file or URL) that the Data Broker should use
     * the user's credentials on the Acumos platform, as needed to authorize the
       user's docker client to pull solution microservice images during deployment

   * B: deploy.sh logs into the Acumos docker registry via the docker-proxy,
     using the provided user credentials
   * C: the docker-proxy calls the /api/auth/jwtToken API of the
     portal-marketplace to verify that the user is registered on the platform,
     and confirms login success to the docker client.
   * D: deploy.sh logs into the Acumos project docker registry, using the
     Acumos project credentials
   * E: deploy.sh copies the model.proto files for the solution to a host-shared
     folder where the probe service can access them, and initiates deployment of
     the solution via kubectl, using the solution.yaml template. kubectl deploys
     all the services defined in the template.
   * F: using the cached authentication for the Acumos docker registry and
     the Acumos project docker registry, k8s pulls the docker images for all
     solution microservices and Acumos project components, and deplpys them.
   * G: the docker-proxy validates the active login of the user, and pulls the
     requested image from the Acumos platform docker registry.
   * H: When the Data Broker service is active (determined by monitoring its
     status through kubectl), deploy.sh

     * copies the file containing the solution input data (if the user selected
       a file source) to a host folder mapped to a Data Broker container folder
     * invokes the Data Broker /configDB API to configure Data Broker with model
       data source to target mapping info using databroker.json, and the
       solution input data source

   * I: The Data Broker begins retrieving the solution input data, and waits for
     a /pullData API request from the Model Connector
   * J: When all of the microservices are active (determined by monitoring their
     status through kubectl), deploy.sh

     * retrieves the assigned ports from kubectl
     * creates a dockerinfo file with microservice name to IP/Port mapping info
     * invokes the Model Connector /putBlueprint API with blueprint.json
     * invokes the Model Connector /putDockerInfo API with the generated
       dockerinfo file

   * K: Once /putDockerInfo is processed by the Model Connector, it calls the
     Data Broker /pullData API to start retrieval of test/training data, and
     solution operation proceeds from there, with data being routed by the
     Model Connector through the microservice forwarding graph defined for the
     solution

.....................
Functional Components
.....................

The private-k8s-deployment feature will depend upon two new Acumoscomponent
microservices:

* kubernetes-client: packages solution artifacts and deployment tools into the
  "solution.zip" package
* docker-proxy: provides an authentication proxy for the platform docker repo

Other Acumos component dependencies, with related impacts in this release:

* portal-marketplace: provides the user with a download link to the
  "setup_k8s.sh" script, and a "deploy to private kubernetes" dialog that allows
  the user to download the solution.zip package

Other Acumos component dependencies, used as-is:

* common-data-svc: provides information about solution artifacts to be retrieved
* nexus: provides access to the maven artifact repository
* docker repository: as provided by the Acumos nexus service or another docker
  repository service, provides access to the microservice docker images as
  they are deployed by the k8s cluster

Other dependencies:

* a kubernetes cluster, deployed via the "setup_k8s.sh" script, or otherwise

..........
Interfaces
..........

************
Exposed APIs
************

+++++++++++++++++
Solution Download
+++++++++++++++++

The k8s-client service exposes the following API for the portal-marketplace to
obtain a downloadable package of solution artifacts and deployment script,
for a specific solution revision.

The base URL for this API is: http://<k8s-client-service-host>:<port>, where
'k8s-client-service-host' is the routable address of the verification service
in the Acumos platform deployment, and port is the assigned port where the
service is listening for API requests.

* URL resource: /getSolutionZip/{solutionId}/{revisionId}

  * {solutionId}: ID of a solution present in the CDS 
  * {revisionId}: ID of a version for a solution present in the CDS 

* Supported HTTP operations

  * GET

    * Response

      * 200 OK

        * meaning: request successful
        * body: solution package (solution.zip)

      * 404 NOT FOUND

        * meaning: solution/revision not found, details in JSON body. NOTE: this
          response is only expected in race conditions, e.g. in which a deploy
          request was initiated when at the same time, the solution was deleted
          by another user
        * body: JSON object as below

          * status: "invalid solutionId"|"invalid revisionId"

++++++++++++
Docker Login
++++++++++++

The Acumos platform docker-proxy will expose the docker login API.

+++++++++++
Docker Pull
+++++++++++

The Acumos platform docker-proxy will expose the docker pull API.

*************
Consumed APIs
*************

++++++++++++
Docker Login
++++++++++++

Via the local docker CLI client on the host machine, deploy.sh will call the
login API of:

* the Acumos platform docker-proxy, to verify that the user is authorized to
  access docker images in the Acumos platform docker registry
* the Acumos project Nexus docker API, to enable pull of the Acumos project
  docker images to be deployed as part of the solution

+++++++++++
Docker Pull
+++++++++++

Via the local docker CLI client on the host machine, kubectl will call the
docker pull API of:

* the Acumos platform docker-proxy, to pull the model microservice images to be
  deployed as part of the solution
* the Acumos project Nexus docker API, to pull the Acumos project docker images
  to be deployed as part of the solution

++++++++++++++++++++++++++
Portal User Authentication
++++++++++++++++++++++++++

The docker-proxy service will call the portal-marketplace /api/auth/jwtToken API
to verify that the user running the deploy.sh script is an actual registered
user of the Acumos platform, thus is allowed to access docker images from the
docker registry configured for the Acumos platform.

+++++++++++++++++++
Solution Controller
+++++++++++++++++++

The k8s-client service will call the Solution Controller APIs of the
common-data-svc to obtain the following solution/revision-related data:

* nexus URI of the model.proto artifact
* nexus URI of the blueprint.json artifact (if any)


----------------
Component Design
----------------

..........
k8s-client
..........

To be provided.

............
docker-proxy
............

To be provided.

..............
k8s_cluster.sh
..............

To be provided.

.........
deploy.sh
.........

To be provided.