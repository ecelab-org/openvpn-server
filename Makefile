include .env
export

all: run

EXTRA_SERVER_CONFIG ::= \
                        -u udp://${CL_SERVER_DOMAIN} \
						-C AES-256-GCM \
						-a SHA256 \
						-e 'duplicate-cn' \
						-e 'topology subnet'

build: .build_stamp
.build_stamp: .env
	docker volume create --name ${CL_OVPN_DATA}
	docker run -v ${CL_OVPN_DATA}:/etc/openvpn --rm kylemanna/openvpn \
		ovpn_genconfig ${EXTRA_SERVER_CONFIG}
	docker run -v ${CL_OVPN_DATA}:/etc/openvpn --rm -it kylemanna/openvpn sh -c \
		"sed -i 's/easyrsa build-server-full/easyrsa --days=${CL_CERT_EXP_PERIOD} build-server-full/g' \
		/usr/local/bin/ovpn_initpki && \
		ovpn_initpki"
	@echo "Build finished."
	@touch $@
	@echo

run: build create-client-config stop
	docker run -v ${CL_OVPN_DATA}:/etc/openvpn --restart unless-stopped --name=${CL_PROJECT_NAME} \
		-d -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn

debug-config: FORCE
	docker run --rm -it -v ${CL_OVPN_DATA}:/etc/openvpn --workdir=/etc/openvpn kylemanna/openvpn \
		bash -l

create-client-config: client.ovpn
client.ovpn: .env
	docker run -v ${CL_OVPN_DATA}:/etc/openvpn --rm -it kylemanna/openvpn easyrsa \
		--days=${CL_CERT_EXP_PERIOD} build-client-full client nopass
	docker run -v ${CL_OVPN_DATA}:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient client > \
		client.ovpn
	@echo "Done generating client certificates and config."
	@echo "Find the client [inline] config file at: $(shell pwd)/client.ovpn"
	@echo

stop: FORCE
	docker stop $(CL_PROJECT_NAME) || :
	docker rm $(CL_PROJECT_NAME) || :

remove-volume: FORCE
	docker volume rm ${CL_OVPN_DATA}

clean: stop remove-volume
	rm -f .build_stamp client.ovpn

Makefile: ;

FORCE:
