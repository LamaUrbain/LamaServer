echo "yes" | sudo add-apt-repository ppa:avsm/ocaml42+opam12
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
sudo apt-get install build-essential autotools-dev automake libtool libpango1.0-dev libcairo2-dev libxml2-dev libprotobuf-dev protobuf-compiler
sudo apt-get install libpcre3-dev libssl-dev libgdbm-dev libffi-dev
wget http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz
tar xvf autoconf-2.69.tar.gz
cd autoconf-2.69
./configure
make
sudo make install
cd ..
export OPAMYES=1
opam init
eval `opam config env`
opam pin add -n macaque https://github.com/ocsigen/macaque.git
opam pin add -n ocsigenserver https://github.com/ocsigen/ocsigenserver.git#cohttp_rebased
opam pin add -n eliom https://github.com/ocsigen/eliom.git#cohttp
opam install batteries eliom safepass oasis dbm mongo cairo2 macaque monomorphic ctypes ctypes-foreign batteries ppx_deriving_yojson
git clone https://github.com/LamaUrbain/libosmscout
cd libosmscout
make full-install
cd Import
./autogen.sh
./configure
make
cd ../maps
wget http://download.geofabrik.de/europe/france/picardie-latest.osm.pbf
./build.sh picardie-latest.osm.pbf
cd ../..
echo 'true: -traverse' >> _tags
echo 'true: not_hygienic' >> _tags
make
sed -i 's/MAP/libosmscout\/maps\/picardie-latest/g' ocsigenserver.conf
sed -i 's/STYLE/libosmscout\/stylesheets\/standard.oss/g' ocsigenserver.conf
make run
sleep 10
curl http://localhost:8080/users/0 -o check
check=`cat check`
if [[ ! $check =~ "User not found" ]]; then
    exit 1
fi
killall ocsigenserver
