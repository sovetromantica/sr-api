FROM debian:buster

RUN apt update && \
    apt install -y libmojolicious-perl libdbd-mysql-perl libyaml-libyaml-perl libfindbin-libs-perl libdbi-perl libanyevent-perl cpanminus make gcc

RUN mkdir /srapi
ADD ./start.sh /srapi/start.sh
ADD ./cpanfile /srapi/cpanfile
RUN mkdir /srapi/etc && touch /srapi/etc/db.cfg && chmod +x /srapi/start.sh

WORKDIR /srapi

RUN cpanm --installdeps /srapi
RUN cd /srapi 

ENTRYPOINT ["/srapi/start.sh"]
