variable "vpc_name" {
  type    = string
  default = "empDirVPC"
}
variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "private_subnets" {
  default = {
    "my_private_subnet_1" = 3
    "my_private_subnet_2" = 4
  }
}

variable "public_subnets" {
  default = {
    "my_public_subnet_1" = 1
    "my_public_subnet_2" = 2
  }
}
