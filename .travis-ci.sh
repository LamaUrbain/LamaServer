echo "yes" | sudo add-apt-repository ppa:avsm/ocaml41+opam11
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
sudo apt-get install libpcre3-dev libssl-dev libsqlite3-dev
export OPAMYES=1
opam init
eval `opam config env`
opam install batteries eliom safepass oasis
make
