FROM gitpod/workspace-base

RUN sudo apt-get update && sudo apt-get install -y haskell-platform nodejs npm
RUN sudo curl -sSL https://get.haskellstack.org/ | sh
RUN sudo curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
    && sudo gunzip elm.gz \
    && sudo chmod +x elm \
    && sudo mv elm /usr/local/bin/
RUN sudo npm install -g elm-test elm-format