provider "aws" {
    region = "us-east-1"
}

variable "token" {
    description = "GitHub API access token"
}

resource "aws_lambda_function" "r-netsec" {
    function_name = "r-netsec"
    filename = "function/build/build.zip"
    source_code_hash = "${filebase64sha256("function/build/build.zip")}"
    role = "${aws_iam_role.r-netsec.arn}"
    handler = "main.handler"
    runtime = "python3.7"
    timeout = "5"
    environment {
        variables = {
            GH_USERNAME = "r-netsec"
            GH_PASSWORD = "${var.token}"
        }
    }
}

resource "aws_cloudwatch_event_rule" "netsec-schedule" {
    name = "netsec-schedule"
    description = "Fire periodically to trigger r-netsec"
    schedule_expression = "rate(30 minutes)"
}

resource "aws_cloudwatch_event_target" "cw-target" {
    rule = "${aws_cloudwatch_event_rule.netsec-schedule.name}"
    target_id = "r-netsec"
    arn = "${aws_lambda_function.r-netsec.arn}"
}

resource "aws_iam_role" "r-netsec" {
    name = "r-netsec"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "CloudWatchPublish" {
    policy =<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:*"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "publish-attach" {
    name = "CloudWatchPublish"
    roles = ["${aws_iam_role.r-netsec.name}"]
    policy_arn = "${aws_iam_policy.CloudWatchPublish.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.r-netsec.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.netsec-schedule.arn}"
}