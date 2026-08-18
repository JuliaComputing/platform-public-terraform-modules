output "controller_role_arn" {
  description = "ARN of the Karpenter controller IRSA role. Set this on the controller service account via the chart's serviceAccount.annotations."
  value       = aws_iam_role.controller.arn
}

output "controller_role_name" {
  description = "Name of the Karpenter controller IRSA role"
  value       = aws_iam_role.controller.name
}

output "node_role_arn" {
  description = "ARN of the role Karpenter-provisioned nodes assume. Pass this to the eks module's additional_node_role_arns and the efs module's restrict_mount_to_role_arns, or nodes cannot join and job pods cannot mount."
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the Karpenter node role. Goes in the EC2NodeClass role field."
  value       = aws_iam_role.node.name
}

output "node_instance_profile_name" {
  description = "Name of the node instance profile"
  value       = aws_iam_instance_profile.node.name
}

output "interruption_queue_name" {
  description = "Name of the interruption queue, or null when it is not created. Set this as the chart's settings.interruptionQueue value."
  value       = one(aws_sqs_queue.interruption[*].name)
}

output "interruption_queue_arn" {
  description = "ARN of the interruption queue, or null when it is not created"
  value       = one(aws_sqs_queue.interruption[*].arn)
}
