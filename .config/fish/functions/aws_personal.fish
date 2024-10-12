#=== GLOBAL VALUES ===#
set editor "code"
set aws_acct "123"
set aws_region "us-east-2"

# MARK: CDK
function cds -d "Synthesize a CDK stack using FZF" --argument-names stack
  set -q stack[1] || set stack (cdk ls | awk '{print $1}' | fzf --height 15% --layout=reverse --prompt="Select a stack to synthesize: ")
  set env (echo $stack | awk -F'-' '{print $2}')
  set stack_type (string match -q -i "*svc" $stack && echo "stack" || echo "pipeline")

  if test -z "$stack"
	echo "no stack selected" && return 1
  end

  echo "synthesizing $env $stack into $stack_type-$env.yml"
  cdk synth $stack > $stack_type-$env.yml
end

function cdd -d "Deploy a CDK stack using FZF" --argument-names stack
  set -q stack[1] || set stack (cdk ls | awk '{print $1}' | fzf --height 15% --layout=reverse --prompt="Select a stack to deploy: ")

  if test -z "$stack"
	echo "no stack selected" && return 1
  end

  cdk deploy $stack
end



# MARK: AWS CLI
function aws_sp -d "Switch active AWS cli profile using FZF"
  set aws_profile (aws configure list-profiles | fzf --height 5% --layout=reverse)

  set -Ux AWS_PROFILE $aws_profile
  set -Ux AWS_DEFAULT_PROFILE $aws_profile

  echo "Switched to AWS profile: $aws_profile"
end

function update_log_group_retention -d "Update the retention period for a CloudWatch log group"
  set group_json_file (bat "$HOME/projects/log-group-retention.json" | jq -r '.[] | @json')

  for group in $group_json_file
	set group_name (echo $group | jq -r .name)
	set existing_retain (echo $group | jq -r .retain)
	switch $group_name
	case "/ecs/tw-api-prod"
  	set retain_period 120
	case "*test*" "*tst*" "*qa*" "*staging*" "*stg*"
  	set retain_period 30
	case "*"
  	set retain_period 90
	end
	if test "$existing_retain" != "null"
  	# echo "OLD: $existing_retain - $group_name"
  	continue
	end
	echo "setting policy: $retain_period days for $group_name"
	aws logs put-retention-policy --log-group-name $group_name --retention-in-days $retain_period
  end
end

function full_search -d "Search Secrets Manager, ECS task definitions, and lambda environments for arbitrary values" --argument-names needle
  if test -z "$needle"
	echo "you didn't provide a search term!"
	return 1
  end
  # takes ~5 mins to run in total atm
  echo -e "\033[91;1mSearching through Secrets Manager secrets...\033[0m" # ~20 seconds
  secret_search $needle
  echo -e "\033[91;1mSearching through ParamStore params...\033[0m" # ~2 mins
  param_search $needle
  echo -e "\033[91;1mSearching through ECS task definitions...\033[0m" # ~1.5 mins
  ecs_task_env_search $needle
  echo -e "\033[91;1mSearching through lambda environment values...\033[0m" # ~40 seconds
  lambda_env_search $needle
end

function ecs_task_envs -d "Snag a list of all env vars across all running task definitions"
  set clusters (aws ecs list-clusters --query clusterArns | jq -r .[])
  for cluster in $clusters
	set tasks (aws ecs list-tasks --cluster $cluster --desired-status RUNNING --query taskArns | jq -r .[])
	if test -z "$tasks"
  	continue
	end
	for container in (aws ecs describe-tasks --cluster $cluster --tasks $tasks --query "tasks[].taskDefinitionArn" | jq -r .[])
  	set container_details (aws ecs describe-task-definition --task-definition $container)
  	set container_name (echo $container_details | jq -r '.taskDefinition.containerDefinitions[].name')
  	set container_envs (echo $container_details | jq -r '.taskDefinition.containerDefinitions[].environment')
  	set container_secrets (echo $container_details | jq -r '.taskDefinition.containerDefinitions[].secrets')
  	if test "$container_envs" != "null" -a "$container_envs" != "[]"
    	echo -e "\033[1m$container_name envs\033[0m:"
    	echo $container_envs | jq .[]
  	end
  	if test "$container_secrets" != "null" -a "$container_secrets" != "[]"
    	echo -e "\033[1m$container_name secrets\033[0m:"
    	echo $container_secrets | jq .[]
  	end
	end
  end
end

function ecs_task_env_search -d "Snag a list of all env vars across all running task definitions" --argument-names needle
  set clusters (aws ecs list-clusters --query clusterArns | jq -r .[])
  for cluster in $clusters
	set tasks (aws ecs list-tasks --cluster $cluster --desired-status RUNNING --query taskArns | jq -r .[])
	if test -z "$tasks"
  	continue
	end
	for task in (aws ecs describe-tasks --cluster $cluster --tasks $tasks --query "tasks[].taskDefinitionArn" | jq -r .[])
  	for container in (aws ecs describe-task-definition --task-definition $task --query "taskDefinition.containerDefinitions[].{name: name, envs: environment, secrets: secrets}" | jq -r '.[] | @json')
    	set container_name (echo $container | jq -r .name)
    	set container_envs (echo $container | jq .envs)
    	set container_secrets (echo $container | jq .secrets)
    	if test "$container_envs" != "null" -a "$container_envs" != "[]"
      	if string match -q -i "*$needle*" $container_envs
        	set matched_key_val (echo $container_envs | jq -r --arg needle $needle '.[] | select((.name | ascii_downcase | test($needle)) or (.value | tostring | ascii_downcase | test($needle)))')
        	echo -e "\033[1m$container_name envs\033[0m:"
        	echo $matched_key_val | jq .
      	end
    	end
    	if test "$container_secrets" != "null" -a "$container_secrets" != "[]"
      	if string match -q -i "*$needle*" $container_secrets
        	echo -e "\033[1m$container_name secrets\033[0m:"
        	set matched_key_val (echo $container_secrets | jq -r --arg needle $needle '.[] | select((.name | ascii_downcase | test($needle)) or (.valueFrom | tostring | ascii_downcase | test($needle)))')
        	echo $matched_key_val | jq .
      	end
    	end
  	end
	end
  end
end

function param_search -d "Search SSM parameters for a given string" --argument-names needle
  if test -z "$needle"
	echo "you didn't provide a search term!"
	return 1
  end
  set params (aws ssm describe-parameters --query "Parameters[].Name" | jq -r .[])

  for param in $params
	set param_data (aws ssm get-parameter --name $param --with-decryption --query "Parameter.[Name, Value]")
	set param_name (echo $param_data | jq -r .[0])
	set param_val (echo $param_data | jq -r .[1])
	if string match -q -i "*$needle*" $param_data
  	# perform a jq search for the search term, then print the key/value pair that contains it
  	echo -e "\033[1m$param_name\033[0m:"
  	echo -e \t$param_val
	end
  end
end

# awscli function that lists all services in all clusters
function ecs_services -d "List all services in all ECS clusters"
  set clusters (aws ecs list-clusters --query clusterArns | jq -r .[] | sort)

  for cluster in $clusters
	set cluster_name (string split '/' $cluster -r -m1 -f2)
	# echo - $cluster_name
	set services (aws ecs list-services --cluster $cluster --query "serviceArns[*]" | jq -r .[] | sort)

	for service in $services
  	set service_name (string split '/' $service -r -m1 -f2)
  	# echo \U221F $service_name # nicer formatting
  	echo "$cluster_name: $service_name"
	end
  end
end

function sqs_queues -d "List all SQS queues"
  aws sqs list-queues --query "QueueUrls[]" | \
	jq -r '.[] | split("/") | .[-1] | split(".") | "\(.[0]): \(.[1])"' | sort
end

function rds_instances -d "List all RDS instances"
  aws rds describe-db-instances --query "DBInstances[].{Name: DBInstanceIdentifier, Engine: Engine}" | \
	jq -r '.[] | "\(.Name): \(.Engine)"' | sort
end

function ec2_instances -d "List all EC2 instances in all regions"
  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].{Name: Tags[?Key=='Name'] | [0].Value, InstanceId: InstanceId}" | \
	jq -r '.[] | "\(.Name): \(.InstanceId)"' | sort
end

# note: ultimately useless, only needed to allow 0.0.0.0/0 for the QA domain to be verified, then closed it back down. Fun exercise though.
function stripe_ips -d "Retrieve Stripe IP list and create security groups for them in batches"
  # gather data to build IP lists and determine how many security groups we'll need
  set ips (curl https://stripe.com/files/ips/ips_api.txt)
  set total_ips (count $ips)
  set quota (aws service-quotas get-service-quota --service-code vpc --quota-code L-0EA8095F --query "Quota.Value")
  set group_count (math ceil $total_ips / $quota)

  for idx in (seq 1 $group_count)
	set group_name "stripe-api-ips-$idx"

	# deal with annoying 1-based array indexing
	if test $idx -eq 1
  	set batch_start 1
	else
  	set batch_start (math $idx \* $quota - $quota)
	end

	# avoid making extra API calls if we're on the last batch
	if test $idx -eq $group_count
  	set batch_end $total_ips
	else
  	set batch_end (math $idx \* $quota - 1)
	end

	# move on if security group already exists, else create it (this doesn't work for some reason, it just errors and then creates the groups and ends the script)
	aws ec2 create-security-group --group-name $group_name --description "Stripe API IPs batch $idx"

	# add Stripe IPs to security groups in batches
	for ip in $ips[$batch_start..$batch_end]
  	aws ec2 authorize-security-group-ingress --group-name $group_name --protocol tcp --port 443 --cidr "$ip/32"
	end
  end
end

function stripe_webhook_ips -d "Create a security group with all Stripe webhook IPs whitelisted"
  # gather data to build IP lists and determine how many security groups we'll need
  set ips (curl https://stripe.com/files/ips/ips_webhooks.txt)
  set total_ips (count $ips)
  set quota (aws service-quotas get-service-quota --service-code vpc --quota-code L-0EA8095F --query "Quota.Value")
  set group_count (math ceil $total_ips / $quota)

  for idx in (seq 1 $group_count)
	set group_name "stripe-webhook-ips-$idx"

	# deal with annoying 1-based array indexing
	if test $idx -eq 1
  	set batch_start 1
	else
  	set batch_start (math $idx \* $quota - $quota)
	end

	# avoid making extra API calls if we're on the last batch
	if test $idx -eq $group_count
  	set batch_end $total_ips
	else
  	set batch_end (math $idx \* $quota - 1)
	end

	aws ec2 create-security-group \
	--group-name $group_name \
	--description "Stripe API IPs batch $idx" \
	--tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value="Stripe webhook IPs"},{Key=Environment,Value=production},{Key=Service,Value=stripe}]'

	# add Stripe IPs to security groups in batches
	for ip in $ips[$batch_start..$batch_end]
  	aws ec2 authorize-security-group-ingress --group-name $group_name --protocol tcp --port 443 --cidr "$ip/32"
	end
  end
end

# aws cli function to retrieve list of all lambda function names
function lambda_names -d "List all lambda function names"
  aws lambda list-functions  --no-paginate --region $aws_region --query "Functions[].FunctionName" --output yaml | sort
end

function lambda_envs -d "Audit of all environment variables used by our lambdas"
  # grab a list of all stored sekrit ARNs
  set list (aws lambda list-functions  --no-paginate --region $aws_region --query "Functions[].FunctionName" | jq -r .[] | sort)
  # loop through the list of ARNs, checking each item's env vars for the search term
  for entry in $list
	set entry_data (aws lambda get-function-configuration --function-name $entry --query "[FunctionName, Environment]")
	set entry_name (echo $entry_data | jq -r .[0])
	set entry_val (echo $entry_data | jq -r .[1].Variables)
	# only print the entry's name/value if the value is not "null"
	if test "$entry_val" != "null"
  	echo -e "\033[1m$entry_name\033[0m:"
  	echo $entry_val | jq
  	echo -e \n
	end
  end
end

function lambda_env_search -d "Find any running ECS task definitions with env vars or secrets containing var values containing the search term" --argument-names needle
  # do nothing if no arg/search term is provided
  if test -z "$needle"
	echo "you didn't provide a search term!"
	return 1
  end
  # grab a list of all stored sekrit ARNs
  set list (aws lambda list-functions  --no-paginate --region $aws_region --query "Functions[].FunctionName" | jq -r .[] | sort)
  # loop through the list of ARNs, checking each item's env vars for the search term
  for entry in $list
	set entry_data (aws lambda get-function-configuration --function-name $entry --query "[FunctionName, Environment]")
	set entry_name (echo $entry_data | jq -r .[0])
	set entry_val (echo $entry_data | jq -r .[1].Variables)
	# only print the entry's name/value if the search term is found
	if string match -q -i "*$needle*" $entry_val
  	# perform a jq search for the search term, then print the key/value pair that contains it
  	set matched_key_val (echo $entry_val | jq -r --arg needle $needle 'to_entries[] | select(.value | tostring | contains($needle)) | "\(.key): \(.value)"')
  	echo -e "\033[1m$entry_name\033[0m:"
  	echo -e \t$matched_key_val
	end
  end
end

function list_ic_users -d "Return a formatted, sorted list of all Identity Center users"
  aws identitystore list-users --identity-store-id d-9a67172dcc --query "Users[].[NickName,UserName]" | jq -r '.[] | flatten | join(": ")' | sort
end

function list_a_record_ips -d "Return a list of all DNS A records pointing to a given IP"
  # get all hosted zones and their IDs
  set zone_ids_list (aws route53 list-hosted-zones --query "HostedZones[].[Name,Id]")
  # format the list to be human-readable and usable by skim
  set formatted_list ($zone_ids_list | jq -r '.[] | [.[0],.[1] | split("/")[-1]] | join("|")')
  # use skim to choose a zone from the formatted list and return ONLY the zone ID
  set zone_choice ($formatted_list | sk | cut -d "|" -f 2)
  aws route53 list-resource-record-sets --hosted-zone-id $zone_choice --query "ResourceRecordSets[?@.ResourceRecords && Type == 'A'].[Name,ResourceRecords[*].Value]" \
	| jq -r '.[] | flatten | join(": ")' \
	| sort
end

function iam_group_policies -d "Audit of all IAM user group permissions policies"
  set groups (aws iam list-groups --query "Groups[].GroupName" | jq -r .[])

  for group in $groups
	echo $group:
	aws iam list-attached-group-policies --group-name $group --query "AttachedPolicies[].PolicyName"
  end
end

function lambda_dl -d "Download all lambda functions code to disk" --argument-names location
  set lambdas (aws lambda list-functions  --no-paginate --region $aws_region --query "Functions[].FunctionName" | jq -r .[])
  set -q location[1] || set location "/Users/jessedupuy/Downloads/"
  if slash_test $location
	set location $location/
  end

  for lambda_name in $lambdas
	echo "downloading: $function to $location$function"
	set code_link (aws lambda get-function --function-name $lambda_name --query "Code.Location" --output text)
	cd $location
	mkdir $location$lambda_name && cd $location$lambda_name
	wget -q $code_link -O $location$lambda_name/$lambda_name.zip
	unzip $lambda_name.zip && rm $lambda_name.zip
	cd ..
  end
end

function slash_test --argument-names test_str
  string match -rv "/\$" $test_str >> /dev/null
end

function ecr_repos -d "Get a full, sorted list of ECR repo names"
  aws ecr describe-repositories --no-paginate --query 'repositories[].repositoryName' | jq -r .[] | sort
end

function ecs_roles -d "Get a list of all IAM roles used by ECS clusters/services/tasks"
  set clusters (aws ecs list-clusters --query clusterArns | jq -r .[])

  for cluster in $clusters
	set services (aws ecs list-services --cluster $cluster --query "serviceArns[*]" | jq -r .[])
	for service in $services
  	set service_name (string split '/' $service -r -m1 -f2)
  	set service_role (aws ecs describe-services --services $service --cluster $cluster --query "services[].roleArn" | jq -r .)
  	echo $service_role
	end
  end
end

function eb_env_vars -d "Get a full, sorted list of Elasticbeanstalk env vars"
  set apps (aws elasticbeanstalk describe-applications --query "Applications[].ApplicationName" | jq -r .[] | sort)
  for app in $apps
	echo $app
	set app_envs (aws elasticbeanstalk describe-environments --application-name $app --query "Environments[].EnvironmentName" | jq -r .[] | sort)
	for app_env in $app_envs
  	echo $app_env
  	set env_config (aws elasticbeanstalk describe-configuration-settings --application-name $app --environment-name $app_env --query "ConfigurationSettings[].OptionSettings[? Namespace==`aws:elasticbeanstalk:application:environment` && OptionName.contains(@, `PG`)][OptionName, Value] | [].join(': ', @)")
  	echo $env_config | jq .[] | sort
	end
  end
end

function params_list -d "Get a full, sorted list of SSM parameter values"
  set ssm_params (aws ssm describe-parameters --query "Parameters[].Name" | jq -r .[] | sort)
  for ssm_param in $ssm_params
	set param_val (aws ssm get-parameter --name $ssm_param --with-decryption --query "Parameter.[Name, Value]")
	echo $param_val
  end
end

function secret_search -d "Sift through all stored secret values for <search string>" --argument-names needle
  # do nothing if no arg/search term is provided
  if test -z "$needle"
	echo "you didn't provide a search term!"
	return 1
  end
  # grab a list of all stored sekrit ARNs
  set list (aws secretsmanager list-secrets --query "SecretList[].ARN" | jq -r .[] | sort)
  # loop through the list of ARNs, checking each item's value for the search term
  for entry in $list
	set entry_data (aws secretsmanager get-secret-value --secret-id $entry --query "[Name, SecretString]")
	set entry_name (echo $entry_data | jq -r .[0])
	set entry_val (echo $entry_data | jq -r .[1])
	# only print the entry's name/value if the search term is found
	if string match -q -i "*$needle*" $entry_val
  	# perform a jq search for the search term, then print the key/value pair that contains it
  	set matched_key_val (echo $entry_val | jq -r --arg needle $needle 'to_entries[] | select(.value | tostring | contains($needle)) | "\(.key): \(.value)"')
  	echo -e "\033[1m$entry_name\033[0m:"
  	echo -e \t$matched_key_val
	end
  end
end

# MARK: LB policy updater
function update_elb_listeners -d "Find outdated ELB listener SSL policies and update them to a specified new one"
  set elbArns (aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" | jq -r .[] | sort)
  # check current policy list with `aws elbv2 describe-ssl-policies --query "SslPolicies[].Name"`
  # then verify ciphers etc at https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
  set desiredPolicy "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"

  for arn in $elbArns
	set elbName (string split / $arn -f 3)
	set listener (aws elbv2 describe-listeners --load-balancer-arn $arn --query "Listeners[?Protocol=='HTTPS' && SslPolicy!='$desiredPolicy'].[ListenerArn,SslPolicy][]")

	# avoid doing further work if the SSL policy is correct
	if test "$listener" = "[]"
  	continue
	end

	# update all the ELBs with listeners using old SSL policies
	set listenerArn (echo $listener | jq -r .[0])
	set listenerPolicy (echo $listener | jq -r .[1])
	echo "$elbName [from] $listenerPolicy [to] $desiredPolicy"
	aws elbv2 modify-listener --listener-arn $listenerArn --ssl-policy $desiredPolicy > /dev/null
  end
end

function update_elb_attributes -d "Update specified ELB attributes across all load balancers"
  set elbArns (aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" | jq -r .[] | sort)

  for arn in $elbArns
	set elbName (string split / $arn -f 3)
	echo "updating $elbName attrs"
	aws elbv2 modify-load-balancer-attributes --load-balancer-arn $arn --attributes "Key=routing.http.drop_invalid_header_fields.enabled,Value=false" > /dev/null
  end
end

function get_role_services -d "List all services used by an IAM role"
  set job_id (aws iam generate-service-last-accessed-details --arn arn:aws:iam::$aws_acct:role/enquirer-test-EnquirerService-1Y1-CodePipelineRole-6QW1HCLAA6RR --query "JobId" | jq -r .)
  # evidently doing this automatically doesn't work ಠ_ಠ TODO: figure out why
  # set accessed_services (aws iam get-service-last-accessed-details --no-paginate --job-id "$job_id" --query "ServicesLastAccessed[?TotalAuthenticatedEntities>`0`]")
  set accessed_services (jq -r .[].ServiceNamespace ~/projects/tw-enquirer/role-access-details.json)
  for service in $accessed_services
	echo $service
	set entities (aws iam get-service-last-accessed-details-with-entities --no-paginate --job-id $job_id --service-namespace $service)
	echo $entities
  end
end

# MARK: CFormation updater
function update_cf -d "Quickly generate changeset for a CloudFormation stack, inspect, and (optionally) run it" --argument-names stack_name template
  set -q stack_name[1] || set stack_name (aws cloudformation list-stacks --query "StackSummaries[].StackName" | jq -r .[] | fzf --height 5% --layout=reverse)

  if test -z "$stack_name"
	echo "pls provide a stack name" && return 1
  end

  echo "would you like to [c]reate a new changeset? Or just hit [enter] to operate on existing changes:"

  switch (read)
  case 'C' 'c' 'create' 'Create'
	set -q template[1] || set template (fd .yml ~/projects/tw-cloud-infra | fzf --height 5% --layout=reverse)
	# set change_name tw-$stack_name-changeset-$(date +%s)

	if test -z "$template"
  	echo "pls provide a template" && return 1
	end

	echo "deploying changeset for $stack_name"

	# aws cloudformation create-change-set \
	#   --stack-name $stack_name \
	#   --change-set-name $change_name \
	#   --template-body file://$template \
	#   --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND

	aws cloudformation deploy \
  	--stack-name $stack_name \
  	--template-file $template \
  	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  	--no-execute-changeset

	# aws cloudformation wait change-set-create-complete \
	#   --stack-name $stack_name \
	#   --change-set-name $change_name
  case '*'
	echo "ok, looking for existing changes"
  end

  set changeset_prev_cmd "aws cloudformation describe-change-set --stack-name $stack_name --change-set-name {} --output yaml | bat -l yaml --color=always"
  set changeset_exec_cmd "aws cloudformation execute-change-set --stack-name $stack_name --change-set-name {1}"
  set changeset_delt_cmd "aws cloudformation delete-change-set --stack-name $stack_name --change-set-name {1}"

  aws cloudformation list-change-sets --stack-name $stack_name --query "Summaries[].ChangeSetName" | jq -r .[] | \
	fzf --preview $changeset_prev_cmd \
  	--header "press [enter] to execute a $stack_name changeset or [esc] to exit" \
  	--preview-window 'down,80%,border-top' \
  	--bind "enter:execute($changeset_exec_cmd)+execute(echo 'applying changeset..')+abort" \
  	--bind "ctrl-d:execute($changeset_delt_cmd)+execute(echo 'deleting changeset..')+reload($changeset_prev_cmd)" \
  	--bind "esc:execute(echo 'exited without changing $stack_name')+abort" \
  	--bind "zero:execute(echo 'no changelists found for $stack_name')+abort"
end

# MARK: Certs and DNS
function add_hosted_zone -d "Add a new hosted zone to Route53" --argument-names domain
  set domain_name $domain
  set hosted_zone_id (aws route53 create-hosted-zone --name $domain_name --caller-reference (date +%s) --query "HostedZone.Id" | cut -d '"' -f 2)
  set name_servers (aws route53 get-hosted-zone --id $hosted_zone_id --query "DelegationSet.NameServers" | jq -r .[])
  echo "Hosted zone created for $domain_name with ID $hosted_zone_id"
  echo "Please add the following name servers to your domain registrar:"
  echo $name_servers
end

function redirect_alb_rules -d "Add rules to prod marketing ALB for the domains in ~/Downloads/redirect-domains"
  set domain_list (cat ~/Downloads/redirect-domains)
  set listener_arn "arn:aws:elasticloadbalancing:$aws_region:$aws_acct:listener/app/tw-prod-marketing-landing/231766bcf483797b/86917671d57e368d"
  set priority (aws elbv2 describe-rules --listener-arn $listener_arn --query "Rules[].Priority" | jq -r .[] | sort -n | tail -1)
  set total_domains (count $domain_list)

  for idx in (seq 1 $total_domains)
	set rule_priority (math $priority + $idx)
	set domain $domain_list[$idx]

	echo "Adding rule for $domain with priority $rule_priority"

	aws elbv2 create-rule \
  	--listener-arn $listener_arn \
  	--priority $rule_priority \
  	--conditions Field=host-header,Values=[$domain,"www.$domain"] \
  	--actions "Type=redirect,RedirectConfig={Protocol=HTTPS,Host=trustandwill.com,Port=443,Path='/#{path}',Query='#{query}',StatusCode=HTTP_302}" \
  	--tags "Key=Name,Value=redirect $domain" "Key=Service,Value=redirect" "Key=Environment,Value=production"
  end
end

function get_nameservers -d "Get a sorted list of nameservers for all hosted zones"
  set zones (aws route53 list-hosted-zones --query "HostedZones[].Id" | jq -r .[])
  for zone in $zones
	set zone_name (aws route53 get-hosted-zone --id $zone --query "HostedZone.Name" | jq -r .)
	set name_servers (aws route53 get-hosted-zone --id $zone --query "DelegationSet.NameServers" | jq -r .[])
	echo "$zone_name: $name_servers"
  end
end

function transfer_domains -d "Submit domain transfer requests for each domain in ~/Downloads/redirect-domains"
  set domain_list (cat ~/Downloads/redirect-domains)

  for domain in $domain_list
	echo "Transferring $domain"
	aws route53domains transfer-domain-to-another-aws-account \
  	--domain-name $domain
  	--account-id $aws_acct
  	--auth-code $auth_code
  	--cli-input-json-file ~/Documents/tw-domain-contacts.json
  end
end

function list_certificates -d "List all SSL certificates in current region's ACM"
  aws acm list-certificates --query "CertificateSummaryList[].[DomainName, CertificateArn]" | jq -r '. | sort | .[] | "\(.[0]): \(.[1])"'
end

function create_certs -d "create an SSL certificate in ACM for each domain in ~/Downloads/redirect-domains"
  set domain_list (aws acm list-certificates --query "CertificateSummaryList[].DomainName" | jq -r '. | sort')
  # use jq contains() to ensure the list does not contain entries with \* nor trustandwill.com
  set domain_list (echo $domain_list | jq -r 'map(select(. | contains("*") or contains("trustandwill.com") | not)) | .[]')

  set cert_region "us-east-1"

  for domain in $domain_list
	echo "Creating certificate for $domain in $cert_region"
	aws acm request-certificate --domain-name $domain --validation-method DNS --subject-alternative-names "*.$domain" --region $cert_region > /dev/null
  end
end

function validate_certs -d "validate the ACM certificates for each domain in ~/Downloads/redirect-domains"
  set cert_arns (aws acm list-certificates --certificate-statuses PENDING_VALIDATION --query "CertificateSummaryList[].CertificateArn" | jq -r .[])

  for arn in $cert_arns
	aws acm describe-certificate --certificate-arn $arn --query "Certificate.DomainValidationOptions[0].ResourceRecord.[Name,Value]" | jq -r .[]
  end
end

function redirect_dns -d "Add records to Route53 for the domains in ~/Downloads/redirect-domains"
  set domain_list (cat ~/Downloads/redirect-domains)
  set alb_zone (aws elbv2 describe-load-balancers --names tw-prod-marketing-landing --query "LoadBalancers[].CanonicalHostedZoneId" | jq -r .[])
  set zone_name "dualstack.tw-prod-marketing-landing-1981028415.$aws_region.elb.amazonaws.com."

  for domain in $domain_list
	set hosted_zone_id (aws route53 list-hosted-zones --query "HostedZones[?Name==`$domain.`].Id" | jq -r '.[0] | split("/") | .[-1]')

	set records_json (jq -nc \
  	--arg dname "$domain" \
  	--arg wwwdname "www.$domain" \
  	--arg albz "$alb_zone" \
  	--arg albzname "$zone_name" \
  	'{"Changes": [
    	{
      	"Action": "CREATE","ResourceRecordSet": {
        	"Name": $dname,
        	"Type": "A",
        	"AliasTarget": {
          	"HostedZoneId": $albz,
          	"DNSName": $albzname,
          	"EvaluateTargetHealth": true
        	}
      	}
    	},
    	{
      	"Action": "CREATE","ResourceRecordSet": {
        	"Name": $wwwdname,
        	"Type": "CNAME",
        	"TTL": 300,
        	"ResourceRecords": [{"Value": $dname}]}
    	}
  	]}'
	)
	echo "Adding records for $domain to hosted zone $hosted_zone_id"
	aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch $records_json
  end
end

function list_alb_http2 -d "List the routing.http2.enabled attribute of all load balancers"
  set alb_arns (aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" | jq -r .[])

  for arn in $alb_arns
	set alb_name (string split / $arn -f 3)
	set http2_enabled (aws elbv2 describe-load-balancer-attributes --load-balancer-arn $arn --query "Attributes[?Key=='routing.http2.enabled'].Value" | jq -r .[])
	echo "$alb_name: $http2_enabled"
  end
end

# MARK: RDS
function rds_bastion_tunnel -d "Create an ssh tunnel through a bastion host to an RDS instance" --argument-names rds_host rds_port
  set -q rds_host[1] || set rds_host "xxx"
  set -q rds_port[1] || set rds_port 3306
  set bastion_host "scary" # defined in ~/.ssh/config

  # Create an ssh tunnel using specific flags:
  # -f: fork to background
  # -N: don't execute a remote command
  # -M: place the ssh client into "master" mode for connection sharing
  # -S: specify a control socket for the master connection
  # -L: specify a local port to forward to a remote host/port
  ssh -f -N -M -S /tmp/rds-tunnel-session -L 3307:$rds_host:$rds_port $bastion_host
end

function ping_rds -d "Ping an RDS DB every 5 seconds until cancelled" --argument-names rds_user rds_pass
  set -q rds_user[1] || set rds_user "abc"
  set -q rds_pass[1] || set rds_pass "abc"

  date
  while true
	MYSQL_PWD=$rds_pass mysqladmin ping -h 127.0.0.1 -P 3307 -u$rds_user
	date
	sleep 5
  end
end

function sqs_ignore_missing -d "Find all SQS alarms and change their TreatMissingData value to ignore"
  set alarm_list (aws cloudwatch describe-alarms --query "MetricAlarms[?contains(AlarmName, `sqs-`) && TreatMissingData != `ignore`].AlarmName" | jq -r .[])

  for alarm in $alarm_list
	echo Updating $alarm...

	set alarm_details (aws cloudwatch describe-alarms --alarm-names $alarm | jq -r '.MetricAlarms[0] | {ActionsEnabled, AlarmActions, AlarmDescription, AlarmName, ComparisonOperator, DatapointsToAlarm, Dimensions, EvaluateLowSampleCountPercentile, EvaluationPeriods, ExtendedStatistic, InsufficientDataActions, MetricName, Metrics, Namespace, OKActions, Period, Statistic, Tags, Threshold, ThresholdMetricId, TreatMissingData, Unit}')
	set alarm_details (echo $alarm_details | jq '.TreatMissingData = "ignore"')


	aws cloudwatch put-metric-alarm --cli-input-json "$alarm_details"
  end
end

# MARK: Alarms
function add_ok_actions -d "Find all alarms without ok actions and add an SNS topic to them" --argument-names aws_profile
  set -q aws_profile[1] || set aws_profile "default"
  set alarm_list (aws cloudwatch describe-alarms --query "MetricAlarms[?length(OKActions) == `0`].AlarmName" --profile $aws_profile | jq -r .[])

  for alarm in $alarm_list
	echo adding OKActions to $alarm
	set alarm_details (aws cloudwatch describe-alarms --alarm-names $alarm --profile $aws_profile | jq -r '.MetricAlarms[0] | {ActionsEnabled, AlarmActions, AlarmDescription, AlarmName, ComparisonOperator, DatapointsToAlarm, Dimensions, EvaluateLowSampleCountPercentile, EvaluationPeriods, ExtendedStatistic, InsufficientDataActions, MetricName, Metrics, Namespace, OKActions, Period, Statistic, Tags, Threshold, ThresholdMetricId, TreatMissingData, Unit}')
	set sns_topic (echo $alarm_details | jq -r '.AlarmActions[0]')
	set alarm_details (echo $alarm_details | jq --arg sns_topic $sns_topic '.OKActions += [$sns_topic] | del(..|nulls)')

	# update the alarm using its own details plus the new OKActions
	aws cloudwatch put-metric-alarm --cli-input-json "$alarm_details" --profile $aws_profile
  end
end

function create_alarms -d "Create CloudWatch alarms for all desired resources"
  set resource_list (jq -c '.resources_list[]' "$HOME/Downloads/monitored-resources.json")
  # get account ID of active AWS cli profile
  set acct (aws sts get-caller-identity --query "Account" | jq -r .)

  for resource in $resource_list
	set resource_name (echo $resource | jq -r .resource_name)
	set family (echo $resource | jq -r .type)

	switch $family
  	case "ec2"
    	set resource_id (echo $resource | jq -r .resource_id)
    	set resource_threshold (echo $resource | jq -r .cpu)
    	set resource_status (echo $resource | jq -r .stat_check)
    	set env_name (echo $resource | jq -r .env)

    	echo "Creating EC2 alarms for $resource_name..."

    	aws cloudwatch put-metric-alarm \
      	--alarm-name ec2-cpu-$env_name-$resource_name \
      	--alarm-description "CPU for $env_name host $resource_name has exceeded $resource_threshold percent" \
      	--metric-name CPUUtilization \
      	--namespace AWS/EC2 \
      	--statistic Average \
      	--period 300 \
      	--threshold $resource_threshold \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=InstanceId,Value=$resource_id \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Percent \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=EC2" "Key=Metric,Value=CPUUtilization"

    	aws cloudwatch put-metric-alarm \
      	--alarm-name ec2-statcheck-{$env_name}-{$resource_name} \
      	--alarm-description "StatusCheckFailed for $env_name host $resource_name has exceeded $resource_threshold percent" \
      	--metric-name StatusCheckFailed \
      	--namespace AWS/EC2 \
      	--statistic Sum \
      	--period 300 \
      	--threshold $resource_status \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=InstanceId,Value=$resource_id \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Count \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=EC2" "Key=Metric,Value=StatusCheckFailed"

  	case "ecs"
    	set cluster_name (echo $resource | jq -r .cluster)
    	set service_name (echo $resource | jq -r .service)
    	set cpu_value (echo $resource | jq -r .cpu)
    	set mem_value (echo $resource | jq -r .memory)
    	set env_name (echo $resource | jq -r .env)

    	echo "Creating ECS alarms for $resource_name..."

    	aws cloudwatch put-metric-alarm \
      	--alarm-name ecs-cpu-{$env_name}-{$resource_name} \
      	--alarm-description "CPU for $env_name $resource_name has exceeded $cpu_value percent" \
      	--metric-name CPUUtilization \
      	--namespace AWS/ECS \
      	--statistic Average \
      	--period 300 \
      	--threshold $cpu_value \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=ClusterName,Value=$cluster_name Name=ServiceName,Value=$service_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Percent \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=ECS" "Key=Metric,Value=CPUUtilization" "Key=Service,Value=$resource_name"

    	aws cloudwatch put-metric-alarm \
      	--alarm-name ecs-memory-{$env_name}-{$resource_name} \
      	--alarm-description "MemoryUtilization for $env_name $resource_name has exceeded $mem_value percent" \
      	--metric-name MemoryUtilization \
      	--namespace AWS/ECS \
      	--statistic Average \
      	--period 300 \
      	--threshold $mem_value \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=ClusterName,Value=$cluster_name Name=ServiceName,Value=$service_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Percent \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=ECS" "Key=Metric,Value=MemoryUtilization" "Key=Service,Value=$resource_name"

  	case "rds"
    	set cpu_value (echo $resource | jq -r .cpu)
    	set read_value (echo $resource | jq -r .read)
    	set write_value (echo $resource | jq -r .write)
    	set read_throughput (echo $resource | jq -r .read_throughput)
    	set write_throughput (echo $resource | jq -r .write_throughput)
    	set free_storage (echo $resource | jq -r .free_storage)
    	set queue_depth (echo $resource | jq -r .queue_depth)
    	set connections (echo $resource | jq -r .connections)
    	set env_name (echo $resource | jq -r .env)

    	echo "Creating RDS alarms for $resource_name..."

    	aws cloudwatch put-metric-alarm \
      	--alarm-name "rds-cpu-$env_name-$resource_name" \
      	--alarm-description "CPU for $env_name $resource_name has exceeded $cpu_value percent" \
      	--metric-name CPUUtilization \
      	--namespace AWS/RDS \
      	--statistic Average \
      	--period 300 \
      	--threshold $cpu_value \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Percent \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=CPUUtilization"

    	aws cloudwatch put-metric-alarm \
      	--alarm-name "rds-read-$env_name-$resource_name" \
      	--alarm-description "ReadIOPS for $env_name $resource_name has exceeded $read_value / second" \
      	--metric-name ReadIOPS \
      	--namespace AWS/RDS \
      	--statistic Average \
      	--period 300 \
      	--threshold $read_value \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit "Count/Second" \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=ReadIOPS"

    	aws cloudwatch put-metric-alarm \
      	--alarm-name "rds-write-$env_name-$resource_name" \
      	--alarm-description "WriteIOPS for $env_name $resource_name has exceeded $write_value / second" \
      	--metric-name WriteIOPS \
      	--namespace AWS/RDS \
      	--statistic Average \
      	--period 300 \
      	--threshold $write_value \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit "Count/Second" \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=WriteIOPS"

    	aws cloudwatch put-metric-alarm \
      	--alarm-name "rds-read_thru-$env_name-$resource_name" \
      	--alarm-description "ReadThroughput for $env_name $resource_name has exceeded $read_throughput / second" \
      	--metric-name ReadThroughput \
      	--namespace AWS/RDS \
      	--statistic Average \
      	--period 300 \
      	--threshold $read_throughput \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit "Bytes/Second" \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=ReadThroughput"

    	aws cloudwatch put-metric-alarm \
      	--alarm-name "rds-write_thru-$env_name-$resource_name" \
      	--alarm-description "WriteThroughput for $env_name $resource_name has exceeded $write_throughput / second" \
      	--metric-name WriteThroughput \
      	--namespace AWS/RDS \
      	--statistic Average \
      	--period 300 \
      	--threshold $write_throughput \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit "Bytes/Second" \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=WriteThroughput"

    	# not all RDS instances have a free storage metric
    	if test -n "$free_storage"
      	aws cloudwatch put-metric-alarm \
        	--alarm-name rds-free_storage-$env_name-$resource_name \
        	--alarm-description "FreeStorageSpace for $env_name $resource_name has exceeded $free_storage" \
        	--metric-name FreeStorageSpace \
        	--namespace AWS/RDS \
        	--statistic Average \
        	--period 300 \
        	--threshold $free_storage \
        	--comparison-operator GreaterThanThreshold \
        	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
        	--evaluation-periods 2 \
        	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
        	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
        	--unit Bytes \
        	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=FreeStorageSpace"
    	end

    	aws cloudwatch put-metric-alarm \
      	--alarm-name "rds-queue_depth-$env_name-$resource_name" \
      	--alarm-description "DiskQueueDepth for $env_name $resource_name has exceeded $queue_depth" \
      	--metric-name DiskQueueDepth \
      	--namespace AWS/RDS \
      	--statistic Maximum \
      	--period 300 \
      	--threshold $queue_depth \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Count \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=DiskQueueDepth"

    	aws cloudwatch put-metric-alarm \
      	--alarm-name "rds-connections-$env_name-$resource_name" \
      	--alarm-description "DatabaseConnections for $env_name $resource_name has exceeded $connections" \
      	--metric-name DatabaseConnections \
      	--namespace AWS/RDS \
      	--statistic Sum \
      	--period 300 \
      	--threshold $connections \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions Name=DBInstanceIdentifier,Value=$resource_name \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Count \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=RDS" "Key=Metric,Value=DatabaseConnections"

  	case "sqs"
    	set msgs_sent (echo $resource | jq -r .msgs_sent)
    	set approx_visible (echo $resource | jq -r .approx_visible)
    	set approx_hidden (echo $resource | jq -r .approx_hidden)
    	set approx_age (echo $resource | jq -r .approx_age)
    	set env_name (echo $resource | jq -r .env)

    	echo "Creating SQS alarms for $resource_name..."

    	aws cloudwatch put-metric-alarm \
      	--alarm-name sqs-cpu-{$env_name}-{$resource_name} \
      	--alarm-description "NumberOfMessagesSent for $env_name $resource_name has exceeded $msgs_sent" \
      	--metric-name NumberOfMessagesSent \
      	--namespace AWS/SQS \
      	--statistic Average \
      	--period 300 \
      	--threshold $msgs_sent \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions "Name=QueueName,Value=$resource_name.fifo" \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Count \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=SQS" "Key=Metric,Value=NumberOfMessagesSent"
      	--treat-missing-data ignore

    	aws cloudwatch put-metric-alarm \
      	--alarm-name sqs-visible-{$env_name}-{$resource_name} \
      	--alarm-description "ApproximateNumberOfMessagesVisible for $env_name $resource_name has exceeded $approx_visible" \
      	--metric-name ApproximateNumberOfMessagesVisible \
      	--namespace AWS/SQS \
      	--statistic Average \
      	--period 300 \
      	--threshold $approx_visible \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions "Name=QueueName,Value=$resource_name.fifo" \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Count \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=SQS" "Key=Metric,Value=ApproximateNumberOfMessagesVisible"
      	--treat-missing-data ignore

    	aws cloudwatch put-metric-alarm \
      	--alarm-name sqs-not_visible-{$env_name}-{$resource_name} \
      	--alarm-description "ApproximateNumberOfMessagesNotVisible for $env_name $resource_name has exceeded $approx_hidden" \
      	--metric-name ApproximateNumberOfMessagesNotVisible \
      	--namespace AWS/SQS \
      	--statistic Average \
      	--period 300 \
      	--threshold $approx_hidden \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions "Name=QueueName,Value=$resource_name.fifo" \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Count \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=SQS" "Key=Metric,Value=ApproximateNumberOfMessagesNotVisible"
      	--treat-missing-data ignore

    	aws cloudwatch put-metric-alarm \
      	--alarm-name sqs-approx_age-{$env_name}-{$resource_name} \
      	--alarm-description "ApproximateAgeOfOldestMessage for $env_name $resource_name has exceeded $approx_age" \
      	--metric-name ApproximateAgeOfOldestMessage \
      	--namespace AWS/SQS \
      	--statistic Average \
      	--period 300 \
      	--threshold $approx_age \
      	--comparison-operator GreaterThanThreshold \
      	--dimensions "Name=QueueName,Value=$resource_name.fifo" \
      	--evaluation-periods 2 \
      	--alarm-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--ok-actions "arn:aws:sns:"$aws_region":"$acct":"$env_name"_alerts" \
      	--unit Seconds \
      	--tags "Key=Environment,Value=$env_name" "Key=Family,Value=SQS" "Key=Metric,Value=ApproximateAgeOfOldestMessage"
      	--treat-missing-data ignore
	end
  end
end
