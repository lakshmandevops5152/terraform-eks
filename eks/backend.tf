terraform {
  backend "s3" {
    bucket = "lakshman-trraform"
    key    = "eks/terraform.tfstate"
    region = "ap-south-1"
  }
}
