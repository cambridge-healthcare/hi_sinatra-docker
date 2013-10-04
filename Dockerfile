FROM howareyou/ruby:2.0.0-p247

ADD ./ /var/apps/hi_sinatra

RUN \
  . /.profile ;\
  rm -fr /var/apps/hi_sinatra/.git ;\
  cd /var/apps/hi_sinatra ;\
  bundle install --local && bin/test ;\
# END RUN

CMD . /.profile && cd /var/apps/hi_sinatra && bin/boot

EXPOSE 8000
