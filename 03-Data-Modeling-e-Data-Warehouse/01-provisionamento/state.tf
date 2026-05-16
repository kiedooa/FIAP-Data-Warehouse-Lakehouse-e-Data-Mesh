terraform {
  backend "s3" {
    key     = "03-data-warehouse/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
