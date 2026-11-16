terraform {
  backend "s3" {
    key          = "production/production.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}