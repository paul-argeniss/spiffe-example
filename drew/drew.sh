#!/bin/bash

declare -rx TF_VAR_SPIRE_TGZ="${SPIRE_TGZ:-https://s3.us-east-2.amazonaws.com/scytale-artifacts/spire/spire-c37711f-linux-x86_64-glibc.tar.gz}"
declare -rx TF_VAR_AWS_IID_TGZ="${AWS_IID_TGZ:-https://github.com/spiffe/aws-iid-attestor/releases/download/0.1/nodeattestor-aws_iid_0.1_linux_x86_64.tar.gz}"
declare -rx TF_VAR_AWS_RES_TGZ="${AWS_RES_TGZ:-https://github.com/spiffe/aws-resolver/releases/download/0.1.1/noderesolver-aws_0.1.1_linux_x86_64.tar.gz}"
declare -rx TF_VAR_GROK_EXPORTR_TGZ="${GROK_EXPORTR_TGZ:-https://github.com/fstab/grok_exporter/releases/download/v0.2.4/grok_exporter-0.2.4.linux-amd64.zip}"
declare -rx TF_VAR_NODE_EXPORTER_TGZ="${NODE_EXPORTER_TGZ:-https://github.com/prometheus/node_exporter/releases/download/v0.15.2/node_exporter-0.15.2.linux-amd64.tar.gz}"

declare -rx TF_VAR_REGION="us-east-2"
declare -rx TF_VAR_AZ="a"
# note that you will have to change the server address elsewhere if you update the VPC CIDR
declare -rx TF_VAR_CIDR="10.71.0.0/20"

declare -rx TF_VAR_TYPE="t2.micro"
declare -rx TF_VAR_AGENTS="${DEMO_AGENTS:-4}"
declare -rx TF_VAR_WORKLOADS="${DEMO_WORKLOADS:-20}"
declare -rx TF_VAR_PRICE="0.01"

declare -rx TF_VAR_SSH_PRIV_KEY="$PWD/drew_ssh_key"
declare -rx TF_VAR_SSH_PUB_KEY="${TF_VAR_SSH_PRIV_KEY}.pub"

if [[ ! -r $TF_VAR_SSH_PRIV_KEY ]]; then
	ssh-keygen -N '' -f $TF_VAR_SSH_PRIV_KEY
	chmod 600 $TF_VAR_SSH_PRIV_KEY
fi

drew_env() {
	echo "ssh_priv_key=${TF_VAR_SSH_PRIV_KEY}"
	terraform output | sed 's/ //g'
}

drew_packer() {
	terraform get
	terraform apply -target=random_pet.demo -auto-approve
	eval $(drew_env)
	export demo_name
	packer build packer.json
}

drew_agents() {
	local _n _i=1
	eval $(drew_env)
	for _n in $(AWS_REGION=$TF_VAR_REGION aws --output text ec2 describe-instances \
		--filter Name=tag:Name,Values=${demo_name}_spot_agent Name=instance-state-name,Values=running \
		| grep INSTANCES | awk '{print $17}'); do
			echo "public_ip_agent$((_i++))=$_n"
	done
}

_ssh() {
	ssh -q -i drew_ssh_key -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l ubuntu $@
}

_update() {
	echo "=== $1 $2"
	tar -cf - remote | _ssh $2 tar --directory=/tmp -xf -
	_ssh $2 "DEBUG=$DEBUG RECONFIGURE=true NUM_WORKLOAD=$TF_VAR_WORKLOADS SPIRE_TGZ=$SPIRE_TGZ \
		AWS_RES_TGZ=$AWS_RES_TGZ AWS_IID_TGZ=$AWS_IID_TGZ /tmp/remote/install_spire.sh $1"
}

drew_update() {
	local _n _agents _tgz

	eval $(drew_env)
	_agents="$(drew_agents | cut -d= -f2)"

	# messy
	if [[ $SPIRE_TGZ ]]; then
		aws --region $TF_VAR_REGION s3 cp --acl public-read $SPIRE_TGZ s3://$artifact_bucket_id/
		SPIRE_TGZ="https://${artifact_bucket_name}/$(basename $SPIRE_TGZ)"
	else
		SPIRE_TGZ=$TF_VAR_SPIRE_TGZ
	fi
	if [[ $AWS_RES_TGZ ]]; then
		aws --region $TF_VAR_REGION s3 cp --acl public-read $AWS_RES_TGZ s3://$artifact_bucket_id/
		AWS_RES_TGZ="https://${artifact_bucket_name}/$(basename $AWS_RES_TGZ)"
	else
		AWS_RES_TGZ=$TF_VAR_AWS_RES_TGZ
	fi
	if [[ $AWS_IID_TGZ ]]; then
		aws --region $TF_VAR_REGION s3 cp --acl public-read $AWS_IID_TGZ s3://$artifact_bucket_id/
		AWS_RES_TGZ="https://${artifact_bucket_name}/$(basename $AWS_IID_TGZ)"
	else
		AWS_IID_TGZ=$TF_VAR_AWS_IID_TGZ
	fi

	_update server $public_ip_server
	for _n in $_agents; do
		_update agent $_n
	done
}

drew_ssh() {
	local _conect_host

	eval $(drew_env)
	eval $(drew_agents)
	case $2 in
		server) _connect_host=$public_ip_server ;;
		agent) _connect_host=$public_ip_agent1 ;;
		*) _connect_host="$2" ;;
	esac
	_ssh $_connect_host
}

case $1 in
	packer)	drew_packer ;;
	env)	drew_env ;;
	ssh)	drew_ssh "$@" ;;
	agents)	drew_agents ;;
	update)	drew_update "$@" ;;
	*)		terraform get
			terraform "$@"
			;;
esac
