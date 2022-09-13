
FROM mysql:8.0.30
RUN apt-get update && apt-get install -y openssh-client vim net-tools --no-install-recommends \ 
    && rm -rf /var/lib/apt/lists/* 
