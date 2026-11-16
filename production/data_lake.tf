resource "aws_s3_bucket" "example" {
  bucket = "group-21-production-data-ingestion"

  tags = {
    Name        = "group_21_production_data_ingestion"
    Group       = "21"
    Team        = "Data Engineering Team"
    Environment = "Production"
    Service     = "Airflow"
    Project     = "CDE Data Infrastructure"
  }
}
