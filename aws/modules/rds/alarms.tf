locals {
  alarms_enabled = length(var.alarm_sns_topic_arns) > 0
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${var.identifier}-RDS-High-CPU-Utilization"
  alarm_description   = "CPU utilization on ${var.identifier} is above ${var.alarm_high_cpu_threshold}%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alarm_high_cpu_threshold
  period              = 300
  evaluation_periods  = 6
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  dimensions = {
    DBInstanceIdentifier = aws_db_instance._.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "low_memory" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${var.identifier}-RDS-Low-Freeable-Memory"
  alarm_description   = "Freeable memory on ${var.identifier} is below ${var.alarm_low_memory_threshold_bytes} bytes"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.alarm_low_memory_threshold_bytes
  period              = 300
  evaluation_periods  = 6
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  dimensions = {
    DBInstanceIdentifier = aws_db_instance._.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "low_storage" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${var.identifier}-RDS-Low-Free-Storage-Space"
  alarm_description   = "Free storage on ${var.identifier} is below ${var.alarm_low_storage_threshold_bytes} bytes"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.alarm_low_storage_threshold_bytes
  period              = 300
  evaluation_periods  = 5
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  dimensions = {
    DBInstanceIdentifier = aws_db_instance._.identifier
  }

  tags = var.tags
}
