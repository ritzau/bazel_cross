FROM ubuntu:26.04

RUN apt-get update
RUN apt-get install --yes --no-install-recommends ca-certificates curl direnv git libxml2

WORKDIR /src

# Ensure .cache exists and is owned by ubuntu user
# This prevents permission issues when mounting volumes or running bazelisk
RUN mkdir -p /home/ubuntu/.cache && chown -R ubuntu:ubuntu /home/ubuntu

# Hook direnv into bashrc for the ubuntu user
RUN echo 'eval "$(direnv hook bash)"' >> /home/ubuntu/.bashrc

USER ubuntu:ubuntu
