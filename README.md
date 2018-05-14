AWS RDS Final Snapshot Management Module
========================================

> ###### IMPORTANT
> The first time this configuration is applied the `first_run` variable passed to the modules must be `true`.
>
> All subsequent applies should have `first_run` set to false or ommitted (as false is default).

This module, or specifically the two submodules `snapshot_identifiers` and `snapshot_maintenance` will manage 
Final Snapshots of AWS database instances and clusters to ensure that infrastructure can be backed up, destroyed, 
and restored.

It will retain the last `number_of_snapshots_to_retain`.  If the number to retain is 'ALL' then no snapshots will be 
deleted.

The primary purpose of the modules is to allow for destruction of a database, such that it will capture a final 
snapshot and then restore it when later recreated.  

The use case is for development and testing environments which should not be running 24/7 (eg. to save money, or reduce
risk).  Perhaps a project is only developed infrequently; or perhaps you only want development to run 9-5 Mon-Fri.

This module restores a database which was previously destroyed.

> ###### WARNING
> Destroying infrastructure is by its nature destructive - when developing an environment,
> take plenty of manual backups until you have tested your infrastructure code! 

This module can be used from the command-line and can also be used within a CI environment, but there is one manual
step.  The very first time the database is created, the "first_run" variable must be set to true.  On all other runs,
it should be set to false.

This can be handled as follows,

    # First run
    terraform apply -var first_run=true
    
    # Subsequent runs: (warning, wait 3 minutes before destroying) 
    terraform destroy
    terraform apply
    terraform destroy
    terraform apply

Please read all of the README if using or maintaining this module.

The Root module should be used primarily for testing or evaluation.  It will create a usable RDS
database instance, but does not have the full flexibility that a database module such as 
"terraform-aws-modules/aws/rds".

The Root module calls these modules which can (and should) be used separately to create independent resources:
                
* [rds_snapshot_identifiers](https://github.com/connect-group/terraform-aws-rds-finalsnapshot/tree/master/modules/rds_snapshot_identifiers) - calculates Snapshot identifiers
* [rds_snapshot_maintenance](https://github.com/connect-group/terraform-aws-rds-finalsnapshot/tree/master/modules/rds_snapshot_maintenance) - deletes old Snapshots

> ###### IMPORTANT
> When using the child modules directly, both of them must be used, even if you do not want to delete old snapshots.  
> The second module handles some state information which must be implemented after the database instance or cluster 
> is created.

Usage With 'Built-In' Simple MySQL Instance
-------------------------------------------
```hcl
module "db_with_final_snapshot_management" {
  source = "connect-group/rds/aws"

  first_run = "{$var.first_run}"

  instance_identifier = "demodb"
  instance_class      = "db.t2.micro"
  allocated_storage   = 5

  database_name     = "demodb"
  username          = "user"
  password          = "AVerySecureInitialPasswordPerhapsChangeItManually"

  number_of_snapshots_to_retain = 0
}
```


Usage With Official Terraform RDS Module
----------------------------------------
```hcl
module "snapshot_identifiers" {
  source = "connect-group/rds/aws//modules/rds_snapshot_identifiers"

  first_run="${var.first_run}"
  identifier="demodb"
}

module "snapshot_maintenance" {
  source="connect-group/rds/aws//modules/rds_snapshot_maintenance"

  final_snapshot_identifier="${module.snapshot_identifiers.final_snapshot_identifier}"
  is_cluster=false
  identifier="${module.snapshot_identifiers.identifier}"
  database_endpoint="${module.db.this_db_instance_endpoint}"
  number_of_snapshots_to_retain = 1
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${module.snapshot_identifiers.identifier}"

  engine            = "mysql"
  engine_version    = "5.7.19"
  instance_class    = "db.t2.large"
  allocated_storage = 5

  name     = "demodb"
  username = "user"
  password = "YourPwdShouldBeLongAndSecure!"
  port     = "3306"

  vpc_security_group_ids = ["sg-12345678"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # DB subnet group
  subnet_ids = ["subnet-12345678", "subnet-87654321"]

  # DB parameter group
  family = "mysql5.7"

  # Snapshot names managed by module
  snapshot_identifier = "${module.snapshot_identifiers.snapshot_to_restore}"
  final_snapshot_identifier = "${module.snapshot_identifiers.final_snapshot_identifier}"
  skip_final_snapshot = "false"
}
```

Usage With Aurora Cluster
-------------------------
```hcl
module "snapshot_identifiers" {
  source = "connect-group/rds/aws//modules/rds_snapshot_identifiers"

  first_run="${var.first_run}"
  identifier="democluster"
}

module "snapshot_maintenance" {
  source="connect-group/rds/aws//modules/rds_snapshot_maintenance"

  final_snapshot_identifier="${module.snapshot_identifiers.final_snapshot_identifier}"
  is_cluster=true
  identifier="${module.db.this_db_instance_id}"
  database_endpoint="${module.db.this_db_instance_endpoint}"
  number_of_snapshots_to_retain = 1
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = 2
  identifier         = "aurora-cluster-demo-${count.index}"
  cluster_identifier = "${aws_rds_cluster.aurora.id}"
  instance_class     = "db.r3.large"
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${module.snapshot_identifiers.identifier}"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  database_name      = "demodb"
  master_username    = "user"
  master_password    = "AnInsanelyDifficultToGuessPasswordWhichShouldBeChanged"
}
```

Examples
--------

* [Complete RDS example for MySQL](https://github.com/connect-group/terraform-aws-rds-finalsnapshot/tree/master/examples/example-with-rds-module)
* [Complete Aurora example](https://github.com/connect-group/terraform-aws-rds-finalsnapshot/tree/master/examples/example-with-aurora)

Terraform Version
-----------------
This module requires >=0.10.4 because it uses 'Local Values' bug fixed in 0.10.4 and the `timeadd` function from 
version 0.11.2.

How does it work? (Under the hood)
----------------------------------
This module creates a Lambda function which will run just once, after the database is created.  It is triggered by a 
Cloudwatch scheduled event which will run just once, within 3 minutes of creation.

This is required because Terraform data sources fail if a data source returns 0 results.  But after a destroy there
can be no managed Terraform resources; hence, the Lambda maintains an SSM Parameter which is not managed by Terraform.

AWS RDS maintains the final snapshot, which is not managed by Terraform; but on 'first run', and until the database is
destroyed for the first time, that snapshot will not exist: so again, a data source cannot be used as it would cause
Terraform to fail. 

Authors
-------
Currently maintained by [these awesome contributors](https://github.com/connect-group/terraform-aws-rds-finalsnapshot/graphs/contributors).
Module managed by [Adam Perry](https://github.com/4dz) and [Connect Group](https://github.com/connect-group)

License
-------
Apache 2 Licensed. See LICENSE for full details.