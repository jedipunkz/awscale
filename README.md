AWScale
====

Overview
----

AWScale is prototype service for deploying web hosting to AWS. This prototype
includes that such technologies.

* Fog : Cloud Library Software
* Chef : Configuration management Software
* AWS : Cloud Platform

Author
----

    Tomokazu HIRAI @jedipunkz


Architecture
----

                                                                               +----------------+
                                                                               |     chef       | +----------------+
    +-------------+ +-------------+                                            |     mysql      | |     chef       |
    |    mysql    | |    mysql    |                                            |      fog       | |     mysql      |
    +-------------+ +-------------+                                            |    sinatra     | |      fog       |
    |   apache2   | |   apache2   |                                            +----------------+ +----------------+
    +-------------+ +-------------+      +----------------+ +----------------+ | awscale-api.rb |>| awscale-mng.rb |--+----+
    | sensu-agent | | sensu-agent |----->|  sensu-server  | |  chef-server   | +----------------+ +----------------+  |    |
    +-------------+ +-------------+      +----------------+ +----------------+ +-----------------------------------+  |    |
    | vm instance | | vm instance | ...> |  vm instance   | |  vm instance   | |            vm instance            |  |    |
    +-------------+ +-------------+      +----------------+ +----------------+ +-----------------------------------+  +    |
    +--------------------------------------------------------------------------------------------------------------+-----+ |
    |                                              AWS Platform  VPC                                               | API | |
    +--------------------------------------------------------------------------------------------------------------+-----+ |
    +-----------------------------+-----+                                                                                  |
    |    Elastic Loadbalancer     | API |<---------------------------------------------------------------------------------+
    +-----------------------------+-----+

Flow
----

#### flow before bootstrap the chef

* 1) request the API for deploying instance(s) which minimum set.
* 2) awscale-api.rb program make minimum set via AWS VPC/ELB APIs
* 3) awscale-api.rb program bootstrap the chef to these instances

#### Lead-up from stable

* 4) awscale-mng.rb program checks the HTTP status to that HTTP cluster
* 5) if status is not healthy, awscale-mng.rb boot more instance via VPC API
* 6) awscale-mng.rb program bootstrap the chef to that instance

#### Stability from lead-up

* 7) awscale-mng.rb program check the HTTP status
* 8) if status is helathy, awscale-mng.rb delete some instance(s) via VPC API
* 9) and awscale-mng.rb deregister the instance(s) from that ELB via ELB API

APIs
====

Bootstrap
----

#### Bootstrap Minimum HTTP Cluster

    POST /bootstrap -X POST -d
    {
        "flavor_id": "t1.micro",
        "key_name": "test02",
        "secgroup": "awscale-test",
        "ami": "ami-bddaa2bc",
        "group_name": "fuzzbuzzz-group",
        "instance_name": "fuzzbuzzzz",
        "count": "1"
    }

Responce

    ['i-6504f97a']

#### Destroy HTTP Cluster

    POST /destroy_cluster -X POST -d
    {
        "group_name": "foo-group"
    }

Instances
----

#### List Instances

    GET /instances/json

Responce

    [
      [
        "foo0",
        {
          "updated_date": "2014-05-30-15:06:29",
          "created_date": "2014-05-30-15:06:29",
          "status": "up",
          "elb_name": "foo-group",
          "group_name": "foo-group",
          "instance_type": "t1.micro",
          "id": 6,
          "instance_id": "i-cfdd90c9",
          "name": "foo0",
          "private_dns_name": "ip-172-31-4-204.ap-northeast-1.compute.internal",
          "public_dns_name": "ec2-54-238-213-199.ap-northeast-1.compute.amazonaws.com",
          "az": "ap-northeast-1a",
          "security_group": "awscale-test",
          "ami": "ami-bddaa2bc"
        }
      ]
    ]

#### Destroy Instance and Deregister from the ELB

    POST /instances/destroy -X POST -d
    {
        "insntace_id": "<instance_id>"
    }

Responce

    ['i-6504f97a']

#### Stop Instance

    POST /instances/stop -X POST -d
    {
        "instance_id": "<instance_id>"
    }

Responce

    ['i-6504f97a']

#### Start Instance

    POST /instances/start -X POST -d
    {
        "instance_id": "<instance_id>"
    }

Responce

    ['i-6504f97a']

#### Get Instance's Name

    GET /instances/:instance_id/name

Responce

    "foobar"

#### Get Instance's Private DNS Name

    GET /instances/:instance_id/private_dns_name

Responce

    ip-172-31-1-141.ap-northeast-1.compute.internal

#### Get Instance's Public DNS Name

    GET /instances/:instance_id/public_dns_name

Responce

    ec2-54-199-223-15.ap-northeast-1.compute.amazonaws.com

#### Get Instance's Availability Zone Name

    GET /instances/:instance_id/az

Responce

    ap-northeast-1a

#### Get Instance's Security Group Name

    GET /instances/:instance_id/security_group

Responce

    awscale-test

#### Get Instance's AMI Name

    GET /instances/:instance_id/ami

Responce

    ami-bddaa2bc

#### Get Instance's Flavor

    GET /instances/:instance_id/instance_type

Responce

    t1.micro

#### Get Instance's Group Name

    GET /instances/:instance_id/group_name

Responce

    foofoo-group

#### Get Instance's ELB Name

    GET /instances/:instance_id/elb_name

Responce

    foofoo-group

#### Get Instance's Status

    GET /instances/:instance_id/status

Responce

    up

#### Get Instance's Created Time Stamp

    GET /instance/:instance_id/created_date

Responce

    2014-05-28-16:49:15

#### Get Instance's Updated Time Stamp

    GET /instance/:instance_id/updated_date

Responce

    2014-05-28-16:49:15

Cluster_Members
----

#### Get Cluster Members

    GET /cluster_members/:group_name/json

Responce

    [
      [
        "bar0",
        {
          "updated_date": "2014-05-30-17:23:07",
          "created_date": "2014-05-30-17:23:07",
          "status": "up",
          "elb_name": "bar-group",
          "group_name": "bar-group",
          "instance_type": "t1.micro",
          "id": 8,
          "instance_id": "i-03e5a805",
          "name": "bar0",
          "private_dns_name": "ip-172-31-15-47.ap-northeast-1.compute.internal",
          "public_dns_name": "ec2-54-178-230-169.ap-northeast-1.compute.amazonaws.com",
          "az": "ap-northeast-1a",
          "security_group": "awscale-test",
          "ami": "ami-bddaa2bc"
        }
      ],
    ]

Counter
----

#### Get Counter Information

    GET /counter/json

Responce

    [
      [
        "foo-group",
        {
          "updated_date": "2014-05-30-15:06:29",
          "created_date": "2014-05-30-15:06:29",
          "basic_count": 3,
          "count": 2,
          "elb_dns_name": "foo-group-1829502593.ap-northeast-1.elb.amazonaws.com",
          "group_name": "foo-group",
          "id": 5
        }
      ]
    ]

VirtualHost
----

#### Input VirtualHost via Chef DataBags

    POST /databags -d

    '{
      "id": "barbar",
      "vhosts": {
        "test01": {
          "apache2": {
            "name": "test01.cpi.ad.jp",
            "aliases": [
              "test01.jam.cpi.ad.jp"
            ],
            "domain": "cpi.ad.jp",
            "environment": "production"
          },
          "db": {
            "dbname": "wp-test01",
            "dbuser": "test01",
            "dbpass": "test01"
          },
          "wordpress": {
            "wp_trig": true
          }
        }
      }
    }'

Responce

    ['barbar']
