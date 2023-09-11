terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.14.0"
    }
    /*local = {
      source = "hashicorp/local"
      version = "2.4.0"
    }*/
  }

}
provider "aws" {
  region = "us-east-1"
}