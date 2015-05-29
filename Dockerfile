FROM ubuntu:trusty
MAINTAINER lamaurbain
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common
RUN echo "yes" | add-apt-repository ppa:avsm/ocaml42+opam12
RUN DEBIAN_FRONTEND=noninteractive apt-get -qq -y update && apt-get -qq -y install wget ocaml ocaml-native-compilers camlp4-extra opam build-essential autotools-dev automake libtool libpango1.0-dev libcairo2-dev libxml2-dev libprotobuf-dev protobuf-compiler libpcre3-dev libssl-dev libgdbm-dev libffi-dev postgresql

RUN groupadd lamaurbain && useradd -m lamaurbain -g lamaurbain
EXPOSE 8000
WORKDIR /home/lamaurbain

RUN wget http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz
RUN tar xvf autoconf-2.69.tar.gz
RUN cd autoconf-2.69; ./configure; make; sudo make install

ENV OPAMYES 1
RUN opam init
RUN eval `opam config env`; opam pin add -n macaque https://github.com/ocsigen/macaque.git
RUN eval `opam config env`; opam install batteries eliom safepass oasis dbm mongo cairo2 macaque monomorphic ctypes ctypes-foreign batteries ppx_deriving_yojson
RUN git clone https://github.com/LamaUrbain/libosmscout
RUN cd libosmscout; make full-install; cd Import; ./autogen.sh; ./configure; make
RUN cd libosmscout/maps/; wget http://download.geofabrik.de/europe/france/picardie-latest.osm.pbf; LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib" ./build.sh picardie-latest.osm.pbf

ADD . /home/lamaurbain
RUN echo 'true: -traverse' >> _tags
RUN echo 'true: not_hygienic' >> _tags
RUN eval `opam config env`; make

RUN sed -i 's/MAP/libosmscout\/maps\/picardie-latest/g' ocsigenserver.conf
RUN sed -i 's/STYLE/libosmscout\/stylesheets\/standard.oss/g' ocsigenserver.conf
