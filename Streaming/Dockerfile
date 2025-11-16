FROM postgres:17
COPY ./init-primary.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-primary.sh