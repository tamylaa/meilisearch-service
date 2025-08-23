FROM getmeili/meilisearch:latest

# Meilisearch listens on 7700
ENV MEILI_HTTP_ADDR=0.0.0.0:7700
# MEILI_MASTER_KEY should be provided by the Railway environment variables
# Persist data to /data inside the container
VOLUME ["/data"]

EXPOSE 7700

# default entrypoint from image will start Meilisearch
