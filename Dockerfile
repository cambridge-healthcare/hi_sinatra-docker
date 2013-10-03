FROM howareyou/ruby:2.0.0-p247

RUN \
  export RUBY_VERSION=2.0.0-p247 ;\
  add_to_profile() { [ $(grep -c "$1" /.profile) -eq 0 ] && echo "$1" >> /.profile; } ;\
  add_to_profile "export RUBY_VERSION=$RUBY_VERSION" ;\
  add_to_profile "export PATH=/usr/local/lib/$RUBY_VERSION/bin:$PATH" ;\
  add_to_profile "export SERVICE=hi_sinatra" ;\
  mkdir -p /var/apps ;\
# END RUN

# Cache buster!
ADD ./ /var/apps/hi_sinatra

RUN \
  . /.profile ;\
  rm -fr /var/apps/$SERVICE/.git ;\
  cd /var/apps/$SERVICE ;\
  bundle install --local && bin/test ;\
# END RUN

CMD . /.profile && cd /var/apps/$SERVICE && bin/boot

EXPOSE 8000
