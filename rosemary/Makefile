SHELL=/bin/bash
SPIRE_REPO ?= spiffe/spire
SPIRE_REF  ?= c151b80ed554b9ed13b8545f1e6fcbb49ed0f4c7 # branch, tag or commit hash

all: checkout build-artifact build-services

checkout:
	rm -rf build/repos
	mkdir build/repos
	git clone git@github.com:$(SPIRE_REPO).git build/repos/spire
	git -C build/repos/spire checkout $(SPIRE_REF)

build-artifact:
	rm -rf artifact spire/upstreamca-memory-keys/
	mkdir artifact spire/upstreamca-memory-keys/
	docker-compose build build
	docker-compose up -d build
	docker-compose exec build find /root/go/src/github.com/spiffe/spire/ -name '*.tgz' -exec cp {} /home/rosemary/artifact/artifact.tgz \;
	docker-compose exec build cp /root/go/bin/ghostunnel /home/rosemary/artifact/
	docker-compose exec build cp /root/go/src/github.com/spiffe/spiffe-example/rosemary/build/tools/registration/registration /home/rosemary/artifact/
	docker-compose exec build cp /root/go/src/github.com/spiffe/spiffe-example/rosemary/build/tools/registration/registration.json /home/rosemary/artifact/
	docker-compose exec build cp /root/go/src/github.com/spiffe/spiffe-example/rosemary/build/tools/sidecar/sidecar /home/rosemary/artifact/
	docker-compose stop build
	cp artifact/artifact.tgz spire/
	cp artifact/artifact.tgz database/
	cp artifact/artifact.tgz blog/
	cp artifact/artifact.tgz harness/
	cp artifact/registration harness/
	cp artifact/ghostunnel blog/
	cp artifact/ghostunnel database/
	cp artifact/ghostunnel harness/
	cp build/repos/spire/plugin/server/upstreamca-memory/pkg/_test_data/keys/* spire/upstreamca-memory-keys/
	
build-services:
	rm -rf {spire,blog,database}/{conf,pconf}
	mkdir {spire,blog,database}/{conf,pconf}
	cp build/repos/spire/cmd/spire-server/.conf/* spire/conf/
	cp build/repos/spire/plugin/server/.conf/* spire/pconf/
	cp build/repos/spire/cmd/spire-agent/.conf/* blog/conf/
	cp build/repos/spire/plugin/agent/.conf/* blog/pconf/
	cp build/repos/spire/cmd/spire-agent/.conf/* database/conf/
	cp build/repos/spire/plugin/agent/.conf/* database/pconf/
	cp blog/custom_conf/* blog/conf/
	cp blog/custom_pconf/* blog/pconf/
	cp database/custom_conf/* database/conf/
	cp database/custom_pconf/* database/pconf/
	cp spire/custom_conf/* spire/conf/
	cp spire/custom_pconf/* spire/pconf/
	docker-compose build blog database spire harness

demo:
	docker-compose up -d spire
	sleep 5 # TODO: Find another way of making sure server is up before agents
	docker-compose exec spire bash -c 'cd /home/rosemary/artifact/ && ./registration'
	docker-compose up -d blog database harness
	docker-compose exec --user blog blog cp /home/rosemary/artifact/sidecar /sidecar/sidecar
	docker-compose exec --user database database cp /home/rosemary/artifact/sidecar /sidecar/sidecar
	docker-compose exec harness cp /home/rosemary/harness/rosemary.yml /root/.tmuxinator/rosemary.yml
	docker-compose exec harness tmuxinator rosemary
	docker-compose stop harness

clean:
	docker-compose down

.PHONY: checkout build-artifact build-services demo clean
