FROM ubuntu:xenial

LABEL Description="Certificate Rotation SPIFFE: Blog"
LABEL vendor="SPIFFE"
LABEL version="0.1.0"

RUN apt-get update -y
RUN apt-get install -y openssl netcat

COPY conf /spire/.conf
COPY pconf /spire/plugin/agent/.conf
COPY artifact.tgz /
COPY ghostunnel /root/
COPY sidecar_config.hcl /sidecar/
COPY *.sh /spire/
RUN tar --directory / -xvzf /artifact.tgz

RUN addgroup spire && \
   adduser --uid 1111 --disabled-password --shell /bin/bash --ingroup spire spire
RUN chown -R spire /spire

RUN addgroup blog && \
   adduser --uid 1112 --disabled-password --shell /bin/bash --ingroup blog blog
RUN chown -R blog /sidecar

USER spire
WORKDIR /spire/
CMD ./spire-agent run
