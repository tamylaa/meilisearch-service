FROM getmeili/meilisearch:latest

# Meilisearch listens on 7700
ENV MEILI_HTTP_ADDR=0.0.0.0:7700
# MEILI_MASTER_KEY should be provided by the Railway environment variables

# Memory optimization for Railway free tier
ENV MEILI_MAX_INDEXING_MEMORY=50MB
ENV MEILI_MAX_INDEXING_THREADS=1
ENV MEILI_DB_PATH=/data/data.ms
ENV MEILI_DUMP_DIR=/data/dumps/

# Reduce analytics and telemetry to save memory
ENV MEILI_NO_ANALYTICS=true

EXPOSE 7700

# default entrypoint from image will start Meilisearch
