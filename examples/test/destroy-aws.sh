#!/usr/bin/env bash
AWS_NUKE_VERSION=v3.61.0
# reference: https://github.com/GlueOps/scripts-teardown-aws-amazon-web-services
echo "Preform an AWS Cleanup with AWS Nuke"
wget https://github.com/ekristen/aws-nuke/releases/download/$AWS_NUKE_VERSION/aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz && tar -xvf aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz && rm aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz
# --no-alias-check skips the "account has no alias" safety guard; the account
# must also be listed under bypass-alias-check-accounts in nuke.yaml.
./aws-nuke nuke -c nuke.yaml --max-wait-retries 200 --no-dry-run --force --no-alias-check --log-full-timestamp true