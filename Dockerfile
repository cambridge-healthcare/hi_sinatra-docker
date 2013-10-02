FROM howareyou/ruby:2.0.0-p247

RUN \
  export RUBY_VERSION=2.0.0-p247 ;\
  echo "export RUBY_VERSION=$RUBY_VERSION" >> /.profile ;\
  echo "export PATH=/usr/local/lib/$RUBY_VERSION/bin:$PATH" >> /.profile ;\
  echo "export SERVICE=hi_sinatra" >> /.profile ;\
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
