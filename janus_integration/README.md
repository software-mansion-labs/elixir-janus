# Janus Integration Testing

This subproject is used for integration testing with live Janus Gateway instance.

## Running

Before running integration tests Janus Gateway should be started by running provided `docker-compose.yml` setup.

```bash
git submodule init
git submodule update
docker-compose up
```

If gateway is running test can be started with:

```bash
mix test
```
