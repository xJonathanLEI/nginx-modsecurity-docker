# Nginx with ModSecurity

## Acknowledgement

This repository is mostly copy-and-pasted from [the work by krish512](https://github.com/krish512/docker_nginx_modsecurity), with only some small changes.

## Docker Hub

Built images are available on [Docker Hub](https://hub.docker.com/r/xjonathanlei/nginx-modsecurity).

## Configuration

The following environment variables are available for simple configuration. For more sophisticated scenarios you need to edit conf files directly.

### MODSECURITY_DETECTION_ONLY

Whether ModSecurity rule engine should be running in `DetectionOnly` mode. Can be one of the following:

- true
- false

Defaults to `false`.