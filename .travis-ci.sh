echo "yes" | sudo add-apt-repository ppa:avsm/ocaml42+opam12
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
sudo apt-get install build-essential autotools-dev automake libtool libpango1.0-dev libcairo2-dev
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
opam pin add macaque https://github.com/ocsigen/macaque.git
opam install ppx_deriving_yojson
opam pin add ocsigenserver https://github.com/ocsigen/ocsigenserver.git#cohttp_rebased
opam pin add eliom https://github.com/ocsigen/eliom.git#cohttp
opam install batteries eliom safepass oasis dbm mongo cairo2 macaque monomorphic ctypes ctypes-foreign batteries
git clone https://github.com/LamaUrbain/libosmscout
cd libosmscout
make full-install
cd ..
make
