# ---------------------------------------------------------------------------------------------------------------------
# The following variables define how final snapshots are handled.
# ---------------------------------------------------------------------------------------------------------------------

variable "first_run" {
  description = "(Required) Should always be set to 'true' the first time a database is created.  If true, assumes that there is no backup to restore.  After the first run, can be set to false."
}

variable "instance_identifier" {
  description = "(Required) Unique Database Instance identifier.  IMPORTANT: This cannot be randomly generated, since to restore a snapshot you need to know the instance identifier!"
}

# OPTIONAL PARAMETERS
variable "first_run_snapshot_identifier" {
  default=""
  description="(Optional) Only used on the first run, when a database is created for the first time.  If present, the database will be restored from this snapshot.  On all subsequent database creations, the last 'final snapshot' will be used to restore the database regardless of the value of this variable."
}

variable "number_of_snapshots_to_retain" {
  default=1
  description = "(Optional) Number of final snapshots to retain after restoration.  Minimum 0.  Can be set to the string 'ALL' in which case snapshots are never deleted.  Default: 1"
}

# ---------------------------------------------------------------------------------------------------------------------
# The following variables define a simple RDS Database Instance, mainly for demonstration purposes
# ---------------------------------------------------------------------------------------------------------------------

variable "username" {
  default=""
  description="(Required unless a snapshot_identifier is provided) Username for the master DB user."
}

variable "password" {
  default=""
  description="(Required unless a snapshot_identifier is provided) Password for the master DB user. Note that this may show up in logs, and it will be stored in the state file."
}

variable "allocated_storage" {
  default=""
  description="(Required unless a snapshot_identifier is provided) The allocated storage in gigabytes."
}

# OPTIONAL PARAMETERS
variable "database_name" {
  default=""
  description="(Optional) The name of the database to create when the DB instance is created. If this parameter is not specified, no database is created in the DB instance."
}

variable "instance_class" {
  default="db.t2.micro"
  description="(Optional) The instance type of the RDS instance. Defaults to 'db.t2.micro'"
}
