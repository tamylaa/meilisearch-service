FROM getmeili/meilisearch:latest

# Meilisearch listens on 7700
ENV MEILI_HTTP_ADDR=0.0.0.0:7700
# MEILI_MASTER_KEY should be provided by the Railway environment variables
# Persist data to /data inside the container. Railway manages volumes separately;
# configure a Railway volume and mount it to /data in the Railway service settings
# (the VOLUME instruction is disallowed on Railway).

EXPOSE 7700

# default entrypoint from image will start Meilisearch
