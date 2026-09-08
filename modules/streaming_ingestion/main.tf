resource "aws_kinesis_stream" "sensor_stream" {
  name             = "${var.project_name}-iot-stream-${var.environment}"
  shard_count      = var.environment == "prod" ? 2 : 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  encryption_type = "KMS"
  kms_key_id      = "alias/aws/kinesis"
}
