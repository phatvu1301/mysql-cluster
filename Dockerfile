
FROM mysql:8.0.30
COPY init-master-master/ /init/
WORKDIR /init/
COPY ./init-master-master/new-entrypoint.sh /usr/local/bin/new-entrypoint.sh
RUN chmod +x /usr/local/bin/new-entrypoint.sh
ENTRYPOINT [ "new-entrypoint.sh" ]
CMD [ "mysqld" ]