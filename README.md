# parsedmarc-dockerized (Grafana Edition)

## Description

Fork of [patschi/parsedmarc-dockerized](https://github.com/patschi/parsedmarc-dockerized) with **Grafana replacing Kibana** for DMARC report visualization.

The upstream project's Kibana dashboards broke when parsedmarc moved to OpenSearch-only dashboard exports (see [patschi/parsedmarc-dockerized#59](https://github.com/patschi/parsedmarc-dockerized/issues/59)). This fork switches to Grafana, which is lighter, better maintained, and has native Elasticsearch datasource support with dashboards provided directly by the parsedmarc project.

### Changes from upstream
- **Grafana** replaces Kibana for dashboard visualization
- **Elasticsearch 8.17** replaces 7.17 (required by Grafana ES datasource plugin)
- **2GB JVM heap** default (up from 512MB) for better performance with growing data
- **Nginx removed** — use your own reverse proxy (HAProxy, Traefik, etc.) if external access is needed
- **Auto-provisioned** Elasticsearch datasources and DMARC dashboards
- Init container downloads dashboards from the parsedmarc Grafana directory

## Setup

1. Prepare the basics:

    ```bash
    git clone https://github.com/NachoTek/parsedmarc-dockerized.git /opt/parsedmarc-dockerized/
    cp /opt/parsedmarc-dockerized/data/conf/parsedmarc/config.sample.ini /opt/parsedmarc-dockerized/data/conf/parsedmarc/config.ini
    ```

2. Configure parsedmarc (see [parsedmarc documentation](https://domainaware.github.io/parsedmarc/#configuration-file)):

    ```bash
    nano /opt/parsedmarc-dockerized/data/conf/parsedmarc/config.ini
    ```

    **Important note**: This project's purpose is NOT to manage this configuration file for you. Should defaults change of the parsedmarc project, you must change the configuration file yourself.

3. Create the GeoIP environment file from your [MaxMind account](https://www.maxmind.com/en/account/sign-in):

    ```bash
    cat > /opt/parsedmarc-dockerized/geoipupdate.env <<EOF
    GEOIPUPDATE_ACCOUNT_ID=HERE_GOES_YOUR_ACCOUNT_ID
    GEOIPUPDATE_LICENSE_KEY=HERE_GOES_YOUR_LICENSE_KEY
    GEOIPUPDATE_FREQUENCY=24
    EOF
    ```

4. (Optional) Set Grafana admin credentials in a `.env` file:

    ```bash
    cat > /opt/parsedmarc-dockerized/.env <<EOF
    GRAFANA_ADMIN_USER=admin
    GRAFANA_ADMIN_PASSWORD=changeme
    EOF
    ```

5. Start the stack:

    ```bash
    cd /opt/parsedmarc-dockerized/
    docker compose up -d
    ```

    **Note**: Startup may take a couple of minutes, especially for Elasticsearch to become healthy.

### What's happening during startup?

1. Containers are created with health-check dependencies (services wait for dependencies to be fully running).
2. The `parsedmarc-init` container handles preparations: setting ES data permissions, setting Grafana data permissions, and downloading the latest Grafana dashboards from the parsedmarc project.
3. Grafana starts with auto-provisioned Elasticsearch datasources (`dmarc-ag` for aggregate reports, `dmarc-fo` for forensic reports) and DMARC dashboards.
4. Access Grafana directly at `http://HOST_IP:3000`.

### Accessing Grafana

- **Direct**: `http://HOST_IP:3000` (default port, configurable via `.env`)
- Default credentials: `admin` / `admin` (change via `.env` file before first start)
- For external access, place your own reverse proxy (HAProxy, Traefik, Caddy, etc.) in front of Grafana.

## Configuration

### Port configuration

Create a `.env` file to customize:

```bash
# Grafana direct access (HTTP) — default: 3000
GRAFANA_PORT_BINDING=3000:3000

# Grafana admin credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=changeme

# Grafana root URL (update if behind a reverse proxy)
GRAFANA_ROOT_URL=http://your-host:3000
```

**Examples:**

```bash
# Only listen on localhost
GRAFANA_PORT_BINDING=127.0.0.1:3000:3000

# Change Grafana port
GRAFANA_PORT_BINDING=8080:3000
```

### Multi-tenant (index prefix domain map)

If using `index_prefix_domain_map` in your parsedmarc config to separate tenants (e.g., `companya_dmarc_aggregate*`, `companyb_dmarc_aggregate*`), the pre-configured Elasticsearch datasources use wildcard index patterns (`*_dmarc_aggregate*` and `*_dmarc_forensic*`) that will match all tenant indices.

The dashboards include a `fromdomain` variable to filter by domain.

### Elasticsearch memory

Default JVM heap is 2GB (`ES_JAVA_OPTS=-Xms2g -Xmx2g`). For small deployments with few domains, you can reduce to 1GB. For large deployments with many domains, increase to 4GB. Remember to leave sufficient memory for the OS filesystem cache.

## Credits

Built with [parsedmarc](https://github.com/domainaware/parsedmarc), [Elasticsearch](https://www.elastic.co/), [Grafana](https://grafana.com/), [Docker](https://docker.com), and [MaxMind GeoIP](https://dev.maxmind.com/geoip/geoip2/geolite2/).

Based on [patschi/parsedmarc-dockerized](https://github.com/patschi/parsedmarc-dockerized) by Patrik Kernstock.

## Troubleshooting

### No data showing in Grafana dashboards

parsedmarc processes a certain number of emails (see `batch_size` in documentation) before saving to Elasticsearch. Check parsedmarc logs:

```bash
docker logs --tail 50 dmarc-tool-parsedmarc-1
```

You should see entries like:
```text
INFO:__init__.py:1019:Parsing mail from postmaster@example.com on 2020-09-19 23:04:13+00:00
INFO:elastic.py:364:Saving aggregate report to Elasticsearch
DEBUG:elastic.py:284:Creating Elasticsearch index: companya_dmarc_aggregate-2020-09-17
```

### Elasticsearch out of memory

If Elasticsearch logs show `OutOfMemoryError`, increase the JVM heap in `docker-compose.yml`:

```yaml
- "ES_JAVA_OPTS=-Xms4g -Xmx4g"
```

Make sure the host has enough RAM (heap + ~2x overhead for filesystem cache).
